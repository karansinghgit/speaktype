import { RotateCw, TriangleAlert } from "lucide-react";
import { Button, Card, IconTile, Spinner } from "@/components/ui";

/** Shown while the app is still reaching its core, and if it can't. */
export function StartupScreen({ error, onRetry }: { error?: string; onRetry?: () => void }) {
  if (!error) {
    return (
      <div className="flex h-full items-center justify-center bg-app">
        <Spinner size={22} className="text-ink-muted" />
      </div>
    );
  }
  return (
    <div className="flex h-full items-center justify-center bg-app p-10">
      <Card padding="lg" className="flex max-w-[460px] flex-col items-center text-center">
        <IconTile icon={TriangleAlert} tone="danger" size="md" />
        <h1 className="mt-4 type-section">SpeakType couldn't start</h1>
        <p className="mt-1.5 type-body text-ink-secondary">
          Something went wrong while the app was starting up. Trying again usually fixes it.
        </p>
        <p className="mt-4 w-full rounded-control bg-surface-sunken px-3 py-2 type-small break-words text-ink-muted">
          {error}
        </p>
        {onRetry && (
          <Button variant="accent" icon={RotateCw} className="mt-6" onClick={onRetry}>
            Try again
          </Button>
        )}
      </Card>
    </div>
  );
}
