local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  -- 非 emoji 场景的选择键注释；emoji 模式由 emoji_key.lua 处理
  local pattern = env.engine.schema.config:get_string("menu/select_comment_pattern") or ""
  local input = rime.current(env.engine.context) or ""
  return (segment:has_tag("abc") and rime.match(input, pattern)) or
      segment:has_tag("punct") or segment:has_tag("sbyp") or
      (input:len() >= 2 and segment:has_tag("bihua")) or segment:has_tag("zhlf") or
      segment:has_tag("sbzdy") or segment:has_tag("lua")
end

---基于候选和全局索引i，计算并设置comment（与 emoji_key.lua 行为一致）
---@param candidate table
---@param i number
---@param select_keys string
---@param schema_id string
---@param segment table
---@param input string
---@param env Env
local function assign_comment(candidate, i, select_keys, schema_id, segment, input, env)
  local len = select_keys:len()
  local j = i % len + 1
  local key = select_keys:sub(j, j)
  if not core.xmft(schema_id) and candidate.type == "completion" and core.zici(schema_id) and
      segment:has_tag("abc") and not segment:has_tag("bihua") then
    if (input:len() < 7) and (core.fx(schema_id) or core.fj(schema_id)) then
      return
    elseif (input:len() < 6) and not segment:has_tag("sbjm") then
      return
    end
  end
  if (core.fm(schema_id) or core.fy(schema_id)) and segment:has_tag("abc") and env.engine.context:get_option("delayed_pop") and
      rime.match(env.engine.context.input, "([bpmfdtnlgkhjqxzcsrywv][a-z]){2}") then
    key = key:upper()
  end
  if key == "_" then
    if not candidate.comment then candidate.comment = "" end
    return
  end
  if candidate.comment and candidate.comment:len() > 0 then
    if (core.py(schema_id) or core.jp(schema_id) or core.yp(schema_id)) and segment:has_tag("abc") and
        rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?") then
      candidate.comment = key .. candidate.comment
    else
      candidate.comment = candidate.comment .. ":" .. key
    end
  else
    candidate.comment = key
  end
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local schema_id = env.engine.schema.schema_id
  local input = rime.current(env.engine.context) or ""
  local select_keys = env.engine.schema.select_keys or ""
  local segment = env.engine.context.composition:back()

  -- 特殊场景下强制选择键为_23789或_aeuio（与selector.lua一致；emoji由emoji_key.lua处理）
  if (segment:has_tag("sbyp") or (input:len() >= 2 and segment:has_tag("bihua")) or
      segment:has_tag("zhlf") or segment:has_tag("sbzdy")) then
    select_keys = "_23789"
  elseif segment:has_tag("lua") then
    select_keys = "_aeuio"
  elseif segment:has_tag("punct") and core.zici(schema_id) then
    select_keys = "_aeuio"
  end

  local i = 0
  for candidate in translation:iter() do
    assign_comment(candidate, i, select_keys, schema_id, segment, input, env)
    rime.yield(candidate)
    i = i + 1
  end
end

return this
