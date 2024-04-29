-- 选择键转注释过滤器
-- 本过滤器将 alternative_select_keys 中定义的选择键添加到候选项的注释中显示
-- Version: 20240125
-- Author: 戴石麟

local rime = require "sbxlm.lib"

local this = {}

---@param env Env
function this.init(env)
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  -- 当前段落需要为标点或为正常输入码且匹配选择注释模式
  local pattern = env.engine.schema.config:get_string("menu/select_comment_pattern") or ""
  local input = rime.current(env.engine.context) or ""
  return (segment:has_tag("abc") and rime.match(input, pattern))
      or segment:has_tag("punct")
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local id = env.engine.schema.schema_id
  local select_keys = env.engine.schema.select_keys or ""
  local i = 0
  for candidate in translation:iter() do
    -- 通过取模运算获取与候选项对应的选择键
    local j = i % select_keys:len() + 1
    local key = select_keys:sub(j, j)
    -- 如果是下划线，说明是首选，无需操作
    if key == "_" then
      goto continue
    end
    if candidate.comment:len() > 0 then
      if id == "sbpy" or id == "sbjp" then
        candidate.comment = key .. candidate.comment
      else
        candidate.comment = candidate.comment .. ":" .. key
      end
    else
      candidate.comment = key
    end
    ::continue::
    i = i + 1
    rime.yield(candidate)
  end
end

return this
