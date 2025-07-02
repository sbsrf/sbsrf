-- 拼音反查过滤器，适用于声笔的所有整句型方案
-- 针对单字，使用strokes.txt中的汉字笔画编码补齐至6位

local rime = require "lib"
local this = {}

---@class StrokesEnv: Env
---@field strokes table<string, string>

---@param env StrokesEnv
function this.init(env)
  env.strokes = {}
  local dir = rime.api.get_user_data_dir() .. "/lua/sbxlm/"
  local file = io.open(dir .. "strokes.txt", "r")
  if not file then return end
  for line in file:lines() do
    ---@type string, string
    local character, content = line:match("([^\t]+)\t([^\t]+)")
    if not content or not character then
      goto continue
    end
    env.strokes[character] = content
    ::continue::
  end
  file:close()
end

---@param translation Translation
---@param env StrokesEnv
function this.func(translation, env)
  local context = env.engine.context
  local id = env.engine.schema.schema_id
  local len = 3
  if id == "sbpy" then
    len = 1
  elseif id == "sbzz" or id == "sbhz" then
    len = 2
  end
  ---@type Candidate
  for candidate in translation:iter() do
    if utf8.len(candidate.text) ~= 1 then
        yield(candidate)
    else
        local strokes = env.strokes[candidate.text]
        strokes = strokes == nil and "" or strokes:sub(1, len)
        candidate.comment = candidate.comment:gsub("(%S+)","%1" .. strokes)
        yield(candidate)
    end
  end
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return segment:has_tag("sbyp") or segment:has_tag("bihua") or segment:has_tag("zhlf")
end

return this