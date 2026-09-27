import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, FONT, Pill, Scene, entering, rise } from "./shared";

const runtimes = [
  { name: "Node.js", versions: ["v18.20", "v20.16", "v22.4"], color: C.green, symbol: "JS" },
  { name: "PHP", versions: ["8.1", "8.2", "8.3"], color: C.violet, symbol: "PHP" },
  { name: "Go", versions: ["1.21", "1.22"], color: C.cyan, symbol: "GO" },
  { name: "Python", versions: ["3.10", "3.11", "3.12"], color: C.blue, symbol: "PY" },
  { name: "Bun", versions: ["1.1", "1.2"], color: C.orange, symbol: "B" },
];

export const RuntimesScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <Scene tint="#e7eaff">
      <AbsoluteFill style={{ padding: "76px 110px" }}>
        <Eyebrow>Too many toolchains?</Eyebrow>
        <div style={{ marginTop: 22, fontSize: 78, lineHeight: 0.99, fontWeight: 690, letterSpacing: -3.7, opacity: entering(frame, 5), translate: `0 ${rise(frame, 5, 36)}px` }}>
          Find duplicate runtimes.<br />Keep what you use.
        </div>
        <div style={{ marginTop: 23, opacity: entering(frame, 17) }}>
          <Pill color="#596578" fill="rgba(14,17,22,.05)">Node · PHP · Go · Python · Bun · Deno · and more</Pill>
        </div>
        <div style={{ position: "absolute", left: 94, right: 94, top: 508, display: "flex", justifyContent: "center", gap: 17, perspective: 1100 }}>
          {runtimes.map((runtime, index) => {
            const entry = interpolate(frame, [11 + index * 4, 35 + index * 4], [0, 1], { extrapolateRight: "clamp", easing: (v) => 1 - (1 - v) ** 4 });
            return (
              <div
                key={runtime.name}
                style={{
                  width: 320,
                  height: 340,
                  padding: 22,
                  borderRadius: 24,
                  border: "1px solid rgba(180,190,210,.65)",
                  background: "linear-gradient(150deg,rgba(255,255,255,.98),rgba(246,247,251,.96))",
                  boxShadow: "0 24px 55px rgba(44,57,91,.12), inset 0 1px 0 white",
                  transform: `translate3d(0, ${(1 - entry) * 65}px, ${index % 2 ? -18 : 20}px) rotateY(${(2 - index) * -2}deg)`,
                  opacity: entry,
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 13 }}>
                  <div style={{ width: 51, height: 51, borderRadius: 16, display: "grid", placeItems: "center", color: runtime.color, fontSize: runtime.symbol.length > 2 ? 13 : 18, fontWeight: 800, background: `${runtime.color}16`, border: `1px solid ${runtime.color}38` }}>{runtime.symbol}</div>
                  <div style={{ fontSize: 22, letterSpacing: -0.6, fontWeight: 680 }}>{runtime.name}</div>
                  <div style={{ marginLeft: "auto", color: "#858e9c", fontSize: 13, fontWeight: 700 }}>{runtime.versions.length} VERSIONS</div>
                </div>
                <div style={{ marginTop: 20, display: "flex", flexDirection: "column", gap: 10 }}>
                  {runtime.versions.map((version, versionIndex) => {
                    const active = versionIndex === runtime.versions.length - 1;
                    const selected = active && frame > 50;
                    return (
                      <div key={version} style={{ height: 53, borderRadius: 13, border: `1px solid ${selected ? `${runtime.color}80` : C.line}`, background: selected ? `${runtime.color}12` : "white", display: "flex", alignItems: "center", padding: "0 14px", fontFamily: "ui-monospace,SFMono-Regular,Menlo,monospace", fontSize: 17, fontWeight: 650, color: "#535f71", boxShadow: selected ? `0 6px 16px ${runtime.color}18` : "none" }}>
                        <span style={{ width: 9, height: 9, borderRadius: 9, marginRight: 12, background: selected ? runtime.color : "#c5cbd5" }} />{version}
                        <span style={{ marginLeft: "auto", fontFamily: FONT, fontSize: 12, fontWeight: 750, color: selected ? runtime.color : "#9aa2ae" }}>{selected ? "KEEP" : "REVIEW"}</span>
                      </div>
                    );
                  })}
                </div>
                <div style={{ marginTop: 14, fontSize: 13, color: "#9099a7", fontWeight: 550 }}>Review versions before removal</div>
              </div>
            );
          })}
        </div>
        <div style={{ position: "absolute", right: 112, bottom: 53, color: "#98a0ad", fontSize: 14, fontWeight: 650, letterSpacing: 1.1, opacity: entering(frame, 29) }}>VERSION DISCOVERY ACROSS YOUR TOOLCHAINS</div>
      </AbsoluteFill>
    </Scene>
  );
};
