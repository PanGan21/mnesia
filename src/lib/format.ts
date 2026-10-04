const dateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: "long" });

/** A date written out in full, e.g. "14 August 2025", for easy reading. */
export function formatDate(timestamp: number): string {
  return dateFormatter.format(new Date(timestamp));
}

export function formatBytes(value: number): string {
  if (!Number.isFinite(value) || value <= 0) {
    return "0 B";
  }

  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  const size = value / 1024 ** index;
  return `${size.toFixed(size >= 100 || index === 0 ? 0 : 1)} ${units[index]}`;
}

/** Formats seconds as m:ss. Returns an empty string for unknown durations. */
export function formatDuration(seconds: number | null): string {
  if (seconds === null || !Number.isFinite(seconds) || seconds < 0) {
    return "";
  }

  const total = Math.round(seconds);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

export function pluralize(count: number, singular: string, plural = `${singular}s`): string {
  return `${count} ${count === 1 ? singular : plural}`;
}

/** "3 photos", "1 video" or "4 photos and videos", depending on what's included. */
export function countMedia(photos: number, videos: number): string {
  if (videos === 0) {
    return pluralize(photos, "photo");
  }
  if (photos === 0) {
    return pluralize(videos, "video");
  }
  return `${photos + videos} photos and videos`;
}
