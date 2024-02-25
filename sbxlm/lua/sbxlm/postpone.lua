-- 后置过滤器
-- 适用于：声笔拼音
-- 本过滤器记录码长较短时已出现在首选的字词，当码长较长时将这些字词后置，以便提高编码的利用效率

local rime = require "lib"

local this = {}

---@class PostponeEnv: Env
---@field known_candidates table<string, number>

---@param env PostponeEnv
function this.init(env)
  env.known_candidates = {}
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  local context = env.engine.context
  -- 在回补时不刷新
  if context.caret_pos ~= context.input:len() then
    return false
  end
  return context:get_option("postpone")
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
  -- 删除与当前编码长度相等或者更长的已知候选，这些对当前输入无帮助
  for k, v in pairs(env.known_candidates) do
    if v >= input:len() then
      env.known_candidates[k] = nil
    end
  end
  -- 设当前编码长度为 n，则：
  -- 过滤开始前，known_candidates 包含 n-1 项，分别是 1 ~ n-1 长度时对应的首选
  -- 过滤结束后，known_candidates 包含 n 项，分别是 1 ~ n 长度时对应的首选

  -- 用于存放需要后置的候选
  ---@type Candidate[]
  local postponed_candidates = {}
  local is_first = true
  local length_of_first_candidate = 0
  for candidate in translation:iter() do
    local text = candidate.text
    if length_of_first_candidate == 0 then
      length_of_first_candidate = utf8.len(text) or 0
    end
    -- 如果当前候选词的长度已经小于首选了，那么把之前后置过的候选词重新输出
    -- 例如，输入码为两个音节的时候，先输出正常的二字词，然后再输出之前后置的二字词，最后才是单字
    -- 这样可以保证字数较长的词一定排在前面
    -- 做完这件事情之后，剩下的候选词可以直接输出，不用考虑后置
    if utf8.len(text) < length_of_first_candidate then
      if #postponed_candidates > 0 then
        for _, p_candidate in ipairs(postponed_candidates) do
          rime.yield(p_candidate)
        end
        postponed_candidates = {}
      end
      rime.yield(candidate)
      goto continue
    end
    -- 如果这个候选词已经在首选中出现过，那么后置
    if (env.known_candidates[text] or inf) < input:len() then
      table.insert(postponed_candidates, candidate)
    -- 否则直接输出
    else
      -- 记录首选
      if is_first then
        env.known_candidates[text] = input:len()
        is_first = false
      end
      rime.yield(candidate)
    end
    ::continue::
  end
  -- 如果之前没有重新输出后置过的候选词，那么现在输出
  for _, candidate in ipairs(postponed_candidates) do
    rime.yield(candidate)
  end
end

return this
