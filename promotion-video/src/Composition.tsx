import { Audio } from "@remotion/media";
import {
  AbsoluteFill,
  Composition,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import {Accumulation, Crisis, Discovery, Heavyweights, Hibernation, Resolution, Review, Toolchains} from "./film/shots";

const FRAME_COUNT = 36 * 30;
const CUTS = [180, 750];

const CutFlash: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        background: "#345cff",
        translate: `${interpolate(frame, [0, 6, 12], [-1920, 0, 1920])}px 0px`,
      }}
    />
  );
};

export const MyComponent: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: "#f7f8fa", overflow: "hidden" }}>
    <Audio
      src={staticFile("launch-score.wav")}
      volume={(frame) =>
        interpolate(frame, [0, 40, FRAME_COUNT - 42, FRAME_COUNT - 1], [0, 0.95, 0.95, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      }
    />
    <Sequence name="01 · Storage pressure" durationInFrames={90}>
      <Crisis />
    </Sequence>
    <Sequence name="02 · What dev tools leave behind" from={90} durationInFrames={90}>
      <Accumulation />
    </Sequence>
    <Sequence name="03 · Discover the space" from={180} durationInFrames={150}>
      <Discovery />
    </Sequence>
    <Sequence name="04 · Hibernate old projects" from={330} durationInFrames={150}>
      <Hibernation />
    </Sequence>
    <Sequence name="05 · Review runtime versions" from={480} durationInFrames={120}>
      <Toolchains />
    </Sequence>
    <Sequence name="06 · Docker, AI and simulators" from={600} durationInFrames={150}>
      <Heavyweights />
    </Sequence>
    <Sequence name="07 · Cleanup preview" from={750} durationInFrames={150}>
      <Review />
    </Sequence>
    <Sequence name="08 · More room, same Mac" from={900} durationInFrames={180}>
      <Resolution />
    </Sequence>
    {CUTS.map((cut) => (
      <Sequence key={cut} from={cut - 6} durationInFrames={12}>
        <CutFlash />
      </Sequence>
    ))}
  </AbsoluteFill>
);

export const MyComposition = () => (
  <Composition
    id="StorageCleanerLaunch"
    component={MyComponent}
    durationInFrames={FRAME_COUNT}
    fps={30}
    width={1920}
    height={1080}
  />
);
