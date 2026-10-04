import { LIMITS } from "../config";
import type { MediaKind } from "../types";

export interface Preview {
  dataUrl: string;
  width: number;
  height: number;
  /** Seconds, for videos. */
  duration: number | null;
}

/** Thrown when a file can't be decoded by this browser (for example HEIC in Chrome). */
export class UnreadableMediaError extends Error {
  constructor(fileName: string) {
    super(`${fileName} couldn’t be read by this browser.`);
    this.name = "UnreadableMediaError";
  }
}

function withTimeout<T>(promise: Promise<T>, fileName: string): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new UnreadableMediaError(fileName)), LIMITS.decodeTimeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function drawScaled(
  source: CanvasImageSource,
  sourceWidth: number,
  sourceHeight: number,
): Omit<Preview, "duration"> {
  const scale = Math.min(1, LIMITS.previewMaxSide / Math.max(sourceWidth, sourceHeight));
  const width = Math.max(1, Math.round(sourceWidth * scale));
  const height = Math.max(1, Math.round(sourceHeight * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) {
    throw new Error("Canvas 2D isn’t available in this browser.");
  }
  context.drawImage(source, 0, 0, width, height);
  return { dataUrl: canvas.toDataURL("image/jpeg", LIMITS.previewQuality), width, height };
}

async function imagePreview(file: File): Promise<Preview> {
  // createImageBitmap decodes off the main thread and applies EXIF rotation.
  // It can't decode SVG, so fall back to an <img> element for those.
  try {
    const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
    try {
      return { ...drawScaled(bitmap, bitmap.width, bitmap.height), duration: null };
    } finally {
      bitmap.close();
    }
  } catch {
    // Fall through to the element-based decoder.
  }

  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    await image.decode().catch(() => {
      throw new UnreadableMediaError(file.name);
    });
    if (image.naturalWidth === 0 || image.naturalHeight === 0) {
      throw new UnreadableMediaError(file.name);
    }
    return { ...drawScaled(image, image.naturalWidth, image.naturalHeight), duration: null };
  } finally {
    URL.revokeObjectURL(url);
  }
}

function once(
  target: HTMLMediaElement,
  event: "loadeddata" | "seeked",
  fileName: string,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const onError = () => {
      target.removeEventListener(event, onDone);
      reject(new UnreadableMediaError(fileName));
    };
    const onDone = () => {
      target.removeEventListener("error", onError);
      resolve();
    };
    target.addEventListener(event, onDone, { once: true });
    target.addEventListener("error", onError, { once: true });
  });
}

async function videoPreview(file: File): Promise<Preview> {
  const url = URL.createObjectURL(file);
  const video = document.createElement("video");
  video.muted = true;
  video.playsInline = true;
  video.preload = "auto";

  try {
    const loaded = once(video, "loadeddata", file.name);
    video.src = url;
    await loaded;

    // A frame a little way in is more representative than the first one.
    const duration = Number.isFinite(video.duration) ? video.duration : null;
    if (duration !== null && duration > 0.3) {
      const seeked = once(video, "seeked", file.name);
      video.currentTime = Math.min(Math.max(duration * 0.15, 0.15), 2);
      await seeked;
    }
    if (video.videoWidth === 0 || video.videoHeight === 0) {
      throw new UnreadableMediaError(file.name);
    }
    return { ...drawScaled(video, video.videoWidth, video.videoHeight), duration };
  } finally {
    video.removeAttribute("src");
    video.load();
    URL.revokeObjectURL(url);
  }
}

/** Makes a small JPEG preview: shown in results and given to the model. */
export function createPreview(file: File, kind: MediaKind): Promise<Preview> {
  return withTimeout(kind === "video" ? videoPreview(file) : imagePreview(file), file.name);
}
