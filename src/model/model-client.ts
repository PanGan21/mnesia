import { LIMITS, MODEL } from "../config";
import { isWorkerEvent, type Backend, type WorkerMessage, type WorkerRequest } from "./protocol";

export type ModelStatus = "idle" | "loading" | "ready" | "failed";

export interface ModelState {
  status: ModelStatus;
  /** Download progress while loading, 0–100. Never moves backwards within one load. */
  percent: number;
  backend: Backend | null;
  /** A sentence for people, describing the current state. */
  detail: string;
}

/** Rejects in-flight requests when the worker is stopped on purpose. */
export class ModelResetError extends Error {
  constructor() {
    super("The search model was stopped.");
    this.name = "ModelResetError";
  }
}

type DistributiveOmit<T, K extends PropertyKey> = T extends unknown ? Omit<T, K> : never;
type Request = DistributiveOmit<WorkerRequest, "id">;

interface Pending {
  resolve: (message: Extract<WorkerMessage, { ok: true }>) => void;
  reject: (error: Error) => void;
}

const IDLE_DETAIL = `It downloads once (${MODEL.approximateDownload}) the first time you add photos or search.`;
const FALLBACK_DETAIL = "Search will use file names and dates instead.";

function createDefaultWorker(): Worker {
  return new Worker(new URL("./model.worker.ts", import.meta.url), { type: "module" });
}

/**
 * Owns the model worker: starts it on demand, tracks its state for the UI,
 * and turns its messages into promises.
 */
export class ModelClient {
  private worker: Worker | null = null;
  private nextId = 0;
  private readonly pending = new Map<number, Pending>();
  private readying: Promise<boolean> | null = null;
  private readonly listeners = new Set<(state: ModelState) => void>();
  private readonly textCache = new Map<string, Float32Array>();
  private current: ModelState = { status: "idle", percent: 0, backend: null, detail: IDLE_DETAIL };

  constructor(private readonly createWorker: () => Worker = createDefaultWorker) {}

  get state(): ModelState {
    return this.current;
  }

  get isReady(): boolean {
    return this.current.status === "ready";
  }

  /** True once loading has failed; search then falls back to file names and dates. */
  get isUnavailable(): boolean {
    return this.current.status === "failed";
  }

  subscribe(listener: (state: ModelState) => void): () => void {
    this.listeners.add(listener);
    listener(this.current);
    return () => this.listeners.delete(listener);
  }

  /** Starts the model if needed. Resolves false if it can't be used. */
  ensureReady(): Promise<boolean> {
    if (this.current.status === "ready") {
      return Promise.resolve(true);
    }
    if (this.current.status === "failed") {
      return Promise.resolve(false);
    }

    this.readying ??= (async () => {
      this.update({
        status: "loading",
        percent: 0,
        detail: "This only happens once.",
      });
      try {
        const response = await this.send({ type: "init" });
        if (response.type !== "init") {
          throw new Error("Unexpected response from the search model.");
        }
        this.update({
          status: "ready",
          percent: 100,
          backend: response.backend,
          detail: "It works on this computer, even without internet.",
        });
        return true;
      } catch (error) {
        if (error instanceof ModelResetError) {
          return false;
        }
        console.warn("Smart search couldn’t start:", error);
        this.update({ status: "failed", detail: FALLBACK_DETAIL });
        return false;
      } finally {
        this.readying = null;
      }
    })();

    return this.readying;
  }

  /** Tries again after a failed load, e.g. once the network is back. */
  retry(): Promise<boolean> {
    if (this.current.status === "failed") {
      this.update({ status: "idle", percent: 0, backend: null, detail: IDLE_DETAIL });
    }
    return this.ensureReady();
  }

  async embedText(text: string): Promise<Float32Array> {
    const key = text.trim().toLowerCase();
    const cached = this.textCache.get(key);
    if (cached) {
      // Re-insert to keep the most recently used entries.
      this.textCache.delete(key);
      this.textCache.set(key, cached);
      return cached;
    }

    const embedding = await this.embed({ type: "embed-text", text });
    this.textCache.set(key, embedding);
    if (this.textCache.size > LIMITS.queryEmbeddingCacheSize) {
      const oldest = this.textCache.keys().next().value;
      if (oldest !== undefined) {
        this.textCache.delete(oldest);
      }
    }
    return embedding;
  }

  embedImage(dataUrl: string): Promise<Float32Array> {
    return this.embed({ type: "embed-image", dataUrl });
  }

  /** Stops the worker. Anything in flight rejects with ModelResetError. */
  reset(): void {
    this.worker?.terminate();
    this.worker = null;
    this.textCache.clear();
    const error = new ModelResetError();
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();

    if (this.current.status !== "failed") {
      this.update({
        status: "idle",
        percent: 0,
        backend: null,
        detail:
          this.current.status === "loading"
            ? "The download was stopped. It starts again the next time you add photos or search."
            : IDLE_DETAIL,
      });
    }
  }

  private async embed(request: Request): Promise<Float32Array> {
    const response = await this.send(request);
    if (response.type !== "embedding") {
      throw new Error("Unexpected response from the search model.");
    }
    return response.embedding;
  }

  private send(request: Request): Promise<Extract<WorkerMessage, { ok: true }>> {
    const worker = this.ensureWorker();
    const id = ++this.nextId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      worker.postMessage({ ...request, id } satisfies WorkerRequest);
    });
  }

  private ensureWorker(): Worker {
    if (this.worker) {
      return this.worker;
    }

    const worker = this.createWorker();
    worker.onmessage = (event: MessageEvent<WorkerMessage>) => this.handleMessage(event.data);
    worker.onerror = (event) => {
      event.preventDefault();
      this.fail("The search model stopped unexpectedly.");
    };
    this.worker = worker;
    return worker;
  }

  private handleMessage(message: WorkerMessage): void {
    if (isWorkerEvent(message)) {
      if (message.event === "progress") {
        if (this.current.status === "loading") {
          this.update({ percent: Math.max(this.current.percent, message.percent) });
        }
      } else {
        this.update({ detail: message.detail });
      }
      return;
    }

    const pending = this.pending.get(message.id);
    if (!pending) {
      return;
    }
    this.pending.delete(message.id);
    if (message.ok) {
      pending.resolve(message);
    } else {
      pending.reject(new Error(message.error));
    }
  }

  private fail(reason: string): void {
    this.worker?.terminate();
    this.worker = null;
    const error = new Error(reason);
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();
    console.warn("Smart search stopped:", reason);
    this.update({ status: "failed", detail: FALLBACK_DETAIL });
  }

  private update(patch: Partial<ModelState>): void {
    this.current = { ...this.current, ...patch };
    for (const listener of this.listeners) {
      listener(this.current);
    }
  }
}
