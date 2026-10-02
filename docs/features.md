# Features Documentation

This document outlines the key features of our application.

## Feature 1: Game Object System

- **Description**: The game object system allows for the creation and management of game objects.
- **Usage**: Use the `GameObject` class to create and manage game objects.

## Feature 2: Scene Management

- **Description**: The scene management system allows for the creation and management of scenes.
- **Usage**: Use the `Scene` class to create and manage scenes.

## Feature 3: Cache Manager

- **Description**: The cache manager handles caching of spritesheets and other resources.
- **Usage**: Use the `cacheManager` to manage cached resources.

## Feature 4: Audio Management

- **Description**: The audio manager provides a centralized way to handle audio playback, including loading, playing, and managing sound effects and music.
- **Usage**: Use the `audioManager` to load and play audio files.

  ```lua
  -- Example usage of audioManager

  -- Load a sound effect
  local soundEffect = audioManager.loadSound("assets/sounds/boom.wav")

  -- Play the sound effect
  audioManager.playSound(soundEffect)

  -- Load background music
  local music = audioManager.loadMusic("assets/music/theme.mp3")

  -- Play the background music
  audioManager.playMusic(music)

  -- Stop the background music
  audioManager.stopMusic()
  ```

  The `audioManager` can programmatically create sounds and play them. It supports both sound effects and background music, allowing for flexible audio management in the game.

## Feature 5: Asset Export

- **Description**: Scenes can be rendered offscreen at exact pixel sizes and written as PNGs. Used for icons, covers and logos so marketing art follows the game's fonts and colours.
- **Usage**: Add an `assets` block to the `Game` config with `{ name, scene, width, height, postProcess?, transparent? }` items, where `scene` is a Scene constructor taking `(width, height)`. Run `love . --export-assets`.

## Feature 7: Input Actions

- **Description**: Named actions with keyboard, mouse and gamepad bindings; analog strength and vector composition; rebinding with persistence; on-screen prompts that follow the active device; keyboard/gamepad menu navigation.
- **Usage**: Declare actions in the `input` block of the `Game` config, read them with `inputMap.down/pressed/strength/vector`, show them with `InputPrompt`, and keep `scenes/Controls.lua` for remapping. See `docs/Input.md`.

## Feature 6: Saving

- **Description**: `engine/saveManager.lua` persists one plain-data table to LÖVE's save directory as Lua source. Every call is safe: when storage is unavailable, `save` returns false and `load` returns nil instead of raising. Saves carry a schema `version`; a `migrate` function can upgrade old files.
- **Usage**:

  ```lua
  local saveManager = require "engine.saveManager"
  saveManager.configure({ filename = "save.lua", version = 1 })

  -- in the game scene
  function GameScene:onQuit()            -- called by Game:quit
    saveManager.save({ level = self.level, hp = self.hp })
  end

  -- in the menu
  if saveManager.exists() then
    local data = saveManager.load()      -- nil if corrupt or incompatible
    local game = sceneManager.resetScene("Game")
    game:resumeFromSave(data)            -- apply it in GameScene:start()
    sceneManager.setCurrentScene("Game")
  end
  ```

  Set `t.identity` in `conf.lua` so the save directory is the same for source runs and packaged builds. On the web build the page template flushes IndexedDB on tab hide and every 10 s.
