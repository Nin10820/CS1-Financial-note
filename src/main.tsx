import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import "./styles/index.css"
import App from "./App"
import DesignSystem from "./pages/DesignSystem"

/* #/design-system opens the component reference; everything else is the app. */
const Root = () => (location.hash === "#/design-system" ? <DesignSystem /> : <App />)

window.addEventListener("hashchange", () => location.reload())

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
)
