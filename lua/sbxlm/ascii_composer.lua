-- 中英混输处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器实现了 Shift+Enter 反转首字母大小写、Control+Enter 反转编码大小写等功能

local XK_Shift_L = 0xffe1
local XK_Shift_R = 0xffe2
local XK_Control_L = 0xffe3
local XK_Control_R = 0xffe4
local XK_Return = 0xff0d
local XK_Tab = 0xff09
local rime = require("rime")

local this = {}

---@param env Env
function this.init(env)
  this.ascii_composer = rime.Processor(env.engine, "", "ascii_composer")
end

---@param ch number
local function is_upper(ch)
  -- ch >= 'A' and ch <= 'Z'
  return ch >= 0x41 and ch <= 0x5a
end

---@param context Context
function this.switch_inline(context)
  context:set_option("ascii_mode", true)
  this.connection = context.update_notifier:connect(function(ctx)
    if not ctx:is_composing() then
      this.connection:disconnect()
      ctx:set_option("ascii_mode", false)
    end
  end)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
  local ascii_mode = context:get_option("ascii_mode")
  local auto_inline = context:get_option("auto_inline")

  -- auto_inline 启用时，首字母大写时自动切换到内联模式
  if (not ascii_mode and auto_inline and context.input:len() == 0 and is_upper(key_event.keycode) and key_event.modifier == rime.modifier_masks.kShift) then
    context:push_input(string.char(key_event.keycode))
    this.switch_inline(context)
    -- hack，随便发一个没用的键让 ascii_composer 忘掉之前的 shift
    env.engine:process_key(rime.KeyEvent("Release+A"))
    return rime.process_results.kAccepted
  end

  -- 首字母后的 Tab 键切换到内联模式，Shift+Tab 键切换到缓冲模式
  if (not ascii_mode and context.input:len() == 1 and key_event.keycode == XK_Tab and not key_event:release()) then
    if key_event:shift() then
      if not context:get_option("is_buffered") then
        context:set_option("is_buffered", true)
      end
      context:set_option("temp_buffered", true)
    else
      this.switch_inline(context)
    end
    return rime.process_results.kAccepted
  end

  -- 用 Shift+Return 或者 Control+Return 反转大小写
  if key_event.modifier == rime.modifier_masks.kShift and key_event.keycode == XK_Return then
    env.engine:commit_text(context.input:sub(1, 1):upper() .. context.input:sub(2))
    context:clear()
    return rime.process_results.kAccepted
  end
  if key_event.modifier == rime.modifier_masks.kControl and key_event.keycode == XK_Return then
    env.engine:commit_text(context.input:upper())
    context:clear()
    return rime.process_results.kAccepted
  end
  return rime.process_results.kNoop
end

return this
