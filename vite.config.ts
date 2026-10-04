import type { Plugin } from "vite";
import { defineConfig } from "vitest/config";

/**
 * Content Security Policy for the built page. Only applied to production
 * builds, because the dev server injects inline scripts for hot reload.
 * The model worker fetches weights itself and isn't covered by a page <meta>
 * policy; see README for the headers to set when hosting.
 */
const CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data: blob:",
  "media-src 'self' blob:",
  "font-src 'self'",
  "connect-src 'self'",
  "worker-src 'self'",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
].join("; ");

/**
 * Policy to send as an HTTP header when hosting. Unlike the <meta> tag it also
 * covers the model worker, which compiles WebAssembly, imports the cached ONNX
 * runtime from a blob: URL, and downloads the model from Hugging Face.
 * `vite preview` serves it so production behaviour can be tested locally.
 */
export const HOSTING_CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval' blob:",
  "style-src 'self'",
  "img-src 'self' data: blob:",
  "media-src 'self' blob:",
  "font-src 'self'",
  "connect-src 'self' data: blob: https://huggingface.co https://*.hf.co",
  "worker-src 'self' blob:",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join("; ");

export const HOSTING_HEADERS = {
  "Content-Security-Policy": HOSTING_CONTENT_SECURITY_POLICY,
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=(), interest-cohort=()",
};

function contentSecurityPolicy(): Plugin {
  return {
    name: "mnesia-content-security-policy",
    apply: "build",
    transformIndexHtml: () => [
      {
        tag: "meta",
        attrs: { "http-equiv": "Content-Security-Policy", content: CONTENT_SECURITY_POLICY },
        injectTo: "head-prepend",
      },
    ],
  };
}

export default defineConfig({
  plugins: [contentSecurityPolicy()],
  worker: { format: "es" },
  build: { target: "es2022", sourcemap: true },
  preview: { headers: HOSTING_HEADERS },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
