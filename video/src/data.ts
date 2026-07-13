/**
 * The demo transcript.
 *
 * Every line here mirrors skills/recap/recap.py's render() byte for byte at
 * COLUMNS=100. The spacing is not eyeballed: it is produced by the same
 * formulas the tool uses (gap, rule width, header pad), so the video shows the
 * layout the tool actually prints.
 *
 * The sessions are invented. Generic project names, invented UUID session ids,
 * a ~-relative home. Nothing here is a real path or a real session.
 */

import { ansi, claude, projDot } from "./theme";
import { padLeft, spaces, type Span } from "./spans";

const COLS = 112; // see TERM.cols: the narrowest width at which no line wraps

type Session = {
  idx: number;
  dot: string;
  time: string;
  rel: string;
  summary: string;
  sid: string; // full session id, as used by the resume command
  path: string;
  branch: string;
  model: string;
  turns: string;
  day: "today" | "yesterday";
};

export const SESSIONS: Session[] = [
  {
    idx: 1,
    dot: projDot.mySaas,
    time: "18:42",
    rel: "12m ago",
    summary: "Ship the Stripe webhook retry queue",
    sid: "a3f9c1d2-4e7b-4a10-9c3f-2b8e5d1a6f04",
    path: "~/repos/my-saas",
    branch: "main",
    model: "sonnet-4.5",
    turns: "47 turns",
    day: "today",
  },
  {
    idx: 2,
    dot: projDot.paymentsApi,
    time: "17:05",
    rel: "1h ago",
    summary: "Add idempotency keys to the charge endpoint",
    sid: "7be40c19-aa3f-4d82-b1e5-9c4a7f2e0d63",
    path: "~/repos/payments-api",
    branch: "feat/idempotency-keys",
    model: "opus-4.1",
    turns: "63 turns",
    day: "today",
  },
  {
    idx: 3,
    dot: projDot.apiGateway,
    time: "14:20",
    rel: "4h ago",
    summary: "Debug the 502 on the auth proxy",
    sid: "c081ff5a-6d2e-4b93-8a17-4f0c6e93b2d5",
    path: "~/repos/api-gateway",
    branch: "fix/auth-proxy",
    model: "sonnet-4.5",
    turns: "21 turns",
    day: "today",
  },
  {
    idx: 4,
    dot: projDot.portfolioSite,
    time: "22:10",
    rel: "20h ago",
    summary: "Dark mode tokens and the nav rework",
    sid: "5d2ab8e7-f14c-4a06-9e2b-7d3f81c5a9e4",
    path: "~/repos/portfolio-site",
    branch: "main",
    model: "haiku-4.5",
    turns: "9 turns",
    day: "yesterday",
  },
];

// ---------- line builders, mirroring recap.py::render ----------

/** header: left mark, then meta + 14-day sparkline pushed to the right edge. */
const headerLine = (): Span[] => {
  const meta = `${SESSIONS.length} sessions · 4 projects`;
  const spark = "▂▃ ▅▃▆▂▇▅▃█▆▅▇"; // sparkline(day_counts), 14 buckets
  // pad = term_w - 8 - len(meta) - 4 - len(day_counts) - 3
  const pad = Math.max(2, COLS - 8 - meta.length - 4 - 14 - 3);
  return [
    { text: "◆", color: claude.clay, bold: true },
    { text: " " },
    { text: "recap", color: ansi.fg, bold: true },
    { text: spaces(pad) },
    { text: meta, color: ansi.mut },
    { text: "   " },
    { text: "14d ", color: ansi.fnt },
    { text: spark, color: ansi.accent },
  ];
};

/** day rule: "── Today " + "─" * (term_w - len(label) - 6) */
const dayRule = (label: string, color: string): Span[] => [
  { text: `── ${label} `, color, bold: true },
  { text: "─".repeat(COLS - label.length - 6), color: ansi.fnt },
];

/** line 1: index · dot · time · summary · short id */
const sessionHead = (s: Session): Span[] => {
  const dayColor = s.day === "today" ? ansi.today : ansi.yesterday;
  // gap = term_w - 2 - 2 - 2 - 14 - 2 - len(summary) - 8 - 2
  const gap = Math.max(2, COLS - 32 - s.summary.length);
  return [
    { text: " " },
    { text: padLeft(String(s.idx), 2), color: ansi.fnt },
    { text: " " },
    { text: "●", color: s.dot },
    { text: " " },
    { text: s.time, color: dayColor, bold: true },
    { text: " " },
    { text: padLeft(s.rel, 7), color: ansi.fnt },
    { text: "  " },
    { text: s.summary, color: ansi.fg, bold: true },
    { text: spaces(gap) },
    { text: s.sid.slice(0, 8), color: ansi.accent },
  ];
};

/** line 2: path · branch · model · turns, all muted, joined by "  ·  " */
const sessionMeta = (s: Session): Span[] => {
  const sep: Span = { text: "  ·  ", color: ansi.mut };
  return [
    { text: spaces(13) },
    { text: s.path, color: ansi.mut },
    sep,
    { text: "⎇", color: ansi.mut, icon: "branch" },
    { text: ` ${s.branch}`, color: ansi.mut },
    sep,
    { text: s.model, color: ansi.mut },
    sep,
    { text: s.turns, color: ansi.mut },
  ];
};

/** line 3: the ready-to-paste resume command */
const sessionResume = (s: Session): Span[] => [
  { text: spaces(13) },
  { text: `cd ${s.path} && claude -r ${s.sid}`, color: ansi.fnt },
];

// ---------- the transcript ----------

export type TLine = {
  key: string;
  /** scene-local frame at which the line appears */
  from: number;
  kind: "typed" | "out";
  spans: Span[];
  /** vertical rows the line occupies (the footer wraps to 2) */
  rows?: number;
  /** allow soft wrapping (only the footer needs it) */
  wrap?: boolean;
  /** typed lines only: frame at which the first character is typed */
  typeAt?: number;
  /** typed lines only: characters per second */
  cps?: number;
  /** typed lines only: frame at which the line is submitted and the cursor goes */
  submitAt?: number;
};

const promptSpans = (cmd: string): Span[] => [
  { text: "> ", color: claude.clay, bold: true },
  { text: cmd, color: ansi.fg },
];

const blank = (key: string, from: number): TLine => ({
  key,
  from,
  kind: "out",
  spans: [],
});

const out = (key: string, from: number, spans: Span[]): TLine => ({
  key,
  from,
  kind: "out",
  spans,
});

// Beat timings, scene-local frames at 30fps. The list build is deliberately
// unhurried: the payoff beat is the one people need time to actually read.
export const T = {
  windowIn: 0,
  /** the shell prompt is on screen as soon as the window is */
  prompt1: 6,
  type1: 16,
  outputStart: 70,
  /** list is fully built here; it then holds, untouched, for 3 seconds */
  listDone: 176,
  footer: 266,
  prompt2: 305,
  type2: 315,
  openingLine: 388,
  tabsStart: 396,
  tabStagger: 10,
  tabDur: 12,
  doneLine: 452,
  end: 510,
} as const;

const s1 = SESSIONS[0];
const s2 = SESSIONS[1];
const s3 = SESSIONS[2];
const s4 = SESSIONS[3];

export const TRANSCRIPT: TLine[] = [
  {
    key: "p1",
    from: T.prompt1,
    typeAt: T.type1,
    kind: "typed",
    spans: promptSpans("/recap --since 24h"),
    cps: 16,
    submitAt: T.outputStart - 4,
  },

  blank("b0", T.outputStart),
  out("head", T.outputStart + 6, headerLine()),
  blank("b1", T.outputStart + 8),
  out("today", T.outputStart + 14, dayRule("Today", ansi.today)),
  blank("b2", T.outputStart + 16),

  out("s1a", T.outputStart + 22, sessionHead(s1)),
  out("s1b", T.outputStart + 26, sessionMeta(s1)),
  out("s1c", T.outputStart + 30, sessionResume(s1)),
  blank("b3", T.outputStart + 32),

  out("s2a", T.outputStart + 44, sessionHead(s2)),
  out("s2b", T.outputStart + 48, sessionMeta(s2)),
  out("s2c", T.outputStart + 52, sessionResume(s2)),
  blank("b4", T.outputStart + 54),

  out("s3a", T.outputStart + 66, sessionHead(s3)),
  out("s3b", T.outputStart + 70, sessionMeta(s3)),
  out("s3c", T.outputStart + 74, sessionResume(s3)),
  blank("b5", T.outputStart + 76),

  out("yest", T.outputStart + 88, dayRule("Yesterday", ansi.yesterday)),
  blank("b6", T.outputStart + 90),

  out("s4a", T.outputStart + 98, sessionHead(s4)),
  out("s4b", T.outputStart + 102, sessionMeta(s4)),
  out("s4c", T.outputStart + 106, sessionResume(s4)),

  blank("b7", T.footer),
  {
    key: "footer",
    from: T.footer + 2,
    kind: "out",
    spans: [
      {
        text:
          " turns ≈ user + assistant messages   ·   --pick jump in   ·   " +
          "--open all in tabs   ·   --smart 1-line summaries",
        color: ansi.fnt,
      },
    ],
  },

  {
    key: "p2",
    from: T.prompt2,
    typeAt: T.type2,
    kind: "typed",
    spans: promptSpans("/recap --since 24h --open"),
    cps: 16,
    submitAt: T.openingLine - 6,
  },
  blank("b8", T.openingLine - 4),
  out("opening", T.openingLine, [
    { text: "Opening 4 tab(s):", color: ansi.fg, bold: true },
  ]),
  blank("b9", T.doneLine - 4),
  out("done", T.doneLine, [
    { text: "Opened 4 tab(s) in iTerm2", color: ansi.today },
  ]),
];

/** Cumulative row offset of each line, for the scroll math. */
export const rowOffsets: number[] = (() => {
  const offs: number[] = [];
  let row = 0;
  for (const l of TRANSCRIPT) {
    offs.push(row);
    row += l.rows ?? 1;
  }
  return offs;
})();

export const totalRows = (() => {
  let row = 0;
  for (const l of TRANSCRIPT) {
    row += l.rows ?? 1;
  }
  return row;
})();
