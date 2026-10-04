/** Finds a required element, failing loudly at startup if the markup and code drift apart. */
export function requireElement<T extends Element>(
  selector: string,
  type: abstract new () => T,
  root: ParentNode = document,
): T {
  const element = root.querySelector(selector);
  if (!(element instanceof type)) {
    throw new Error(`Expected ${selector} to be a ${type.name}.`);
  }
  return element;
}

export function requireElements<T extends Element>(
  selector: string,
  type: abstract new () => T,
  root: ParentNode = document,
): T[] {
  const elements = Array.from(root.querySelectorAll(selector));
  if (elements.length === 0 || !elements.every((element) => element instanceof type)) {
    throw new Error(`Expected at least one ${type.name} matching ${selector}.`);
  }
  return elements as T[];
}

const SVG_NS = "http://www.w3.org/2000/svg";

/** An inline icon that references a symbol from the sprite in index.html. */
export function createIcon(symbolId: string): SVGSVGElement {
  const svg = document.createElementNS(SVG_NS, "svg");
  svg.setAttribute("class", "icon");
  svg.setAttribute("aria-hidden", "true");
  const use = document.createElementNS(SVG_NS, "use");
  use.setAttribute("href", `#${symbolId}`);
  svg.append(use);
  return svg;
}

export function createSvgElement<K extends keyof SVGElementTagNameMap>(
  tag: K,
): SVGElementTagNameMap[K] {
  return document.createElementNS(SVG_NS, tag);
}

export function debounce<Args extends unknown[]>(
  fn: (...args: Args) => void,
  delayMs: number,
): (...args: Args) => void {
  let timerId: ReturnType<typeof setTimeout> | undefined;
  return (...args: Args) => {
    clearTimeout(timerId);
    timerId = setTimeout(() => fn(...args), delayMs);
  };
}
