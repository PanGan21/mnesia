import { createSampleFiles } from "./demo/sample-library";
import { embedMissing, importFiles, type ImportProgress, type ImportSummary } from "./importer";
import type { Library } from "./library";
import { countMedia, formatBytes } from "./lib/format";
import { collectDroppedFiles } from "./media/files";
import type { ModelClient, ModelState } from "./model/model-client";
import { search, type SearchRequest } from "./search/search";
import { saveSettings, type Settings } from "./storage/settings";
import { MEDIA_FILTERS, TIME_FILTERS, type MediaFilter } from "./types";
import type { Elements } from "./ui/elements";
import { ConfirmDialog, ProgressPanel, Toast } from "./ui/feedback";
import { ResultsView } from "./ui/results-view";
import { Viewer } from "./ui/viewer";

const MODEL_LABELS: Record<ModelState["status"], (state: ModelState) => string> = {
  idle: () => "Not set up yet",
  loading: (state) =>
    state.percent > 0 ? `Getting ready: ${Math.round(state.percent)}%` : "Getting ready",
  ready: () => "Ready",
  failed: () => "Not available right now",
};

function countRecords(records: readonly { mediaKind: string }[]): string {
  const videos = records.filter((record) => record.mediaKind === "video").length;
  return countMedia(records.length - videos, videos);
}

/** Coordinates the library, smart search and the views. */
export class App {
  private readonly toast: Toast;
  private readonly progress: ProgressPanel;
  private readonly confirm: ConfirmDialog;
  private readonly results: ResultsView;
  private readonly viewer: Viewer;

  private searchGeneration = 0;
  private searchQueuedForModel = false;
  private importController: AbortController | null = null;
  /** Bringing older items up to date for smart search, in the background. */
  private backgroundController: AbortController | null = null;
  private refreshTimer: ReturnType<typeof setTimeout> | undefined;
  private askedForPersistentStorage = false;

  constructor(
    private readonly ui: Elements,
    private readonly library: Library,
    private readonly model: ModelClient,
    private readonly settings: Settings,
  ) {
    this.toast = new Toast(ui.toast);
    this.progress = new ProgressPanel(ui.progress);
    this.confirm = new ConfirmDialog(ui.confirm);
    this.results = new ResultsView(ui.results);
    this.viewer = new Viewer(ui.viewer);
  }

  async start(): Promise<void> {
    this.applySettingsToControls();
    this.bindEvents();
    this.model.subscribe((state) => {
      this.renderModelStatus(state);
      if (state.status === "ready") {
        void this.updateEmbeddings();
      }
    });

    try {
      await this.library.load();
    } catch (error) {
      console.error(error);
      this.toast.show("Your saved photos couldn’t be opened. You can still add new ones.");
    }
    this.renderLibraryStatus();
    await this.refresh();

    // A saved library means smart search was downloaded before, so starting it
    // only reads from the browser cache. Otherwise wait until it's needed.
    if (this.library.size > 0) {
      void this.model.ensureReady();
    }
  }

  // ——— Search ———

  private get request(): SearchRequest {
    return {
      query: this.ui.queryInput.value,
      mediaFilter: this.settings.mediaFilter,
      timeFilter: this.settings.timeFilter,
      // Best match first when searching, newest first when browsing.
      sortOrder: "relevance",
    };
  }

  private async refresh(): Promise<void> {
    const generation = ++this.searchGeneration;
    const request = this.request;

    if (
      request.query.trim() &&
      !this.model.isReady &&
      !this.model.isUnavailable &&
      this.library.size > 0
    ) {
      this.searchWhenModelReady();
    }

    let outcome;
    try {
      outcome = await search(
        this.library.all,
        request,
        this.model.isReady ? (text) => this.model.embedText(text) : null,
      );
    } catch (error) {
      // Smart search can fail mid-query; fall back to file names and dates.
      console.error(error);
      outcome = await search(this.library.all, request, null);
    }
    // A newer search started while this one waited for smart search.
    if (generation !== this.searchGeneration) {
      return;
    }

    const libraryEmpty = this.library.size === 0;
    this.ui.suggestions.hidden = libraryEmpty || Boolean(outcome.query);
    this.ui.narrow.hidden = libraryEmpty;
    this.renderUnderstood(outcome.parsed.understood);
    this.results.render(outcome, {
      libraryEmpty,
      modelPending: Boolean(outcome.query) && !outcome.semantic && !this.model.isUnavailable,
      hasFilters: this.settings.mediaFilter !== "all" || this.settings.timeFilter !== "all",
    });
  }

  /** Shows file-name matches now and searches again once smart search is ready. */
  private searchWhenModelReady(): void {
    if (this.searchQueuedForModel) {
      return;
    }
    this.searchQueuedForModel = true;
    void this.model.ensureReady().then(() => {
      this.searchQueuedForModel = false;
      void this.refresh();
    });
  }

  /** Coalesces refreshes while an import adds many files in a row. */
  private scheduleRefresh(): void {
    if (this.refreshTimer !== undefined) {
      return;
    }
    this.refreshTimer = setTimeout(() => {
      this.refreshTimer = undefined;
      void this.refresh();
    }, 400);
  }

  private renderUnderstood(labels: readonly string[]): void {
    const { understood } = this.ui;
    understood.replaceChildren();
    understood.hidden = labels.length === 0;
    if (labels.length > 0) {
      understood.append("Only showing: ");
      labels.forEach((label, index) => {
        if (index > 0) {
          understood.append(", ");
        }
        const strong = document.createElement("strong");
        strong.textContent = label;
        understood.append(strong);
      });
      understood.append(" (from your words)");
    }
  }

  // ——— Adding photos ———

  private async import(files: readonly File[]): Promise<void> {
    if (this.importController) {
      this.toast.show("Photos are still being added. Wait for them to finish, then add more.");
      return;
    }
    if (files.length === 0) {
      return;
    }

    this.ui.sheet.dialog.close();
    // New photos come first; the background update resumes afterwards.
    this.backgroundController?.abort();
    const controller = new AbortController();
    this.importController = controller;
    this.progress.show("Getting ready", "", 0);

    let summary: ImportSummary | null = null;
    try {
      summary = await importFiles(files, this.library, this.model, {
        signal: controller.signal,
        onProgress: (progress) => {
          this.showImportProgress(progress);
        },
        onAdded: () => {
          this.renderLibraryStatus();
          this.scheduleRefresh();
        },
      });
    } catch (error) {
      console.error(error);
      this.toast.show("Adding photos stopped because something went wrong. Please try again.");
    } finally {
      this.importController = null;
      this.progress.hide();
      for (const input of this.ui.fileInputs) {
        input.value = "";
      }
    }

    clearTimeout(this.refreshTimer);
    this.refreshTimer = undefined;
    await this.refresh();
    if (summary) {
      this.toast.show(describeImport(summary));
      if (summary.added > 0) {
        void this.requestPersistentStorage();
      }
    }
    void this.updateEmbeddings();
  }

  /**
   * Prepares items smart search hasn't processed yet: ones added while it was
   * unavailable, or processed by an older model.
   */
  private async updateEmbeddings(): Promise<void> {
    if (this.importController || this.backgroundController || !this.model.isReady) {
      return;
    }
    if (!this.library.all.some((record) => record.embedding === null)) {
      return;
    }

    const controller = new AbortController();
    this.backgroundController = controller;
    try {
      const updated = await embedMissing(this.library, this.model, {
        signal: controller.signal,
        onProgress: (done, total) => {
          this.progress.show(
            "Getting your photos ready for smart search",
            `${done} of ${total} done. You can keep searching meanwhile.`,
            (done / total) * 100,
          );
        },
      });
      if (updated > 0) {
        await this.refresh();
      }
    } catch (error) {
      console.error(error);
    } finally {
      this.backgroundController = null;
      // An import may have started while this ran; it owns the progress panel then.
      if (!this.isImporting()) {
        this.progress.hide();
      }
    }
  }

  private isImporting(): boolean {
    return this.importController !== null;
  }

  private showImportProgress(progress: ImportProgress): void {
    if (progress.stage === "model") {
      this.showModelProgress(progress.percent);
    } else {
      this.progress.show(
        `Adding photo ${progress.index + 1} of ${progress.total}`,
        progress.fileName,
        (progress.index / progress.total) * 100,
      );
    }
  }

  private showModelProgress(percent: number): void {
    this.progress.show(
      "Getting smart search ready",
      `This only happens once. ${Math.round(percent)}% done.`,
      percent,
    );
  }

  private stopImport(): void {
    this.importController?.abort();
    this.backgroundController?.abort();
    // Stop a download in progress; a ready model can stay loaded.
    if (this.model.state.status === "loading") {
      this.model.reset();
    }
  }

  /** Asks the browser not to evict the library under storage pressure. */
  private async requestPersistentStorage(): Promise<void> {
    // navigator.storage is missing outside secure contexts, despite its type.
    const storage = navigator.storage as StorageManager | undefined;
    if (this.askedForPersistentStorage || !this.library.isPersistent || !storage) {
      return;
    }
    this.askedForPersistentStorage = true;
    try {
      await storage.persist();
    } catch {
      // Best effort: without it the browser may clear data when space runs low.
    }
  }

  // ——— Library ———

  private async clearLibrary(): Promise<void> {
    if (this.importController) {
      this.toast.show("Photos are still being added. Press Stop first.");
      return;
    }
    const count = countRecords(this.library.all);
    if (this.library.size === 0) {
      this.toast.show("There are no photos to remove.");
      return;
    }

    const confirmed = await this.confirm.ask({
      title: `Remove ${count} from mnesia?`,
      body: "They will be removed from mnesia only. The original files on your computer are not deleted.",
      confirmLabel: "Remove",
    });
    if (!confirmed) {
      return;
    }

    try {
      await this.library.clear();
    } catch (error) {
      console.error(error);
      this.toast.show("The photos couldn’t be removed. Reload the page and try again.");
      return;
    }
    this.ui.queryInput.value = "";
    this.ui.sheet.dialog.close();
    this.renderLibraryStatus();
    await this.refresh();
    this.toast.show(`Removed ${count} from mnesia.`);
  }

  private async setPersistence(persist: boolean): Promise<void> {
    this.settings.persistLibrary = persist;
    saveSettings(this.settings);
    try {
      await this.library.setPersistent(persist);
      this.toast.show(
        persist
          ? "Your photos will be remembered after you close this page."
          : "Your photos will be forgotten when you close this page.",
      );
      if (persist) {
        void this.requestPersistentStorage();
      }
    } catch (error) {
      console.error(error);
      this.toast.show("That setting couldn’t be changed. Please try again.");
    }
    void this.renderStorageUsage();
  }

  private renderLibraryStatus(): void {
    this.ui.libraryDetail.textContent =
      this.library.size > 0 ? countRecords(this.library.all) : "No photos or videos yet.";
  }

  private async renderStorageUsage(): Promise<void> {
    const storage = navigator.storage as StorageManager | undefined;
    if (!storage) {
      this.ui.storageUsage.textContent = "";
      return;
    }
    try {
      const { usage = 0 } = await storage.estimate();
      this.ui.storageUsage.textContent = `Using ${formatBytes(usage)} on this computer, including smart search.`;
    } catch {
      this.ui.storageUsage.textContent = "";
    }
  }

  private renderModelStatus(state: ModelState): void {
    const label = MODEL_LABELS[state.status](state);
    for (const element of this.ui.modelLabels) {
      element.textContent = label;
    }
    for (const dot of this.ui.modelDots) {
      dot.dataset.state = state.status;
    }
    this.ui.modelDetail.textContent = state.detail;
    this.ui.modelRetry.hidden = state.status !== "failed";

    // Show the one-time download wherever it was started from; imports show their own progress.
    if (!this.importController && !this.backgroundController) {
      if (state.status === "loading") {
        this.showModelProgress(state.percent);
      } else {
        this.progress.hide();
      }
    }
  }

  // ——— Controls ———

  private applySettingsToControls(): void {
    const radio = this.ui.mediaFilter.querySelector<HTMLInputElement>(
      `input[value="${this.settings.mediaFilter}"]`,
    );
    if (radio) {
      radio.checked = true;
    }
    this.ui.timeFilter.value = this.settings.timeFilter;
    this.ui.persistToggle.checked = this.settings.persistLibrary;
  }

  private readControls(): void {
    const media = this.ui.mediaFilter.querySelector<HTMLInputElement>("input:checked")?.value;
    this.settings.mediaFilter = MEDIA_FILTERS.includes(media as MediaFilter)
      ? (media as MediaFilter)
      : "all";
    const time = this.ui.timeFilter.value;
    this.settings.timeFilter = TIME_FILTERS.find((value) => value === time) ?? "all";
    saveSettings(this.settings);
  }

  private bindEvents(): void {
    const { ui } = this;

    // Searching happens when the person asks for it, so results never shift while typing.
    ui.searchForm.addEventListener("submit", (event) => {
      event.preventDefault();
      void this.refresh();
    });
    // Emptying the box (including its clear button) shows everything again.
    ui.queryInput.addEventListener("input", () => {
      if (!ui.queryInput.value.trim()) {
        void this.refresh();
      }
    });
    ui.queryInput.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && ui.queryInput.value) {
        event.preventDefault();
        ui.queryInput.value = "";
        void this.refresh();
      }
    });

    for (const control of [ui.mediaFilter, ui.timeFilter]) {
      control.addEventListener("change", () => {
        this.readControls();
        void this.refresh();
      });
    }
    ui.results.resetFilters.addEventListener("click", () => {
      this.settings.mediaFilter = "all";
      this.settings.timeFilter = "all";
      saveSettings(this.settings);
      this.applySettingsToControls();
      ui.queryInput.value = "";
      void this.refresh();
    });
    ui.suggestions.addEventListener("click", (event) => {
      const button = (event.target as Element).closest<HTMLButtonElement>("[data-suggestion]");
      if (button?.dataset.suggestion) {
        ui.queryInput.value = button.dataset.suggestion;
        void this.refresh();
      }
    });

    ui.results.grid.addEventListener("click", (event) => {
      const button = (event.target as Element).closest<HTMLButtonElement>("[data-record-id]");
      if (button) {
        const records = this.results.current;
        this.viewer.open(
          records,
          records.findIndex((record) => record.id === button.dataset.recordId),
        );
      }
    });

    for (const input of ui.fileInputs) {
      input.addEventListener("change", () => void this.import(Array.from(input.files ?? [])));
    }
    ui.demoButton.addEventListener("click", () => void this.import(createSampleFiles()));
    ui.progress.stop.addEventListener("click", () => {
      this.stopImport();
    });
    ui.clearButton.addEventListener("click", () => void this.clearLibrary());
    ui.persistToggle.addEventListener(
      "change",
      () => void this.setPersistence(ui.persistToggle.checked),
    );
    ui.modelRetry.addEventListener("click", () => {
      void this.model.retry().then(() => this.refresh());
    });

    // Settings panel
    for (const opener of ui.sheet.openers) {
      opener.addEventListener("click", () => {
        void this.renderStorageUsage();
        ui.sheet.dialog.showModal();
      });
    }
    ui.sheet.close.addEventListener("click", () => {
      ui.sheet.dialog.close();
    });
    ui.sheet.dialog.addEventListener("click", (event) => {
      if (event.target === ui.sheet.dialog) {
        ui.sheet.dialog.close();
      }
    });

    // "/" jumps to search from anywhere that isn't a text field or dialog.
    document.addEventListener("keydown", (event) => {
      const target = event.target as Element | null;
      const typing = target?.closest("input, select, textarea, [contenteditable]");
      if (event.key === "/" && !typing && !document.querySelector("dialog[open]")) {
        event.preventDefault();
        ui.queryInput.focus();
      }
    });

    this.bindDropZone();
  }

  private bindDropZone(): void {
    const veil = this.ui.dropVeil;
    let depth = 0;
    const carriesFiles = (event: DragEvent) => event.dataTransfer?.types.includes("Files") ?? false;

    window.addEventListener("dragenter", (event) => {
      if (carriesFiles(event)) {
        event.preventDefault();
        depth += 1;
        veil.hidden = false;
      }
    });
    window.addEventListener("dragover", (event) => {
      if (carriesFiles(event)) {
        event.preventDefault();
      }
    });
    window.addEventListener("dragleave", (event) => {
      if (carriesFiles(event)) {
        depth = Math.max(0, depth - 1);
        veil.hidden = depth > 0;
      }
    });
    window.addEventListener("drop", (event) => {
      if (!carriesFiles(event) || !event.dataTransfer) {
        return;
      }
      event.preventDefault();
      depth = 0;
      veil.hidden = true;
      collectDroppedFiles(event.dataTransfer)
        .then((files) => this.import(files))
        .catch((error: unknown) => {
          console.error(error);
          this.toast.show("Those files couldn’t be opened. Try the Add photos button instead.");
        });
    });
  }
}

/** A short, plain summary of an import, e.g. "Added 12 photos. 2 were already here." */
export function describeImport(summary: ImportSummary): string {
  const added = countMedia(summary.added - summary.addedVideos, summary.addedVideos);
  const sentences: string[] = [];

  if (summary.stopped === "storage-full") {
    sentences.push(
      `This computer is out of space for mnesia. Added ${added}. The last one is only kept until you close the page.`,
    );
  } else if (summary.stopped === "canceled") {
    sentences.push(`Stopped. Added ${added}.`);
  } else if (summary.added > 0) {
    sentences.push(`Added ${added}.`);
  }

  if (summary.duplicates > 0) {
    sentences.push(
      summary.duplicates === 1 ? "1 was already here." : `${summary.duplicates} were already here.`,
    );
  }
  if (summary.unreadable > 0) {
    sentences.push(
      summary.unreadable === 1
        ? "1 file couldn’t be opened and was skipped."
        : `${summary.unreadable} files couldn’t be opened and were skipped.`,
    );
  }
  if (summary.ignored > 0 && summary.added === 0 && summary.duplicates === 0) {
    sentences.push("Those files aren’t photos or videos, so nothing was added.");
  }

  return sentences.join(" ") || "Nothing was added.";
}
