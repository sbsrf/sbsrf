"use strict";
var __values = (this && this.__values) || function(o) {
    var s = typeof Symbol === "function" && Symbol.iterator, m = s && o[s], i = 0;
    if (m) return m.call(o);
    if (o && typeof o.length === "number") return {
        next: function () {
            if (o && i >= o.length) o = void 0;
            return { value: o && o[i++], done: !o };
        }
    };
    throw new TypeError(s ? "Object is not iterable." : "Symbol.iterator is not defined.");
};
var __read = (this && this.__read) || function (o, n) {
    var m = typeof Symbol === "function" && o[Symbol.iterator];
    if (!m) return o;
    var i = m.call(o), r, ar = [], e;
    try {
        while ((n === void 0 || n-- > 0) && !(r = i.next()).done) ar.push(r.value);
    }
    catch (error) { e = { error: error }; }
    finally {
        try {
            if (r && !r.done && (m = i["return"])) m.call(i);
        }
        finally { if (e) throw e.error; }
    }
    return ar;
};
Object.defineProperty(exports, "__esModule", { value: true });
var fs_1 = require("fs");
var sync_1 = require("csv-parse/sync");
function makeStrokesMap() {
    var e_1, _a;
    var strokesContent = (0, fs_1.readFileSync)("hzinfo/gbkhz_bihua.csv", "utf8");
    var strokes = new Map();
    var n = 5;
    try {
        for (var _b = __values((0, sync_1.parse)(strokesContent)), _c = _b.next(); !_c.done; _c = _b.next()) {
            var _d = __read(_c.value, 2), char = _d[0], stroke = _d[1];
            var initialStrokes = stroke.slice(0, n);
            if (initialStrokes.length < n) {
                initialStrokes = initialStrokes.padEnd(n, initialStrokes.at(-1));
            }
            strokes.set(char, initialStrokes);
        }
    }
    catch (e_1_1) { e_1 = { error: e_1_1 }; }
    finally {
        try {
            if (_c && !_c.done && (_a = _b.return)) _a.call(_b);
        }
        finally { if (e_1) throw e_1.error; }
    }
    return strokes;
}
var strokes = makeStrokesMap();
function processLine(line) {
    var e_2, _a;
    // 一行可能是以下三种情况：
    // 1. 字\t拼音\t权重
    // 2. 字\t拼音
    // 3. 字\t权重
    var fields = line.split("\t");
    // 第三种情况无需补充笔画，不处理
    if (fields.length == 2 && /^[0-9]+$/.test(fields[1])) {
        return line;
    }
    // 第一和第二种情况都需要补充笔画，weight 可能不存在
    var _b = __read(fields, 3), word = _b[0], pinyin = _b[1], weight = _b[2];
    var chars = Array.from(word).filter(function (char) { return !"·–（）：".includes(char); });
    var syllables = pinyin.split(" ");
    console.assert(chars.length === syllables.length, "Length mismatch: ".concat(word, " ").concat(pinyin));
    var newSyllables = [];
    try {
        for (var _c = __values(syllables.entries()), _d = _c.next(); !_d.done; _d = _c.next()) {
            var _e = __read(_d.value, 2), index = _e[0], syllable = _e[1];
            var char = chars[index];
            var stroke = strokes.get(char);
            if (stroke) {
                newSyllables.push("".concat(syllable).concat(stroke));
            }
            else {
                return;
            }
        }
    }
    catch (e_2_1) { e_2 = { error: e_2_1 }; }
    finally {
        try {
            if (_d && !_d.done && (_a = _c.return)) _a.call(_c);
        }
        finally { if (e_2) throw e_2.error; }
    }
    var newPinyin = newSyllables.join(" ");
    if (weight === undefined) {
        return "".concat(word, "\t").concat(newPinyin);
    }
    return "".concat(word, "\t").concat(newPinyin, "\t").concat(weight);
}
function processDict(dictName, newName) {
    var e_3, _a;
    var lines = (0, fs_1.readFileSync)("rime-ice/cn_dicts/".concat(dictName, ".dict.yaml"), "utf8");
    var newLines = [];
    try {
        for (var _b = __values(lines.split("\n")), _c = _b.next(); !_c.done; _c = _b.next()) {
            var line = _c.value;
            if (line == "name: ".concat(dictName)) {
                newLines.push("name: ".concat(newName));
                if (dictName === "8105") {
                    newLines.push("import_tables:");
                    newLines.push("  - sbpy.unihan");
                }
                if (dictName === "tencent") {
                    newLines.push("import_tables:");
                    newLines.push("  - sbpy");
                }
                continue;
            }
            else if (line.startsWith("#") || !line.includes("\t")) {
                newLines.push(line);
                continue;
            }
            var newLine = processLine(line);
            if (newLine) {
                newLines.push(newLine);
            }
        }
    }
    catch (e_3_1) { e_3 = { error: e_3_1 }; }
    finally {
        try {
            if (_c && !_c.done && (_a = _b.return)) _a.call(_b);
        }
        finally { if (e_3) throw e_3.error; }
    }
    (0, fs_1.writeFileSync)("sbxlm/".concat(newName, ".dict.yaml"), newLines.join("\n"));
}
processDict("8105", "sbpy");
processDict("41448", "sbpy.unihan");
processDict("base", "sbpy.base");
processDict("ext", "sbpy.ext");
