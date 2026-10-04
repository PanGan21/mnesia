import { MATCHING } from "../config";
import type { MediaKind, MediaRecord, RankedRecord, SortOrder } from "../types";
import { monthKeyOf, seasonOf } from "./time";

/**
 * Lowercases, splits on anything that isn't a letter or digit in any script,
 * and folds simple plurals so "dogs" matches "dog".
 */
export function tokenize(value: string): string[] {
  return value
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .map(normalizeToken);
}

function normalizeToken(token: string): string {
  if (token.length > 3 && token.endsWith("s") && !token.endsWith("ss")) {
    return token.slice(0, -1);
  }
  return token;
}

/** Words a record can be found by without the model: file name, media type, month, year, season. */
export function buildSearchTokens(name: string, timestamp: number, mediaKind: MediaKind): string[] {
  const date = new Date(timestamp);
  const baseName = name.replace(/\.[^.]+$/, "");
  return [
    ...new Set([
      ...tokenize(baseName),
      mediaKind,
      monthKeyOf(date),
      String(date.getFullYear()),
      seasonOf(date),
    ]),
  ];
}

export function cosineSimilarity(a: ArrayLike<number>, b: ArrayLike<number>): number {
  if (a.length === 0 || a.length !== b.length) {
    return 0;
  }

  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let i = 0; i < a.length; i += 1) {
    const x = a[i] as number;
    const y = b[i] as number;
    dot += x * y;
    magA += x * x;
    magB += y * y;
  }

  return magA === 0 || magB === 0 ? 0 : dot / Math.sqrt(magA * magB);
}

/** Share of query words found in the record's words, from 0 to 1. */
export function lexicalOverlap(
  queryTokens: readonly string[],
  recordTokens: readonly string[],
): number {
  const query = new Set(queryTokens);
  if (query.size === 0 || recordTokens.length === 0) {
    return 0;
  }

  const record = new Set(recordTokens);
  let matches = 0;
  for (const token of query) {
    if (record.has(token)) {
      matches += 1;
    }
  }
  return matches / query.size;
}

/**
 * Scores records against a query and marks which ones are real matches.
 *
 * With an embedding, the order blends meaning with file-name words, and a record
 * is a match when its similarity is high in absolute terms and close to the best
 * one (see MATCHING). Without an embedding, only file-name and date words count.
 */
export function rankRecords(
  records: readonly MediaRecord[],
  queryText: string,
  queryEmbedding: Float32Array | null,
): RankedRecord[] {
  const queryTokens = tokenize(queryText);

  if (!queryEmbedding) {
    return records
      .map((record) => {
        const lexical = lexicalOverlap(queryTokens, record.searchTokens);
        return { record, score: lexical, isMatch: lexical > 0 };
      })
      .filter((ranked) => ranked.isMatch);
  }

  const scored = records.map((record) => ({
    record,
    lexical: lexicalOverlap(queryTokens, record.searchTokens),
    similarity: record.embedding ? cosineSimilarity(queryEmbedding, record.embedding) : null,
  }));
  const best = Math.max(...scored.map((entry) => entry.similarity ?? -1));

  return scored.map(({ record, lexical, similarity }) => {
    const closeInMeaning =
      similarity !== null &&
      similarity >= MATCHING.semanticFloor &&
      similarity >= best - MATCHING.semanticMargin;
    // Similarity is about -1…1; map it to 0…1 so it can be blended with word overlap.
    const meaning = similarity === null ? 0 : (similarity + 1) / 2;
    return {
      record,
      score: meaning * 0.55 + lexical * 0.45,
      isMatch: closeInMeaning || lexical >= MATCHING.fileNameMatch,
    };
  });
}

export function sortRanked(results: readonly RankedRecord[], order: SortOrder): RankedRecord[] {
  const byNewest = (a: RankedRecord, b: RankedRecord) =>
    b.record.lastModified - a.record.lastModified;
  const sorted = [...results];

  switch (order) {
    case "newest":
      return sorted.sort(byNewest);
    case "oldest":
      return sorted.sort((a, b) => a.record.lastModified - b.record.lastModified);
    case "name":
      return sorted.sort((a, b) =>
        a.record.name.localeCompare(b.record.name, undefined, { numeric: true }),
      );
    case "relevance":
      return sorted.sort(
        (a, b) => Number(b.isMatch) - Number(a.isMatch) || b.score - a.score || byNewest(a, b),
      );
  }
}
