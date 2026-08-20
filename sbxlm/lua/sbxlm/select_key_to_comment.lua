local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  local pattern = env.engine.schema.config:get_string("menu/select_comment_pattern") or ""
  local input = rime.current(env.engine.context) or ""
  -- 修正续行语法（运算符在行尾）
  return (segment:has_tag("abc") and rime.match(input, pattern)) or
      segment:has_tag("punct") or segment:has_tag("sbyp") or segment:has_tag("emoji") or
      (input:len() >= 2 and segment:has_tag("bihua")) or segment:has_tag("zhlf") or
      segment:has_tag("sbzdy") or segment:has_tag("lua")
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local schema_id = env.engine.schema.schema_id
  local input = rime.current(env.engine.context) or ""
  local select_keys = env.engine.schema.select_keys or ""
  local segment = env.engine.context.composition:back()
  -- 特殊场景下强制选择键为_23789或_aeuio（与selector.lua一致）
  if (segment:has_tag("sbyp") or (input:len() >= 2 and segment:has_tag("bihua")) or
      segment:has_tag("zhlf") or segment:has_tag("sbzdy") or
      segment:has_tag("emoji")) then
    select_keys = "_23789"
  elseif segment:has_tag("lua") then
    select_keys = "_aeuio"
  end
  local i = 0
  for candidate in translation:iter() do
    -- 基于当前i获取选择键（现在🏠🏡会经过这里，i会正常递增！）
    local j = i % select_keys:len() + 1
    local key = select_keys:sub(j, j)
    if key == "_" then
      goto continue
    end

    if core.xmft(schema_id) then
      goto continue2
    end
    -- 单次选重非全码补全
    if candidate.type == "completion" and core.zici(schema_id) and
        segment:has_tag("abc") and not segment:has_tag("bihua") then
      if (input:len() < 7) and (core.fx(schema_id) or core.fj(schema_id)) then
        goto continue
      elseif (input:len() < 6) and not segment:has_tag("sbjm") then
        goto continue
      end
    end
    if (core.fm(schema_id) or core.fy(schema_id)) and segment:has_tag("abc") and env.engine.context:get_option("delayed_pop") and
        rime.match(env.engine.context.input, "([bpmfdtnlgkhjqxzcsrywv][a-z]){2}") then
      key = key:upper()
    end
    ::continue2::
    -- 对于_23789/_aeuio的特殊场景：无条件覆盖comment（因为此时es_conversion产出的emoji会带空comment进入本过滤器）
    if select_keys == "_23789" or select_keys == "_aeuio" then
      candidate.comment = key
      goto continue
    end
    -- 普通场景：保留原有comment并追加选择键
    if candidate.comment:len() > 0 then
      if (core.py(schema_id) or core.jp(schema_id) or core.yp(schema_id)) and segment:has_tag("abc") and
          rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?") then
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
