import { Component, type ErrorInfo, type ReactNode } from "react";
import { AlertCircle, RefreshCw } from "lucide-react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public override state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public override componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("[ErrorBoundary] Caught unhandled React error:", error, errorInfo);
  }

  private handleReload = () => {
    window.location.reload();
  };

  public override render() {
    if (this.state.hasError) {
      return (
        <div className="flex h-screen w-screen flex-col items-center justify-center bg-app p-8 text-ink">
          <div className="flex max-w-[500px] flex-col items-center rounded-2xl border border-line bg-surface p-8 text-center shadow-lg">
            <div className="mb-4 flex size-12 items-center justify-center rounded-full bg-danger-soft text-danger">
              <AlertCircle size={24} />
            </div>
            <h2 className="text-xl font-bold">Something went wrong</h2>
            <p className="mt-2 text-sm text-ink-secondary">
              SpeakType encountered an initialization or rendering error.
            </p>
            {this.state.error && (
              <pre className="mt-4 max-h-36 w-full overflow-auto rounded-lg bg-surface-sunken p-3 text-left font-mono text-xs text-ink-muted">
                {this.state.error.message || String(this.state.error)}
              </pre>
            )}
            <button
              onClick={this.handleReload}
              className="mt-6 flex items-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-medium text-on-primary transition hover:bg-primary-hover"
            >
              <RefreshCw size={16} />
              Reload App
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
