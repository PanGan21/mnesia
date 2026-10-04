import type { MediaKind, TimeFilter } from "../types";

export interface ParsedQuery {
  /** What's left to match by meaning once filter words are removed. */
  text: string;
  mediaKind: MediaKind | null;
  timeFilter: TimeFilter | null;
  /** Human-readable labels for the filters found in the words, in the order found. */
  understood: string[];
}

interface Rule<T> {
  pattern: string;
  value: T;
  label: string;
}

const MEDIA_RULES: readonly Rule<MediaKind>[] = [
  { pattern: "videos?|clips?|movies?", value: "video", label: "Videos" },
  { pattern: "photos?|images?|pictures?|screenshots?", value: "image", label: "Photos" },
];

// Order matters: multi-word phrases first, then seasons, then months.
const TIME_RULES: readonly Rule<TimeFilter>[] = [
  { pattern: "last 30 days", value: "30d", label: "Last 30 days" },
  { pattern: "this year", value: "this-year", label: "This year" },
  { pattern: "last year", value: "last-year", label: "Last year" },
  { pattern: "winter", value: "winter", label: "Winter" },
  { pattern: "spring", value: "spring", label: "Spring" },
  { pattern: "summer", value: "summer", label: "Summer" },
  { pattern: "autumn|fall", value: "autumn", label: "Autumn" },
  { pattern: "january|jan", value: "jan", label: "January" },
  { pattern: "february|feb", value: "feb", label: "February" },
  { pattern: "march|mar", value: "mar", label: "March" },
  { pattern: "april|apr", value: "apr", label: "April" },
  { pattern: "may", value: "may", label: "May" },
  { pattern: "june|jun", value: "jun", label: "June" },
  { pattern: "july|jul", value: "jul", label: "July" },
  { pattern: "august|aug", value: "aug", label: "August" },
  { pattern: "september|sept|sep", value: "sep", label: "September" },
  { pattern: "october|oct", value: "oct", label: "October" },
  { pattern: "november|nov", value: "nov", label: "November" },
  { pattern: "december|dec", value: "dec", label: "December" },
];

/** Whole words only, so "waterfall" isn't autumn and "eclipse" isn't a video. */
function wordPattern(pattern: string): RegExp {
  return new RegExp(`(?<![\\p{L}\\p{N}])(?:${pattern})(?![\\p{L}\\p{N}])`, "giu");
}

function extract<T>(
  text: string,
  rules: readonly Rule<T>[],
): { text: string; rule: Rule<T> | null } {
  for (const rule of rules) {
    const regex = wordPattern(rule.pattern);
    if (regex.test(text)) {
      regex.lastIndex = 0;
      return { text: text.replace(regex, " "), rule };
    }
  }
  return { text, rule: null };
}

// Words left dangling once a filter phrase is removed ("photos from | april").
const CONNECTORS = new Set([
  "in",
  "from",
  "during",
  "on",
  "at",
  "of",
  "the",
  "last",
  "this",
  "taken",
]);

function trimConnectors(text: string): string {
  const words = text.split(" ").filter(Boolean);
  while (words.length > 0 && CONNECTORS.has(words[0] as string)) {
    words.shift();
  }
  while (words.length > 0 && CONNECTORS.has(words[words.length - 1] as string)) {
    words.pop();
  }
  return words.join(" ");
}

/**
 * Pulls media-type and time hints out of a natural-language query, e.g.
 * "videos of the beach last summer" → { text: "beach", mediaKind: "video", timeFilter: "summer" }.
 */
export function parseQuery(rawQuery: string): ParsedQuery {
  const original = rawQuery.trim();
  const media = extract(original.toLowerCase(), MEDIA_RULES);
  const time = extract(media.text, TIME_RULES);
  const filtered = media.rule !== null || time.rule !== null;
  const collapsed = time.text.replace(/\s+/g, " ").trim();
  // Only trim connectors when a filter was removed; "the beach" alone stays as typed.
  const text = filtered ? trimConnectors(collapsed) : collapsed;

  return {
    // If the whole query was filter words ("videos"), keep it so ranking still has something to use.
    text: text || original,
    mediaKind: media.rule?.value ?? null,
    timeFilter: time.rule?.value ?? null,
    understood: [media.rule?.label, time.rule?.label].filter(
      (label): label is string => label !== undefined,
    ),
  };
}
