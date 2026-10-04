/** Messages between the app and the model worker. Shared by both sides. */

export type Backend = "webgpu" | "wasm";

export type WorkerRequest =
  | { id: number; type: "init" }
  | { id: number; type: "embed-text"; text: string }
  | { id: number; type: "embed-image"; dataUrl: string };

export type WorkerResponse =
  | { id: number; ok: true; type: "init"; backend: Backend }
  | { id: number; ok: true; type: "embedding"; embedding: Float32Array }
  | { id: number; ok: false; error: string };

/** Unsolicited updates while the model loads. */
export type WorkerEvent =
  { event: "progress"; percent: number } | { event: "status"; detail: string };

export type WorkerMessage = WorkerResponse | WorkerEvent;

export function isWorkerEvent(message: WorkerMessage): message is WorkerEvent {
  return "event" in message;
}
