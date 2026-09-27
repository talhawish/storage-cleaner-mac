import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  staticFile,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export const C = {
  blue: "#2f57f0",
  ink: "#0e1116",
  muted: "#667085",
  line: "#e6e9ef",
  paper: "#ffffff",
  pale: "#f7f8fa",
  cyan: "#2bb4d8",
  green: "#34c08f",
  violet: "#9461f5",
  orange: "#f5914a",
  pink: "#ee5a8b",
};

export const FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Inter, sans-serif';

export const entering = (frame: number, delay = 0) =>
  interpolate(frame, [delay, delay + 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

export const rise = (frame: number, delay = 0, distance = 34) =>
  interpolate(frame, [delay, delay + 23], [distance, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

export const pop = (frame: number, delay = 0) =>
  spring({ frame: frame - delay, fps: 30, config: { damping: 15, mass: 0.8, stiffness: 110 } });

export const Backdrop: React.FC<{ tint?: string }> = ({ tint = "#dfe7ff" }) => (
  <AbsoluteFill
    style={{
      background:
        `radial-gradient(ellipse at 78% 45%, ${tint} 0%, rgba(247,248,250,0) 48%),` +
        "radial-gradient(ellipse at 6% 100%, rgba(226,244,249,.68) 0%, transparent 39%), #f7f8fa",
    }}
  >
    <div
      style={{
        position: "absolute",
        inset: 0,
        opacity: 0.18,
        backgroundImage:
          "linear-gradient(rgba(95,110,140,.09) 1px, transparent 1px), linear-gradient(90deg, rgba(95,110,140,.09) 1px, transparent 1px)",
        backgroundSize: "72px 72px",
        maskImage: "linear-gradient(to right, transparent 3%, black 75%)",
      }}
    />
  </AbsoluteFill>
);

export const BrandMark: React.FC<{ size?: number }> = ({ size = 48 }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.24,
      background: "linear-gradient(145deg, #5275ff, #2448db)",
      display: "grid",
      placeItems: "center",
      boxShadow: "0 10px 24px rgba(47,87,240,.24), inset 0 1px 0 rgba(255,255,255,.38)",
      flexShrink: 0,
    }}
  >
    <Img
      src={staticFile("app-icon.png")}
      style={{ width: size, height: size, objectFit: "cover", borderRadius: size * 0.24 }}
    />
  </div>
);

export const Wordmark: React.FC<{ light?: boolean }> = ({ light = false }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 14, color: light ? "white" : C.ink }}>
    <BrandMark size={50} />
    <div style={{ fontSize: 24, fontWeight: 650, letterSpacing: -0.7, lineHeight: 1.08 }}>
      Storage Cleaner
      <div style={{ fontSize: 17, color: light ? "rgba(255,255,255,.68)" : C.muted, fontWeight: 500, letterSpacing: 0.05 }}>
        for Developers
      </div>
    </div>
  </div>
);

export const Eyebrow: React.FC<{ children: React.ReactNode; color?: string }> = ({ children, color = C.blue }) => (
  <div
    style={{
      color,
      fontSize: 18,
      fontWeight: 700,
      letterSpacing: 2.8,
      textTransform: "uppercase",
    }}
  >
    {children}
  </div>
);

export const Scene: React.FC<{ tint?: string; children: React.ReactNode }> = ({ tint, children }) => (
  <AbsoluteFill style={{ fontFamily: FONT, color: C.ink }}>
    <Backdrop tint={tint} />
    {children}
  </AbsoluteFill>
);

export const Heading: React.FC<{
  children: React.ReactNode;
  frame: number;
  delay?: number;
  size?: number;
  width?: number;
  align?: "left" | "center";
  color?: string;
}> = ({ children, frame, delay = 0, size = 78, width = 820, align = "left", color = C.ink }) => (
  <div
    style={{
      maxWidth: width,
      color,
      fontSize: size,
      lineHeight: 1.0,
      letterSpacing: -3.9,
      fontWeight: 680,
      textAlign: align,
      opacity: entering(frame, delay),
      translate: `0px ${rise(frame, delay)}px`,
      textWrap: "balance",
    }}
  >
    {children}
  </div>
);

export const Pill: React.FC<{ children: React.ReactNode; color?: string; fill?: string }> = ({
  children,
  color = C.blue,
  fill = "rgba(47,87,240,.08)",
}) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 9,
      padding: "10px 15px",
      borderRadius: 999,
      background: fill,
      color,
      fontSize: 19,
      lineHeight: 1,
      fontWeight: 650,
      whiteSpace: "nowrap",
    }}
  >
    <span style={{ width: 9, height: 9, background: color, borderRadius: "50%" }} />
    {children}
  </div>
);

export const MacWindow: React.FC<{ title: string; children: React.ReactNode; style?: React.CSSProperties }> = ({
  title,
  children,
  style,
}) => (
  <div
    style={{
      overflow: "hidden",
      position: "relative",
      borderRadius: 26,
      transformStyle: "preserve-3d",
      border: "1px solid rgba(164,174,194,.64)",
      background: "linear-gradient(145deg,rgba(255,255,255,.99),rgba(249,250,253,.98))",
      boxShadow: "0 54px 120px rgba(29,43,78,.2), 0 16px 34px rgba(40,54,90,.1), 0 3px 8px rgba(40,54,90,.07), inset 0 1px 0 white, inset 0 -1px 0 rgba(117,130,155,.12)",
      ...style,
    }}
  >
    <div
      style={{
        height: 57,
        background: "linear-gradient(180deg,rgba(253,253,255,.98),rgba(243,245,249,.98))",
        borderBottom: `1px solid ${C.line}`,
        display: "flex",
        alignItems: "center",
        gap: 9,
        padding: "0 22px",
      }}
    >
      {["#ff6259", "#ffbe2f", "#28c840"].map((color) => (
        <i key={color} style={{ width: 12, height: 12, borderRadius: 99, background: color }} />
      ))}
      <span style={{ marginLeft: 13, fontSize: 17, fontWeight: 550, color: "#697386" }}>{title}</span>
      <span style={{ marginLeft: "auto", width: 8, height: 8, borderRadius: 8, background: C.green }} />
      <span style={{ fontSize: 15, color: "#697386", marginLeft: 2 }}>Scan complete</span>
    </div>
    {children}
    <div aria-hidden="true" style={{ position: "absolute", pointerEvents: "none", zIndex: 5, inset: 1, borderRadius: 25, boxShadow: "inset 0 1px 0 rgba(255,255,255,.85), inset 1px 0 0 rgba(255,255,255,.5), inset -1px 0 0 rgba(170,180,198,.2)" }} />
  </div>
);

export const useMotion = () => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  return { frame, fps, width, height };
};
