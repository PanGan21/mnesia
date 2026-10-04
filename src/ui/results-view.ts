import { LIMITS } from "../config";
import { createIcon } from "../lib/dom";
import { countMedia, formatDate, formatDuration } from "../lib/format";
import type { SearchOutcome } from "../search/search";
import type { MediaRecord } from "../types";
import type { Elements } from "./elements";

export interface ResultsContext {
  libraryEmpty: boolean;
  /** Smart search is still getting ready, so results only match file names and dates. */
  modelPending: boolean;
  hasFilters: boolean;
}

function countOf(records: readonly MediaRecord[]): string {
  const videos = records.filter((record) => record.mediaKind === "video").length;
  return countMedia(records.length - videos, videos);
}

/** The grid of results, its heading, and the empty states. */
export class ResultsView {
  private matches: MediaRecord[] = [];
  private others: MediaRecord[] = [];
  private showingOthers = false;
  private shown = 0;
  private bestId: string | null = null;
  private keepBestStill = false;

  constructor(private readonly elements: Elements["results"]) {
    elements.showMore.addEventListener("click", () => {
      this.appendPage();
    });
    elements.showOthers.addEventListener("click", () => {
      this.revealOthers();
    });
    elements.showClosest.addEventListener("click", () => {
      elements.empty.hidden = true;
      elements.head.hidden = false;
      elements.summary.textContent = "These are the closest, but none is a clear match.";
      this.revealOthers();
    });
  }

  /** The records currently listed, in display order. */
  get current(): readonly MediaRecord[] {
    return this.showingOthers ? [...this.matches, ...this.others] : this.matches;
  }

  render(outcome: SearchOutcome, context: ResultsContext): void {
    const { elements } = this;
    const previousBest = this.bestId;
    this.matches = outcome.results.map((result) => result.record);
    this.others = outcome.others.map((result) => result.record);
    this.showingOthers = false;
    this.shown = 0;
    elements.grid.replaceChildren();
    elements.others.hidden = true;

    elements.head.hidden = context.libraryEmpty;
    this.renderHeading(outcome, context);

    if (this.matches.length === 0) {
      this.bestId = null;
      elements.grid.classList.remove("has-best");
      elements.more.hidden = true;
      elements.empty.hidden = false;
      elements.emptyLibrary.hidden = !context.libraryEmpty;
      elements.emptySearch.hidden = context.libraryEmpty;
      elements.head.hidden = true;

      const hasClosest = this.others.length > 0;
      elements.showClosest.hidden = !hasClosest;
      elements.emptySearchTitle.textContent = outcome.query
        ? `No photos clearly match “${outcome.query}”`
        : "No photos found";
      elements.emptySearchDetail.textContent = context.modelPending
        ? "Smart search is still getting ready. For now only file names and dates are searched."
        : hasClosest
          ? "Try describing it in other words, or look at the closest photos."
          : "Try different words, or show everything from any time.";
      return;
    }

    elements.empty.hidden = true;
    // Only label a best match when the results were ranked by what's in the photos.
    const showBest = Boolean(outcome.query) && outcome.semantic;
    this.bestId = showBest ? (this.matches[0]?.id ?? null) : null;
    this.keepBestStill = previousBest !== null && previousBest === this.bestId;
    elements.grid.classList.toggle("has-best", showBest);
    this.appendPage();
  }

  private renderHeading(outcome: SearchOutcome, context: ResultsContext): void {
    const { title, summary } = this.elements;
    const count = countOf(this.matches);

    if (!outcome.query) {
      title.textContent = "Your photos";
      summary.textContent = context.hasFilters
        ? `${count} match your choices`
        : `${count}, newest first`;
      return;
    }

    title.textContent = `Results for “${outcome.query}”`;
    if (context.modelPending) {
      summary.textContent = "Smart search is getting ready. Results will improve in a moment.";
    } else if (outcome.semantic) {
      summary.textContent =
        this.matches.length === 1 ? "1 match." : `${count} match. The best match is first.`;
    } else {
      summary.textContent = `${count}, matched by file name and date`;
    }
  }

  private revealOthers(): void {
    this.showingOthers = true;
    this.elements.others.hidden = true;
    this.appendPage();
    // Bring the newly shown photos into view; they start below the close matches.
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.elements.grid
      .querySelector(".grid-divider")
      ?.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" });
  }

  private appendPage(): void {
    const list = this.current;
    const page = list.slice(this.shown, this.shown + LIMITS.resultsPageSize);
    const fragment = document.createDocumentFragment();
    page.forEach((record, offset) => {
      const position = this.shown + offset;
      if (position === this.matches.length && this.showingOthers && position > 0) {
        fragment.append(this.createDivider());
      }
      fragment.append(this.createTile(record, record.id === this.bestId, this.keepBestStill));
    });
    this.elements.grid.append(fragment);
    this.shown += page.length;

    const remaining = list.length - this.shown;
    this.elements.more.hidden = remaining <= 0;
    this.elements.showMore.textContent = `Show ${Math.min(remaining, LIMITS.resultsPageSize)} more`;
    // Offer the less likely photos once every close match is on screen.
    this.elements.others.hidden = this.showingOthers || remaining > 0 || this.others.length === 0;
  }

  private createDivider(): HTMLElement {
    const divider = document.createElement("li");
    divider.className = "grid-divider";
    divider.textContent = "Other photos that might match";
    return divider;
  }

  private createTile(record: MediaRecord, isBest: boolean, keepStill: boolean): HTMLElement {
    const item = document.createElement("li");
    item.className = isBest ? "tile tile-best" : "tile";

    const open = document.createElement("button");
    open.type = "button";
    open.className = "tile-open";
    open.dataset.recordId = record.id;
    const kind = record.mediaKind === "video" ? "video" : "photo";
    open.setAttribute(
      "aria-label",
      `${isBest ? "Best match. " : ""}Open ${kind} from ${formatDate(record.lastModified)}, ${record.name}`,
    );

    const photo = document.createElement("span");
    photo.className = "tile-photo";
    const image = document.createElement("img");
    image.alt = "";
    image.loading = "lazy";
    image.decoding = "async";
    image.src = record.previewDataUrl;
    photo.append(image);

    if (record.mediaKind === "video") {
      const badge = document.createElement("span");
      badge.className = "tile-badge";
      const duration = formatDuration(record.duration);
      badge.append(createIcon("i-play"), duration ? `Video ${duration}` : "Video");
      photo.append(badge);
    }

    const text = document.createElement("span");
    text.className = "tile-text";
    const date = document.createElement("span");
    date.className = "tile-date";
    date.textContent = formatDate(record.lastModified);
    const name = document.createElement("span");
    name.className = "tile-name";
    name.textContent = record.name;
    text.append(date, name);

    open.append(photo, text);
    item.append(open);

    if (isBest) {
      const label = document.createElement("span");
      label.className = "best-label";
      label.setAttribute("aria-hidden", "true");
      label.textContent = "Best match";
      // Don't replay the entrance when the same photo stays on top.
      if (keepStill) {
        label.style.animation = "none";
      }
      item.append(label);
    }
    return item;
  }
}
