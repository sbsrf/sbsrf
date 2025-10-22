-- 正则按键绑定处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器在 Rime 标准库的按键绑定处理器（key_binder）的基础上增加了用正则表达式判断当前输入的编码的功能
-- 也即，在输入编码不同时，可以将按键绑定到不同的功能

local XK_semicolon = 0x003b
local XK_Tab = 0xff09
local XK_apostrophe = 0x0027
local XK_space = 0x0020
local XK_period = 0x002e
local XK_Return = 0xff0d
local XK_Shift_R = 0xffe2
local XK_0 = 0x0030
local XK_1 = 0x0031
local XK_4 = 0x0034
local XK_5 = 0x0035
local XK_6 = 0x0036

local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---@class KeyBinderEnv: Env
---@field redirecting boolean
---@field bindings Binding[]
---@field space_word boolean
---@field tab_word boolean

---@class Binding
---element
---@field match string
---@field accept KeyEvent
---@field send_sequence KeySequence

---解析配置文件中的按键绑定配置
---@param value ConfigMap
---@return Binding | nil
local function parse(value)
  local match = value:get_value("match")
  local accept = value:get_value("accept")
  local send_sequence = value:get_value("send_sequence")
  if not match or not accept or not send_sequence then
    return nil
  end
  local key_event = rime.KeyEvent(accept:get_string())
  local sequence = rime.KeySequence(send_sequence:get_string())
  local binding = { match = match:get_string(), accept = key_event, send_sequence = sequence }
  return binding
end

---@param ch number
local function is_upper(ch)
  -- ch >= 'A' and ch <= 'Z'
  return ch >= 0x41 and ch <= 0x5a
end

---@param env KeyBinderEnv
function this.init(env)
  env.redirecting = false
  ---@type Binding[]
  env.bindings = {}
  local bindings = env.engine.schema.config:get_list("key_binder/bindings")
  if not bindings then
    return
  end
  for i = 1, bindings.size do
    local item = bindings:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local binding = parse(value)
    if not binding then goto continue end
    table.insert(env.bindings, binding)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env KeyBinderEnv
function this.func(key_event, env)
  local context = env.engine.context
  local segment = env.engine.context.composition:back()
  local schema_id = env.engine.schema.schema_id
  local ascii_mode = context:get_option("ascii_mode")
  local delayed_pop = context:get_option("delayed_pop")
  local space_word = context:get_option("space_word")
  local tab_word = context:get_option("tab_word")
  if env.redirecting then
    return rime.process_results.kNoop
  end
  local input = rime.current(context)
  if not input then
    return rime.process_results.kNoop
  end
  if not segment:has_tag("abc") then
    return rime.process_results.kNoop
  end

  if not ascii_mode and not key_event:ctrl() and core.fy(schema_id) and key_event.keycode == XK_Shift_R then
    if core.sxsx(input) then
      env.engine:process_key(rime.KeyEvent("Tab"))
    elseif core.sss(input) then
      env.engine:process_key(rime.KeyEvent("Escape"))
      env.engine:process_key(rime.KeyEvent(input:sub(1,1)))
      env.engine:process_key(rime.KeyEvent("space"))
      env.engine:process_key(rime.KeyEvent(input:sub(2,2)))
      env.engine:process_key(rime.KeyEvent(input:sub(3,3)))
      env.engine:process_key(rime.KeyEvent("Tab"))
    end
  end

  -- 飞码延顶四码特殊处理
  if not ascii_mode and not key_event:ctrl() and not key_event:shift()
  and (core.fm(schema_id) or core.fy(schema_id)) and delayed_pop then
    env.redirecting = true
    if core.sxsx(input) then
      if (key_event.keycode == XK_space and space_word)
      or (key_event.keycode == XK_Tab and tab_word) then
        env.engine:process_key(rime.KeyEvent("BackSpace"))
        env.engine:process_key(rime.KeyEvent(input:upper():sub(4,4)))
      elseif key_event.keycode == XK_Tab
      or key_event.keycode == XK_semicolon
      or key_event.keycode == XK_apostrophe then
        env.engine:process_key(rime.KeyEvent("BackSpace"))
        env.engine:process_key(rime.KeyEvent("BackSpace"))
        env.engine:process_key(rime.KeyEvent("space"))
        if key_event.keycode == XK_semicolon then
          if core.sxsb(input) then
            env.engine:process_key(rime.KeyEvent(input:sub(3,3)))
            env.engine:process_key(rime.KeyEvent(input:sub(4,4)))
            env.engine:process_key(rime.KeyEvent(";"))
            env.engine:process_key(rime.KeyEvent("space"))
          else
            env.engine:process_key(rime.KeyEvent(input:sub(3,3)))
            env.engine:process_key(rime.KeyEvent("space"))
            env.engine:process_key(rime.KeyEvent(input:sub(4,4)))
            env.engine:process_key(rime.KeyEvent("space"))
          end
        else
          env.engine:process_key(rime.KeyEvent(input:sub(3,3)))
          env.engine:process_key(rime.KeyEvent(input:sub(4,4)))
          env.engine:process_key(rime.KeyEvent("'"))
          env.engine:process_key(rime.KeyEvent("space"))
        end
      else
        env.redirecting = false
        goto continue
      end
    else
      env.redirecting = false
      goto continue
    end
    env.redirecting = false
    return rime.process_results.kAccepted
  end

  -- 飞简延顶四码特殊处理
  if not ascii_mode and not key_event:ctrl() and not key_event:shift()
  and core.fj(schema_id) and delayed_pop and key_event.keycode == XK_Tab then
    env.redirecting = true
    if core.ssss(input) then
      env.engine:process_key(rime.KeyEvent("BackSpace"))
      env.engine:process_key(rime.KeyEvent("BackSpace"))
      env.engine:process_key(rime.KeyEvent("'"))
      env.engine:process_key(rime.KeyEvent(input:sub(3,3)))
      env.engine:process_key(rime.KeyEvent(input:sub(4,4)))
      env.engine:process_key(rime.KeyEvent("'"))
      env.engine:process_key(rime.KeyEvent("space"))
    else
      env.redirecting = false
      goto continue
    end
    env.redirecting = false
    return rime.process_results.kAccepted
  end

  ::continue::
  for _, binding in ipairs(env.bindings) do
    -- 只有当按键和当前输入的模式都匹配的时候，才起作用
    if key_event:eq(binding.accept) and rime.match(input, binding.match) then
      env.redirecting = true
      for _, event in ipairs(binding.send_sequence:toKeyEvent()) do
        env.engine:process_key(event)
      end
      env.redirecting = false
      return rime.process_results.kAccepted
    end
  end

  if core.yp(schema_id) and input:sub(-2,-1) == "''"
  and (key_event.keycode == XK_1 or key_event.keycode == XK_4
  or key_event.keycode == XK_5 or key_event.keycode == XK_6
  or key_event.keycode == XK_0) then
    env.engine:process_key(rime.KeyEvent("BackSpace"))
  end
  return rime.process_results.kNoop
end

return this
