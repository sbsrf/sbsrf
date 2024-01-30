--[[
datetime_translator: 将 `ors` 翻译为当前日期
--]]
local function translator(input, seg)
   if (input == "orq") then
	   yield(Candidate("orq", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
      yield(Candidate("orq", seg.start, seg._end, os.date("%Y-%m-%d"), ""))
   end
   if (input == "ors") then
      yield(Candidate("ors", seg.start, seg._end, os.date("%Y年%m月%d日%H时%M分%S秒"), ""))
      yield(Candidate("ors", seg.start, seg._end, os.date("%Y%m%d%H%M%S"), ""))
   end
   if (input == "osj") then
      yield(Candidate("osj", seg.start, seg._end, os.date("%H时%M分%S秒"), ""))
      yield(Candidate("osj", seg.start, seg._end, os.date("%H:%M:%S"), ""))
   end
end

return translator
