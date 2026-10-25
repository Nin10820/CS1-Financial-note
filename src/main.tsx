import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import "./styles/index.css"
import DesignSystem from "./pages/DesignSystem"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <DesignSystem />
  </StrictMode>,
)
