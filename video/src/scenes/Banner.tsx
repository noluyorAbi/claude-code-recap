import type { CSSProperties, FC } from "react";
import { AbsoluteFill } from "remotion";

import { MONO } from "../font";
import { ansi, claude } from "../theme";

/**
 * README hero banner, 1584x396 (LinkedIn 4:1), rendered as a still and shipped to
 * assets/banner.png. Same wordmark grammar as the social card and end card:
 * the coral brand diamond, JetBrains Mono, the reserved coral accent. The
 * 14-day activity sparkline underneath is the exact glyph run recap.py prints
 * in its own header, in the same xterm-74 blue (theme `ansi.accent`), so the
 * banner is a faithful piece of the product, not decoration bolted on top.
 */

const mono: CSSProperties = {
  fontFamily: MONO,
  fontVariantLigatures: "none",
  fontFeatureSettings: '"liga" 0, "calt" 0',
  whiteSpace: "pre",
};

// the header sparkline from a real recap run
const SPARK = "▂▁▄▃▅▂▆█▃▅▇▄▆█";

export const Banner: FC = () => {
  return (
    <AbsoluteFill style={{ background: claude.bg }}>
      {/* soft coral radial lift behind the wordmark */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(1180px 470px at 50% 46%, rgba(217,119,87,0.15), rgba(217,119,87,0) 64%)",
        }}
      />

      {/* hairline top and bottom rules, the day-divider motif */}
      <AbsoluteFill
        style={{
          borderTop: `1px solid ${claude.border}`,
          borderBottom: `1px solid ${claude.border}`,
          opacity: 0.6,
        }}
      />

      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          gap: 22,
        }}
      >
        <div
          style={{
            ...mono,
            fontSize: 132,
            fontWeight: 700,
            color: claude.bright,
            letterSpacing: -1,
            lineHeight: 1,
          }}
        >
          <span style={{ color: claude.clay }}>◆</span> recap
        </div>

        <div style={{ ...mono, fontSize: 31, color: claude.dim }}>
          Get back into every Claude Code session.
        </div>

        <div
          style={{
            ...mono,
            fontSize: 30,
            color: ansi.accent,
            letterSpacing: 3,
            marginTop: 8,
          }}
        >
          {SPARK}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
