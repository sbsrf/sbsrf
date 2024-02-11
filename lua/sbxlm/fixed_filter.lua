-- 固顶过滤器
-- 适用于：声笔拼音
-- 本过滤器读取用户自定义的固顶短语，将其与当前翻译结果进行匹配，如果匹配成功，则将特定字词固顶到特定位置
-- 仅在模式为固顶、混顶、纯顶时才执行

local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
  ---@type { string : string[] }
  this.fixed = {}
  local path = rime.api.get_user_data_dir() .. "/sbpy.fixed.txt"
  local file = io.open(path, "r")
  if not file then
    return
  end
  for line in file:lines() do
    local phrase, code = line:match("([^\t]+)\t([^\t]+)")
    if not phrase or not code then
      goto continue
    end
    if not this.fixed[code] then
      this.fixed[code] = {}
    end
    table.insert(this.fixed[code], phrase)
    ::continue::
  end
  file:close()
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return segment:has_tag("abc") and segment.length <= 3
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local context = env.engine.context
  local has_fixed = context:get_option("fixed") or context:get_option("mixed") or context:get_option("popping")
  -- 取出输入中当前正在翻译的一部分
  local segment = context.composition:toSegmentation():back()
  if not segment then
    return rime.process_results.kNoop
  end
  local input = string.sub(context.input, segment.start + 1, segment._end)
  local fixed_phrases = this.fixed[input]
  if has_fixed and core.sss(input) then
    local ss = this.fixed[input:sub(1, 2)][1]
    local s = this.fixed[input:sub(3, 3)][1]
    if ss and s then
      local candidate = rime.Candidate("combination", segment.start, segment._end, ss .. s, "")
      candidate.preedit = input:sub(1, 1) .. ' ' .. input:sub(2, 2) .. ' ' .. input:sub(3, 3)
      rime.yield(candidate)
    end
  end
  if not fixed_phrases or not has_fixed then
    for candidate in translation:iter() do
      rime.yield(candidate)
    end
    return
  end
  -- 生成固顶候选
  ---@type Candidate[]
  local unknown_candidates = {}
  ---@type { string: Candidate }
  local known_candidates = {}
  local i = 1
  for candidate in translation:iter() do
    local text = candidate.text
    local is_fixed = false
    for _, phrase in ipairs(fixed_phrases) do
      if text == phrase then
        known_candidates[phrase] = candidate
        is_fixed = true
        break
      end
    end
    if not is_fixed then
      table.insert(unknown_candidates, candidate)
    end
    local current = fixed_phrases[i]
    if current and known_candidates[current] then
      rime.yield(known_candidates[current])
      i = i + 1
    end
  end
  for _, candidate in ipairs(unknown_candidates) do
    rime.yield(candidate)
  end
end

return this
