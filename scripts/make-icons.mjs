// Builds the PWA / home-screen icons from the Figma logo mark: white asterisk on the brand green.
// Run: node scripts/make-icons.mjs  (writes into public/icons)
import { readFileSync, mkdirSync } from "node:fs"
import sharp from "sharp"

const mark = readFileSync(new URL("../src/assets/icons/logo-mark.svg", import.meta.url), "utf8")
const inner = mark
  .replace(/^[\s\S]*?<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "")
  // The export sets the colour twice: a fill attribute and a style with a P3 colour. Make both white.
  .replace(/style="[^"]*"/g, "")
  .replace(/fill="#5FA82F"/gi, 'fill="#ffffff"')
const [vw, vh] = mark.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/).slice(1).map(Number)

/** `scale` = how much of the square the mark fills; maskable icons need a smaller mark (safe zone). */
function icon(size, scale, { rounded = false } = {}) {
  const markH = size * scale
  const k = markH / vh
  const x = (size - vw * k) / 2
  const y = (size - markH) / 2
  const r = rounded ? size * 0.225 : 0
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7cc447"/>
      <stop offset="0.55" stop-color="#5fa82f"/>
      <stop offset="1" stop-color="#3f7d1f"/>
    </linearGradient>
    <linearGradient id="s" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="${size}" height="${size}" rx="${r}" fill="url(#g)"/>
  <rect width="${size}" height="${size}" rx="${r}" fill="url(#s)"/>
  <g transform="translate(${x} ${y}) scale(${k})">${inner}</g>
</svg>`
}

mkdirSync(new URL("../public/icons", import.meta.url), { recursive: true })
const out = (name) => new URL(`../public/icons/${name}`, import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")

const jobs = [
  ["apple-touch-icon.png", 180, 0.56], // iOS adds its own rounded corners
  ["icon-192.png", 192, 0.56],
  ["icon-512.png", 512, 0.56],
  ["icon-maskable-512.png", 512, 0.42], // Android safe zone
  ["favicon-32.png", 32, 0.64, { rounded: true }],
]
for (const [name, size, scale, opts] of jobs) {
  await sharp(Buffer.from(icon(size, scale, opts))).png().toFile(out(name))
  console.log("wrote", name)
}
