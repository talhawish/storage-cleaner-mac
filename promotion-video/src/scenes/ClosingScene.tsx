import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { C, BrandMark, Eyebrow, Scene, rise } from "./shared";

const ReviewCard: React.FC<{ frame: number }> = ({ frame }) => (
  <div
    style={{
      position: "absolute",
      left: 835,
      top: 199,
      width: 850,
      height: 540,
      borderRadius: 26,
      border: "1px solid rgba(180,188,204,.65)",
      background: "rgba(255,255,255,.95)",
      boxShadow: "0 38px 90px rgba(40,54,90,.15), inset 0 1px 0 white",
      opacity: interpolate(frame, [0, 14, 56, 75], [0, 1, 1, 0], { extrapolateRight: "clamp" }),
      translate: `${interpolate(frame, [0, 18, 75], [75, 0, -60])}px 0px`,
      rotate: "-1deg",
      overflow: "hidden",
    }}
  >
    <div style={{ height: 56, padding: "0 22px", display: "flex", alignItems: "center", gap: 9, background: "#f7f8fa", borderBottom: `1px solid ${C.line}` }}>
      {["#ff6259", "#ffbe2f", "#28c840"].map((color) => <i key={color} style={{ width: 12, height: 12, background: color, borderRadius: 12 }} />)}
      <span style={{ marginLeft: 12, color: "#697386", fontSize: 16, fontWeight: 550 }}>Cleanup preview</span>
      <span style={{ marginLeft: "auto", borderRadius: 99, background: "#fff4e5", color: "#a56b21", padding: "7px 11px", fontSize: 12, letterSpacing: 0.7, fontWeight: 750 }}>REVIEW FIRST</span>
    </div>
    <div style={{ padding: 30 }}>
      <div style={{ fontSize: 23, fontWeight: 680, letterSpacing: -0.5 }}>Inactive project dependencies</div>
      <div style={{ marginTop: 7, color: "#7c8695", fontSize: 15 }}>Review each location before cleanup</div>
      {[
        ["~/Code/old-dashboard/node_modules", "8.6 GB"],
        ["~/Code/old-dashboard/.build", "3.2 GB"],
        ["~/Code/old-dashboard/vendor", "1.4 GB"],
      ].map(([path, size], index) => (
        <div key={path} style={{ height: 75, display: "flex", alignItems: "center", borderBottom: `1px solid ${C.line}`, opacity: interpolate(frame, [12 + index * 6, 23 + index * 6], [0, 1], { extrapolateRight: "clamp" }), translate: `${interpolate(frame, [12 + index * 6, 23 + index * 6], [25, 0], { extrapolateRight: "clamp" })}px 0px` }}>
          <div style={{ width: 37, height: 37, borderRadius: 11, background: "#eef2ff", color: C.blue, display: "grid", placeItems: "center", fontWeight: 750, fontSize: 14 }}>{["{}", "⌘", "▦"][index]}</div>
          <div style={{ marginLeft: 14, fontFamily: "ui-monospace,SFMono-Regular,Menlo,monospace", fontSize: 15, color: "#596477" }}>{path}</div>
          <div style={{ marginLeft: "auto", fontSize: 17, fontWeight: 680 }}>{size}</div>
        </div>
      ))}
      <div style={{ marginTop: 23, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ color: "#596477", fontSize: 15, fontWeight: 550 }}>Potential recovery <strong style={{ color: C.ink, fontSize: 20, marginLeft: 8 }}>13.2 GB</strong></div>
        <div style={{ padding: "12px 20px", background: C.blue, color: "white", fontSize: 15, fontWeight: 650, borderRadius: 12, boxShadow: "0 9px 18px rgba(47,87,240,.23)" }}>Review selection</div>
      </div>
    </div>
  </div>
);

export const ClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const fade = interpolate(frame, [60, 79, 94], [0, 1, 1], { extrapolateRight: "clamp" });
  return (
    <Scene tint="#e4eaff">
      <ReviewCard frame={frame} />
      <div style={{ position: "absolute", left: 112, top: 302, width: 660, opacity: interpolate(frame, [0, 11, 57, 74], [0, 1, 1, 0], { extrapolateRight: "clamp" }), translate: `0 ${rise(frame, 5, 30)}px` }}>
        <Eyebrow>Clear visibility. Your call.</Eyebrow>
        <div style={{ marginTop: 24, fontSize: 80, lineHeight: 0.98, letterSpacing: -3.8, fontWeight: 690 }}>Know before<br />you clean.</div>
        <div style={{ marginTop: 23, fontSize: 25, lineHeight: 1.24, color: "#5c6676", fontWeight: 520 }}>Preview exact paths. Choose what stays.</div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 126, bottom: 90, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: fade, scale: interpolate(frame, [58, 92], [0.88, 1], { extrapolateRight: "clamp" }) }}>
        <div style={{ display: "flex", justifyContent: "center", alignItems: "center", gap: 19 }}>
          <BrandMark size={76} />
          <div style={{ textAlign: "left", fontSize: 35, lineHeight: 1.05, letterSpacing: -1.1, fontWeight: 690, color: C.ink }}>
            Storage Cleaner
            <div style={{ marginTop: 5, color: "#6b7584", fontSize: 23, fontWeight: 530, letterSpacing: -0.25 }}>for Developers</div>
          </div>
        </div>
        <div style={{ marginTop: 36, fontSize: 58, lineHeight: 1.03, letterSpacing: -3.3, fontWeight: 690, textAlign: "center", color: C.ink }}>
          Make room for what’s next.
        </div>
        <div style={{ marginTop: 27, display: "flex", gap: 13, alignItems: "center", padding: "15px 23px", background: C.blue, color: "white", borderRadius: 14, fontSize: 22, fontWeight: 650, boxShadow: "0 14px 32px rgba(47,87,240,.24)" }}>
          <span>Download on the Mac App Store</span><span style={{ fontSize: 24 }}>↗</span>
        </div>
        <div style={{ marginTop: 17, color: "#687386", fontSize: 18, fontWeight: 560 }}>Free to scan <span style={{ padding: "0 10px", color: C.blue }}>•</span> No account <span style={{ padding: "0 10px", color: C.blue }}>•</span> macOS 14+</div>
        <div style={{ marginTop: 26, fontSize: 18, color: C.blue, fontWeight: 650, letterSpacing: 0.1 }}>storagecleaner.horizam.com</div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 6, background: "#e4e8f2", opacity: 1 - fade }}>
        <div style={{ width: `${interpolate(frame, [0, 59], [0, 100], { extrapolateRight: "clamp" })}%`, height: "100%", background: C.blue }} />
      </div>
    </Scene>
  );
};
