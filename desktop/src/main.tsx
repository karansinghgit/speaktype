import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "@/app/App";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { ToastProvider } from "@/components/ui";
import { StoreProvider } from "@/lib/store";
import "@/styles/globals.css";

if (import.meta.env.DEV) {
  const { installBrowserPreview } = await import("@/dev/browserPreview");
  installBrowserPreview();
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ErrorBoundary>
      <ToastProvider>
        <StoreProvider>
          <App />
        </StoreProvider>
      </ToastProvider>
    </ErrorBoundary>
  </StrictMode>,
);
