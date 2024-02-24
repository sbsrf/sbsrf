-- 后置过滤器
-- 适用于：声笔拼音
-- 本过滤器记录码长较短时已出现在首选的字词，当码长较长时将这些字词后置，以便提高编码的利用效率

local rime = require "lib"

local this = {}

---@class PostponeEnv: Env
---@field known_candidates { string : number }

---@param env PostponeEnv
function this.init(env)
  env.known_candidates = {}
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return env.engine.context:get_option("postpone")
end

---@param translation Translation
---@param env PostponeEnv
function this.func(translation, env)
  local context = env.engine.context
  -- 取出输入中当前正在翻译的一部分
  local input = rime.current(context)
  if not input then
    return
  end
  -- 生成固顶候选
  ---@type Candidate[]
  local postponed_candidates = {}
  local is_first = true
  for candidate in translation:iter() do
    local text = candidate.text
    if (env.known_candidates[text] or inf) < input:len() then
      table.insert(postponed_candidates, candidate)
    else
      if is_first then
        env.known_candidates[text] = input:len()
        is_first = false
      end
      rime.yield(candidate)
    end
  end
  for _, candidate in ipairs(postponed_candidates) do
    rime.yield(candidate)
  end
end

return this
