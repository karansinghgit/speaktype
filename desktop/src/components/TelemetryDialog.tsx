import { Check, Copy, Power } from "lucide-react";
import { useState } from "react";
import { Button, Dialog } from "@/components/ui";
import { api, type TelemetryPayload } from "@/lib/api";

export function TelemetryDialog({
  payload,
  isExit,
  onClose,
}: {
  payload: TelemetryPayload | null;
  isExit?: boolean;
  onClose: () => void;
}) {
  const [copied, setCopied] = useState(false);

  const copy = () => {
    if (!payload) return;
    navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formattedJson = payload ? JSON.stringify(payload, null, 2) : "";

  return (
    <Dialog
      open={Boolean(payload)}
      onClose={onClose}
      width={520}
      title="Telemetry Payload"
      description={
        isExit
          ? "The following anonymous telemetry payload is being sent on exit."
          : "Review the current anonymous telemetry payload."
      }
      footer={
        <>
          <Button onClick={onClose}>{isExit ? "Cancel" : "Close"}</Button>
          {isExit && (
            <Button
              variant="primary"
              icon={Power}
              onClick={() => {
                api.quitApp(true);
                onClose();
              }}
            >
              Exit SpeakType
            </Button>
          )}
        </>
      }
    >
      <div className="rounded-card border border-line-subtle bg-surface-sunken p-3.5">
        <div className="mb-2 flex items-center justify-between">
          <span className="type-overline text-ink-muted">JSON Payload</span>
          <Button
            size="sm"
            variant="ghost"
            icon={copied ? Check : Copy}
            onClick={copy}
            className="h-7 px-2 text-xs"
          >
            {copied ? "Copied" : "Copy JSON"}
          </Button>
        </div>
        <pre
          data-selectable
          className="max-h-64 overflow-y-auto font-mono text-[11px] leading-relaxed text-ink-secondary selection:bg-accent/30"
        >
          {formattedJson}
        </pre>
      </div>
    </Dialog>
  );
}
