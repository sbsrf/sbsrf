// 给定词频和固顶词，在雾凇拼音词库上模拟出静态编码

import { readFileSync, writeFileSync } from "fs";

const fixed = readFileSync("sbjz.fixed.txt", "utf8").trim().split("\n");
const fixedSet = new Set();

const encoded = [];
const wordCodeHash = new Set();
const codeHash = new Map();

for (const line of fixed) {
  let [code, words] = line.split("\t");
  const word = words.split(" ")[0];
  if (!code.match(/[aeiou]$/)) code += "_";
  encoded.push(`${code}\t${word}`);
  wordCodeHash.add(`${code}\t${word}`);
  codeHash.set(code, word);
  fixedSet.add(word);
}

const codes = [];
const core = readFileSync("sbpy.dict.yaml", "utf8").trim().split("\n");
const base = readFileSync("sbpy.base.dict.yaml", "utf8").trim().split("\n");

const stem = new Map();

for (const line of core.concat(base)) {
  if (line.startsWith("#")) continue;
  if (!line.includes("\t")) continue;
  const [word, code, weight_s] = line.split("\t");
  const weight = parseInt(weight_s ?? "0");
  codes.push([word, code, weight]);
  if (stem.has(word) && stem.get(word).weight >= weight) continue;
  stem.set(word, { code, weight });
}

codes.sort((a, b) => b[2] - a[2]);

function transform(code) {
  let prism = code.replace(/\b(?=[aoe])/g, "v");
  prism = prism.replace(/\b([a-z])[a-z]+/, "$1");
  // replace 12345 by eiuoa
  prism = prism.replace(/1/g, "e");
  prism = prism.replace(/2/g, "i");
  prism = prism.replace(/3/g, "u");
  prism = prism.replace(/4/g, "o");
  prism = prism.replace(/5/g, "a");
  return prism;
}

function assemble(syllables) {
  let base = syllables
    .map((x, i) => (i >= 4 ? x[0].toUpperCase() : x[0]))
    .join("");
  base += syllables.at(-1).slice(1, 3);
  base += syllables[0].slice(1);
  return base;
}

for (const [word, code] of codes) {
  if (fixedSet.has(word)) continue;
  let finalCode = "";
  const syllables = code.split(" ");
  if (syllables.includes("")) continue;
  const transformed = syllables.map(transform);
  const full =
    transformed.length === 1 ? transformed[0] : assemble(transformed);
  let hasShort = false;
  for (let i = syllables.length; i != full.length; i++) {
    let short = full.slice(0, i);
    if (i === syllables.length && i < 4) short += "_";
    if (codeHash.get(short) === undefined || codeHash.get(short) === word) {
      finalCode = short;
      hasShort = true;
      break;
    }
  }
  if (!hasShort) finalCode = full;
  const hash = `${finalCode}\t${word}`;
  if (wordCodeHash.has(hash)) continue;
  codeHash.set(finalCode, word);
  encoded.push(hash);
  wordCodeHash.add(hash);
}

writeFileSync("simulated.txt", encoded.join("\n"), "utf8");
