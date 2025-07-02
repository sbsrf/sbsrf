-- 笔画过滤器，适用于声笔的所有整句型方案
-- 超过基本编码后，使用strokes.txt中的汉字笔画编码快速过滤重码

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

---@param text string
---@param stroke_input string
---@param env StrokesEnv
local function handle_candidate(text, stroke_input, env)
  local len = stroke_input:len()
  if  len == 0 then return true end
  local offset = 0
  local char1 = ""
  if utf8.len(text) == 1 then
    char1 = text
  else
    offset = utf8.offset(text, 2)
    char1 = text:sub(1, offset - 1)
  end
  local strokes = env.strokes[char1]
  if stroke_input == strokes:sub(1, len) then
    return true
  end
  return false
end

---@param translation Translation
---@param env StrokesEnv
function this.func(translation, env)
  local context = env.engine.context
  local id = env.engine.schema.schema_id
  local stroke_input = context:get_property("stroke_input")
  local len = 3
  if id == "sbpy" then
    len = 5
  elseif id == "sbzz" or id == "sbhz" then
    len = 4
  end
  ---@type Candidate
  for candidate in translation:iter() do
    if handle_candidate(candidate.text, stroke_input, env) then
      candidate.preedit = candidate.preedit:sub(1,len) .. stroke_input ..candidate.preedit:sub(len + 1)
      yield(candidate)
    end
  end
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return segment:has_tag("abc")
end

return this