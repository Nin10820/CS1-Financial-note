/** Profile › Display › Appearance: follow the phone, or always light / dark. */
export type Appearance = "auto" | "light" | "dark"

const media = () => window.matchMedia("(prefers-color-scheme: dark)")

/** Sets data-theme on <html> (the dark tokens hang off it) and the browser bar colour. */
export function applyAppearance(a: Appearance = "auto") {
  const dark = a === "dark" || (a === "auto" && media().matches)
  document.documentElement.dataset.theme = dark ? "dark" : "light"
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", dark ? "#0c1019" : "#eaecf0")
}

/** Keeps "auto" in step when the phone switches between light and dark. */
export function watchAppearance(a: Appearance) {
  applyAppearance(a)
  if (a !== "auto") return () => {}
  const m = media()
  const on = () => applyAppearance("auto")
  m.addEventListener("change", on)
  return () => m.removeEventListener("change", on)
}

/** Read straight from storage before the first paint, so the page never flashes white. */
export function savedAppearance(): Appearance {
  try {
    const raw = localStorage.getItem("financial-note:v1")
    const a = raw ? (JSON.parse(raw) as { prefs?: { appearance?: Appearance } }).prefs?.appearance : undefined
    return a ?? "auto"
  } catch {
    return "auto"
  }
}
