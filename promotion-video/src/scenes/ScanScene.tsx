import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, MacWindow, Scene, entering, rise } from "./shared";

const rows = [
  { name: "Xcode DerivedData", detail: "12 projects", size: "22.4 GB", color: C.blue },
  { name: "node_modules", detail: "184 folders", size: "14.6 GB", color: C.cyan },
  { name: "Docker builder cache", detail: "32 layers", size: "11.8 GB", color: C.violet },
  { name: "Simulator runtimes", detail: "4 installed", size: "9.2 GB", color: C.green },
  { name: "Ollama models", detail: "6 models", size: "5.1 GB", color: C.orange },
];

export const ScanScene: React.FC = () => {
  const frame = useCurrentFrame();
  const scan = interpolate(frame, [10, 145], [-5, 565], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const progress = interpolate(frame, [3, 115], [0.04, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <Scene tint="#e3ebff">
      <AbsoluteFill style={{ padding: "76px 100px" }}>
        <div style={{ position: "absolute", left: 106, top: 292, width: 525, zIndex: 2 }}>
          <Eyebrow>One scan. Every domain.</Eyebrow>
          <div style={{ marginTop: 25, fontSize: 74, lineHeight: 1, fontWeight: 680, letterSpacing: -3.5, opacity: entering(frame, 6), translate: `0 ${rise(frame, 6, 38)}px` }}>
            Find what’s filling<br />your Mac.
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 11, marginTop: 31, opacity: entering(frame, 17) }}>
            <strong style={{ fontSize: 63, letterSpacing: -3.4, color: C.blue, fontWeight: 700 }}>87.4</strong>
            <span style={{ fontSize: 28, fontWeight: 650, color: C.blue }}>GB</span>
            <span style={{ marginLeft: 3, color: "#687386", fontSize: 21, fontWeight: 550 }}>found in this example scan</span>
          </div>
          <div style={{ marginTop: 20, width: 400, height: 6, borderRadius: 99, background: "#dfe4f0", overflow: "hidden" }}>
            <div style={{ width: `${progress * 100}%`, height: "100%", borderRadius: 99, background: "linear-gradient(90deg,#2f57f0,#2bb4d8)" }} />
          </div>
        </div>
        <MacWindow title="Storage Cleaner — Scan results" style={{ position: "absolute", left: 670, top: 145, width: 1140, height: 760, transform: `perspective(1500px) rotateY(-7deg) rotateX(2deg) translateX(${interpolate(frame, [0, 25], [85, 0], { extrapolateRight: "clamp" })}px)`, opacity: entering(frame, 0) }}>
          <div style={{ padding: "29px 34px 24px", display: "flex", height: 702, gap: 28 }}>
            <div style={{ width: 230, borderRight: `1px solid ${C.line}`, paddingRight: 26 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: "#9299a6", letterSpacing: 1.8, marginBottom: 20 }}>OVERVIEW</div>
              {["Dashboard", "Apple", "Web", "Docker", "Mobile", "AI & ML"].map((label, i) => (
                <div key={label} style={{ display: "flex", alignItems: "center", gap: 11, height: 45, padding: "0 12px", margin: "4px 0", borderRadius: 12, background: i === 0 ? "#eef2ff" : "transparent", color: i === 0 ? C.blue : "#687386", fontSize: 18, fontWeight: i === 0 ? 650 : 520 }}>
                  <span style={{ width: 8, height: 8, borderRadius: 9, background: [C.blue, C.blue, C.cyan, C.violet, C.green, C.orange][i] }} />{label}
                </div>
              ))}
                <div style={{ marginTop: 32, padding: 18, borderRadius: 17, background: "linear-gradient(135deg,#f2f5ff,#fff)", border: `1px solid ${C.line}` }}>
                <div style={{ fontSize: 13, color: "#8a93a3", fontWeight: 700, letterSpacing: 1 }}>DETECTION COVERAGE</div>
                <div style={{ marginTop: 8, fontSize: 27, fontWeight: 680, letterSpacing: -1 }}>15+ domains</div>
              </div>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                <div>
                  <div style={{ fontSize: 27, fontWeight: 680, letterSpacing: -0.9 }}>Potential to reclaim</div>
                  <div style={{ marginTop: 6, fontSize: 16, color: "#858e9c" }}>Review these findings before cleanup</div>
                </div>
                <div style={{ padding: "9px 15px", borderRadius: 11, color: C.blue, background: "#eef2ff", fontSize: 15, fontWeight: 650 }}>Scan complete</div>
              </div>
              <div style={{ marginTop: 25, display: "grid", gridTemplateColumns: "230px 1fr", gap: 25, alignItems: "center" }}>
                <div style={{ position: "relative", width: 206, height: 206, borderRadius: "50%", background: "conic-gradient(#2f57f0 0 37%, #2bb4d8 37% 58.4%, #9461f5 58.4% 72.5%, #34c08f 72.5% 82.7%, #f5914a 82.7% 90.9%, #ee5a8b 90.9% 97.1%, #f56a78 97.1% 100%)", rotate: `${frame * 0.16}deg`, boxShadow: "0 12px 26px rgba(47,87,240,.16), inset 0 1px 1px rgba(255,255,255,.58)" }}>
                  <div style={{ position: "absolute", inset: 18, borderRadius: "50%", background: "linear-gradient(145deg,#fff,#f8faff)", display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", rotate: `${-frame * 0.16}deg`, boxShadow: "inset 0 2px 8px rgba(38,54,90,.08)" }}>
                    <span style={{ fontSize: 15, color: "#818a99", fontWeight: 600 }}>REVIEW</span>
                    <strong style={{ fontSize: 31, letterSpacing: -1.5, marginTop: 3 }}>87.4 GB</strong>
                  </div>
                </div>
                  <div style={{ display: "grid", gridTemplateColumns: "repeat(3,minmax(0,1fr))", gap: "13px 10px" }}>
                  {[["Apple", "32.1 GB", C.blue], ["Web", "18.7 GB", C.cyan], ["Docker", "12.3 GB", C.violet], ["Mobile", "8.9 GB", C.green], ["AI & ML", "7.2 GB", C.orange], ["Media", "5.4 GB", C.pink], ["Junk", "2.8 GB", "#f56a78"]].map(([name, size, color]) => (
                    <div key={name} style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 16, color: "#555f70", fontWeight: 550 }}><span style={{ width: 10, height: 10, borderRadius: 10, background: color }} />{name}<strong style={{ marginLeft: "auto", color: C.ink, fontSize: 16 }}>{size}</strong></div>
                  ))}
                </div>
              </div>
              <div style={{ marginTop: 22, borderTop: `1px solid ${C.line}` }}>
                {rows.map((row, i) => {
                  const visible = interpolate(frame, [20 + i * 8, 35 + i * 8], [0, 1], { extrapolateRight: "clamp" });
                  return (
                    <div key={row.name} style={{ height: 73, display: "grid", gridTemplateColumns: "44px 1fr 105px 115px", alignItems: "center", gap: 12, borderBottom: `1px solid ${C.line}`, opacity: visible, translate: `${(1 - visible) * 30}px 0px` }}>
                      <div style={{ width: 38, height: 38, borderRadius: 12, background: `${row.color}17`, color: row.color, display: "grid", placeItems: "center", fontSize: 17, fontWeight: 750 }}>{["⌘", "{}", "◈", "▣", "✳"][i]}</div>
                      <div><div style={{ fontSize: 18, fontWeight: 650 }}>{row.name}</div><div style={{ marginTop: 3, fontSize: 14, color: "#8a93a3" }}>{row.detail}</div></div>
                      <div style={{ fontSize: 18, fontWeight: 650, textAlign: "right" }}>{row.size}</div>
                      <div style={{ justifySelf: "end", fontSize: 13, fontWeight: 700, color: i < 3 ? "#238766" : "#b97823", padding: "6px 10px", borderRadius: 99, background: i < 3 ? "#e9f8f2" : "#fff4e5" }}>{i < 3 ? "SAFE" : "REVIEW"}</div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
          <div style={{ position: "absolute", left: 280, right: 18, top: scan, height: 2, background: "linear-gradient(90deg,transparent,#50a4ff,transparent)", boxShadow: "0 0 17px #549cff", opacity: interpolate(frame, [6, 18, 126, 150], [0, 1, 1, 0], { extrapolateRight: "clamp" }) }} />
        </MacWindow>
        <div style={{ position: "absolute", bottom: 52, right: 111, color: "#9299a6", fontSize: 15, fontWeight: 600, letterSpacing: 1.2, opacity: entering(frame, 26) }}>SAMPLE INVENTORY · ACTUAL RESULTS VARY</div>
      </AbsoluteFill>
    </Scene>
  );
};
