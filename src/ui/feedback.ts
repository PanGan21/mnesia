import { LIMITS } from "../config";
import type { Elements } from "./elements";

/** Short confirmations at the bottom of the screen, announced to screen readers. */
export class Toast {
  private timer: ReturnType<typeof setTimeout> | undefined;

  constructor(private readonly element: HTMLElement) {}

  show(message: string): void {
    clearTimeout(this.timer);
    this.element.textContent = message;
    this.element.hidden = false;
    this.timer = setTimeout(() => {
      this.element.hidden = true;
    }, LIMITS.toastDurationMs);
  }
}

export class ProgressPanel {
  constructor(private readonly elements: Elements["progress"]) {}

  show(title: string, detail: string, percent: number): void {
    this.elements.panel.hidden = false;
    this.elements.title.textContent = title;
    this.elements.detail.textContent = detail;
    this.elements.fill.style.width = `${Math.max(0, Math.min(100, percent))}%`;
  }

  hide(): void {
    this.elements.panel.hidden = true;
  }
}

/** A modal yes/no question. Resolves true only when the person confirms. */
export class ConfirmDialog {
  constructor(private readonly elements: Elements["confirm"]) {}

  ask({
    title,
    body,
    confirmLabel,
  }: {
    title: string;
    body: string;
    confirmLabel: string;
  }): Promise<boolean> {
    const { dialog } = this.elements;
    this.elements.title.textContent = title;
    this.elements.body.textContent = body;
    this.elements.accept.textContent = confirmLabel;
    dialog.returnValue = "";

    return new Promise((resolve) => {
      dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), {
        once: true,
      });
      dialog.showModal();
    });
  }
}
