import { readFileSync, writeFileSync } from "fs";

function extract(
  content: string,
  filter: (entry: [string, string]) => boolean
) {
  const lookup = new Map<string, string[]>();
  for (const line of content.trim().split("\r\n")) {
    if (!line.includes("\t")) continue;
    let [word, code] = line.trim().split("\t");
    if (code.endsWith("'")) code = code.slice(0, -1);
    if (!filter([word, code])) continue;
    lookup.set(code, (lookup.get(code) || []).concat(word));
  }
  return [...lookup]
    .map(([code, word]) => `${code}\t${word.join(" ")}`)
    .join("\n");
}

const spFilter = ([word, code]: [string, string]) => {
  // 整句模式下相当于声笔双拼的快调模式，所以不固定三码字
  return code.length < 3;
};

const sbzr = readFileSync("sbxlm/sbzr.dict.yaml", "utf8");
writeFileSync("sbzz.fixed.txt", extract(sbzr, spFilter), "utf8");

const sbxh = readFileSync("sbxlm/sbxh.dict.yaml", "utf8");
writeFileSync("sbhz.fixed.txt", extract(sbxh, spFilter), "utf8");

const jmFilter = ([word, code]: [string, string]) => {
  return !/\d/.test(code);
};

const sbjm = readFileSync("sbxlm/sbjm.dict.yaml", "utf8");
writeFileSync("sbjz.fixed.txt", extract(sbjm, jmFilter), "utf8");
