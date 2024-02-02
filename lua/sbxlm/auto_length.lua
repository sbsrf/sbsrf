-- 自动码长翻译器
-- 适用于：声笔简码、声笔飞码、声笔飞单、声笔飞讯、声笔小鹤、声笔自然

local rime           = require "rime"
local yield          = rime.yield
local core           = require "sbxlm.core"

local this           = {}
local kEncodedPrefix = "\x7fenc\x1f"
local kTopSymbol     = " \xe2\x98\x86 "
local kUnitySymbol   = " \xe2\x98\xaf "

---对词组中的每一个字枚举所有可能的构词码，然后排列组合造词
---在 librime 中，这个函数已经被 TableEncoder 实现，但是 lua 无法调用，所以不得不重写一遍
---未来可能有更优雅的实现方式
---@param phrase string 待造词的短语
---@param position number 下一个需要编码枚举的位置
---@param code string[] 已经完成编码枚举的编码
function this.dfs_encode(phrase, position, code)
  -- 如果已经枚举完所有字，就尝试造词
  -- word_rules 可能会失败，如果失败就返回 false
  if position > utf8.len(phrase) then
    local encoded = core.word_rules(code, this.id)
    if encoded then
      rime.errorf("encode: %s %s, stems: %s", phrase, encoded, table.concat(code, " "))
      local entry = rime.DictEntry()
      entry.text = phrase
      entry.custom_code = encoded .. " "
      this.memory:update_userdict(entry, 0, kEncodedPrefix)
      return true
    else
      return false
    end
  end
  -- 把 UTF-8 编码的词语拆成单个字符的列表
  local characters = {}
  for _, char in utf8.codes(phrase) do
    table.insert(characters, utf8.char(char))
  end
  -- 对于飞系方案，构词用的编码不一定出现在单字全面中，所以需要单独的构词码
  -- 对于其他方案，调用单字全码即可，可以减少词库的大小
  local translations = this.reverse:lookup_stems(characters[position])
  if translations == "" then
    translations = this.reverse:lookup(characters[position])
  end
  local success = false
  -- 对所有可能的构词码，逐个入栈，然后递归调用，从而实现各字的构词码之间的排列组合
  for t in string.gmatch(translations, "[^ ]+") do
    -- 如果之前调用的是 reverse:lookup，那么除了单字全码之外，也可能查询到简码
    -- 这里要把它们过滤掉
    if string.len(t) < 4 then
      goto continue
    end
    table.insert(code, t)
    local ok = this.dfs_encode(phrase, position + 1, code)
    success = success or ok
    table.remove(code)
    ::continue::
  end
  return success
end

---由本翻译器生成的候选上屏时的回调函数
---需要完成两个任务：1. 记忆刚上屏的字词 2. 对上屏历史造词
---@param commit CommitEntry
---@param context Context
function this.callback(commit, context)
  if this.stop_change then
    return
  end
  -- 记忆刚上屏的字词
  for _, entry in ipairs(commit:get())
  do
    if this.static(entry.preedit) then
      goto continue
    end
    rime.errorf("memorize: %s %s", entry.text, entry.preedit)
    -- 如果这个词之前标记为临时词，就消除这个标记，正式进入词库
    if string.find(entry.custom_code, kEncodedPrefix) then
      local new_entry = rime.DictEntry()
      new_entry.text = entry.text
      new_entry.custom_code = string.sub(entry.custom_code, string.len(kEncodedPrefix) + 1)
      this.memory:update_userdict(new_entry, 1, "")
    else
      this.memory:update_userdict(entry, 1, "")
    end
    ::continue::
  end
  if not this.enable_encoder then
    return
  end
  -- 对上屏历史造词
  local phrase = ""
  -- 允许包含的上屏字词类型
  local valid_types = rime.Set({ "table", "user_table", "sentence", "simplified", "uniquified", "raw", "completion" })
  local index = 0
  for _, record in context.commit_history:iter() do
    -- 如果最后一次上屏是标点顶屏，跳过标点查看前面的部分
    if index == 0 and record.type == "punct" then
      goto continue
    end
    index = index + 1
    -- 如果是其他类型，打断造词
    if not valid_types[record.type] then
      break
    end
    -- librime 的 bug：顶字上屏会产生一个空的 raw 记录，这里要跳过
    if record.type == "raw" then
      if record.text == "" then
        goto continue
      else
        break
      end
    end
    -- 对最末一个上屏的候选，跳过造词，直接看下一个
    if string.len(phrase) == 0 then
      phrase = record.text
      goto continue
    end
    phrase = record.text .. phrase
    -- 如果造词的长度超过了最大长度，就不再造词
    -- 普通模式下，最大长度是 translator/max_phrase_length
    -- 缓冲模式下，最大长度是 12
    if this.is_buffered and utf8.len(phrase) > 12 then
      break
    elseif not this.is_buffered and utf8.len(phrase) > this.max_phrase_length then
      break
    end
    ---@type string[]
    local code = {}
    this.dfs_encode(phrase, 1, code)
    ::continue::
  end
end

---@param env Env
function this.init(env)
  this.memory = rime.Memory(env.engine, env.engine.schema)
  this.id = env.engine.schema.schema_id
  local dict_name = this.id == "sbfd" and "sbfm" or this.id
  local config = env.engine.schema.config
  this.reverse = rime.ReverseLookup(dict_name)
  this.third_pop = false
  this.enable_filtering = config:get_bool("translator/enable_filtering") or false
  this.lower_case = config:get_bool("translator/lower_case") or false
  this.stop_change = config:get_bool("translator/stop_change") or false
  this.enable_encoder = config:get_bool("translator/enable_encoder") or true
  this.delete_threshold = config:get_int("translator/delete_threshold") or 1000
  this.max_phrase_length = config:get_int("translator/max_phrase_length") or 4
  this.static_patterns = rime.get_string_list(config, "translator/disable_user_dict_for_patterns");
  this.memory:memorize(function(commit) this.callback(commit, env.engine.context) end)
  ---@type { string: number }
  this.known_candidates = {}
  this.is_buffered = env.engine.context:get_option("is_buffered")
end

---判断输入的编码是否为静态编码
---@param input string
function this.static(input)
  for _, pattern in ipairs(this.static_patterns) do
    if rime.match(input, pattern) then
      return true
    end
  end
  return false
end

---涉及到自动码长翻译时，指定对特定类型的输入应该用何种策略翻译
---@enum DynamicCodeType
local dtypes = {
  --- 不适用于自动码长翻译
  invalid = -1,
  --- 该编码是自动码长的起始调整位，返回一个权重最高的候选
  short = 0,
  --- 该编码是基本编码的全码
  base = 1,
  --- 该编码是在基本编码的基础上加上了一个选重键
  select = 2,
  --- 该编码是扩展编码的全码
  full = 3,
}

---判断输入的编码是否为动态编码
---如果是，返回应用自动码长翻译的策略
---@param input string
---@return DynamicCodeType
function this.dynamic(input)
  -- 对于除了飞讯之外的方案来说，基本编码的长度是 4，扩展编码是 6，在 5 码时选重，此外简码还有一个 3 码时的码长调整位
  -- 因此，将编码的长度减去 3 就分别对应了上述的 short, base, select, full 四种情况
  if core.jm(this.id) or core.fm(this.id) or core.fd(this.id) or core.sp(this.id) then
    return string.len(input) - 3
  end
  -- 对于飞讯来说，一般情况下基本编码的长度是 5，扩展编码是 7，在 6 码时选重
  -- 因此，将编码的长度减去 4 就分别对应了上述的 short, base, select, full 四种情况
  -- 但是，如果以 sssS 格式输入多字词，那么基本编码的长度是 4，扩展编码是 6，在 5 码时选重
  -- 另外，如果开启快顶模式，则有一个 3 码时的码长调整位
  -- 以下综合考虑了这些情况
  if core.fx(this.id) then
    if rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{4}.*") then
      return string.len(input) - 3
    end
    if string.len(input) == 4 and not rime.match(input, ".{3}[23789]") then
      return dtypes.invalid
    end
    return string.len(input) - 4
  end
  return dtypes.invalid
end

-- 飞讯在快顶模式下的换码操作
local fx_exchange = {
  ["2"] = "a",
  ["3"] = "e",
  ["7"] = "u",
  ["8"] = "i",
  ["9"] = "o"
}

---在进行自动码长检索的时候，统一以输入的前三码来模糊匹配固态词典和用户词典中的编码
---然后再比对检索得到的结果和具体的输入内容来进行精确匹配
---如果匹配成功，返回一个 Phrase 对象，否则返回 nil
---@param entry DictEntry
---@param segment Segment
---@param type string
---@param input string
---@return Phrase | nil
function this.validate_phrase(entry, segment, type, input)
  -- 一开始，entry.comment 中放置了 "~xxx" 形式的编码补全内容
  -- 对其取子串，得到真正的编码补全内容
  local completion = string.sub(entry.comment, 2)
  local alt_completion = ""
  local to_match = ""
  if entry.comment == "" then
    goto valid
  end
  -- 声笔简码和声笔飞讯的多字词有两种输入方式
  -- 在存储时，简码以 sssbbbs 的格式存储，飞讯以 sssbbbbs 的格式存储
  -- 如果识别到这种编码，需要把它们重排一下，得到另一种编码，即以 ssss 开头的编码，然后再进行匹配
  if rime.match(completion, "[aeiou]{3,4}[bpmfdtnlgkhjqxzcsrywv]") then
    alt_completion = string.sub(completion, -1, -1) .. string.sub(completion, -3, -2)
    -- 如果简码没启用 lower_case，就消除掉原来的编码，相当于禁用 sssbbb 这种打法
    if core.jm(this.id) and (not this.lower_case or not this.third_pop) then
      completion = ""
    end
  end
  if string.len(input) == 3 then
    if core.jm(this.id) and this.enable_filtering and utf8.len(entry.text) > 3 then
      return nil
    end
    goto valid
    -- 如果当前的策略是 select，那么最后一码并不代表有效的编码，而是选择键，可以忽略
  elseif this.dynamic(input) == dtypes.select then
    to_match = string.sub(input, 4, -2)
    -- 如果当前的策略是 base, full 或者 short，那么从 4 码开始的部分都要匹配
  else
    to_match = string.sub(input, 4)
  end
  -- 如果第 4 码是 23789，那么需要把它换成 aeiou
  if fx_exchange[string.sub(to_match, 1, 1)] then
    to_match = fx_exchange[string.sub(to_match, 1, 1)] .. string.sub(to_match, 2)
  end
  -- 如果 completion 和 alt_completion 有一个匹配上了，就认为这是一个有效的候选
  if string.sub(completion, 1, string.len(to_match)) == to_match then
    goto valid
  elseif string.sub(alt_completion, 1, string.len(to_match)) == to_match then
    goto valid
  else
    return nil
  end
  ::valid::
  -- 创建一个新的候选，并且把 preedit 设置成输入的内容
  local phrase = rime.Phrase(this.memory, type, segment.start, segment._end, entry)
  phrase.preedit = input
  -- 如果这个候选来自用户词典，根据不同的情况加上不同的标记
  if string.find(entry.custom_code, kEncodedPrefix) then
    phrase.comment = kUnitySymbol
  elseif string.len(entry.custom_code) > 0 and string.len(entry.custom_code) < 6 then
    phrase.comment = kTopSymbol
  else
    phrase.comment = ""
  end
  return phrase
end

---@param input string
---@param segment Segment
function this.translate_by_split(input, segment)
  local memory = this.memory
  memory:dict_lookup(string.sub(input, 1, 2), false, 1)
  local text = ""
  for entry in memory:iter_dict() do
    text = text .. entry.text
    break
  end
  memory:dict_lookup(string.sub(input, 3), false, 1)
  for entry in memory:iter_dict() do
    text = text .. entry.text
    break
  end
  local candidate = rime.Candidate("combination", segment.start, segment._end, text, "")
  candidate.preedit = input
  yield(candidate)
end

---@param input string
---@param segment Segment
---@param env Env
function this.func(input, segment, env)
  this.is_buffered = env.engine.context:get_option("is_buffered")
  this.third_pop = env.engine.context:get_option("third_pop")
  local memory = this.memory
  -- 如果当前编码是静态编码，就只进行精确匹配，并依原样返回结果
  if this.static(input) then
    -- 清空候选缓存
    this.known_candidates = {}
    memory:dict_lookup(input, false, 0)
    for entry in memory:iter_dict() do
      local phrase = rime.Phrase(memory, "table", segment.start, segment._end, entry)
      phrase.preedit = input
      rime.yield(phrase:toCandidate())
    end
    return
  end
  -- 在一些情况下，需要把三码或者四码的编码拆分成两段分别翻译，这也算是一种静态编码
  -- 1. 编码为 sxs 格式时，只要不是简码的三顶模式，就要拆分成二简字 + 一简字翻译
  -- 2. 飞系方案，编码为 sbsb 格式时，拆分成声笔字 + 声笔字翻译
  -- 3. 飞讯，编码为 sxsb 格式时，拆分成二简字 + 声笔字翻译
  if (core.sxs(input) and not this.third_pop)
      or (core.feixi(this.id) and core.sbsb(input))
      or (core.fx(this.id) and core.sxsb(input)) then
    this.translate_by_split(input, segment)
    return
  end
  -- 静态编码都处理完了，现在进入自动码长的动态编码部分
  -- 首先，根据输入的前三码来模糊匹配，依次查询固态词典和用户词典，并且结果都存放到一个列表中
  local lookup_code = string.sub(input, 0, 3)
  ---@type Phrase[]
  local phrases = {}
  memory:user_lookup(lookup_code, true)
  for entry in memory:iter_user() do
    local phrase = this.validate_phrase(entry, segment, "user_table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  memory:dict_lookup(lookup_code, true, 0)
  for entry in memory:iter_dict() do
    local phrase = this.validate_phrase(entry, segment, "table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  -- 对列表根据置顶与否以及频率进行排序
  table.sort(phrases, function(a, b)
    if a.comment == kTopSymbol and b.comment ~= kTopSymbol then
      return true
    end
    if a.comment ~= kTopSymbol and b.comment == kTopSymbol then
      return false
    end
    return a.weight > b.weight
  end)
  -- 在列表的末尾加上未确认的用户自造词
  memory:user_lookup(kEncodedPrefix .. lookup_code, true)
  for entry in memory:iter_user() do
    local phrase = this.validate_phrase(entry, segment, "user_table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  -- 如果动态编码没有检索到结果，对于双拼方案来说，可以尝试拆分编码给出一个候选
  if #phrases == 0 then
    if core.sp(this.id) and rime.match(input, "[a-z]{4}") then
      this.translate_by_split(input, segment)
    end
    return
  end
  -- 以下分 4 种情况实现自动码长的翻译策略
  -- 1. 如果输入的编码是一个动态编码的起始调整位，那么返回一个权重最高的候选
  -- 2. 如果输入的编码是基本编码的全码，那么返回所有的候选
  -- 3. 如果输入的编码是在基本编码的基础上加上了一个选重键，那么返回一个特定的候选
  -- 4. 如果输入的编码是扩展编码的全码，那么返回所有的候选
  -- 在情况 1 和 2 下，还要把已经见到的候选放到缓存中，以便在更长码时不重复出现这个候选
  -- 例如，对于声笔简码来说，3 码出现过的字词就不会再出现在 4 码的候选中，4 码出现过的字词就不会再出现在 6 码的候选中
  if this.dynamic(input) == dtypes.short then
    local cand = phrases[1]:toCandidate()
    this.known_candidates[cand.text] = 0
    yield(cand)
  elseif this.dynamic(input) == dtypes.base then
    local count = 1
    for _, phrase in ipairs(phrases) do
      local cand = phrase:toCandidate()
      if (this.known_candidates[cand.text] or inf) < count then
        goto continue
      end
      if count <= 6 then
        this.known_candidates[cand.text] = count
      end
      yield(cand)
      count = count + 1
      ::continue::
    end
  elseif this.dynamic(input) == dtypes.select then
    local last = string.sub(input, -1)
    local order = string.find(env.engine.schema.select_keys, last)
    for _, phrase in ipairs(phrases) do
      local cand = phrase:toCandidate()
      if this.known_candidates[cand.text] == order then
        yield(cand)
        break
      end
    end
  elseif this.dynamic(input) == dtypes.full then
    for _, phrase in ipairs(phrases) do
      local cand = phrase:toCandidate()
      if this.known_candidates[cand.text] then
        goto continue
      end
      yield(cand)
      ::continue::
    end
  end
end

return this
