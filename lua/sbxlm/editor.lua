-- 回头补码处理器
-- 适用于：声笔拼音
-- 本处理器实现了声笔拼音的自动回头补码的功能
-- 即在输入 aeiou 时，如果末音节有 3 码，且前面至少还有一个音节，则将这个编码追加到首音节上
-- 注意，这里的音节是 Rime 中的音节概念，在声笔拼音中对应的是压缩拼音 + 笔画形成的最长 5 码的编码组合，不一定只包含读音信息

local rime = require("rime")

local this = {}

---@param env Env
function this.init(env)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
  -- 只在混顶或者纯顶模式下生效
  if not (context:get_option("mixed") or context:get_option("popping")) then
    return rime.process_results.kNoop
  end
  -- 只对单个 aeiou 按键生效
  if key_event.modifier > 0 then
    return rime.process_results.kNoop
  end
  local incoming = utf8.char(key_event.keycode)
  if not rime.match(incoming, "[aeiou]") then
    return rime.process_results.kNoop
  end
  -- 判断是否满足补码条件：末音节有 3 码，且前面至少还有一个音节
  -- confirmed_position 是拼音整句中已经被确认的编码的长度，只有后面的部分是可编辑的
  -- current_input 获取的是这部分的编码
  -- 这样，我们就可以在拼音整句中多次应用补码，而不会影响到已经确认的部分
  local confirmed_position = context.composition:toSegmentation():get_confirmed_position()
  local current_input = string.sub(context.input, confirmed_position + 1)
  if not rime.match(current_input, ".+[bpmfdtnlgkhjqxzcsrywv][aeiou]{2}") then
    return rime.process_results.kNoop
  end
  -- 找出补码的位置（第二个音节之前），并添加补码
  local first_char_code_len = string.find(current_input, "[bpmfdtnlgkhjqxzcsrywv]", 2) - 1
  context.caret_pos = confirmed_position + first_char_code_len
  context:push_input(incoming)
  -- 如果补码后不到 5 码，则返回当前的位置，使得补码后的输入可以继续匹配词语；
  -- 如果补码后已有 5 码，则不返回，相当于进入单字模式
  if first_char_code_len < 4 then
    context.caret_pos = string.len(context.input) + 1
  end
  return rime.process_results.kAccepted
end

return this
