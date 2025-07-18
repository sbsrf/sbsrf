-- 回头补码处理器
-- 适用于：声笔双拼
-- 本处理器实现了声笔双拼的自动回头补码的功能
-- 即在输入 aeiou 时，如果末音节有 3 码，且前面至少还有一个音节，则将这个编码追加到首音节上
-- 注意，这里的音节是 Rime 中的音节概念，不一定只包含读音信息

local rime = require "lib"

local this = {}

---@param env Env
function this.init(env)
  local function clear()
    env.engine.context:set_property("stroke_input", "")
    env.engine.context:refresh_non_confirmed_composition()
  end
  local context = env.engine.context
  context:delete_input()
  context.select_notifier:connect(clear)
  context.commit_notifier:connect(clear)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
  local input = rime.current(env.engine.context)
  -- 只对无修饰按键生效
  if key_event.modifier > 0 then
    return rime.process_results.kNoop
  end
  local incoming = key_event:repr()
  -- 如果输入为空格或数字，代表着作文即将上屏，此时把 kConfirmed 的片段改为 kSelected
  -- 这解决了 https://github.com/rime/home/issues/276 中的不造词问题
  if rime.match(incoming, "\\d") or incoming == "space" then
    for _, segment in ipairs(context.composition:toSegmentation():get_segments()) do
      if segment.status == rime.segment_types.kConfirmed then
        segment.status = rime.segment_types.kSelected
      end
    end
  end
  -- 只在顶功模式下生效
  if context:get_option("free") or context:get_option("fixed") then
    return rime.process_results.kNoop
  end
  -- 只对 aeiou 和 Backspace 键生效
  -- 如果输入是 aeiou，则添加一个码
  -- 如果输入是 Backspace，则从之前增加的补码中删除一个码
  if not (rime.match(incoming, "[aeiou]") or incoming == "BackSpace") then
    return rime.process_results.kNoop
  end
  -- 判断是否满足补码条件：末音节有 3 码，且前面至少还有一个音节
  -- confirmed_position 是拼音整句中已经被确认的编码的长度，只有后面的部分是可编辑的
  -- current_input 获取的是这部分的编码
  -- 这样，我们就可以在拼音整句中多次应用补码，而不会影响到已经确认的部分
  local confirmed_position = context.composition:toSegmentation():get_confirmed_position()
  local previous_caret_pos = context.caret_pos
  local current_input = context.input:sub(confirmed_position + 1, previous_caret_pos)

  -- 追加笔画
  if rime.match(input, "^[bpmfdtnlgkhjqxzcsrywv][a-z][aeuio]{2}.*") then
    local stroke_input = context:get_property("stroke_input")
    if rime.match(context.input:sub(1, 4) .. stroke_input, "[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]{4,}")
    and incoming ~= "BackSpace" then
      return rime.process_results.kAccepted
    end
    if incoming == "BackSpace" and stroke_input ~= "" then
      stroke_input = stroke_input:sub(1, -2)
    elseif rime.match(incoming, "[aeuio]") 
    and rime.match(current_input, "^[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]{2,}|([bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]*)+[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]") then
      stroke_input = stroke_input .. incoming
    else
      goto continue
    end
    context:set_property("stroke_input", stroke_input)
    env.engine.context:refresh_non_confirmed_composition()
    return rime.process_results.kAccepted
  end
  ::continue::

  if not rime.match(current_input, "([bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]*)+[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]") then
    return rime.process_results.kNoop
  end
  -- 如果输入是 Backspace，还要验证是否有补码
  if incoming == "BackSpace" then
    if not rime.match(current_input, "[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]+.+") then
      return rime.process_results.kNoop
    end
  end
  -- 找出补码的位置（第一个音节之后），并添加补码
  local e
  _, e = current_input:find("[bpmfdtnlgkhjqxzcsrywv][a-z][aeiou]*")
  context.caret_pos = confirmed_position + e
  if incoming == "BackSpace" then
    context:pop_input(1)
  elseif e < 4 then
    context:push_input(incoming)
  end
  --如果达到限制长度则禁止补码
  if e <= 4 then
    context.caret_pos = previous_caret_pos + 1
  end
  return rime.process_results.kAccepted
end

return this
