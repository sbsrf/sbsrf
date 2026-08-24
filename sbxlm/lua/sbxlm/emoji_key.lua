local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---加载es.txt字典（OpenCC格式），返回text→emoji列表的映射
---@param env Env
---@return table<string, string[]>
local function load_emoji_dict(env)
  local dict = {}
  local path = rime.api.get_user_data_dir() .. "/opencc/es.txt"
  local f = io.open(path, "r")
  if not f then
    return dict
  end
  for line in f:lines() do
    local pos = line:find("\t")
    if pos then
      local key = line:sub(1, pos - 1)
      local rest = line:sub(pos + 1)
      local list = {}
      for s in rest:gmatch("[^%s]+") do
        table.insert(list, s)
      end
      if #list > 0 then
        dict[key] = list
      end
    end
  end
  f:close()
  return dict
end

---@param env Env
function this.init(env)
  env.emoji_dict = load_emoji_dict(env)
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  local pattern = env.engine.schema.config:get_string("menu/select_comment_pattern") or ""
  local input = rime.current(env.engine.context) or ""
  return (segment:has_tag("abc") and rime.match(input, pattern)) or
      segment:has_tag("punct") or segment:has_tag("sbyp") or segment:has_tag("emoji") or
      (input:len() >= 2 and segment:has_tag("bihua")) or segment:has_tag("zhlf") or
      segment:has_tag("sbzdy") or segment:has_tag("lua")
end

---辅助函数：基于候选和全局索引i，计算并设置comment
---特殊场景（_23789/_aeuio）优先判断并直接赋值，避免被其他条件提前return
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

  local is_emoji_mode = false
  local pattern = env.engine.schema.config:get_string("menu/select_comment_pattern") or ""
  if (segment:has_tag("sbyp") or (input:len() >= 2 and segment:has_tag("bihua")) or
      segment:has_tag("zhlf") or segment:has_tag("sbzdy") or
      segment:has_tag("emoji")) then
    select_keys = "_23789"
    is_emoji_mode = segment:has_tag("emoji")
  elseif segment:has_tag("lua") then
    select_keys = "_aeuio"
  elseif segment:has_tag("abc") and rime.match(input, pattern) then
    select_keys = "_23789"
  end

  local show_emoji = false
  if is_emoji_mode then
    show_emoji = env.engine.context:get_option("show_es")
    if show_emoji == nil then show_emoji = true end
  end

  local emoji_dict = env.emoji_dict or {}
  local i = 0
  for candidate in translation:iter() do
    assign_comment(candidate, i, select_keys, schema_id, segment, input, env)
    rime.yield(candidate)
    i = i + 1

    if show_emoji and emoji_dict and emoji_dict[candidate.text] then
      for _, emoji_text in ipairs(emoji_dict[candidate.text]) do
        if emoji_text ~= candidate.text then
          local emoji_cand = rime.Candidate(
            candidate.type,
            candidate.start,
            candidate._end,
            emoji_text,
            ""
          )
          if candidate.preedit then
            emoji_cand.preedit = candidate.preedit
          end
          assign_comment(emoji_cand, i, select_keys, schema_id, segment, input, env)
          rime.yield(emoji_cand)
          i = i + 1
        end
      end
    end
  end
end

---@param env Env
function this.fini(env)
  env.emoji_dict = nil
end

return this
