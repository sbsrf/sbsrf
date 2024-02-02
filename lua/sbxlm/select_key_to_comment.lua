-- 选择键转注释过滤器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本过滤器将 alternative_select_keys 中定义的选择键添加到候选项的注释中显示
-- Version: 20240125
-- Author: 戴石麟

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.select_keys = env.engine.schema.select_keys
end

---@param translation Translation
function this.default(translation)
  for candidate in translation:iter() do
    rime.yield(candidate)
  end
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  -- 第一种情况：当前段落是常规编码，且编码长度大于等于 4
  -- 第二种情况：当前段落是标点
  return (segment:has_tag("abc") and segment.length >= 4) or segment:has_tag("punct")
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local i = 0
  for candidate in translation:iter() do
    -- 通过取模运算获取与候选项对应的选择键
    local j = i % string.len(this.select_keys) + 1
    local key = string.sub(this.select_keys, j, j)
    -- 如果是下划线，说明是首选，无需操作
    if key == "_" then
      goto continue
    end
    if string.len(candidate.comment) > 0 then
      candidate.comment = candidate.comment .. ":" .. key
    else
      candidate.comment = key
    end
    ::continue::
    i = i + 1
    rime.yield(candidate)
  end
end

return this
