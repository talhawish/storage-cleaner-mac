import React, {useEffect, useMemo} from "react";
import {ThreeCanvas} from "@remotion/three";
import {useThree} from "@react-three/fiber";
import {CanvasTexture, PMREMGenerator, SRGBColorSpace} from "three";
import {RoundedBoxGeometry} from "three/examples/jsm/geometries/RoundedBoxGeometry.js";
import {RoomEnvironment} from "three/examples/jsm/environments/RoomEnvironment.js";
import {useCurrentFrame} from "remotion";
import {linear, move, P} from "./design";

type Vec = [number, number, number];
type BoxProps = {size: Vec; position?: Vec; rotation?: Vec; color?: string; radius?: number; metal?: number; rough?: number; opacity?: number; glow?: string};

const StudioEnvironment: React.FC = () => {
  const {gl} = useThree();
  const environment = useMemo(() => {
    const generator = new PMREMGenerator(gl);
    const room = new RoomEnvironment();
    const result = generator.fromScene(room, .03);
    room.dispose();
    generator.dispose();
    return result;
  }, [gl]);
  useEffect(() => () => environment.dispose(), [environment]);
  return <primitive object={environment.texture} attach="environment" />;
};

export const Box: React.FC<BoxProps> = ({size, position, rotation, color = "#fff", radius = .08, metal = .18, rough = .28, opacity = 1, glow}) => {
  const [w, h, d] = size;
  const geometry = useMemo(() => new RoundedBoxGeometry(w, h, d, 3, Math.min(radius, w / 2, h / 2, d / 2)), [w, h, d, radius]);
  useEffect(() => () => geometry.dispose(), [geometry]);
  return <mesh geometry={geometry} position={position} rotation={rotation} castShadow receiveShadow>
    <meshPhysicalMaterial color={color} roughness={rough} metalness={metal} clearcoat={.6} clearcoatRoughness={.25} transparent={opacity < 1} opacity={opacity} emissive={glow ?? "#000"} emissiveIntensity={glow ? .55 : 0} />
  </mesh>;
};

export const Label: React.FC<{text: string; position: Vec; width?: number; color?: string; fontSize?: number}> = ({text, position, width = 2.5, color = "#fff", fontSize = 112}) => {
  const texture = useMemo(() => {
    const canvas = document.createElement("canvas");
    canvas.width = 1536;
    canvas.height = 512;
    const ctx = canvas.getContext("2d");
    if (ctx) {
      ctx.clearRect(0, 0, 1536, 512);
      ctx.fillStyle = color;
      ctx.font = `600 ${fontSize}px Helvetica, Arial, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(text, 768, 256, 1430);
    }
    const result = new CanvasTexture(canvas);
    result.colorSpace = SRGBColorSpace;
    return result;
  }, [text, color, fontSize]);
  useEffect(() => () => texture.dispose(), [texture]);
  return <mesh position={position}><planeGeometry args={[width, width / 3]} /><meshBasicMaterial map={texture} transparent depthWrite={false} /></mesh>;
};

const ContactShadow: React.FC<{wide: boolean; dark: boolean}> = ({wide, dark}) => {
  const texture = useMemo(() => {
    const canvas = document.createElement("canvas");
    canvas.width = 256;
    canvas.height = 256;
    const ctx = canvas.getContext("2d");
    if (ctx) {
      const falloff = ctx.createRadialGradient(128, 128, 0, 128, 128, 124);
      falloff.addColorStop(0, "rgba(13,28,57,.34)");
      falloff.addColorStop(.35, "rgba(13,28,57,.17)");
      falloff.addColorStop(1, "rgba(13,28,57,0)");
      ctx.fillStyle = falloff;
      ctx.fillRect(0, 0, 256, 256);
    }
    return new CanvasTexture(canvas);
  }, []);
  useEffect(() => () => texture.dispose(), [texture]);
  return <mesh rotation={[-Math.PI / 2, 0, 0]} position={[wide ? 0 : 3.15, -2.85, 0]}><planeGeometry args={[wide ? 15 : 7, 6]} /><meshBasicMaterial map={texture} transparent opacity={dark ? .5 : .7} depthWrite={false} /></mesh>;
};

export const Stage: React.FC<{children: React.ReactNode; dark?: boolean; wide?: boolean}> = ({children, dark = false, wide = false}) => <ThreeCanvas width={1920} height={1080} shadows dpr={1} camera={{position: [0, 0, 12], fov: 35}} gl={{alpha: true, antialias: true}} onCreated={({scene}) => {scene.environmentIntensity = .72;}} style={{position: "absolute", inset: 0}}>
  <StudioEnvironment />
  <ambientLight intensity={dark ? .35 : .5} />
  <directionalLight position={[-4, 7, 8]} intensity={1.8} castShadow shadow-mapSize={[2048, 2048]} shadow-camera-left={-10} shadow-camera-right={10} shadow-camera-top={7} shadow-camera-bottom={-7} shadow-normalBias={.03} />
  <directionalLight position={[7, 3, 5]} intensity={.8} color={dark ? "#739aff" : "#dce6ff"} />
  <directionalLight position={[0, -3, 4]} intensity={.2} color="#a9b9ff" />
  <pointLight position={[4, 2, -3]} intensity={8} color="#4d6eff" />
  <ContactShadow wide={wide} dark={dark} />
  {children}
</ThreeCanvas>;

export const Drive: React.FC<{clean?: boolean; frame: number; center?: Vec}> = ({clean = false, frame, center = [3.15, -.25, 0]}) => {
  const entry = move(frame, 0, 32);
  return <group position={center} rotation={[-.19, -.32 + Math.sin(frame / 100) * .12, -.09]} scale={.8 + .2 * entry}>
    <Box size={[4.65, 3.55, .48]} color={clean ? "#c6cfdd" : "#263247"} metal={.65} rough={.22} radius={.21} />
    <Box size={[4.36, 3.25, .07]} position={[0, 0, .26]} color={clean ? "#f0f3fc" : "#101722"} metal={.12} radius={.03} />
    <Label text="DEVELOPER DISK" position={[0, 1.14, .31]} width={3} color={clean ? "#4b5b77" : "#879ab8"} />
    {Array.from({length: 25}, (_, i) => <Box key={i} size={[.112, 1.42, .085]} position={[-1.77 + i * .148, -.02, .33]} color={i < (clean ? 8 : Math.floor(10 + entry * 14)) ? (clean ? P.blue : "#f46d77") : clean ? "#dae0ec" : "#2c3649"} glow={i < (clean ? 8 : 24) ? (clean ? "#294ad3" : "#712c36") : undefined} radius={.024} metal={.15} />)}
    <Label text={clean ? "ROOM FOR WHAT’S NEXT" : "DISK ALMOST FULL"} position={[0, -1.1, .32]} width={3.45} color={clean ? "#345cff" : "#f8c2c7"} />
    {[-1, 1].map(x => [-1, 1].map(y => <mesh key={`${x}${y}`} position={[x * 2.08, y * 1.47, .315]} rotation={[Math.PI / 2, 0, 0]}><cylinderGeometry args={[.05, .05, .04, 16]} /><meshStandardMaterial color="#8b96a9" metalness={.8} roughness={.25} /></mesh>))}
    <Box size={[2.2, .06, .1]} position={[0, -1.785, .04]} color="#536580" radius={.025} />
  </group>;
};

export const DataCluster: React.FC = () => {
  const f = useCurrentFrame();
  const spread = move(f, 12, 70, 1.02, 1.28);
  const colors = [P.blue, P.purple, P.cyan, "#f2a568"];
  return <group position={[3.1, .2, 0]} rotation={[.35, -.55 + f * .0035, -.14]} scale={.89}>
    {Array.from({length: 27}, (_, i) => {
      const x = i % 3 - 1, y = Math.floor(i / 3) % 3 - 1, z = Math.floor(i / 9) - 1;
      return <Box key={i} size={[.93, .93, .93]} position={[x * spread, y * spread, z * spread]} color={colors[(i + Math.floor(i / 9)) % colors.length]} radius={.13} metal={.25} rough={.2} />;
    })}
  </group>;
};

export const StorageRing: React.FC = () => {
  const f = useCurrentFrame();
  const shares = [.367, .214, .141, .102, .082, .062, .032];
  const colors = [P.blue, P.cyan, P.purple, P.green, "#f3a35e", "#ed6499", "#ec7e80"];
  let angle = .3;
  return <group position={[3.12, .05, 0]} rotation={[.13, -.22 + move(f, 0, 90, -.15, 0), move(f, 0, 85, -.6, 0)]} scale={move(f, 0, 30, .7, 1)}>
    {shares.map((part, i) => {
      const start = angle;
      angle += part * Math.PI * 2;
      return <mesh key={i} rotation={[0, 0, start]} castShadow><torusGeometry args={[2.03, .25, 24, 80, part * Math.PI * 2 - .035]} /><meshPhysicalMaterial color={colors[i]} roughness={.22} metalness={.3} clearcoat={1} /></mesh>;
    })}
  </group>;
};

export const ProjectFolder: React.FC = () => {
  const f = useCurrentFrame();
  return <>
    <group position={[2.7, -.08, 0]} rotation={[-.12, -.25 + Math.sin(f / 90) * .08, -.07]} scale={move(f, 0, 28, .8, 1)}>
      <Box size={[3.75, 2.65, .16]} position={[0, .15, -.23]} color="#527aff" radius={.075} />
      <Box size={[1.6, .47, .16]} position={[-1.05, 1.63, -.23]} color="#527aff" radius={.075} />
      {[0, 1, 2].map(i => <group key={i} position={[i * .07, .4 + i * .13, -.08 + i * .12]} rotation={[0, 0, (i - 1) * -.04]}>
        <Box size={[3.1, 2.1, .055]} color={i === 2 ? "#f6faff" : "#bfcff3"} radius={.025} />
        {Array.from({length: 5}, (_, j) => <Box key={j} size={[j % 2 ? 1.6 : 2.2, .046, .008]} position={[-.17, .7 - j * .2, .034]} color={j % 2 ? "#8f9cb8" : "#5a80e4"} radius={.003} />)}
      </group>)}
      <Box size={[3.86, 1.96, .19]} position={[0, -.33, .48]} color="#345cff" radius={.09} rough={.22} />
      <Label text="SOURCE CODE" position={[0, -.32, .584]} width={2.8} />
    </group>
    <group position={[5.23, -1.95, .3]} rotation={[.08, -.2, .06]}>
      <mesh castShadow><cylinderGeometry args={[.65, .51, 1.05, 48, 1, true]} /><meshPhysicalMaterial color="#bac6dc" metalness={.65} roughness={.25} side={2} /></mesh>
      <mesh rotation={[Math.PI / 2, 0, 0]} position={[0, .52, 0]}><torusGeometry args={[.65, .055, 12, 48]} /><meshStandardMaterial color="#edf3ff" metalness={.7} roughness={.2} /></mesh>
    </group>
    {[0, 1, 2].map(i => {
      const start = 27 + i * 27;
      const travel = linear(f, start, 71 + i * 27);
      const visible = f >= start && travel < 1;
      return visible ? <group key={i} position={[3.2 + travel * 2.03, 1.75 + Math.sin(travel * Math.PI) * .8 - travel * 3.6, 1.2 - travel * .9]} rotation={[travel * .8, travel * 2, -.1]} scale={(1 - travel * .35) * move(f, start, start + 6, .05, 1)}>
        <Box size={[.75, .75, .75]} color={[P.cyan, P.purple, "#f2a35e"][i]} radius={.12} />
      </group> : null;
    })}
  </>;
};

export const RuntimeTiles: React.FC = () => {
  const f = useCurrentFrame();
  return <>{["18", "20", "22"].map((v, i) => {
    const chosen = move(f, 45, 70);
    return <group key={v} position={[(i - 1) * 3.75, -.9 + (i === 2 ? chosen * .22 : -chosen * .12), i === 2 ? chosen * .35 : -chosen * .35]} rotation={[-.13, (1 - i) * .13, i === 2 ? -.025 * chosen : .03 * (i - 1)]} scale={move(f, i * 5, 25 + i * 5, .72, 1)}>
      <Box size={[3.08, 2.68, .25]} color={i === 2 && chosen > .1 ? "#43cda0" : "#e8ecf3"} metal={.35} rough={.25} radius={.12} />
      <Box size={[2.92, 2.52, .045]} position={[0, 0, .147]} color={i === 2 ? "#f1fff8" : "#fff"} radius={.02} />
      <Label text="Node.js" position={[0, .78, .18]} width={2} fontSize={220} color="#536474" />
      <Label text={`v${v}`} position={[0, -.02, .185]} width={3.5} fontSize={285} color={i === 2 ? "#159c70" : "#1f293b"} />
      <Label text={i === 2 && chosen > .2 ? "KEEP" : "REVIEW"} position={[0, -.87, .185]} width={1.5} fontSize={230} color={i === 2 ? "#159c70" : "#8893a8"} />
    </group>;
  })}</>;
};

export const EcosystemObjects: React.FC = () => {
  const f = useCurrentFrame();
  return <>
    <group position={[-4, -.7, 0]} rotation={[.08, -.4 + f * .001, -.04]} scale={move(f, 0, 30, .65, 1)}>
      <Box size={[2.65, 1.95, 1.7]} color="#326cf2" radius={.12} metal={.35} />
      {Array.from({length: 9}, (_, i) => <Box key={i} size={[.055, 1.66, .11]} position={[-1.08 + i * .27, 0, .89]} color="#7cb0ff" radius={.02} />)}
      <Box size={[2.58, .065, .09]} position={[0, -.83, .96]} color="#bdd7ff" radius={.015} />
      <Box size={[2.58, .065, .09]} position={[0, .83, .96]} color="#bdd7ff" radius={.015} />
    </group>
    <group position={[0, -.64, 0]} rotation={[.4, f * .014, -.3]} scale={move(f, 7, 37, .65, 1)}>
      <mesh castShadow><sphereGeometry args={[.87, 48, 32]} /><meshPhysicalMaterial color="#c9b2ff" metalness={.4} roughness={.34} clearcoat={.5} clearcoatRoughness={.3} /></mesh>
      {[0, 1, 2].map(i => <mesh key={i} rotation={[Math.PI / 2 * (i % 2), i * .95, i * .65]}><torusGeometry args={[1.38, .044, 12, 100]} /><meshStandardMaterial color={i === 1 ? "#9a7cff" : "#d0c1ff"} emissive="#4e2c9e" emissiveIntensity={.5} metalness={.5} roughness={.2} /></mesh>)}
    </group>
    <group position={[4, -.6, 0]} rotation={[.05, -.28, .09]} scale={move(f, 14, 44, .65, 1)}>
      <Box size={[1.6, 2.88, .2]} color="#8ea3c9" metal={.75} radius={.095} />
      <Box size={[1.44, 2.72, .04]} position={[0, 0, .115]} color="#0d2038" radius={.02} />
      <Box size={[1.29, 2.51, .025]} position={[0, -.025, .145]} color="#a0d9f5" radius={.01} />
      <Box size={[.48, .105, .04]} position={[0, 1.15, .17]} color="#14283e" radius={.018} />
      {[0, 1, 2, 3, 4, 5].map(i => <Box key={i} size={[.29, .29, .03]} position={[-.41 + (i % 3) * .4, .45 - Math.floor(i / 3) * .49, .176]} color={["#3682ee", "#edf7ff", "#7468e4"][i % 3]} radius={.014} />)}
      <Box size={[.5, .035, .015]} position={[0, -1.15, .171]} color="#ffffff" radius={.006} />
    </group>
  </>;
};
