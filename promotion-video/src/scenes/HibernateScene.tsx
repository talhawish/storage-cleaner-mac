import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, MacWindow, Pill, Scene, entering, rise } from "./shared";

const Dependency: React.FC<{ frame: number; delay: number; color: string; label: string }> = ({ frame, delay, color, label }) => {
  const flight = interpolate(frame, [delay, delay + 32, delay + 58], [0, 0.26, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: (v) => 1 - (1 - v) ** 3,
  });
  return (
    <div
      style={{
        position: "absolute",
        left: 500 + flight * 145,
        top: 154 + flight * 240,
        width: 290 - flight * 105,
        height: 70 - flight * 30,
        borderRadius: 18,
        border: `1px solid ${color}55`,
        background: `linear-gradient(135deg, white, ${color}16)`,
        boxShadow: "0 13px 28px rgba(45,58,93,.1)",
        display: "flex",
        alignItems: "center",
        padding: "0 18px",
        gap: 13,
        opacity: interpolate(frame, [delay, delay + 5, delay + 48, delay + 58], [0, 1, 1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
        scale: 1 - flight * 0.28,
      }}
    >
      <div style={{ width: 36, height: 36, borderRadius: 11, color, background: `${color}19`, display: "grid", placeItems: "center", fontSize: 14, fontWeight: 800 }}>
        {label === "node_modules" ? "{}" : label === ".build" ? "⌘" : "▦"}
      </div>
      <div style={{ fontSize: 19, fontWeight: 650 }}>{label}</div>
      <div style={{ marginLeft: "auto", fontSize: 17, fontWeight: 650, color: "#697386" }}>{label === "node_modules" ? "8.6 GB" : label === ".build" ? "3.2 GB" : "1.4 GB"}</div>
    </div>
  );
};

export const HibernateScene: React.FC = () => {
  const frame = useCurrentFrame();
  const folderLift = interpolate(frame, [0, 22], [65, 0], { extrapolateRight: "clamp" });
  return (
    <Scene tint="#e4f4ee">
      <AbsoluteFill style={{ padding: "82px 110px" }}>
        <div style={{ position: "absolute", left: 112, top: 250, width: 720 }}>
          <Eyebrow>When a project goes quiet</Eyebrow>
          <div style={{ marginTop: 23, fontSize: 81, lineHeight: 0.98, letterSpacing: -3.8, fontWeight: 690, opacity: entering(frame, 5), translate: `0 ${rise(frame, 5, 40)}px` }}>
            Hibernate old<br />projects.
          </div>
          <div style={{ marginTop: 25, fontSize: 29, color: "#535e6e", lineHeight: 1.23, letterSpacing: -0.7, fontWeight: 540, opacity: entering(frame, 17) }}>
            Keep source. Rebuild dependencies<br />when you come back.
          </div>
          <div style={{ marginTop: 24, opacity: entering(frame, 25) }}><Pill color="#238766" fill="#e8f8f1">Regenerable folders go to Trash</Pill></div>
        </div>
        <MacWindow title="Project hibernation preview" style={{ position: "absolute", left: 835, top: 165, width: 932, height: 620, transform: `perspective(1400px) rotateY(-6deg) translateY(${folderLift}px)`, opacity: entering(frame, 0) }}>
          <div style={{ padding: 31, position: "relative", height: 563 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 18, padding: 17, background: "#f8f9fb", border: `1px solid ${C.line}`, borderRadius: 18, width: 457 }}>
              <div style={{ width: 54, height: 54, borderRadius: 16, background: "linear-gradient(140deg,#6d8bff,#3157e9)", display: "grid", placeItems: "center", color: "white", fontSize: 27, fontWeight: 750 }}>⌘</div>
              <div><div style={{ fontSize: 22, fontWeight: 680, letterSpacing: -0.6 }}>old-dashboard</div><div style={{ marginTop: 4, fontSize: 15, color: "#7e8797" }}>~/Code/old-dashboard · inactive 187 days</div></div>
              <div style={{ marginLeft: "auto", color: "#b97823", background: "#fff4e5", padding: "7px 11px", borderRadius: 99, fontSize: 13, fontWeight: 750 }}>REVIEW</div>
            </div>
            <div style={{ position: "absolute", left: 50, top: 205, width: 425, height: 258, borderRadius: 21, padding: 24, background: "linear-gradient(150deg,#f3f6ff,#fff)", border: "1px solid #d9e1f6", boxShadow: "0 18px 42px rgba(47,87,240,.09)", opacity: entering(frame, 10), translate: `0px ${rise(frame, 10, 24)}px` }}>
              <div style={{ fontSize: 13, fontWeight: 750, color: C.blue, letterSpacing: 1.4 }}>YOUR SOURCE STAYS</div>
              <div style={{ marginTop: 14, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", fontSize: 17, lineHeight: 1.8, color: "#586478" }}>
                <div><span style={{ color: C.blue }}>▸</span> src/</div>
                <div><span style={{ color: C.blue }}>▸</span> tests/</div>
                <div><span style={{ color: C.blue }}>▸</span> README.md</div>
                <div><span style={{ color: C.blue }}>▸</span> package.json</div>
              </div>
              <div style={{ position: "absolute", bottom: 17, left: 24, fontSize: 14, fontWeight: 650, color: "#238766" }}>Source files remain in place</div>
            </div>
            <div style={{ position: "absolute", left: 500, top: 213, fontSize: 25, fontWeight: 650, color: "#9ba4b1", opacity: entering(frame, 14) }}>→</div>
            <div style={{ position: "absolute", right: 33, bottom: 39, width: 190, height: 135, borderRadius: 26, background: "linear-gradient(145deg,#fff,#f4f5f8)", border: `1px solid ${C.line}`, boxShadow: "0 15px 35px rgba(46,54,78,.12)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", opacity: entering(frame, 18) }}>
              <div style={{ fontSize: 55, lineHeight: 1 }}>⌑</div><div style={{ fontSize: 16, marginTop: 6, color: "#606a7a", fontWeight: 650 }}>macOS Trash</div>
            </div>
            <Dependency frame={frame} delay={10} color={C.cyan} label="node_modules" />
            <Dependency frame={frame} delay={65} color={C.blue} label=".build" />
            <Dependency frame={frame} delay={120} color={C.violet} label="vendor" />
            <div style={{ position: "absolute", left: 49, bottom: 26, display: "flex", gap: 11, alignItems: "center", color: "#687386", fontSize: 16, fontWeight: 550, opacity: entering(frame, 23) }}>
              <span style={{ width: 9, height: 9, borderRadius: 9, background: C.green }} />Preview first · restore from Trash if needed
            </div>
          </div>
        </MacWindow>
      </AbsoluteFill>
    </Scene>
  );
};
