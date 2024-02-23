import { readFileSync, writeFileSync } from "fs";
import { parse } from "csv-parse/sync";

function makeStrokesMap() {
  const strokesContent = readFileSync("hzinfo/gbkhz_bihua.csv", "utf8");
  const strokes = new Map<string, string>();

  for (const [char, stroke] of parse(strokesContent) as [string, string][]) {
    let firstThree = stroke.slice(0, 3);
    if (firstThree.length < 3) {
      firstThree = firstThree.padEnd(3, firstThree.at(-1));
    }
    strokes.set(char, firstThree);
  }
  return strokes;
}

const strokes = makeStrokesMap();

function processLine(line: string) {
  const [word, pinyin, ...rest] = line.split("\t");
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
  return `${word}\t${newPinyin}\t${rest.join("\t")}`;
}

function processDict(dictName: string, newName: string) {
  const lines = readFileSync(`rime-ice/cn_dicts/${dictName}.dict.yaml`, "utf8");
  const newLines: string[] = [];
  for (const line of lines.split("\n")) {
    if (line == `name: ${dictName}`) {
      newLines.push(`name: ${newName}`);
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
  writeFileSync(`${newName}.dict.yaml`, newLines.join("\n"));
}

processDict("8105", "sbpy");
processDict("base", "sbpy.base");
