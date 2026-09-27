import React from "react";
import {AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame} from "remotion";
import "@fontsource-variable/manrope";

export const P = {ink: "#141821", blue: "#345cff", paper: "#f5f6f8", dark: "#090c14", cyan: "#29c7ed", purple: "#926bff", green: "#43cfa3"};
export const move = (frame: number, start: number, end: number, from = 0, to = 1) =>
  interpolate(frame, [start, end], [from, to], {extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.22, 1, 0.36, 1)});
export const linear = (frame: number, start: number, end: number, from = 0, to = 1) =>
  interpolate(frame, [start, end], [from, to], {extrapolateLeft: "clamp", extrapolateRight: "clamp"});

export const Set: React.FC<{children: React.ReactNode; dark?: boolean; accent?: string}> = ({children, dark = false, accent = "#dfe6ff"}) => (
  <AbsoluteFill style={{fontFamily: '"Manrope Variable", sans-serif', color: dark ? "#f7f8fd" : P.ink, background: dark ? P.dark : P.paper, overflow: "hidden"}}>
    <AbsoluteFill style={{background: dark
      ? "radial-gradient(ellipse at 74% 54%,#172440 0%,transparent 49%), radial-gradient(ellipse at 10% 90%,#101529 0%,transparent 50%)"
      : `radial-gradient(ellipse at 79% 62%,${accent} 0%,transparent 52%),linear-gradient(135deg,#fff7 0%,transparent 60%)`}} />
    <div style={{position: "absolute", width: 1300, height: 650, right: -250, bottom: -370, borderRadius: "50%", border: `1px solid ${dark ? "#ffffff0a" : "#345cff08"}`, boxShadow: `0 0 0 80px ${dark ? "#ffffff02" : "#345cff02"},0 0 0 160px ${dark ? "#ffffff02" : "#345cff02"}`}} />
    {children}
  </AbsoluteFill>
);

export const Brand: React.FC<{dark?: boolean}> = ({dark = false}) => (
  <div style={{position: "absolute", top: 64, left: 100, display: "flex", alignItems: "center", gap: 16, color: dark ? "white" : P.ink}}>
    <Img src={staticFile("app-icon.png")} style={{width: 54, height: 54, borderRadius: 13, boxShadow: "0 12px 30px #0002"}} />
    <div style={{fontSize: 25, fontWeight: 700, letterSpacing: -0.9}}>Storage Cleaner<span style={{fontWeight: 450, opacity: .55, marginLeft: 12}}>for Developers</span></div>
  </div>
);

export const Kicker: React.FC<{children: React.ReactNode; dark?: boolean}> = ({children, dark = false}) => (
  <div style={{fontSize: 23, fontWeight: 650, letterSpacing: 2.7, textTransform: "uppercase", color: dark ? "#99adff" : P.blue}}>{children}</div>
);

export const Title: React.FC<{lines: string[]; size?: number; delay?: number; colors?: string[]; centered?: boolean}> = ({lines, size = 108, delay = 0, colors = [], centered = false}) => {
  const frame = useCurrentFrame();
  return <div style={{fontSize: size, fontWeight: 650, letterSpacing: -size * .055, lineHeight: 1.06, textAlign: centered ? "center" : "left"}}>
    {lines.map((line, index) => <div key={line} style={{overflow: "hidden", paddingBottom: 9, marginBottom: -9}}>
      <div style={{color: colors[index], whiteSpace: "nowrap", transform: `translateY(${move(frame, delay + index * 4, delay + 24 + index * 4, 118, 0)}%)`, opacity: linear(frame, delay + index * 4, delay + 7 + index * 4)}}>{line}</div>
    </div>)}
  </div>;
};

export const Caption: React.FC<{children: React.ReactNode; delay?: number; dark?: boolean; style?: React.CSSProperties}> = ({children, delay = 15, dark = false, style}) => {
  const frame = useCurrentFrame();
  return <div style={{fontSize: 34, fontWeight: 480, letterSpacing: -.8, lineHeight: 1.45, color: dark ? "#aab5cb" : "#637087", opacity: move(frame, delay, delay + 18), transform: `translateY(${move(frame, delay, delay + 25, 20, 0)}px)`, ...style}}>{children}</div>;
};

export const Check: React.FC<{size?: number}> = ({size = 24}) => <svg width={size} height={size} viewBox="0 0 24 24" fill="none"><path d="m5 12 4 4L19 6" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" /></svg>;

export const Pointer: React.FC<{x: number; y: number; click: number}> = ({x, y, click}) => <div style={{position: "absolute", left: x, top: y, zIndex: 9, transform: `scale(${1 - click * .15})`, transformOrigin: "8px 4px", filter: "drop-shadow(0 4px 5px #0004)"}}>
  <svg width="48" height="60" viewBox="0 0 48 60"><path d="M5 3v43l11-10 10 20 9-5-11-19 16-2Z" fill="#111827" stroke="white" strokeWidth="3" strokeLinejoin="round" /></svg>
</div>;
