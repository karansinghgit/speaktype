import { X } from "lucide-react";
import { useEffect, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { cn } from "@/lib/cn";
import { Button, IconButton } from "./Button";

export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  width = 440,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: ReactNode;
  children?: ReactNode;
  footer?: ReactNode;
  width?: number;
}) {
  const panel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const previous = document.activeElement as HTMLElement | null;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    // Focus the first field, or the panel itself.
    const first = panel.current?.querySelector<HTMLElement>("input, textarea, [data-autofocus]");
    (first ?? panel.current)?.focus();
    return () => {
      document.removeEventListener("keydown", onKey);
      previous?.focus();
    };
  }, [open, onClose]);

  if (!open) return null;
  return createPortal(
    <div className="fixed inset-0 z-40 flex items-center justify-center p-6">
      <div className="absolute inset-0 animate-fade-in bg-black/25 backdrop-blur-[2px] dark:bg-black/50" onClick={onClose} />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        style={{ width }}
        className="relative max-h-full animate-pop-in overflow-y-auto rounded-panel border border-line bg-surface shadow-elevated outline-none"
      >
        <div className="flex items-start gap-3 px-6 pt-5">
          <div className="flex-1">
            <h2 className="type-section">{title}</h2>
            {description && <p className="mt-1 type-small text-ink-secondary">{description}</p>}
          </div>
          <IconButton icon={X} label="Close" size="sm" onClick={onClose} className="-mr-2" />
        </div>
        {children && <div className="px-6 pt-4">{children}</div>}
        <div className={cn("flex justify-end gap-2 px-6 pt-5 pb-5")}>{footer}</div>
      </div>
    </div>,
    document.body,
  );
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  description,
  confirmLabel,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  description?: ReactNode;
  confirmLabel: string;
}) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      description={description}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button
            data-autofocus
            variant="primary"
            onClick={() => {
              onConfirm();
              onClose();
            }}
          >
            {confirmLabel}
          </Button>
        </>
      }
    />
  );
}
