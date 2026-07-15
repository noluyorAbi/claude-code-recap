import type { FC } from "react";
import { Composition, Still } from "remotion";

import { Demo, DEMO_DURATION } from "./Demo";
import { Banner } from "./scenes/Banner";
import { SocialCard } from "./scenes/SocialCard";

// side effect: blocks the render until JetBrains Mono is actually loaded
import "./font";

export const RemotionRoot: FC = () => {
  return (
    <>
      <Composition
        id="Demo"
        component={Demo}
        durationInFrames={DEMO_DURATION}
        fps={30}
        width={1920}
        height={1080}
      />
      <Still id="Social" component={SocialCard} width={1280} height={640} />
      <Still id="Banner" component={Banner} width={1584} height={396} />
    </>
  );
};
