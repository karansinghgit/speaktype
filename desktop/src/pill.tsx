import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { Pill } from "@/pill/Pill";
import "@/styles/globals.css";

if (import.meta.env.DEV) {
  const { installBrowserPreview } = await import("@/dev/browserPreview");
  installBrowserPreview();
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Pill />
  </StrictMode>,
);
