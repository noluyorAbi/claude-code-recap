import type { CSSProperties, FC } from "react";
import { AbsoluteFill } from "remotion";

import { MONO } from "../font";
import { ansi, claude, projDot } from "../theme";

/**
 * README hero banner, 1584x396 (LinkedIn 4:1), rendered as a still and shipped
 * to assets/banner.png.
 *
 * Design intent: this is not a logo card, it is a product shot. The left is the
 * brand lockup, the value line, the one install command, and the three trust
 * claims the tool actually keeps (read-only, zero deps, offline). The right is a
 * faithful slice of recap.py's real output: the header count and 14-day
 * sparkline, the green "Today" divider, the per-project colored dots, the coral
 * brand diamond, xterm-256 session ids, and the indented `cd ... && claude -r`
 * resume line that is the whole point of the tool. Colour is spent the way
 * recap spends it: dark surface, one reserved coral accent, green for Today,
 * xterm-74 blue for ids and the sparkline. Nothing decorative.
 */

const mono: CSSProperties = {
  fontFamily: MONO,
  fontVariantLigatures: "none",
  fontFeatureSettings: '"liga" 0, "calt" 0',
  whiteSpace: "pre",
};

const Light: FC<{ c: string }> = ({ c }) => (
  <span style={{ width: 12, height: 12, borderRadius: 6, background: c, display: "block" }} />
);

const Mid: FC = () => <span style={{ color: ansi.fnt }}> · </span>;

type RowData = {
  n: string;
  dot: string;
  time: string;
  rel: string;
  summary: string;
  id: string;
  path: string;
  branch: string;
  model: string;
  turns: string;
};

const ROWS: RowData[] = [
  {
    n: "1",
    dot: projDot.paymentsApi,
    time: "14:22",
    rel: "12m ago",
    summary: "Fix the flaky auth test in checkout",
    id: "a3f91c02",
    path: "~/repos/shop-web",
    branch: "fix/flaky-auth",
    model: "opus-4.8",
    turns: "46 turns",
  },
  {
    n: "2",
    dot: projDot.apiGateway,
    time: "11:05",
    rel: "3h ago",
    summary: "Rewrite the ingest worker to stream",
    id: "6d20be14",
    path: "~/repos/pipeline",
    branch: "main",
    model: "sonnet-4.5",
    turns: "18 turns",
  },
];

const Row: FC<{ row: RowData }> = ({ row }) => (
  <div style={{ ...mono, fontSize: 16, lineHeight: "23px", marginTop: 12 }}>
    <div style={{ display: "flex", alignItems: "baseline" }}>
      <span style={{ color: ansi.fnt, width: 16, display: "inline-block" }}>{row.n}</span>
      <span style={{ color: row.dot, marginRight: 10 }}>●</span>
      <span style={{ color: ansi.today, fontWeight: 700, marginRight: 12 }}>{row.time}</span>
      <span style={{ color: ansi.fnt, width: 78, display: "inline-block" }}>{row.rel}</span>
      <span style={{ color: claude.bright, fontWeight: 700, flex: 1 }}>{row.summary}</span>
      <span style={{ color: ansi.accent, marginLeft: 14 }}>{row.id}</span>
    </div>
    <div style={{ color: claude.dim, paddingLeft: 42, marginTop: 2 }}>
      {row.path}
      <Mid />⎇ {row.branch}
      <Mid />
      {row.model}
      <Mid />
      {row.turns}
    </div>
    <div style={{ paddingLeft: 42, marginTop: 2, color: ansi.mut }}>
      <span style={{ color: ansi.fnt }}>cd</span> {row.path}{" "}
      <span style={{ color: ansi.fnt }}>&amp;&amp; claude -r</span>{" "}
      <span style={{ color: ansi.accent }}>{row.id}</span>
    </div>
  </div>
);

export const Banner: FC = () => {
  return (
    <AbsoluteFill style={{ background: claude.frame }}>
      {/* coral radial lift, weighted toward the brand lockup */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(1150px 560px at 26% 42%, rgba(217,119,87,0.14), rgba(217,119,87,0) 60%)",
        }}
      />

      <AbsoluteFill
        style={{
          padding: "44px 64px",
          display: "flex",
          flexDirection: "row",
          alignItems: "center",
          gap: 56,
        }}
      >
        {/* LEFT: brand lockup + value + install + trust */}
        <div style={{ width: 556, display: "flex", flexDirection: "column", gap: 22 }}>
          <div
            style={{
              ...mono,
              fontSize: 78,
              fontWeight: 700,
              color: claude.bright,
              letterSpacing: -1,
              lineHeight: 1,
            }}
          >
            <span style={{ color: claude.clay }}>◆</span> recap
          </div>

          <div style={{ ...mono, fontSize: 24, color: claude.dim, lineHeight: "34px" }}>
            Every recent Claude Code session,{"\n"}across every repo, on one screen.
          </div>

          <div
            style={{
              ...mono,
              fontSize: 22,
              color: claude.text,
              background: claude.panel,
              border: `1px solid ${claude.border}`,
              borderRadius: 10,
              padding: "12px 20px",
              alignSelf: "flex-start",
            }}
          >
            <span style={{ color: claude.clay }}>$</span> npx claude-code-recap
          </div>

          <div style={{ ...mono, fontSize: 18, color: ansi.mut, letterSpacing: 0.3 }}>
            read-only
            <span style={{ color: claude.clay }}> · </span>zero deps
            <span style={{ color: claude.clay }}> · </span>offline
            <span style={{ color: claude.clay }}> · </span>one command back in
          </div>
        </div>

        {/* RIGHT: the real product, as proof */}
        <div
          style={{
            flex: 1,
            background: claude.bg,
            border: `1px solid ${claude.border}`,
            borderRadius: 14,
            boxShadow: "0 24px 60px rgba(0,0,0,0.5)",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              height: 38,
              background: claude.panel,
              borderBottom: `1px solid ${claude.border}`,
              display: "flex",
              alignItems: "center",
              paddingLeft: 16,
              gap: 8,
            }}
          >
            <Light c="#ff5f57" />
            <Light c="#febc2e" />
            <Light c="#28c840" />
            <span style={{ ...mono, fontSize: 15, color: ansi.mut, marginLeft: 14 }}>recap</span>
          </div>

          <div style={{ padding: "16px 22px" }}>
            {/* header: brand, counts, 14-day sparkline */}
            <div
              style={{
                ...mono,
                fontSize: 16,
                display: "flex",
                alignItems: "baseline",
                justifyContent: "space-between",
              }}
            >
              <span>
                <span style={{ color: claude.clay }}>◆</span>{" "}
                <span style={{ color: claude.bright, fontWeight: 700 }}>recap</span>
              </span>
              <span style={{ color: ansi.fnt }}>6 sessions · 5 projects</span>
              <span>
                <span style={{ color: ansi.mut }}>14d </span>
                <span style={{ color: ansi.accent }}>▂▁▄▃▅▂▆█▃▅▇▄▆█</span>
              </span>
            </div>

            <div style={{ ...mono, fontSize: 15, marginTop: 10, color: ansi.today, fontWeight: 700 }}>
              {"── Today "}
              <span style={{ color: ansi.fnt }}>
                {"────────────────────────────────────────────"}
              </span>
            </div>

            {ROWS.map((row) => (
              <Row key={row.id} row={row} />
            ))}
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
