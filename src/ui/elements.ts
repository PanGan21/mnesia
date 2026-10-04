import { requireElement as one, requireElements as all } from "../lib/dom";

/** Every element the app talks to, looked up once at startup. */
export function getElements() {
  return {
    modelLabels: all("[data-runtime-label]", HTMLElement),
    modelDots: all("[data-model-dot]", HTMLElement),
    modelDetail: one("[data-runtime-detail]", HTMLElement),
    modelRetry: one("[data-model-retry]", HTMLButtonElement),
    libraryDetail: one("[data-library-detail]", HTMLElement),
    storageUsage: one("[data-storage-usage]", HTMLElement),
    fileInputs: all("[data-file-input], [data-folder-input]", HTMLInputElement),
    demoButton: one("[data-demo-button]", HTMLButtonElement),
    persistToggle: one("[data-persist-toggle]", HTMLInputElement),
    clearButton: one("[data-clear-button]", HTMLButtonElement),
    searchForm: one("[data-search-form]", HTMLFormElement),
    queryInput: one("[data-query-input]", HTMLInputElement),
    mediaFilter: one("[data-media-filter]", HTMLFieldSetElement),
    narrow: one("[data-narrow]", HTMLElement),
    timeFilter: one("[data-time-filter]", HTMLSelectElement),
    understood: one("[data-active-filters]", HTMLElement),
    suggestions: one("[data-suggestion-row]", HTMLElement),
    progress: {
      panel: one("[data-progress-panel]", HTMLElement),
      title: one("[data-progress-title]", HTMLElement),
      detail: one("[data-progress-detail]", HTMLElement),
      fill: one("[data-progress-fill]", HTMLElement),
      stop: one("[data-cancel-button]", HTMLButtonElement),
    },
    results: {
      head: one("[data-results-head]", HTMLElement),
      title: one("[data-results-title]", HTMLElement),
      summary: one("[data-results-summary]", HTMLElement),
      grid: one("[data-results-grid]", HTMLUListElement),
      more: one("[data-results-more]", HTMLElement),
      others: one("[data-results-others]", HTMLElement),
      showOthers: one("[data-show-others]", HTMLButtonElement),
      showClosest: one("[data-show-closest]", HTMLButtonElement),
      emptySearchTitle: one("[data-empty-search-title]", HTMLElement),
      showMore: one("[data-show-more]", HTMLButtonElement),
      empty: one("[data-empty-state]", HTMLElement),
      emptyLibrary: one("[data-empty-library]", HTMLElement),
      emptySearch: one("[data-empty-search]", HTMLElement),
      emptySearchDetail: one("[data-empty-search-detail]", HTMLElement),
      resetFilters: one("[data-reset-filters]", HTMLButtonElement),
    },
    sheet: {
      dialog: one("[data-library-sheet]", HTMLDialogElement),
      openers: all("[data-open-sheet]", HTMLElement),
      close: one("[data-close-sheet]", HTMLButtonElement),
    },
    confirm: {
      dialog: one("[data-confirm-dialog]", HTMLDialogElement),
      title: one("[data-confirm-title]", HTMLElement),
      body: one("[data-confirm-body]", HTMLElement),
      accept: one('[data-confirm-dialog] [value="confirm"]', HTMLButtonElement),
    },
    viewer: {
      dialog: one("[data-viewer-dialog]", HTMLDialogElement),
      title: one("[data-viewer-title]", HTMLElement),
      body: one("[data-viewer-body]", HTMLElement),
      meta: one("[data-viewer-meta]", HTMLElement),
      prev: one("[data-viewer-prev]", HTMLButtonElement),
      next: one("[data-viewer-next]", HTMLButtonElement),
      close: one("[data-viewer-close]", HTMLButtonElement),
      position: one("[data-viewer-position]", HTMLElement),
    },
    dropVeil: one("[data-drop-veil]", HTMLElement),
    toast: one("[data-toast]", HTMLElement),
  };
}

export type Elements = ReturnType<typeof getElements>;
