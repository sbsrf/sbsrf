-- 中英混输处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器实现了 Shift+Enter 反转首字母大小写、Control+Enter 反转编码大小写等功能

local XK_Shift_L = 0xffe1
local XK_Shift_R = 0xffe2
local XK_Control_L = 0xffe3
local XK_Control_R = 0xffe4
local XK_Return = 0xff0d
local rime = require("rime")

local this = {}

---@param env Env
function this.init(env)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
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
