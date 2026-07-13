/**
 * Palette and motion tokens.
 *
 * Two sources, deliberately kept apart:
 *
 * 1. `claude`: the Anthropic / Claude Code design tokens (surfaces, chrome,
 *    the coral accent). These style the *window* the tool runs in.
 * 2. `ansi`: the true xterm-256 colors that recap.py actually emits. These
 *    style the *output text*, so the recap listing in the video is the same
 *    listing you get in a real 256-color terminal.
 *
 * Coral (#d97757) is reserved. It is used only for the prompt caret, the
 * cursor, the brand diamond, and the end card. If everything is coral,
 * nothing is.
 */

export const claude = {
  clay: "#d97757", // --clay, the Claude coral
  clayDeep: "#c6613f", // --clay-emphasized
  bg: "#0b0b0b", // --gray-900, terminal backdrop
  frame: "#060606", // page behind the window
  panel: "#1a1a19", // --gray-830, window chrome
  panelHi: "#20201f", // --gray-800
  border: "#383835", // --gray-700
  dim: "#7b7974", // --gray-450
  text: "#e4e3dd", // --gray-90
  bright: "#faf9f5", // headline
} as const;

/**
 * xterm-256 -> hex, matching the constants at the top of skills/recap/recap.py.
 * FG 253, SEC 248, MUT 242, FNT 238, ACCENT 74, TODAY 114, YESTERDAY 179.
 */
export const ansi = {
  fg: "#dadada", // 253, primary
  sec: "#a8a8a8", // 248, secondary
  mut: "#6c6c6c", // 242, muted
  fnt: "#444444", // 238, faint
  accent: "#5fafd7", // 74, session ids, brand mark, sparkline
  today: "#87d787", // 114
  yesterday: "#d7af5f", // 179
} as const;

/**
 * PROJ_PALETTE entries picked by recap.py's proj_color() for the four demo
 * paths. Verified by importing recap.py and calling proj_color() on each path,
 * so these are the dots the real tool would draw.
 */
export const projDot = {
  mySaas: "#af87af", // xterm 139
  paymentsApi: "#87afd7", // xterm 110
  apiGateway: "#d787d7", // xterm 176
  portfolioSite: "#d7af87", // xterm 180
} as const;

/** Anthropic's own easing curves, straight from the Claude Code design tokens. */
export const easing = {
  out: [0.165, 0.84, 0.44, 1] as [number, number, number, number], // --ease-out
  snap: [0.32, 0.72, 0, 1] as [number, number, number, number], // --ease-snap
} as const;

/**
 * Terminal metrics. JetBrains Mono has an advance width of exactly 600/1000 em
 * for every glyph it ships (verified against the font's hmtx table, including
 * the box-drawing and block characters), so one column is exactly 0.6 * fontSize.
 */
export const TERM = {
  /**
   * 112 columns. recap.py renders to min(terminal width, 130), and its footer
   * hint line is 111 characters, so anything narrower hard-wraps that line mid
   * word and it reads as a typo. 112 is the narrowest width at which every line
   * the tool prints lands on a single row, which is how it looks in a real
   * shell.
   */
  cols: 112,
  fontSize: 25,
  charW: 25 * 0.6, // 15px exactly
  lineHeight: 34, // 1.36, in the range real terminals use
  /**
   * 23 rows is exactly the height of the finished listing (the prompt plus all
   * 22 output rows through the last resume command), so the payoff frame sits
   * at scroll 0 with nothing clipped. The buffer only starts scrolling once
   * `--open` adds to it.
   */
  viewportRows: 23,
} as const;

export const CONTENT_W = TERM.cols * TERM.charW; // 1680
export const PAD_X = 40;
export const PAD_Y = 28;
export const TITLEBAR_H = 48;
export const VIEWPORT_H = TERM.viewportRows * TERM.lineHeight; // 880

export const WINDOW_W = CONTENT_W + PAD_X * 2; // 1760
export const WINDOW_H = VIEWPORT_H + TITLEBAR_H + PAD_Y * 2; // 984
