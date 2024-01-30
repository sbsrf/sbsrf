-- 顶功处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器能够支持所有的规则顶功模式
-- 根据当前编码和新输入的按键来决定是否将当前编码或其一部分的首选顶上屏

local rime = require("rime")

local this = {}

---@class PoppingConfig
---@field when string | nil
---@field when_not string | nil
---@field match string
---@field accept string
---@field prefix number | nil

---@param env Env
function this.init(env)
  local config = env.engine.schema.config
  local popping_config = config:get_list("speller/popping")
  if not popping_config then
    return
  end
  ---@type PoppingConfig[]
  this.popping = {}
  for i = 1, popping_config.size do
    local item = popping_config:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local popping = {
      when = value:get_value("when") and value:get_value("when"):get_string(),
      when_not = value:get_value("when_not") and value:get_value("when_not"):get_string(),
      match = value:get_value("match"):get_string(),
      accept = value:get_value("accept"):get_string(),
      prefix = value:get_value("prefix") and value:get_value("prefix"):get_int(),
    }
    table.insert(this.popping, popping)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
  if key_event:release() or key_event:shift() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return rime.process_results.kNoop
  end
  -- 取出输入中当前活跃的一部分
  local confirmed_position = context.composition:toSegmentation():get_confirmed_position()
  local input = string.sub(context.input, confirmed_position + 1)
  if string.len(input) == 0 then
    return rime.process_results.kNoop
  end
  -- Rime 有一个非常奇怪的 bug，在按句号键之后的那个字词的编码的会有一个隐藏的 "."
  -- 这导致顶功判断失败，所以先屏蔽了。但是这个对用 "." 作为编码的方案会有影响
  if rime.match(input, ".+\\.") then
    context:pop_input(1)
    input = string.sub(context.input, confirmed_position + 1)
  end
  local incoming = key_event:repr()
  for _, rule in ipairs(this.popping) do
    local when = rule.when
    local when_not = rule.when_not
    if when and not context:get_option(when) then
      goto continue
    end
    if when_not and context:get_option(when_not) then
      goto continue
    end
    if not rime.match(input, rule.match) then
      goto continue
    end
    if not rime.match(incoming, rule.accept) then
      goto continue
    end
    -- 如果当前有候选，则执行顶屏；否则执行清空编码
    if context:has_menu() then
      if rule.prefix then
        context:pop_input(string.len(input) - rule.prefix)
      end
      context:confirm_current_selection()
      context:commit()
      if rule.prefix then
        context:push_input(string.sub(input, rule.prefix + 1))
      end
    else
      context:clear()
    end
    goto finish
    ::continue::
  end
  ::finish::
  return rime.process_results.kNoop
end

return this
