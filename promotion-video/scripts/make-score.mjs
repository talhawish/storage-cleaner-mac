import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(root, "public/launch-score.wav");
const rawOutput = resolve(root, "out/score-source.wav");
const sampleRate = 48_000;
const duration = 36;
const frames = sampleRate * duration;
const channels = 2;
const pcm = Buffer.alloc(frames * channels * 2);
const bpm = 120;
const beat = 60 / bpm;
const bar = beat * 4;
const cuts = [3, 6, 11, 16, 20, 25, 30, 32];
const selectionClicks = [25.9, 26.8, 27.7];
const dependencyDrops = [11 + 71 / 30, 11 + 98 / 30, 11 + 125 / 30];
const chordMidi = [
  [50, 57, 61, 66], // Dmaj9
  [47, 54, 57, 62], // Bm7
  [43, 50, 54, 59], // Gmaj9
  [45, 52, 57, 61], // A
];
const dryLeft = new Float32Array(frames);
const dryRight = new Float32Array(frames);
const sendLeft = new Float32Array(frames);
const sendRight = new Float32Array(frames);
const arpPatterns = [0, 2, 1, 3, 2, 1, 3, 1];
const frequency = (midi) => 440 * 2 ** ((midi - 69) / 12);
const smoothstep = (value) => {
  const bounded = Math.max(0, Math.min(1, value));
  return bounded * bounded * (3 - 2 * bounded);
};
const envelope = (time, length, attack, release) =>
  smoothstep(time / attack) * smoothstep((length - time) / release);

let randomState = 0x5a17c9e3;
const random = () => {
  randomState ^= randomState << 13;
  randomState ^= randomState >>> 17;
  randomState ^= randomState << 5;
  return (randomState >>> 0) / 0xffffffff;
};

// Pre-filter seeded noise so hats and the snare stay soft instead of crackling.
const noise = new Float32Array(sampleRate);
let lowPass = 0;
for (let index = 0; index < noise.length; index += 1) {
  const raw = random() * 2 - 1;
  lowPass += (raw - lowPass) * 0.22;
  noise[index] = lowPass;
}

for (let index = 0; index < frames; index += 1) {
  const time = index / sampleRate;
  const currentBar = Math.min(16, Math.floor(time / bar));
  const localBar = time - currentBar * bar;
  const chord = chordMidi[currentBar % chordMidi.length];
  const previousChord = chordMidi[(currentBar + chordMidi.length - 1) % chordMidi.length];
  const chordBlend = smoothstep(localBar / 0.72);
  let left = 0;
  let right = 0;

  const padFade = Math.min(1, time / 1.4, (duration - time) / 1.8);
  for (let noteIndex = 0; noteIndex < chord.length; noteIndex += 1) {
    const previousHz = frequency(previousChord[noteIndex]);
    const currentHz = frequency(chord[noteIndex]);
    const padVoice = (hz) =>
      Math.sin(2 * Math.PI * hz * time) * 0.72 +
      Math.sin(2 * Math.PI * hz * 2.002 * time) * 0.18 +
      Math.sin(2 * Math.PI * hz * 0.5 * time) * 0.1;
    const pad = (
      padVoice(previousHz) * (1 - chordBlend) + padVoice(currentHz) * chordBlend
    ) * padFade * 0.022;
    left += pad * (0.82 + noteIndex * 0.035);
    right += pad * (0.9 - noteIndex * 0.035);
    sendLeft[index] += pad * .8;
    sendRight[index] += pad * .9;
  }

  const beatNumber = Math.floor(time / beat);
  const withinBeat = time - beatNumber * beat;
  const bassNote = chord[0] - 12 + (beatNumber % 4 === 2 ? 7 : 0);
  const bassGain = envelope(withinBeat, beat, 0.012, 0.085) * Math.exp(-withinBeat * 7);
  const bass = Math.sin(2 * Math.PI * frequency(bassNote) * withinBeat) * bassGain * 0.09;
  left += bass;
  right += bass;

  if ((time >= 3 || beatNumber % 2 === 0) && withinBeat < 0.34) {
    const kickTime = withinBeat;
    const kickPhase = 2 * Math.PI * (38 * kickTime + (66 / 28) * (1 - Math.exp(-28 * kickTime)));
    const kick = Math.sin(kickPhase) * envelope(kickTime, 0.34, 0.004, 0.09) * Math.exp(-kickTime * 12) * 0.20;
    left += kick;
    right += kick;
  }

  if (time >= 3 && (beatNumber % 4 === 1 || beatNumber % 4 === 3) && withinBeat < 0.16) {
    const snareEnvelope = envelope(withinBeat, 0.16, 0.003, 0.025) * Math.exp(-withinBeat * 22);
    const noiseSample = noise[Math.floor(withinBeat * sampleRate) % noise.length];
    const snap = noiseSample * snareEnvelope * 0.1;
    const body = Math.sin(2 * Math.PI * 188 * withinBeat) * snareEnvelope * 0.045;
    left += snap * 0.84 + body;
    right += snap + body * 0.9;
  }

  const eighth = beat / 2;
  const step = Math.floor(time / eighth);
  const withinEighth = time - step * eighth;
  const arpBar = Math.min(16, Math.floor(step * eighth / bar));
  const arpChord = chordMidi[arpBar % chordMidi.length];
  const note = arpChord[arpPatterns[step % arpPatterns.length]] + 12;
  if (withinEighth < 0.19 && (step % 2 === 0 || (time > 20 && step % 4 === 3))) {
    const pluckEnvelope = envelope(withinEighth, 0.19, 0.006, 0.035) * Math.exp(-withinEighth * 17);
    const pluck = (
      Math.sin(2 * Math.PI * frequency(note) * withinEighth) * 0.78 +
      Math.sin(2 * Math.PI * frequency(note + 12) * withinEighth) * 0.12
    ) * pluckEnvelope * 0.038;
    left += pluck * (step % 2 ? 0.78 : 1);
    right += pluck * (step % 2 ? 1 : 0.78);
    sendLeft[index] += pluck;
    sendRight[index] += pluck * .7;
  }

  if (time >= 6 && step % 2 === 1 && withinEighth < 0.045) {
    const hatEnvelope = envelope(withinEighth, 0.045, 0.002, 0.012) * Math.exp(-withinEighth * 74);
    const hatSample = noise[Math.floor(withinEighth * sampleRate) % noise.length];
    const hat = hatSample * hatEnvelope * 0.055;
    left += hat * 0.72;
    right += hat;
  }

  for (const cutTime of cuts) {
    const hitTime = time - cutTime;
    if (hitTime >= 0 && hitTime < 0.7) {
      const hitEnvelope = envelope(hitTime, 0.7, 0.008, 0.16) * Math.exp(-hitTime * 5.5);
      const impact = Math.sin(2 * Math.PI * (55 * hitTime + 10 * hitTime * hitTime)) * hitEnvelope * 0.085;
      const shimmerEnvelope = envelope(hitTime, 0.32, 0.012, 0.08) * Math.exp(-hitTime * 9);
      const shimmer = Math.sin(2 * Math.PI * 880 * hitTime) * shimmerEnvelope * 0.027;
      left += impact + shimmer * 0.75;
      right += impact + shimmer;
      sendLeft[index] += shimmer;
      sendRight[index] += shimmer;
    }
  }

  for (const clickTime of selectionClicks) {
    const age = time - clickTime;
    if (age >= 0 && age < .052) {
      const tap = Math.sin(2 * Math.PI * 1350 * age) * envelope(age, .052, .002, .012) * Math.exp(-age * 95) * .03;
      left += tap;
      right += tap * .8;
    }
  }
  for (const dropTime of dependencyDrops) {
    const age = time - dropTime;
    if (age >= 0 && age < .17) {
      const drop = (Math.sin(2 * Math.PI * 740 * age) + Math.sin(2 * Math.PI * 1487 * age) * .16) * envelope(age, .17, .004, .04) * Math.exp(-age * 32) * .016;
      left += drop * .7;
      right += drop;
      sendRight[index] += drop;
    }
  }

  dryLeft[index] = left;
  dryRight[index] = right;
}

// Short room reflections and tempo-related stereo delays add space to the score.
const taps = [[.037, .15], [.071, .12], [.113, .095], [.25, .24], [.375, .18], [.50, .11], [.75, .06]];
let wetLeft = 0;
let wetRight = 0;
for (let index = 0; index < frames; index += 1) {
  const time = index / sampleRate;
  let reflectionsLeft = 0;
  let reflectionsRight = 0;
  for (let tap = 0; tap < taps.length; tap += 1) {
    const [delay, gain] = taps[tap];
    const source = index - Math.floor(delay * sampleRate);
    if (source >= 0) {
      reflectionsLeft += (tap % 2 ? sendRight[source] : sendLeft[source]) * gain;
      reflectionsRight += (tap % 2 ? sendLeft[source] : sendRight[source]) * gain;
    }
  }
  wetLeft += (reflectionsLeft - wetLeft) * .16;
  wetRight += (reflectionsRight - wetRight) * .16;
  const fade = Math.min(1, smoothstep(time / .3), smoothstep((duration - time) / 1.25));
  const leftValue = Math.tanh((dryLeft[index] + wetLeft) * 1.4) * fade;
  const rightValue = Math.tanh((dryRight[index] + wetRight) * 1.4) * fade;
  pcm.writeInt16LE(Math.round(leftValue * 32767), index * 4);
  pcm.writeInt16LE(Math.round(rightValue * 32767), index * 4 + 2);
}

const header = Buffer.alloc(44);
header.write("RIFF", 0);
header.writeUInt32LE(36 + pcm.length, 4);
header.write("WAVE", 8);
header.write("fmt ", 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);
header.writeUInt16LE(channels, 22);
header.writeUInt32LE(sampleRate, 24);
header.writeUInt32LE(sampleRate * channels * 2, 28);
header.writeUInt16LE(channels * 2, 32);
header.writeUInt16LE(16, 34);
header.write("data", 36);
header.writeUInt32LE(pcm.length, 40);

await mkdir(dirname(output), { recursive: true });
await mkdir(dirname(rawOutput), { recursive: true });
await writeFile(rawOutput, Buffer.concat([header, pcm]));
const master = spawnSync("corepack", ["pnpm", "exec", "remotion", "ffmpeg", "-y", "-i", rawOutput, "-af", "loudnorm=I=-18:TP=-2:LRA=9", "-ar", "48000", output, "-loglevel", "error"], {cwd: root, stdio: "inherit"});
if (master.status !== 0) throw new Error("Soundtrack mastering failed");
console.log(`Wrote mastered ${duration}s stereo score at ${bpm} BPM: ${output}`);
