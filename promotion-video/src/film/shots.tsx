import React from "react";
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from "remotion";
import {Brand, Caption, Check, Kicker, move, P, Pointer, Set, Title} from "./design";
import {DataCluster, Drive, EcosystemObjects, ProjectFolder, RuntimeTiles, Stage, StorageRing} from "./geometry";

export const Crisis: React.FC = () => {
  const f = useCurrentFrame();
  return <Set dark>
    <Stage dark><Drive frame={f} /></Stage>
    <Brand dark />
    <div style={{position: "absolute", left: 100, top: 265}}>
      <Kicker dark>Before you buy a bigger Mac</Kicker>
      <div style={{marginTop: 30}}><Title lines={["Mac full?", "Look closer."]} size={142} delay={-8} colors={["#f7f8fc", "#94aaff"]} /></div>
      <Caption dark style={{marginTop: 32}}>Your next build needs room.</Caption>
    </div>
    <div style={{position: "absolute", right: 140, bottom: 125, fontSize: 25, color: "#aebbd3", display: "flex", alignItems: "center", gap: 12, opacity: move(f, 14, 30)}}><span style={{width: 10, height: 10, borderRadius: 10, background: "#f78d94", boxShadow: "0 0 20px #f78d94aa"}} />Sound familiar?</div>
  </Set>;
};

export const Accumulation: React.FC = () => {
  const f = useCurrentFrame();
  return <Set accent="#dbe6ff">
    <Stage><DataCluster /></Stage>
    <div style={{position: "absolute", left: 100, top: 257}}>
      <Kicker>The hidden storage bill</Kicker>
      <div style={{marginTop: 30}}><Title lines={["Builds. Caches.", "Models. More."]} size={112} /></div>
      <Caption style={{marginTop: 30}}>Your dev tools leave a lot behind.</Caption>
    </div>
    <div style={{position: "absolute", left: 100, right: 100, bottom: 113, height: 70, overflow: "hidden", maskImage: "linear-gradient(90deg,transparent,black 5%,black 95%,transparent)", borderTop: "1px solid #162f631a", paddingTop: 29}}>
      <div style={{display: "flex", gap: 58, fontSize: 28, fontWeight: 550, letterSpacing: -1, color: "#71809a", whiteSpace: "nowrap", transform: `translateX(${-f * 1.65}px)`}}>
        {["node_modules", "DerivedData", "Docker images", "Ollama models", "Gradle", "Simulator runtimes", "node_modules"].map((name, i) => <span key={`${name}${i}`}><span style={{color: P.blue, marginRight: 20}}>↗</span>{name}</span>)}
      </div>
    </div>
  </Set>;
};

export const Discovery: React.FC = () => {
  const f = useCurrentFrame();
  const amount = (move(f, 18, 67) * 87.4).toFixed(1);
  return <Set accent="#dfe6ff">
    <Stage><StorageRing /></Stage>
    <Brand />
    <div style={{position: "absolute", left: 100, top: 299}}>
      <Title lines={["Find what’s", "filling your Mac."]} size={106} />
      <Caption style={{marginTop: 33}}>One scan. Across your dev tools.</Caption>
      <div style={{marginTop: 36, display: "flex", gap: 10, alignItems: "center", color: P.blue, fontSize: 29, fontWeight: 600, opacity: move(f, 43, 66)}}><Check size={30} /> Built for the way developers work.</div>
    </div>
    <div style={{position: "absolute", left: 1195, top: 443, width: 420, textAlign: "center", opacity: move(f, 17, 36)}}>
      <div style={{fontSize: 22, fontWeight: 600, letterSpacing: 2.4, color: "#74819a"}}>STORAGE FOUND</div>
      <div style={{fontSize: 91, fontWeight: 650, letterSpacing: -6, lineHeight: 1.3, fontVariantNumeric: "tabular-nums"}}>{amount}<span style={{fontSize: 31, letterSpacing: -1, marginLeft: 8, color: "#758099"}}>GB</span></div>
    </div>
    <div style={{position: "absolute", left: 1125, top: 859, width: 570, textAlign: "center", fontSize: 23, color: "#78849b", opacity: move(f, 38, 56)}}>Example scan · your results will vary</div>
  </Set>;
};

export const Hibernation: React.FC = () => {
  const f = useCurrentFrame();
  return <Set accent="#deecef">
    <Stage><ProjectFolder /></Stage>
    <div style={{position: "absolute", left: 100, top: 246}}>
      <Kicker>Not working on it?</Kicker>
      <div style={{marginTop: 31}}><Title lines={["Hibernate", "old projects."]} size={119} /></div>
      <Caption style={{marginTop: 32}}>Keep your code.<br />Reinstall dependencies later.</Caption>
    </div>
    <div style={{position: "absolute", left: 1135, top: 166, fontSize: 30, fontWeight: 550, letterSpacing: -.7, opacity: move(f, 12, 32), color: "#6d7d93"}}>{f < 61 ? "node_modules" : f < 88 ? ".build" : "vendor"}<span style={{color: P.blue, marginLeft: 15}}>→</span></div>
    <div style={{position: "absolute", left: 1095, bottom: 123, display: "flex", alignItems: "center", gap: 13, color: "#247b64", fontSize: 28, fontWeight: 600, opacity: move(f, 82, 105)}}><Check size={30} /> Source stays. Dependencies go to Trash.</div>
  </Set>;
};

export const Toolchains: React.FC = () => {
  const f = useCurrentFrame();
  return <Set accent="#e2edea">
    <Stage wide><RuntimeTiles /></Stage>
    <div style={{position: "absolute", left: 100, top: 108}}>
      <Kicker>How many versions do you need?</Kicker>
      <div style={{marginTop: 26}}><Title lines={["Find old runtime versions."]} size={100} /></div>
      <Caption style={{marginTop: 20}}>Choose what you keep.</Caption>
    </div>
    <div style={{position: "absolute", left: 100, right: 100, bottom: 94, display: "flex", justifyContent: "center", gap: 31, color: "#6c7a8f", fontSize: 29, fontWeight: 550, opacity: move(f, 17, 34)}}>{["Node", "PHP", "Go", "Python", "Bun", "Deno", "and more"].map((name, i) => <span key={name}>{i > 0 && <span style={{color: "#c7cedb", marginRight: 31}}>·</span>}{name}</span>)}</div>
  </Set>;
};

export const Heavyweights: React.FC = () => {
  const f = useCurrentFrame();
  return <Set dark>
    <Stage dark wide><EcosystemObjects /></Stage>
    <div style={{position: "absolute", left: 100, right: 100, top: 92}}><Title lines={["Docker. Local AI.", "Simulators, too."]} size={94} centered /></div>
    <div style={{position: "absolute", left: 100, right: 100, top: 827, display: "grid", gridTemplateColumns: "repeat(3,1fr)", textAlign: "center", fontSize: 35, fontWeight: 550, letterSpacing: -1, opacity: move(f, 22, 42)}}>{["Containers", "Local models", "Simulators"].map(name => <div key={name}>{name}</div>)}</div>
    <div style={{position: "absolute", left: 100, right: 100, bottom: 83, textAlign: "center", fontSize: 28, color: "#91a3c4", opacity: move(f, 49, 73)}}>Plus Gradle, builds, old APKs, large files and apps.</div>
  </Set>;
};

const PreviewPanel: React.FC = () => {
  const f = useCurrentFrame();
  const rows = [{name: "node_modules", path: "~/Code/old-dashboard/node_modules", size: "8.6 GB"}, {name: ".build", path: "~/Code/old-dashboard/.build", size: "3.2 GB"}, {name: "vendor", path: "~/Code/old-dashboard/vendor", size: "1.4 GB"}];
  const recovery = f < 27 ? "0" : f < 54 ? "8.6" : f < 81 ? "11.8" : "13.2";
  const cursorY = 200 + move(f, 35, 48, 0, 107) + move(f, 62, 75, 0, 107) + move(f, 99, 117, 0, 143);
  const click = f % 27 > 24 ? .7 : 0;
  return <div style={{position: "absolute", left: 945, top: 197, width: 850, height: 689, borderRadius: 28, background: "linear-gradient(145deg,#fff,#fbfcff)", border: "1px solid #d9dfeb", boxShadow: "0 55px 120px #17356820,0 3px 10px #15284910,inset 0 1px 0 #fff", transform: `perspective(1800px) rotateY(-5deg) translateX(${move(f, 0, 29, 90, 0)}px)`, opacity: move(f, 0, 20), padding: 38}}>
    <div style={{display: "flex", alignItems: "center", justifyContent: "space-between"}}><span style={{fontSize: 33, fontWeight: 650, letterSpacing: -1}}>Cleanup preview</span><span style={{fontSize: 20, color: "#8793a8"}}>Example</span></div>
    <div style={{fontSize: 25, color: "#7b879d", marginTop: 13, paddingBottom: 24, borderBottom: "1px solid #e6eaf1"}}>Inactive project dependencies</div>
    {rows.map((row, i) => {
      const selected = f >= 27 + i * 27;
      return <div key={row.name} style={{display: "flex", alignItems: "center", height: 107, borderBottom: "1px solid #e6eaf1", gap: 20}}>
        <div style={{width: 29, height: 29, borderRadius: 9, background: selected ? P.blue : "white", color: "white", border: `1.5px solid ${selected ? P.blue : "#cdd5e3"}`, display: "grid", placeItems: "center", flexShrink: 0}}>{selected && <Check size={22} />}</div>
        <div><div style={{fontSize: 30, fontWeight: 600, letterSpacing: -.7}}>{row.name}</div><div style={{marginTop: 8, fontSize: 21, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", color: "#8190a8"}}>{row.path}</div></div>
        <div style={{marginLeft: "auto", fontSize: 30, fontWeight: 600, whiteSpace: "nowrap", letterSpacing: -1}}>{row.size}</div>
      </div>;
    })}
    <div style={{display: "flex", alignItems: "baseline", justifyContent: "space-between", marginTop: 25}}><span style={{fontSize: 25, color: "#7b879d"}}>Selected for review</span><span style={{fontSize: 42, fontWeight: 650, color: P.blue, letterSpacing: -1.9}}>{recovery}<span style={{fontSize: 23, marginLeft: 7}}>GB</span></span></div>
    <div style={{marginTop: 19, borderRadius: 13, background: P.blue, color: "white", display: "flex", alignItems: "center", justifyContent: "center", height: 63, fontSize: 25, fontWeight: 600, boxShadow: "0 9px 20px #345cff25"}}>Review selection <span style={{marginLeft: 15}}>→</span></div>
    <Pointer x={f < 104 ? move(f, 8, 29, 730, 28) : move(f, 104, 122, 28, 488)} y={cursorY} click={click} />
  </div>;
};

export const Review: React.FC = () => <Set accent="#e5eaff">
  <div style={{position: "absolute", left: 100, top: 269}}>
    <Kicker>Your files. Your decision.</Kicker>
    <div style={{marginTop: 31}}><Title lines={["Review first.", "Then reclaim."]} size={106} /></div>
    <Caption style={{marginTop: 30}}>See the exact paths.<br />Choose what stays.</Caption>
  </div>
  <PreviewPanel />
</Set>;

export const Resolution: React.FC = () => {
  const f = useCurrentFrame();
  const finale = move(f, 62, 84);
  return <Set accent="#dce5ff">
    <AbsoluteFill style={{opacity: 1 - finale, transform: `scale(${1 + finale * .07})`}}>
      <Stage><Drive clean frame={f} /></Stage>
      <Brand />
      <div style={{position: "absolute", left: 100, top: 309}}><Title lines={["More room.", "Same Mac."]} size={139} colors={[P.ink, P.blue]} /><Caption style={{marginTop: 30}}>Make space for your next build.</Caption></div>
    </AbsoluteFill>
    <AbsoluteFill style={{opacity: finale, alignItems: "center", paddingTop: 181, transform: `translateY(${(1 - finale) * 32}px)`}}>
      <Img src={staticFile("app-icon.png")} style={{width: 135, height: 135, borderRadius: 31, boxShadow: "0 20px 55px #253e7433,0 2px 5px #16295920"}} />
      <div style={{marginTop: 35, fontSize: 78, fontWeight: 650, letterSpacing: -4.5}}>Storage Cleaner</div>
      <div style={{fontSize: 43, fontWeight: 450, letterSpacing: -1.8, color: "#6c7a93", marginTop: 3}}>for Developers</div>
      <div style={{marginTop: 47, display: "flex", alignItems: "center", padding: "21px 33px", borderRadius: 17, fontSize: 28, fontWeight: 600, background: P.blue, color: "white", boxShadow: "0 15px 32px #345cff30"}}>Download on the Mac App Store <span style={{marginLeft: 23}}>↗</span></div>
      <div style={{marginTop: 25, fontSize: 29, fontWeight: 550, color: P.blue, letterSpacing: -.7}}>storagecleaner.horizam.com</div>
      <div style={{marginTop: 33, fontSize: 24, color: "#8792a7"}}>Free to scan · No account · macOS 14+</div>
    </AbsoluteFill>
  </Set>;
};
