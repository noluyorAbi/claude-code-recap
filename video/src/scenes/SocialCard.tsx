import type { CSSProperties, FC } from "react";
import { AbsoluteFill } from "remotion";

import { MONO } from "../font";
import { ansi, claude, projDot } from "../theme";

/**
 * GitHub social preview card, 1280x640 (2:1), rendered as a still.
 *
 * GitHub crops this card to different aspect ratios across surfaces, so every
 * load-bearing element stays inside a centered safe area with generous margins.
 * The mini listing is a faithful (static) slice of recap.py's real output: the
 * same column order, the same coral brand diamond, the same xterm-256 colors.
 */

const mono: CSSProperties = {
  fontFamily: MONO,
  fontVariantLigatures: "none",
  fontFeatureSettings: '"liga" 0, "calt" 0',
  whiteSpace: "pre",
};

type Row = {
  dot: string;
  time: string;
  rel: string;
  summary: string;
  id: string;
};

const ROWS: Row[] = [
  { dot: projDot.mySaas, time: "18:42", rel: "12m ago", summary: "Ship the Stripe webhook retry queue", id: "a3f9c1d2" },
  { dot: projDot.paymentsApi, time: "17:05", rel: "1h ago", summary: "Add idempotency keys to the charge endpoint", id: "7be40c19" },
  { dot: projDot.apiGateway, time: "14:20", rel: "4h ago", summary: "Debug the 502 on the auth proxy", id: "c081ff5a" },
];

const ListingRow: FC<{ row: Row }> = ({ row }) => (
  <div style={{ ...mono, fontSize: 20, lineHeight: "30px", display: "flex", alignItems: "baseline" }}>
    <span style={{ color: row.dot, marginRight: 14 }}>●</span>
    <span style={{ color: ansi.today, fontWeight: 700, marginRight: 12 }}>{row.time}</span>
    <span style={{ color: ansi.fnt, marginRight: 18, width: 74, display: "inline-block" }}>{row.rel}</span>
    <span style={{ color: claude.bright, fontWeight: 700, flex: 1 }}>{row.summary}</span>
    <span style={{ color: ansi.accent, marginLeft: 18 }}>{row.id}</span>
  </div>
);

export const SocialCard: FC = () => {
  return (
    <AbsoluteFill style={{ background: claude.frame }}>
      {/* soft radial lift behind the content */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(1100px 620px at 50% 40%, rgba(217,119,87,0.10), rgba(217,119,87,0) 60%)",
        }}
      />

      <AbsoluteFill
        style={{
          padding: 64,
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        {/* brand + tagline */}
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div style={{ ...mono, fontSize: 68, fontWeight: 700, color: claude.bright, letterSpacing: -1 }}>
            <span style={{ color: claude.clay }}>◆</span> recap
          </div>
          <div style={{ ...mono, fontSize: 27, color: claude.dim }}>
            Get back into every Claude Code session.
          </div>
        </div>

        {/* mini terminal window: the product, as proof */}
        <div
          style={{
            background: claude.bg,
            border: `1px solid ${claude.border}`,
            borderRadius: 14,
            boxShadow: "0 24px 60px rgba(0,0,0,0.45)",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              height: 40,
              background: claude.panel,
              borderBottom: `1px solid ${claude.border}`,
              display: "flex",
              alignItems: "center",
              paddingLeft: 18,
              gap: 9,
            }}
          >
            <span style={{ width: 12, height: 12, borderRadius: 6, background: "#ff5f57", display: "block" }} />
            <span style={{ width: 12, height: 12, borderRadius: 6, background: "#febc2e", display: "block" }} />
            <span style={{ width: 12, height: 12, borderRadius: 6, background: "#28c840", display: "block" }} />
            <span style={{ ...mono, fontSize: 16, color: ansi.mut, marginLeft: 16 }}>recap</span>
          </div>

          <div style={{ padding: "20px 26px", display: "flex", flexDirection: "column", gap: 4 }}>
            <div style={{ ...mono, fontSize: 18, color: ansi.today, fontWeight: 700, marginBottom: 6 }}>
              {"── Today "}
              <span style={{ color: ansi.fnt }}>
                {"──────────────────────────────────────────────────"}
              </span>
            </div>
            {ROWS.map((row) => (
              <ListingRow key={row.id} row={row} />
            ))}
          </div>
        </div>

        {/* install + repo */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div
            style={{
              ...mono,
              fontSize: 26,
              color: claude.text,
              background: claude.panel,
              border: `1px solid ${claude.border}`,
              borderRadius: 10,
              padding: "13px 24px",
            }}
          >
            <span style={{ color: claude.clay }}>$</span> npx claude-code-recap
          </div>
          <div style={{ ...mono, fontSize: 22, color: ansi.mut }}>
            github.com/noluyorAbi/claude-code-recap
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
