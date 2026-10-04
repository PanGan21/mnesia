/** A few drawn scenes so people can try search without their own photos. */

interface SampleTemplate {
  name: string;
  lastModified: number;
  svg: string;
}

const SAMPLES: readonly SampleTemplate[] = [
  {
    name: "dog-park-sunset-demo.svg",
    lastModified: new Date("2025-08-14T18:15:00Z").getTime(),
    svg: `
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900">
        <defs>
          <linearGradient id="sky" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stop-color="#5a6aa8"/>
            <stop offset="52%" stop-color="#ef8d67"/>
            <stop offset="100%" stop-color="#27473b"/>
          </linearGradient>
        </defs>
        <rect width="1200" height="900" fill="url(#sky)"/>
        <rect y="560" width="1200" height="340" fill="#2f6b42"/>
        <circle cx="930" cy="230" r="110" fill="#ffd796" opacity="0.92"/>
        <ellipse cx="420" cy="620" rx="210" ry="110" fill="#88b36f" opacity="0.55"/>
        <path d="M420 560c-48 0-82 38-82 86 0 47 34 86 82 86 49 0 84-39 84-86 0-48-35-86-84-86zm88 56 38-44 36 22-29 55zm-179 11-40-29-37 25 35 40z" fill="#fff7ef"/>
      </svg>
    `,
  },
  {
    name: "birthday-cake-kitchen-demo.svg",
    lastModified: new Date("2025-11-02T19:40:00Z").getTime(),
    svg: `
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900">
        <rect width="1200" height="900" fill="#2f2430"/>
        <rect y="600" width="1200" height="300" fill="#5b3f34"/>
        <ellipse cx="600" cy="650" rx="250" ry="90" fill="#d1d8ea"/>
        <rect x="420" y="420" width="360" height="180" rx="40" fill="#ffddb6"/>
        <rect x="460" y="360" width="280" height="90" rx="30" fill="#f6aec2"/>
        <circle cx="530" cy="390" r="25" fill="#ffe6f1"/>
        <circle cx="600" cy="375" r="24" fill="#fff2c6"/>
        <circle cx="675" cy="392" r="25" fill="#ffe6f1"/>
        <rect x="500" y="280" width="16" height="95" rx="8" fill="#ffd6ab"/>
        <rect x="590" y="250" width="16" height="125" rx="8" fill="#ffd6ab"/>
        <rect x="680" y="275" width="16" height="100" rx="8" fill="#ffd6ab"/>
        <path d="M508 250c20 20 20 46 0 62-20-16-20-42 0-62zm90-25c24 24 24 52 0 72-24-20-24-48 0-72zm89 23c22 22 22 49 0 66-22-17-22-44 0-66z" fill="#ffca58"/>
      </svg>
    `,
  },
  {
    name: "canal-lunch-spring-demo.svg",
    lastModified: new Date("2026-04-21T12:05:00Z").getTime(),
    svg: `
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900">
        <rect width="1200" height="900" fill="#5d7485"/>
        <rect y="500" width="1200" height="400" fill="#31485f"/>
        <rect x="0" y="560" width="1200" height="140" fill="#23374e"/>
        <rect x="120" y="240" width="160" height="340" fill="#6f594b"/>
        <rect x="920" y="190" width="140" height="390" fill="#7e695c"/>
        <ellipse cx="640" cy="640" rx="240" ry="95" fill="#efe6d6"/>
        <ellipse cx="640" cy="620" rx="160" ry="55" fill="#d59762"/>
        <ellipse cx="580" cy="600" rx="54" ry="40" fill="#a64f34"/>
        <ellipse cx="700" cy="610" rx="82" ry="48" fill="#9bcc6a"/>
        <circle cx="885" cy="220" r="76" fill="#d8e8ff" opacity="0.92"/>
      </svg>
    `,
  },
  {
    name: "night-tower-city-demo.svg",
    lastModified: new Date("2025-01-09T21:22:00Z").getTime(),
    svg: `
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900">
        <rect width="1200" height="900" fill="#1b2435"/>
        <rect y="620" width="1200" height="280" fill="#0e1523"/>
        <circle cx="820" cy="170" r="72" fill="#f7efcb"/>
        <rect x="570" y="160" width="34" height="520" rx="17" fill="#d4e2ff"/>
        <ellipse cx="587" cy="220" rx="120" ry="34" fill="#b6cdfd"/>
        <ellipse cx="587" cy="220" rx="60" ry="74" fill="#ccdefe"/>
        <rect x="560" y="360" width="54" height="320" rx="27" fill="#89aef4"/>
        <rect x="140" y="410" width="180" height="210" fill="#2b3550"/>
        <rect x="860" y="370" width="220" height="250" fill="#26344d"/>
      </svg>
    `,
  },
];

export function createSampleFiles(): File[] {
  return SAMPLES.map(
    (sample) =>
      new File([sample.svg.trim()], sample.name, {
        type: "image/svg+xml",
        lastModified: sample.lastModified,
      }),
  );
}
