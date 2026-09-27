import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, Scene, entering, rise } from "./shared";

const panels = [
  { title: "Docker & VMs", detail: "images · layers · volumes", symbol: "◈", color: C.violet },
  { title: "Local AI", detail: "Ollama · LM Studio · models", symbol: "✳", color: C.orange },
  { title: "Simulators", detail: "iOS · Android · device support", symbol: "▣", color: C.green },
  { title: "Build artifacts", detail: "Gradle · Flutter · archives", symbol: "⌘", color: C.blue },
  { title: "Large files & apps", detail: "videos · installers · bundles", symbol: "◫", color: C.pink },
];

export const EcosystemScene: React.FC = () => {
  const frame = useCurrentFrame();
  const wave = interpolate(frame, [0, 165], [-8, 8]);
  return (
    <Scene tint="#e5efff">
      <AbsoluteFill style={{ padding: "78px 110px" }}>
        <Eyebrow>Built around the developer Mac</Eyebrow>
        <div style={{ marginTop: 22, fontSize: 78, lineHeight: 0.99, fontWeight: 690, letterSpacing: -3.7, opacity: entering(frame, 5), translate: `0 ${rise(frame, 5, 36)}px` }}>
          See the whole dev disk.
        </div>
        <div style={{ marginTop: 22, fontSize: 26, color: "#5c6676", fontWeight: 520, opacity: entering(frame, 15) }}>
          One inventory across the tools you actually use.
        </div>
        <div style={{ position: "absolute", left: 112, right: 112, bottom: 138, height: 490, display: "flex", gap: 14, alignItems: "center", perspective: 1200 }}>
          {panels.map((panel, index) => {
            const entry = interpolate(frame, [8 + index * 5, 34 + index * 5], [0, 1], { extrapolateRight: "clamp", easing: (v) => 1 - (1 - v) ** 3 });
            const bob = Math.sin((frame + index * 16) / 20) * 7;
            return (
              <div
                key={panel.title}
                style={{
                  flex: 1,
                  height: 325 + (index % 2) * 23,
                  borderRadius: 24,
                  padding: "24px 19px",
                  border: "1px solid rgba(180,190,210,.65)",
                  background: "linear-gradient(145deg,rgba(255,255,255,.98),rgba(246,248,252,.96))",
                  boxShadow: "0 24px 55px rgba(44,57,91,.13), inset 0 1px 0 white",
                  opacity: entry,
                  transform: `translate3d(0,${(1 - entry) * 60 + bob}px,${index % 2 ? -24 : 20}px) rotateY(${(2 - index) * 1.5}deg)`,
                }}
              >
                <div style={{ width: 65, height: 65, borderRadius: 20, display: "grid", placeItems: "center", color: panel.color, background: `${panel.color}16`, border: `1px solid ${panel.color}38`, fontSize: 31, fontWeight: 750 }}>{panel.symbol}</div>
                <div style={{ marginTop: 24, fontSize: 21, lineHeight: 1.08, letterSpacing: -0.6, fontWeight: 680 }}>{panel.title}</div>
                <div style={{ marginTop: 11, minHeight: 53, fontSize: 16, lineHeight: 1.27, color: "#778191", fontWeight: 520 }}>{panel.detail}</div>
                <div style={{ marginTop: 18, height: 6, width: "100%", borderRadius: 9, background: `${panel.color}18`, overflow: "hidden" }}><div style={{ width: `${(44 + index * 11 + wave) % 80 + 18}%`, height: "100%", background: panel.color, borderRadius: 9 }} /></div>
                <div style={{ marginTop: 14, display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 13, color: "#9aa2ae", fontWeight: 700, letterSpacing: 0.5 }}><span>FOUND</span><span style={{ color: panel.color, fontSize: 15 }}>VIEW →</span></div>
              </div>
            );
          })}
        </div>
        <div style={{ position: "absolute", left: 112, bottom: 57, color: "#758092", fontSize: 16, fontWeight: 650, opacity: entering(frame, 30) }}>
          Docker · Local AI · Simulators · Gradle · APKs · large files · apps
        </div>
      </AbsoluteFill>
    </Scene>
  );
};
