import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, Heading, Pill, Scene, entering, rise } from "./shared";

const objects = [
  { label: "Xcode builds", unit: "BUILD OUTPUTS", color: C.blue, x: 0, y: 0, z: 30 },
  { label: "Docker layers", unit: "CONTAINERS", color: C.violet, x: 1, y: 1, z: -30 },
  { label: "AI models", unit: "LOCAL AI", color: C.orange, x: 2, y: 0, z: 60 },
  { label: "Simulators", unit: "MOBILE", color: C.green, x: 0, y: 2, z: -55 },
  { label: "Package caches", unit: "DEPENDENCIES", color: C.cyan, x: 1, y: 3, z: 20 },
  { label: "Old runtimes", unit: "TOOLCHAINS", color: C.pink, x: 2, y: 2, z: -15 },
];

export const WorldScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <Scene tint="#e7edff">
      <AbsoluteFill style={{ padding: "92px 112px" }}>
        <Eyebrow>It adds up quietly</Eyebrow>
        <div style={{ marginTop: 23 }}>
          <Heading frame={frame} delay={3} size={80} width={760}>
            Your tools leave more than code.
          </Heading>
        </div>
        <div style={{ marginTop: 27, opacity: entering(frame, 17), translate: `0px ${rise(frame, 17, 15)}px` }}>
          <Pill color="#566074" fill="rgba(14,17,22,.055)">Builds · caches · models · runtimes</Pill>
        </div>
        <div
          style={{
            position: "absolute",
            left: 995,
            top: 128,
            width: 790,
            height: 780,
            perspective: 1000,
            transformStyle: "preserve-3d",
          }}
        >
          <div
            style={{
              position: "absolute",
              left: 12,
              top: 70,
              width: 730,
              height: 640,
              borderRadius: 100,
              background: "radial-gradient(ellipse, rgba(47,87,240,.14), transparent 65%)",
              filter: "blur(25px)",
            }}
          />
          {objects.map((item, index) => {
            const entrance = interpolate(frame, [index * 4, index * 4 + 22], [0, 1], {
              extrapolateRight: "clamp",
              easing: (v) => 1 - (1 - v) ** 4,
            });
            const float = Math.sin((frame + index * 11) / 17) * 9;
            const left = 75 + item.x * 225;
            const top = 106 + item.y * 174;
            return (
              <div
                key={item.label}
                style={{
                  position: "absolute",
                  left,
                  top,
                  width: 220,
                  height: 150,
                  borderRadius: 28,
                  padding: 22,
                  background: "linear-gradient(145deg, rgba(255,255,255,.98), rgba(244,246,251,.96))",
                  border: "1px solid rgba(180,190,210,.58)",
                  boxShadow: "0 24px 55px rgba(44,57,91,.14), inset 0 1px 0 white",
                  transform: `translate3d(${(1 - entrance) * 90}px, ${float + (1 - entrance) * 45}px, ${item.z}px) rotateY(-8deg) rotateX(5deg)`,
                  opacity: entrance,
                }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div
                    style={{
                      width: 46,
                      height: 46,
                      borderRadius: 15,
                      background: `${item.color}18`,
                      border: `1px solid ${item.color}42`,
                      display: "grid",
                      placeItems: "center",
                      color: item.color,
                      fontSize: 22,
                      fontWeight: 750,
                    }}
                  >
                    {index === 0 ? "⌘" : index === 1 ? "◈" : index === 2 ? "✳" : index === 3 ? "▣" : index === 4 ? "{}" : "⌁"}
                  </div>
                  <span style={{ width: 11, height: 11, borderRadius: 10, background: item.color, boxShadow: `0 0 15px ${item.color}` }} />
                </div>
                <div style={{ marginTop: 16, fontSize: 20, fontWeight: 650, color: C.ink, letterSpacing: -0.5 }}>{item.label}</div>
                <div style={{ marginTop: 7, fontSize: 12, letterSpacing: 1.6, fontWeight: 700, color: "#9299a6" }}>{item.unit}</div>
              </div>
            );
          })}
        </div>
        <div style={{ position: "absolute", bottom: 54, left: 112, color: "#8992a1", fontSize: 16, fontWeight: 550, opacity: entering(frame, 35) }}>
          XCODE <span style={{ padding: "0 12px", color: "#c0c5cf" }}>•</span> WEB <span style={{ padding: "0 12px", color: "#c0c5cf" }}>•</span> MOBILE <span style={{ padding: "0 12px", color: "#c0c5cf" }}>•</span> AI & ML
        </div>
      </AbsoluteFill>
    </Scene>
  );
};
