import { readFileSync, writeFileSync } from "fs";

function extract(content: string, filter: (entry: [string, string]) => boolean) {
  const lookup = new Map();
  for (const line of content.trim().split("\r\n")) {
    if (!line.includes("\t")) continue;
    const [word, code] = line.trim().split("\t");
    if (!filter([word, code])) continue;
    lookup.set(code, word);
  }
  return [...lookup].map(([code, word]) => `${code}\t${word}`).join("\n");
}

const spFilter = ([word, code]: [string, string]) => {
  // 由于无法处理词的简拼，所以只处理单字
  // 整句模式下不固定三码字
  return code.length < 3 && word.length === 1;
};

const sbzr = readFileSync("sbxlm/sbzr.dict.yaml", "utf8");
writeFileSync("sbzrzj.fixed.txt", extract(sbzr, spFilter), "utf8");

const sbxh = readFileSync("sbxlm/sbxh.dict.yaml", "utf8");
writeFileSync("sbxhzj.fixed.txt", extract(sbxh, spFilter), "utf8");

const jmFilter = ([word, code]: [string, string]) => {
  // code contains number
  return !/\d/.test(code);
}

const sbjm = readFileSync("sbxlm/sbjm.dict.yaml", "utf8");
writeFileSync("sbjmzj.fixed.txt", extract(sbjm, jmFilter), "utf8");
