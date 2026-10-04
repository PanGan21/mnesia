/// <reference lib="webworker" />
import {
  AutoProcessor,
  AutoTokenizer,
  CLIPTextModelWithProjection,
  CLIPVisionModelWithProjection,
  RawImage,
  env,
  type Tensor,
} from "@huggingface/transformers";
import runtimeMjsUrl from "onnxruntime-web/ort-wasm-simd-threaded.mjs?url";
import runtimeWasmUrl from "onnxruntime-web/ort-wasm-simd-threaded.wasm?url";
import asyncifyRuntimeMjsUrl from "onnxruntime-web/ort-wasm-simd-threaded.asyncify.mjs?url";
import asyncifyRuntimeWasmUrl from "onnxruntime-web/ort-wasm-simd-threaded.asyncify.wasm?url";

import { MODEL } from "../config";
import type { Backend, WorkerMessage, WorkerRequest } from "./protocol";

declare const self: DedicatedWorkerGlobalScope;

// Serve the ONNX runtime from this app's bundle instead of the jsDelivr CDN,
// keeping whichever runtime build transformers.js picked for this browser.
const bundledRuntime: Record<string, string> = {
  "ort-wasm-simd-threaded.mjs": runtimeMjsUrl,
  "ort-wasm-simd-threaded.wasm": runtimeWasmUrl,
  "ort-wasm-simd-threaded.asyncify.mjs": asyncifyRuntimeMjsUrl,
  "ort-wasm-simd-threaded.asyncify.wasm": asyncifyRuntimeWasmUrl,
};
const wasmEnv = env.backends.onnx.wasm;
if (wasmEnv && typeof wasmEnv.wasmPaths === "object") {
  wasmEnv.wasmPaths = Object.fromEntries(
    Object.entries(wasmEnv.wasmPaths).map(([key, url]) => {
      const local = bundledRuntime[String(url).split("/").pop() ?? ""];
      if (!local) {
        throw new Error(`No bundled ONNX runtime file for ${String(url)}.`);
      }
      return [key, new URL(local, self.location.href).href];
    }),
  );
}

interface Runtime {
  backend: Backend;
  tokenizer: Awaited<ReturnType<typeof AutoTokenizer.from_pretrained>>;
  textModel: Awaited<ReturnType<typeof CLIPTextModelWithProjection.from_pretrained>>;
  processor: Awaited<ReturnType<typeof AutoProcessor.from_pretrained>>;
  visionModel: Awaited<ReturnType<typeof CLIPVisionModelWithProjection.from_pretrained>>;
}

let runtime: Promise<Runtime> | null = null;

function post(message: WorkerMessage, transfer: Transferable[] = []): void {
  self.postMessage(message, transfer);
}

async function load(): Promise<Runtime> {
  // Sum per-file download progress into one percentage.
  const files = new Map<string, { loaded: number; total: number }>();
  const progress_callback = (update: {
    status: string;
    file?: string;
    loaded?: number;
    total?: number;
  }) => {
    if (update.status !== "progress" || !update.file || !Number.isFinite(update.total)) {
      return;
    }
    files.set(update.file, { loaded: update.loaded ?? 0, total: update.total ?? 0 });
    let loaded = 0;
    let total = 0;
    for (const entry of files.values()) {
      loaded += entry.loaded;
      total += entry.total;
    }
    post({ event: "progress", percent: total > 0 ? (loaded / total) * 100 : 0 });
  };

  const shared = { revision: MODEL.revision, progress_callback };
  // Always the CPU runtime with 8-bit weights; see MODEL.dtype for why not WebGPU.
  const modelOptions = { ...shared, device: "wasm" as const, dtype: MODEL.dtype };

  // CLIP text and image embeddings only share a vector space through the
  // projection heads, so both sides use the projected models. They're loaded
  // directly rather than through pipeline(), which doesn't forward `revision`
  // to its file-discovery requests in transformers.js 4.2.0. Loading in
  // parallel makes the summed progress settle early.
  const [tokenizer, textModel, processor, visionModel] = await Promise.all([
    AutoTokenizer.from_pretrained(MODEL.id, shared),
    CLIPTextModelWithProjection.from_pretrained(MODEL.id, modelOptions),
    AutoProcessor.from_pretrained(MODEL.id, shared),
    CLIPVisionModelWithProjection.from_pretrained(MODEL.id, modelOptions),
  ]);

  return { backend: "wasm", tokenizer, textModel, processor, visionModel };
}

function getRuntime(): Promise<Runtime> {
  runtime ??= load().catch((error: unknown) => {
    runtime = null;
    throw error;
  });
  return runtime;
}

/** Copies a model output into a standalone float32 vector, converting fp16 output if needed. */
function toVector(tensor: Tensor): Float32Array {
  const source = tensor.type === "float16" ? tensor.to("float32") : tensor;
  return Float32Array.from(source.data as ArrayLike<number>);
}

async function embedText(text: string): Promise<Float32Array> {
  const { tokenizer, textModel } = await getRuntime();
  const inputs = tokenizer([text], { padding: true, truncation: true });
  const { text_embeds } = (await textModel(inputs)) as { text_embeds: Tensor };
  return toVector(text_embeds);
}

async function embedImage(dataUrl: string): Promise<Float32Array> {
  const { processor, visionModel } = await getRuntime();
  const image = await RawImage.read(dataUrl);
  const inputs = (await processor(image)) as Record<string, Tensor>;
  const { image_embeds } = (await visionModel(inputs)) as { image_embeds: Tensor };
  return toVector(image_embeds);
}

self.onmessage = async (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;

  try {
    switch (request.type) {
      case "init": {
        const { backend } = await getRuntime();
        post({ id: request.id, ok: true, type: "init", backend });
        return;
      }
      case "embed-text": {
        const embedding = await embedText(request.text);
        post({ id: request.id, ok: true, type: "embedding", embedding }, [embedding.buffer]);
        return;
      }
      case "embed-image": {
        // Only previews this app generated are accepted.
        if (!request.dataUrl.startsWith("data:image/")) {
          throw new Error("Expected an image data URL.");
        }
        const embedding = await embedImage(request.dataUrl);
        post({ id: request.id, ok: true, type: "embedding", embedding }, [embedding.buffer]);
        return;
      }
    }
  } catch (error) {
    post({
      id: request.id,
      ok: false,
      error: error instanceof Error ? error.message : "The search model failed.",
    });
  }
};
