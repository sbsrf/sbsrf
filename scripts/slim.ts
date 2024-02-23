import fs from "fs";
import { load, dump } from "js-yaml";

// Read character_frequency.txt
const characterFile = fs.readFileSync(
  "character_frequency.txt",
  "utf-8"
);
const characterSet = new Map(
  characterFile.split("\n").map((x) => {
    const [char, freq] = x.split("\t");
    return [char, Number(freq)];
  })
);

// Read word_frequency.txt
const wordFile = fs.readFileSync("word_frequency.txt", "utf-8");
const wordSet = new Map(
  wordFile.split("\n").map((x) => {
    const [char, freq] = x.split("\t");
    return [char, Number(freq)];
  })
);

function processSchema(id) {
  const name = `${id}.schema.yaml`;
  const schemaFile = fs.readFileSync(name, "utf-8");
  const schema = load(schemaFile);
  schema.schema.dependencies = undefined
  if (schema.engine) {
    schema.engine.translators = schema.engine.translators?.filter(
      (x) => !x.includes("lookup")
    );
    schema.engine.filters = schema.engine.filters?.filter(
      (x) => !x.includes("lookup")
    );
  }
  const filteredSchema = dump(schema);
  fs.writeFileSync(name, filteredSchema);
}

function processDict(id) {
  const base = `${id}.dict.yaml`;
  fs.copyFileSync((id == "sbjm" ? `backup.` : "") + base, base);
  if (id == "sbfd" || id == "sbpy") return;
  const extended = `${id}.extended.dict.yaml`;
  const extendedContent = fs.readFileSync(extended, "utf-8");
  const filtered = extendedContent
    .split("\n")
    .filter((entry) => {
      if (!entry.includes("\t")) return true;
      const charOrWord = entry.split("\t")[0].trim();
      const value =
        (characterSet.get(charOrWord) ?? 0) + (wordSet.get(charOrWord) ?? 0);
      return value > 0;
    })
    .join("\n");
  fs.writeFileSync(extended, filtered);
}

for (const id of ["sbjm", "sbfm", "sbfd", "sbfx", "sbxh", "sbzr", "sbpy"]) {
  processSchema(id);
  processDict(id);
}

for (const file of [
  "fmzdy.dict.yaml",
  "sbxlm.yaml",
  "lua",
  "sbzdy.txt",
  "pyzdy.txt",
]) {
  fs.cpSync(file, file, { recursive: true });
}
