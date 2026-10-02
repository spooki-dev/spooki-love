#!/usr/bin/env bash
# Scaffold a new game from the spooki-love template.
#
#   ./init.sh ../my-game                 # copy this checkout into ../my-game and run the wizard
#   ./init.sh ../my-game --title "My Game" --author "Me" --itch myuser --yes
#   ./init.sh                            # in-place: rename a fresh clone of the template (cwd)
#   curl -fsSL https://raw.githubusercontent.com/spooki-dev/spooki-love/main/init.sh | bash -s my-game
#
# The wizard asks for the game title, author and itch.io username (Enter keeps
# the default shown in brackets), then rewrites every place the template says
# "New Game": conf.lua, main.lua, the Menu and marketing-asset wordmarks,
# scripts/release.sh, README.md and CHANGELOG.md. It does not run git init or
# export assets; it prints those as next steps. Needs bash 3.2+, git, perl, tar.
set -euo pipefail

TEMPLATE_REPO="${TEMPLATE_REPO:-https://github.com/spooki-dev/spooki-love.git}"
TEMPLATE_URL="https://github.com/spooki-dev/spooki-love"
LOVE=/Applications/love.app/Contents/MacOS/love

usage() {
  cat <<USAGE
usage: init.sh [target-dir] [options]

  target-dir        directory to create (must not exist or be empty). Omit it
                    to rename the template clone you are standing in.

options:
  --title "Name"    game title (default: derived from the target directory name)
  --author "Name"   author for the release script (default: git config user.name)
  --itch user       itch.io username; fills ITCH and ITCH_EDIT_URL in scripts/release.sh
  --uti id          macOS bundle identifier (default: com.spooki.<slug>)
  -y, --yes         accept defaults for anything not given, no prompts
  -h, --help        show this help

environment:
  TEMPLATE_REPO     git URL cloned when the script is not run from a checkout
                    (default: $TEMPLATE_REPO)
USAGE
}

die() { echo "init.sh: $*" >&2; exit 1; }

TARGET=""
TITLE=""
AUTHOR=""
ITCH_USER=""
UTI=""
YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   [[ $# -ge 2 ]] || die "--title needs a value"; TITLE="$2"; shift 2 ;;
    --title=*) TITLE="${1#*=}"; shift ;;
    --author)   [[ $# -ge 2 ]] || die "--author needs a value"; AUTHOR="$2"; shift 2 ;;
    --author=*) AUTHOR="${1#*=}"; shift ;;
    --itch)   [[ $# -ge 2 ]] || die "--itch needs a value"; ITCH_USER="$2"; shift 2 ;;
    --itch=*) ITCH_USER="${1#*=}"; shift ;;
    --uti)   [[ $# -ge 2 ]] || die "--uti needs a value"; UTI="$2"; shift 2 ;;
    --uti=*) UTI="${1#*=}"; shift ;;
    -y|--yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; [[ $# -le 1 ]] || die "unexpected argument: $2"; [[ $# -eq 0 ]] || { [[ -z "$TARGET" ]] || die "unexpected argument: $1"; TARGET="$1"; shift; } ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) [[ -z "$TARGET" ]] || die "unexpected argument: $1"; TARGET="$1"; shift ;;
  esac
done

# --- Where is the template? -------------------------------------------------

is_template() { [[ -f "$1/main.lua" && -d "$1/engine" && -f "$1/scripts/release.sh" ]]; }

SRC=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  is_template "$SCRIPT_DIR" && SRC="$SCRIPT_DIR"
fi

# --- Pick the mode -------------------------------------------------------------------

IN_PLACE=0
CREATED=0
TEMPLATE_REV=main
if [[ -z "$TARGET" ]]; then
  is_template "$PWD" || { usage >&2; die "pass a target directory, or run from inside a clone of the template to rename it in place"; }
  IN_PLACE=1
  DEST="$PWD"
  TEMPLATE_REV=$(git -C "$DEST" rev-parse --short HEAD 2>/dev/null || echo main)
else
  if [[ -e "$TARGET" ]]; then
    [[ -d "$TARGET" ]] || die "$TARGET exists and is not a directory"
    [[ -z "$(ls -A "$TARGET")" ]] || die "$TARGET is not empty"
    DEST=$(cd "$TARGET" && pwd)
  else
    DEST=$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET") \
      || die "parent directory of $TARGET does not exist"
  fi
  [[ -n "$SRC" ]] || command -v git >/dev/null || die "git is required to fetch the template"
fi

# Copies the template into $DEST (not used in place). Called after the wizard
# so an aborted run leaves nothing behind.
fetch_template() {
  if [[ ! -d "$DEST" ]]; then
    mkdir -p "$DEST"
    CREATED=1
  fi
  if [[ -n "$SRC" ]]; then
    echo "==> Copying template from $SRC"
    TEMPLATE_REV=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo main)
    if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      # Tracked plus untracked-but-not-ignored files, so .gitignore keeps
      # releases/, scripts/node_modules/, *.love and local settings out.
      git -C "$SRC" ls-files -z --cached --others --exclude-standard \
        | (cd "$SRC" && tar -c --null -T - -f -) \
        | tar -x -C "$DEST" -f -
    else
      tar -C "$SRC" -c \
        --exclude .git --exclude releases --exclude designs --exclude node_modules \
        --exclude .DS_Store --exclude '*.love' --exclude '.aider*' \
        --exclude .claude/settings.local.json \
        -f - . | tar -x -C "$DEST" -f -
    fi
  else
    echo "==> Cloning $TEMPLATE_REPO"
    git clone --quiet --depth 1 "$TEMPLATE_REPO" "$DEST"
    TEMPLATE_REV=$(git -C "$DEST" rev-parse --short HEAD 2>/dev/null || echo main)
    rm -rf "$DEST/.git"
  fi
  is_template "$DEST" || die "$DEST does not look like the spooki-love template after copying"
}

# Remove a directory this run created if anything fails after the copy starts.
cleanup() {
  local status=$?
  if [[ $status -ne 0 && $CREATED -eq 1 && -d "$DEST" ]]; then
    rm -rf "$DEST"
    echo "init.sh: removed incomplete $DEST" >&2
  fi
}
trap cleanup EXIT

command -v perl >/dev/null || die "perl is required"

# --- Wizard -------------------------------------------------------------------

# Prompts read from the terminal directly so `curl ... | bash` still works.
have_tty() { ( : </dev/tty ) 2>/dev/null; }

# ask VAR "Prompt" "default": sets VAR to the answer, or the default on Enter.
ask() {
  local var="$1" prompt="$2" default="$3" answer
  if [[ $YES -eq 1 ]]; then
    printf -v "$var" '%s' "$default"
    return
  fi
  have_tty || die "no terminal to ask questions on; pass --yes or the --title/--author/--itch flags"
  if [[ -n "$default" ]]; then
    read -r -e -p "$prompt [$default]: " answer </dev/tty
  else
    read -r -e -p "$prompt: " answer </dev/tty
  fi
  printf -v "$var" '%s' "${answer:-$default}"
}

title_from_dir() {
  # controller-demo -> Controller Demo
  perl -e '$_ = shift; s/[-_.]+/ /g; s/^\s+|\s+$//g; s/(\w+)/\u$1/g; print' -- "$(basename "$1")"
}

DEFAULT_TITLE=$(title_from_dir "$DEST")
DEFAULT_AUTHOR=$(git config user.name 2>/dev/null || true)
DEFAULT_AUTHOR="${DEFAULT_AUTHOR:-Your Name}"

echo
echo "spooki-love: new game in $DEST"
echo
while [[ -z "$TITLE" ]]; do
  ask TITLE "Game title" "$DEFAULT_TITLE"
  [[ -n "$TITLE" ]] || { [[ $YES -eq 0 ]] || die "a title is required (--title)"; echo "A title is required." >&2; }
done
[[ -n "$AUTHOR" ]] || ask AUTHOR "Author" "$DEFAULT_AUTHOR"
[[ -n "$ITCH_USER" ]] || ask ITCH_USER "itch.io username (Enter to skip)" ""

# --- Derived values -------------------------------------------------------------

SLUG=$(perl -e '$_ = shift; s/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g; print lc' -- "$TITLE")
[[ -n "$SLUG" ]] || die "could not derive a slug from title '$TITLE'; use letters or digits"
PKG="$SLUG"
[[ -n "$UTI" ]] || UTI="com.spooki.$SLUG"
TITLE_UPPER=$(perl -e 'print uc shift' -- "$TITLE")
INITIAL=$(perl -e '$_ = shift; /([A-Za-z0-9])/ and print uc $1' -- "$TITLE")
[[ -n "$INITIAL" ]] || INITIAL="$(perl -e 'print substr(shift, 0, 1)' -- "$TITLE_UPPER")"
# Escaped forms for the files they land in.
lua_str() { perl -e '$_ = shift; s/([\\"])/\\$1/g; print' -- "$1"; }
sh_str()  { perl -e '$_ = shift; s/([\\"\$`])/\\$1/g; print' -- "$1"; }
TITLE_LUA=$(lua_str "$TITLE")
UPPER_LUA=$(lua_str "$TITLE_UPPER")
LINES_LUA=$(perl -e 'my @w = split /\s+/, shift; s/([\\"])/\\$1/g for @w; print "{ " . join(", ", map { "\"$_\"" } @w) . " }"' -- "$TITLE_UPPER")
TITLE_SH=$(sh_str "$TITLE")
AUTHOR_SH=$(sh_str "$AUTHOR")
ITCH_OWNER="${ITCH_USER:-your-itch-username}"
ITCH="$ITCH_OWNER/$SLUG"
ITCH_EDIT_URL="https://$ITCH_OWNER.itch.io/$SLUG/edit"

cat <<SUMMARY

  Title       $TITLE
  Wordmark    $LINES_LUA  (favicon "$INITIAL")
  Author      $AUTHOR
  Slug / PKG  $SLUG
  Bundle id   $UTI
  itch.io     $ITCH$( [[ -n "$ITCH_USER" ]] || printf '  (placeholder, set ITCH in scripts/release.sh later)' )
  Directory   $DEST$( [[ $IN_PLACE -eq 0 ]] || printf '  (in place)' )

SUMMARY

if [[ $YES -eq 0 ]]; then
  have_tty || die "no terminal to confirm on; pass --yes"
  read -r -p "Create? [Y/n] " confirm </dev/tty
  case "$confirm" in
    ""|y|Y|yes|YES|Yes) ;;
    *) echo "aborted"; exit 1 ;;
  esac
fi

[[ $IN_PLACE -eq 1 ]] || fetch_template

# --- Rename -----------------------------------------------------------------------

# replace_exact FILE ANCHOR REPLACEMENT: every occurrence of the literal ANCHOR
# becomes REPLACEMENT. The anchor must exist, so if the template changes the
# words this script looks for, the scaffold fails loudly instead of shipping
# "New Game".
replace_exact() {
  local file="$DEST/$1"
  [[ -f "$file" ]] || die "missing $1 in the template"
  grep -qF -- "$2" "$file" || die "expected to find '$2' in $1; update init.sh to match the template"
  ANCHOR="$2" REPL="$3" perl -pi -e 's/\Q$ENV{ANCHOR}\E/$ENV{REPL}/g' "$file"
}

echo "==> Renaming \"New Game\" to \"$TITLE\""
replace_exact conf.lua  't.window.title = "New Game"' "t.window.title = \"$TITLE_LUA\""
replace_exact conf.lua  't.identity = "newgame"' "t.identity = \"$PKG\""
replace_exact main.lua  'title = "New Game",'         "title = \"$TITLE_LUA\","
replace_exact CLAUDE.md 'title = "New Game",'         "title = \"$TITLE_LUA\","
replace_exact scenes/Menu.lua '"NEW GAME"' "\"$UPPER_LUA\""
replace_exact scenes/assets/Logo.lua 'lines = { "NEW GAME" }' "lines = { \"$UPPER_LUA\" }"
for scene in Cover Wide Social Icon; do
  replace_exact "scenes/assets/$scene.lua" 'lines = { "NEW", "GAME" }' "lines = $LINES_LUA"
done
replace_exact scenes/assets/Favicon.lua 'lines = { "N" }' "lines = { \"$INITIAL\" }"

replace_exact scripts/release.sh 'TITLE="New Game"'  "TITLE=\"$TITLE_SH\""
replace_exact scripts/release.sh 'PKG=newgame'       "PKG=$PKG"
replace_exact scripts/release.sh 'UTI=com.example.newgame' "UTI=$UTI"
replace_exact scripts/release.sh 'AUTHOR="Your Name"' "AUTHOR=\"$AUTHOR_SH\""
replace_exact scripts/release.sh 'ITCH=your-itch-username/your-game-slug' "ITCH=$ITCH"
replace_exact scripts/release.sh 'ITCH_EDIT_URL="https://your-itch-username.itch.io/your-game-slug/edit"' "ITCH_EDIT_URL=\"$ITCH_EDIT_URL\""

# The template docs describe init.sh itself; a scaffolded game has no init.sh.
grep -q '^### Scaffolding$' "$DEST/CLAUDE.md" || die "expected a '### Scaffolding' section in CLAUDE.md; update init.sh to match the template"
perl -0pi -e 's/^### Scaffolding\n.*?(?=^### )//ms' "$DEST/CLAUDE.md"
replace_exact AGENTS.md ' `init.sh` at the root scaffolds a new game from this template (wizard for title/author/itch; it rewrites the "New Game" literals, so keep those anchors or update the script).' ''

echo "==> Writing README.md and CHANGELOG.md"
cat >"$DEST/README.md" <<README
# $TITLE

A LÖVE (Love2D) 11.5 game built on the [spooki-love]($TEMPLATE_URL) engine template.

## Run

\`\`\`sh
# love is not on PATH on macOS:
$LOVE .
\`\`\`

Hot reload is on in dev: saved edits under \`engine/\`, \`scenes/\`, \`gameObjects/\`, \`constants/\` and \`state/\` reload automatically (backtick forces it). A dev MCP bridge listens on port 12345.

## Develop

- Scenes live in \`scenes/\` and are registered in \`main.lua\` (\`Preload\` first). See \`docs/CreatingANewScene.md\`.
- Entities go in \`gameObjects/\`, data in \`constants/\`, shared state in \`state/GameState.lua\`.
- \`engine/\` is the shared engine. Configure it through the \`Game\` table in \`main.lua\` rather than editing it.
- The web build runs on Lua 5.1 (love.js), so avoid \`goto\` and LuaJIT-only modules. \`scripts/lint-lua51.sh\` checks every tracked Lua file; enable the pre-commit hook with \`git config core.hooksPath .githooks\`.
- Marketing art in \`assets/generated/\` is rendered from \`scenes/assets/*.lua\` by \`love . --export-assets\`.

## Release

\`\`\`sh
scripts/release.sh            # export assets, build Mac/Windows/web/.love, push to itch.io
scripts/release.sh --no-push  # build only; artefacts land in releases/$PKG/
$LOVE . --export-assets       # regenerate assets/generated/*.png only
\`\`\`

\`TITLE\`, \`PKG\`, \`UTI\`, \`AUTHOR\` and \`ITCH\` are set at the top of \`scripts/release.sh\`. Requires \`love-release\`, \`love.js\`, \`butler\` (logged in), node and the macOS \`iconutil\`/\`sips\`/\`plutil\` tools.

See \`CLAUDE.md\` for the architecture and engine contracts, and \`AGENTS.md\` for the short version.
README

cat >"$DEST/CHANGELOG.md" <<CHANGELOG
# Changelog

## $(date +%Y-%m-%d)

- Scaffolded from [spooki-love]($TEMPLATE_URL) ($TEMPLATE_REV).
CHANGELOG

rm -f "$DEST/init.sh"

# --- Done -----------------------------------------------------------------------

if [[ $IN_PLACE -eq 1 ]]; then
  origin=$(git -C "$DEST" remote get-url origin 2>/dev/null || true)
  if [[ "$origin" == *spooki-love* ]]; then
    echo
    echo "note: the origin remote still points at the template ($origin)."
    echo "      Point it at the new game's repo: git remote set-url origin <url>"
  fi
fi

leftovers=$(grep -rIl --exclude-dir=.git --exclude-dir=releases -e 'New Game' -e 'NEW GAME' -e newgame "$DEST" || true)
[[ -z "$leftovers" ]] || { echo "warning: the template name is still mentioned in:" >&2; echo "$leftovers" >&2; }

cat <<NEXT

Done. $TITLE is in $DEST

Next steps:
  cd $DEST
  git init && git config core.hooksPath .githooks
  $LOVE . --export-assets   # regenerate icons/covers with the new name
  $LOVE .
NEXT
