// Replaces every icon group in a Windows PE (love.exe) with icons built from
// the given PNGs. Pure JS via pe-library/resedit, so it runs on macOS.
//
//   node scripts/patch-win-icon.mjs <in.exe> <out.exe> <png> [<png>...]
import fs from "node:fs";
import { NtExecutable, NtExecutableResource, Data, Resource } from "resedit";
import pngToIco from "png-to-ico";

const [, , input, output, ...pngs] = process.argv;
if (!input || !output || pngs.length === 0) {
  console.error("usage: patch-win-icon.mjs <in.exe> <out.exe> <png> [<png>...]");
  process.exit(2);
}

const toArrayBuffer = (buf) => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);

const exe = NtExecutable.from(toArrayBuffer(fs.readFileSync(input)), { ignoreCert: true });
const res = NtExecutableResource.from(exe);
const iconFile = Data.IconFile.from(toArrayBuffer(await pngToIco(pngs)));
const icons = iconFile.icons.map((item) => item.data);

const groups = Resource.IconGroupEntry.fromEntries(res.entries);
if (groups.length === 0) {
  console.error(`${input}: no icon groups found`);
  process.exit(1);
}
for (const group of groups) {
  Resource.IconGroupEntry.replaceIconsForResource(res.entries, group.id, group.lang, icons);
}
res.outputResource(exe);
fs.writeFileSync(output, Buffer.from(exe.generate()));
console.log(`patched ${groups.length} icon group(s) -> ${output}`);
