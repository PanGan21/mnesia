import type { MediaFilter, MediaRecord, RankedRecord, SortOrder, TimeFilter } from "../types";
import { parseQuery, type ParsedQuery } from "./query-parser";
import { rankRecords, sortRanked } from "./ranking";
import { matchesTimeFilter } from "./time";

export interface SearchRequest {
  query: string;
  mediaFilter: MediaFilter;
  timeFilter: TimeFilter;
  sortOrder: SortOrder;
}

export interface SearchOutcome {
  query: string;
  parsed: ParsedQuery;
  /** Close matches, best first. Without a query: everything that passes the filters. */
  results: RankedRecord[];
  /** The rest, ordered by how close they are; offered as "might match". */
  others: RankedRecord[];
  /** Whether results were ranked by meaning, not only by file names and dates. */
  semantic: boolean;
}

/** Turns a query into a vector, or null when the model isn't available. */
export type EmbedQuery = ((text: string) => Promise<Float32Array>) | null;

export async function search(
  records: readonly MediaRecord[],
  request: SearchRequest,
  embedQuery: EmbedQuery,
  now = new Date(),
): Promise<SearchOutcome> {
  const query = request.query.trim();
  const parsed = parseQuery(query);
  // Words in the query ("videos", "last summer") take precedence over the controls.
  const mediaFilter: MediaFilter = parsed.mediaKind ?? request.mediaFilter;
  const timeFilter: TimeFilter = parsed.timeFilter ?? request.timeFilter;

  const candidates = records.filter(
    (record) =>
      (mediaFilter === "all" || record.mediaKind === mediaFilter) &&
      matchesTimeFilter(record.lastModified, timeFilter, now),
  );

  if (!query) {
    const order = request.sortOrder === "relevance" ? "newest" : request.sortOrder;
    const all = candidates.map((record) => ({ record, score: 1, isMatch: true }));
    return { query, parsed, results: sortRanked(all, order), others: [], semantic: false };
  }

  const embedding = embedQuery ? await embedQuery(parsed.text) : null;
  const ranked = sortRanked(rankRecords(candidates, parsed.text, embedding), request.sortOrder);
  return {
    query,
    parsed,
    results: ranked.filter((entry) => entry.isMatch),
    others: ranked.filter((entry) => !entry.isMatch),
    semantic: embedding !== null,
  };
}
