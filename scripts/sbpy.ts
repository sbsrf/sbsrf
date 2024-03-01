import { readFileSync, rmSync, writeFileSync } from "fs";
import { parse } from "csv-parse/sync";

function makeStrokesMap() {
  const strokesContent = readFileSync("hzinfo/gbkhz_bihua.csv", "utf8");
  const strokes = new Map<string, string>();
  const n = 4;

  for (const [char, stroke] of parse(strokesContent) as [string, string][]) {
    let initialStrokes = stroke.slice(0, n);
    if (initialStrokes.length < n) {
      initialStrokes = initialStrokes.padEnd(n, initialStrokes.at(-1));
    }
    strokes.set(char, initialStrokes);
  }
  return strokes;
}

const strokes = makeStrokesMap();

function processLine(line: string) {
  // 一行可能是以下三种情况：
  // 1. 字\t拼音\t权重
  // 2. 字\t拼音
  // 3. 字\t权重
  const fields = line.split("\t");
  // 第三种情况无需补充笔画，不处理
  if (fields.length == 2 && /^[0-9]+$/.test(fields[1])) {
    return line;
  }
  // 第一和第二种情况都需要补充笔画，weight 可能不存在
  const [word, pinyin, weight] = fields;
  const chars = Array.from(word).filter((char) => !"·–（）：".includes(char));
  const syllables = pinyin.split(" ");
  console.assert(
    chars.length === syllables.length,
    `Length mismatch: ${word} ${pinyin}`
  );
  const newSyllables: string[] = [];
  for (const [index, syllable] of syllables.entries()) {
    const char = chars[index];
    const stroke = strokes.get(char);
    if (stroke) {
      newSyllables.push(`${syllable}${stroke}`);
    } else {
      return;
    }
  }
  const newPinyin = newSyllables.join(" ");
  if (weight === undefined) {
    return `${word}\t${newPinyin}`;
  }
  return `${word}\t${newPinyin}\t${weight}`;
}

function processDict(dictName: string, newName: string) {
  const lines = readFileSync(`rime-ice/cn_dicts/${dictName}.dict.yaml`, "utf8");
  const newLines: string[] = [];
  for (const line of lines.split("\n")) {
    if (line == `name: ${dictName}`) {
      newLines.push(`name: ${newName}`);
      if (dictName === "8105") {
        newLines.push(`import_tables:`);
        newLines.push(`  - sbpy.unihan`);
      }
      if (dictName === "tencent") {
        newLines.push(`import_tables:`);
        newLines.push(`  - sbpy`);
      }
      continue;
    } else if (line.startsWith("#") || !line.includes("\t")) {
      newLines.push(line);
      continue;
    }
    const newLine = processLine(line);
    if (newLine) {
      newLines.push(newLine);
    }
  }
  writeFileSync(`sbxlm/${newName}.dict.yaml`, newLines.join("\n"));
}

processDict("8105", "sbpy");
processDict("41448", "sbpy.unihan");
processDict("base", "sbpy.base");
processDict("ext", "sbpy.ext");
processDict("tencent", "sbpy.tencent");
