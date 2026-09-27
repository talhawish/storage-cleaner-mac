import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, Eyebrow, Scene, Wordmark, entering, rise } from "./shared";

const DiskStack: React.FC<{ frame: number }> = ({ frame }) => {
  const opening = interpolate(frame, [0, 34, 82], [1.2, 1, 1], { extrapolateRight: "clamp" });
  const turn = interpolate(frame, [0, 120], [-12, 10]);
  const layers = [
    { label: "Xcode builds", type: "BUILD DATA", color: "#3159ee", h: 94, w: 540 },
    { label: "Docker images", type: "CONTAINER DATA", color: "#855af0", h: 88, w: 500 },
    { label: "Local AI models", type: "MODEL DATA", color: "#ef8c48", h: 84, w: 460 },
    { label: "Dependency trees", type: "PROJECT DATA", color: "#20a9ce", h: 82, w: 425 },
  ];
  return (
    <div
      style={{
        position: "absolute",
        left: 970,
        top: 158,
        width: 760,
        height: 760,
        perspective: 1350,
        scale: opening,
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 5,
          top: 45,
          width: 700,
          height: 650,
          borderRadius: "50%",
          background: "radial-gradient(ellipse, rgba(47,87,240,.2) 0%, rgba(63,119,255,.11) 34%, rgba(47,87,240,0) 72%)",
          filter: "blur(32px)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 115,
          top: 180,
          width: 500,
          height: 430,
          borderRadius: "50%",
          border: "1px solid rgba(68,107,235,.18)",
          boxShadow: "0 0 0 28px rgba(87,119,236,.035), 0 0 0 58px rgba(87,119,236,.025), inset 0 0 50px rgba(255,255,255,.38)",
          transform: `rotateX(62deg) rotateZ(${turn}deg)`,
          opacity: 0.9,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          transformStyle: "preserve-3d",
          transform: `rotateX(27deg) rotateZ(${turn}deg)`,
        }}
      >
        {layers.map((layer, index) => {
          const reveal = interpolate(frame, [index * 7, index * 7 + 24], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
          const float = Math.sin((frame + index * 17) / 17) * 3.5;
          const y = 478 - index * 111 + float + (1 - reveal) * 86;
          const z = index * 28;
          return (
            <React.Fragment key={layer.label}>
              <div
                style={{
                  position: "absolute",
                  left: (610 - layer.w) / 2,
                  top: y + 12,
                  width: layer.w,
                  height: layer.h,
                  borderRadius: 21,
                  transform: `translateZ(${z - 10}px)`,
                  background: `linear-gradient(180deg,${layer.color} 0%,${layer.color} 50%,${layer.color} 100%)`,
                  filter: "brightness(.62) saturate(.9)",
                  boxShadow: "0 22px 28px rgba(18,32,74,.16)",
                  opacity: reveal,
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: (610 - layer.w) / 2,
                  top: y,
                  width: layer.w,
                  height: layer.h,
                  borderRadius: 21,
                  transform: `translateZ(${z}px) scale(${0.96 + reveal * 0.04})`,
                  transformOrigin: "center",
                  background: `linear-gradient(145deg,${layer.color} 0%,${layer.color} 54%,${layer.color}d6 100%)`,
                  boxShadow: `0 25px 42px rgba(23,40,87,.18), inset 0 1px 0 rgba(255,255,255,.65), inset 0 -2px 0 rgba(15,25,60,.18)`,
                  border: "1px solid rgba(255,255,255,.66)",
                  display: "flex",
                  alignItems: "center",
                  padding: "0 30px",
                  color: "white",
                  fontSize: 24,
                  fontWeight: 650,
                  letterSpacing: -0.5,
                  opacity: reveal,
                }}
              >
                <span style={{ width: 14, height: 14, flexShrink: 0, borderRadius: "50%", background: "white", marginRight: 17, boxShadow: "0 0 20px rgba(255,255,255,.9)" }} />
                {layer.label}
                <span style={{ marginLeft: "auto", opacity: 0.86, fontSize: 14, fontWeight: 750, letterSpacing: 0.8, whiteSpace: "nowrap" }}>{layer.type}</span>
              </div>
            </React.Fragment>
          );
        })}
        <div
          style={{
            position: "absolute",
            top: 435,
            left: 75,
            width: 472,
            height: 238,
            borderRadius: "50%",
            border: "2px solid rgba(47,87,240,.26)",
            boxShadow: "0 0 58px rgba(47,87,240,.2), inset 0 0 44px rgba(47,87,240,.08)",
            transform: "translateZ(-16px)",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: 82,
            right: 92,
            top: interpolate(frame, [23, 94], [580, 80], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            height: 2,
            transform: "translateZ(70px)",
            background: "linear-gradient(90deg,transparent,rgba(255,255,255,.95),#77a7ff,rgba(255,255,255,.92),transparent)",
            boxShadow: "0 0 16px rgba(75,135,255,.9), 0 0 32px rgba(75,135,255,.44)",
            opacity: interpolate(frame, [21, 32, 86, 100], [0, 0.95, 0.95, 0], { extrapolateRight: "clamp" }),
          }}
        />
      </div>
      <div
        style={{
          position: "absolute",
          top: 635,
          left: 104,
          color: C.blue,
          fontSize: 16,
          fontWeight: 700,
          letterSpacing: 2.1,
          opacity: entering(frame, 14),
        }}
      >
        BUILDS · CONTAINERS · MODELS · DEPENDENCIES
      </div>
    </div>
  );
};

export const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <Scene tint="#e4eaff">
      <AbsoluteFill style={{ padding: "62px 108px" }}>
        <div style={{ opacity: entering(frame, 0), translate: `0px ${rise(frame, 0)}px` }}>
          <Wordmark />
        </div>
        <div style={{ position: "absolute", left: 112, top: 248, width: 815 }}>
          <Eyebrow>Before you buy a bigger Mac</Eyebrow>
          <div
            style={{
              marginTop: 28,
              fontSize: 90,
              lineHeight: 0.98,
              letterSpacing: -4,
              fontWeight: 700,
              color: C.ink,
              opacity: entering(frame, 8),
              translate: `0px ${rise(frame, 8, 44)}px`,
            }}
          >
            See where your
            <br />
            dev storage went.
          </div>
          <div
            style={{
              marginTop: 29,
              color: "#555f70",
              fontSize: 28,
              letterSpacing: -0.5,
              fontWeight: 500,
              opacity: entering(frame, 22),
            }}
          >
            Find the caches, builds, models and runtimes taking up space.
          </div>
        </div>
        <DiskStack frame={frame} />
        <div style={{ position: "absolute", right: 112, bottom: 62, fontSize: 17, fontWeight: 600, color: "#687386", opacity: entering(frame, 30) }}>
          NATIVE macOS APP <span style={{ color: C.blue, padding: "0 10px" }}>•</span> BUILT FOR DEVELOPERS
        </div>
      </AbsoluteFill>
    </Scene>
  );
};
