-- 条件选重处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器可以限制 alternative_select_keys 的作用范围
-- 即只有当编码匹配一定模式的时候，才将这些键视为选重键，否则仍然可以用于编码
-- 使用时，应当保证本处理器在 speller 之前，speller 在 selector 之前
-- 例如，在声笔系列码中，aeuio 可以在一定的时机作为选重键

local rime = require "lib"

local this = {}

---@param env Env
function this.init(env)
  local config = env.engine.schema.config;
  local select_keys = env.engine.schema.select_keys;
  ---@type { string: boolean }
  this.select_keys = {}
  for i = 1, string.len(select_keys) do
    this.select_keys[string.sub(select_keys, i, i)] = true
  end
  this.select_patterns = rime.get_string_list(config, "menu/alternative_select_patterns")
  this.selector = rime.Processor(env.engine, "", "selector")
end

---@param key_event KeyEvent
---@param env Env
---@return ProcessResult
function this.func(key_event, env)
  local key = utf8.char(key_event.keycode)
  if not this.select_keys[key] then
    return rime.process_results.kNoop
  end
  local context = env.engine.context
  local segment = context.composition:toSegmentation():back()
  if not segment then
    return rime.process_results.kNoop
  end
  if segment:has_tag("punct") or segment:has_tag("paging") then
    return this.selector:process_key_event(key_event)
  end
  local input = rime.current(context)
  if not input then
    return rime.process_results.kNoop
  end
  -- 如果当前编码符合选重模式，就将这些键视为选重键
  for _, pattern in ipairs(this.select_patterns) do
    if rime.match(input, pattern) then
      return this.selector:process_key_event(key_event)
    end
  end
  return rime.process_results.kNoop
end

return this
