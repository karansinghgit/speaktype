import { Component, type ReactNode } from "react";
import { StartupScreen } from "@/components/StartupScreen";

/**
 * Catches render errors so a bug in one screen shows a message instead of a
 * blank window. React has no hook for this, so it has to be a class.
 */
export class ErrorBoundary extends Component<{ children: ReactNode }, { error?: string }> {
  override state: { error?: string } = {};

  static getDerivedStateFromError(error: unknown) {
    return { error: error instanceof Error ? error.message : String(error) };
  }

  override componentDidCatch(error: unknown) {
    console.error("[ui]", error);
  }

  override render() {
    if (this.state.error !== undefined) {
      return <StartupScreen error={this.state.error} onRetry={() => window.location.reload()} />;
    }
    return this.props.children;
  }
}
