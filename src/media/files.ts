/** Choosing which files to import, from pickers and from drag and drop. */

export function isSupportedMedia(file: File): boolean {
  return file.type.startsWith("image/") || file.type.startsWith("video/");
}

/**
 * Collects files from a drop, walking into dropped folders where the browser
 * supports it. Hidden files (like .DS_Store) are skipped.
 */
export async function collectDroppedFiles(dataTransfer: DataTransfer): Promise<File[]> {
  const entries = Array.from(dataTransfer.items)
    .map((item) => item.webkitGetAsEntry())
    .filter((entry): entry is FileSystemEntry => entry !== null);

  if (entries.length === 0) {
    return Array.from(dataTransfer.files);
  }

  const files: File[] = [];
  const walk = async (entry: FileSystemEntry): Promise<void> => {
    if (entry.name.startsWith(".")) {
      return;
    }
    if (isFileEntry(entry)) {
      files.push(await new Promise<File>((resolve, reject) => entry.file(resolve, reject)));
      return;
    }
    if (isDirectoryEntry(entry)) {
      const reader = entry.createReader();
      // readEntries returns results in batches until it returns an empty one.
      for (;;) {
        const batch = await new Promise<FileSystemEntry[]>((resolve, reject) =>
          reader.readEntries(resolve, reject),
        );
        if (batch.length === 0) {
          break;
        }
        for (const child of batch) {
          await walk(child);
        }
      }
    }
  };

  for (const entry of entries) {
    await walk(entry);
  }
  return files;
}

function isFileEntry(entry: FileSystemEntry): entry is FileSystemFileEntry {
  return entry.isFile;
}

function isDirectoryEntry(entry: FileSystemEntry): entry is FileSystemDirectoryEntry {
  return entry.isDirectory;
}
