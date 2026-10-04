import { formatBytes, formatDate, formatDuration } from "../lib/format";
import type { MediaRecord } from "../types";
import type { Elements } from "./elements";

/** Full-screen viewer that steps through the current results. */
export class Viewer {
  private records: readonly MediaRecord[] = [];
  private index = -1;
  private objectUrl: string | null = null;

  constructor(private readonly elements: Elements["viewer"]) {
    const { dialog } = elements;
    elements.prev.addEventListener("click", () => this.step(-1));
    elements.next.addEventListener("click", () => this.step(1));
    elements.close.addEventListener("click", () => dialog.close());
    dialog.addEventListener("keydown", (event) => {
      if (event.key === "ArrowLeft") {
        this.step(-1);
      } else if (event.key === "ArrowRight") {
        this.step(1);
      }
    });
    dialog.addEventListener("close", () => {
      elements.body.replaceChildren();
      this.releaseObjectUrl();
      this.index = -1;
    });
  }

  open(records: readonly MediaRecord[], index: number): void {
    if (!records[index]) {
      return;
    }
    this.records = records;
    this.show(index);
    if (!this.elements.dialog.open) {
      this.elements.dialog.showModal();
    }
  }

  private step(delta: number): void {
    const next = this.index + delta;
    if (next >= 0 && next < this.records.length) {
      this.show(next);
    }
  }

  private show(index: number): void {
    const record = this.records[index];
    if (!record) {
      return;
    }
    this.index = index;
    this.releaseObjectUrl();

    // Records kept only for this session, or saved by older versions, may have no
    // original file; the preview is the fallback.
    let source = record.previewDataUrl;
    if (record.fileBlob) {
      this.objectUrl = URL.createObjectURL(record.fileBlob);
      source = this.objectUrl;
    }

    let media: HTMLImageElement | HTMLVideoElement;
    if (record.mediaKind === "video" && record.fileBlob) {
      media = document.createElement("video");
      media.controls = true;
      media.autoplay = true;
      media.playsInline = true;
    } else {
      media = document.createElement("img");
      media.alt = record.name;
    }
    media.src = source;
    this.elements.body.replaceChildren(media);
    this.elements.title.textContent = formatDate(record.lastModified);
    const kind =
      record.mediaKind === "video" ? `Video ${formatDuration(record.duration)}`.trim() : "Photo";
    this.elements.meta.textContent = `${kind}, ${formatBytes(record.size)}, ${record.name}`;
    this.elements.position.textContent = `${index + 1} of ${this.records.length}`;
    this.elements.prev.disabled = index === 0;
    this.elements.next.disabled = index === this.records.length - 1;
  }

  private releaseObjectUrl(): void {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl);
      this.objectUrl = null;
    }
  }
}
