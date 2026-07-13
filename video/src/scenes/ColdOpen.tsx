import type { FC } from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

import { Cursor } from "../components/Term";
import { MONO } from "../font";
import { claude, easing } from "../theme";

/**
 * The problem, stated once, in the tool's own voice. Three lines, staggered.
 *
 * The count is 11: that is every session on disk. The demo then runs
 * `--since 24h`, which is why the listing that follows shows 4. The two numbers
 * are consistent, not a slip.
 */
const LINES: { text: string; color: string; bold: boolean }[] = [
  { text: "You rebooted.", color: claude.dim, bold: false },
  { text: "Eleven sessions.", color: claude.text, bold: false },
  { text: "Which one was the hotfix?", color: claude.bright, bold: true },
];

export const COLD_OPEN_DUR = 132;

export const ColdOpen: FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const leave = interpolate(frame, [COLD_OPEN_DUR - 20, COLD_OPEN_DUR], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        opacity: leave,
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        {LINES.map((line, i) => {
          const start = 10 + i * 20;
          const t = interpolate(frame, [start, start + 12], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(...easing.out),
          });
          const last = i === LINES.length - 1;
          return (
            <div
              key={line.text}
              style={{
                fontFamily: MONO,
                fontSize: 54,
                lineHeight: 1.35,
                color: line.color,
                fontWeight: line.bold ? 700 : 400,
                fontVariantLigatures: "none",
                fontFeatureSettings: '"liga" 0, "calt" 0',
                whiteSpace: "pre",
                opacity: t,
                transform: `translateY(${interpolate(t, [0, 1], [10, 0])}px)`,
              }}
            >
              {line.text}
              {/* the first coral on screen, and the bridge into the terminal */}
              {last && frame >= start + 12 ? (
                <>
                  {" "}
                  <Cursor frame={frame} fps={fps} blink />
                </>
              ) : null}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
