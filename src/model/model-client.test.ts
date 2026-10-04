import { describe, expect, it } from "vitest";
import { ModelClient, ModelResetError } from "./model-client";
import type { WorkerMessage, WorkerRequest } from "./protocol";

/** Stands in for the model worker; tests decide how it answers. */
class FakeWorker {
  onmessage: ((event: MessageEvent<WorkerMessage>) => void) | null = null;
  onerror: ((event: ErrorEvent) => void) | null = null;
  readonly received: WorkerRequest[] = [];
  terminated = false;

  postMessage(request: WorkerRequest): void {
    this.received.push(request);
  }

  terminate(): void {
    this.terminated = true;
  }

  emit(message: WorkerMessage): void {
    this.onmessage?.({ data: message } as MessageEvent<WorkerMessage>);
  }

  last(): WorkerRequest {
    const request = this.received.at(-1);
    if (!request) {
      throw new Error("No request was sent.");
    }
    return request;
  }
}

function setup() {
  const workers: FakeWorker[] = [];
  const client = new ModelClient(() => {
    const worker = new FakeWorker();
    workers.push(worker);
    return worker as unknown as Worker;
  });
  const worker = () => {
    const current = workers.at(-1);
    if (!current) {
      throw new Error("No worker was created.");
    }
    return current;
  };
  return { client, worker, workers };
}

describe("ModelClient", () => {
  it("loads on demand and reports progress without going backwards", async () => {
    const { client, worker } = setup();
    const percents: number[] = [];
    client.subscribe((state) => percents.push(state.percent));

    const ready = client.ensureReady();
    expect(client.state.status).toBe("loading");
    worker().emit({ event: "progress", percent: 40 });
    worker().emit({ event: "progress", percent: 25 });
    worker().emit({ id: worker().last().id, ok: true, type: "init", backend: "wasm" });

    await expect(ready).resolves.toBe(true);
    expect(client.state).toMatchObject({ status: "ready", backend: "wasm" });
    expect(percents).toEqual([0, 0, 40, 40, 100]);
  });

  it("shares one load between concurrent callers", () => {
    const { client, worker } = setup();
    void client.ensureReady();
    void client.ensureReady();
    expect(worker().received).toHaveLength(1);
  });

  it("falls back when loading fails and can retry", async () => {
    const { client, worker } = setup();
    const first = client.ensureReady();
    worker().emit({ id: worker().last().id, ok: false, error: "offline" });
    await expect(first).resolves.toBe(false);
    expect(client.isUnavailable).toBe(true);
    await expect(client.ensureReady()).resolves.toBe(false);

    const second = client.retry();
    worker().emit({ id: worker().last().id, ok: true, type: "init", backend: "webgpu" });
    await expect(second).resolves.toBe(true);
  });

  it("rejects in-flight work with ModelResetError when reset", async () => {
    const { client, worker } = setup();
    const ready = client.ensureReady();
    worker().emit({ id: worker().last().id, ok: true, type: "init", backend: "wasm" });
    await ready;

    const pending = client.embedImage("data:image/jpeg;base64,AAAA");
    client.reset();
    await expect(pending).rejects.toBeInstanceOf(ModelResetError);
    expect(worker().terminated).toBe(true);
    expect(client.state.status).toBe("idle");
  });

  it("caches text embeddings", async () => {
    const { client, worker } = setup();
    const first = client.embedText("Dog");
    worker().emit({
      id: worker().last().id,
      ok: true,
      type: "embedding",
      embedding: Float32Array.from([1]),
    });
    await first;

    await client.embedText(" dog ");
    expect(worker().received).toHaveLength(1);
  });

  it("fails pending work if the worker crashes", async () => {
    const { client, worker } = setup();
    const ready = client.ensureReady();
    worker().onerror?.({ preventDefault: () => undefined } as ErrorEvent);
    await expect(ready).resolves.toBe(false);
    expect(client.state.status).toBe("failed");
  });
});
