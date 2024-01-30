-- 固顶翻译器
-- 适用于：声笔拼音
-- 本翻译器是对拼音自定义（pyzdy）码表翻译器的封装
-- 实现了仅在模式为固顶、混顶、纯顶时才翻译

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.translator = rime.Translator(env.engine, "pyzdy", "table_translator")
end

---@param input string
---@param segment Segment
---@param env Env
function this.func(input, segment, env)
  local context = env.engine.context
  if not (context:get_option("fixed") or context:get_option("mixed") or context:get_option("popping")) then
    return
  end
  if string.len(input) < 3 then
    local translation = this.translator:query(input, segment)
    for cand in translation:iter() do
      rime.yield(cand)
    end
  elseif string.len(input) == 3 then
    local translation1 = this.translator:query(string.sub(input, 1, 2), segment)
    local translation2 = this.translator:query(string.sub(input, 3), segment)
    for cand1 in translation1:iter() do
      for cand2 in translation2:iter() do
        local text = cand1.text .. cand2.text
        local cand = rime.Candidate("combination", segment.start, segment._end, text, "")
        rime.yield(cand)
        return
      end
      break
    end
  end
end

return this
