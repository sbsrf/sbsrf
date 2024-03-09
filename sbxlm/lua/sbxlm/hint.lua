-- 提示过滤器
-- 适用于：声笔简码、声笔飞码、声笔飞单、声笔飞讯、声笔小鹤、声笔自然
-- 本过滤器在不同的编码模式和不同的选项下分别提示数选字词、声笔字、缩减码

local rime = require "sbxlm.lib"
local core = require "sbxlm.core"

local this = {}

---@class HintEnv: Env
---@field memory Memory
---@field reverse ReverseLookup

---@param env HintEnv
function this.init(env)
	env.memory = rime.Memory(env.engine, env.engine.schema)
	local id = env.engine.schema.schema_id
	-- 声笔飞单用了声笔飞码的词典，所以反查词典的名称与方案 ID 不相同，需要特殊判断
	local dict_name = id == "sbfd" and "sbfm" or id
	env.reverse = rime.ReverseLookup(dict_name)
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
	return segment:has_tag("abc")
end

---@param translation Translation
---@param env HintEnv
function this.func(translation, env)
	local is_enhanced = env.engine.context:get_option("is_enhanced")
	--[[
		0：隐藏，为不显示，即完全隐藏
		1：有理，为显示23789有理组
		2：无理，为显示14560无理组
		3：显示，为显示所有数选字词
	]]
	local is_hidden = env.engine.context:get_option("hide")
	local id = env.engine.schema.schema_id
	local hint_n1 = { "2", "3", "7", "8", "9" }
	local hint_n2 = { "1", "4", "5", "6", "0" }
	local hint_b = { "a", "e", "u", "i", "o" }
	local i = 1
	local memory = env.memory
	for candidate in translation:iter() do
		local input = candidate.preedit
		-- 第一种情况：飞系方案 spbb 格式上的编码需要提示 sbb 或者 sbbb 格式的缩减码
		if core.feixi(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{2}[aeuio]{2,}") then
			local codes = env.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][aeiou]{2,}") then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end
		-- 除了缩减码之外，其他的提示都只需要用到首选字词的信息，所以其他字词可以直接通过
		if i > 1 then
		    -- 如果是双拼的声声词，也直接通过
		    if core.sp(id) and core.ss(input) then
		      goto continue
		    end
			rime.yield(candidate)
			goto continue
		end
		-- 第二种情况：飞系、简码或双拼方案 ss 格式输入需要提示 ss' 格式的二字词
		if (core.feixi(id) or core.sp(id) or core.jm(id) and is_enhanced and not is_hidden) and (core.s(input) or core.ss(input)) then
			memory:dict_lookup(candidate.preedit .. "'", false, 1)
			for entry in memory:iter_dict()
			do
				candidate:get_genuine().comment = ' ' .. entry.text
				break
			end
		end
		rime.yield(candidate)
		-- 第三种情况：飞系方案和声笔简码在 s, sb, ss, sxb 格式的编码上提示 23789 和 14560 两组数选字词
		if (core.s(input) or core.sb(input) or core.ss(input) or core.sxb(input))
				and is_enhanced and not env.engine.context:get_option("hide") then
			for j = 1, #hint_n1 do
				local n1 = hint_n1[j]
				local n2 = hint_n2[j]
				memory:dict_lookup(candidate.preedit .. n1, false, 1)
				local entry_n1 = nil
				for entry in memory:iter_dict() do
					entry_n1 = entry
					break
				end
				if not entry_n1 then
					goto continue
				end
				memory:dict_lookup(candidate.preedit .. n2, false, 1)
				local entry_n2 = nil
				for entry in memory:iter_dict() do
					entry_n2 = entry
					break
				end
				local comment = n1
				local forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n1.text, comment)
				if env.engine.context:get_option("irrational") then
					comment = n2
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n2.text, comment)
				elseif entry_n2 and env.engine.context:get_option("both") then
					comment = comment .. entry_n2.text .. n2
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n1.text, comment)
				end
				rime.yield(forward)
				::continue::
			end
		end
		-- 第四种情况：飞系方案和双拼方案在 s 和 sxs 码位上，提示声笔字
		-- 对于飞系，所有 sb 都提示
		-- 对于小鹤和自然，只有几个 sb 格式的编码是真正的声笔字，通过声韵拼合规律判断出来
		if ((core.s(input) or core.sxs(input)) and (core.feixi(id) or core.sp(id)))
				or rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0123456789]") then
			for _, bihua in ipairs(hint_b) do
				local shengmu = candidate.preedit:sub(-1)
				-- hack，假设 UTF-8 编码都是 3 字节的
				local prev_text = candidate.text:sub(1, -4)
				if core.sp(id) and not core.invalid_pinyin(shengmu .. bihua) then
					goto continue
				end
				memory:dict_lookup(shengmu .. bihua, false, 1)
				for entry in memory:iter_dict() do
					local forward = rime.Candidate("hint", candidate.start, candidate._end, prev_text .. entry.text, bihua)
					rime.yield(forward)
					break
				end
				::continue::
			end
		end
		-- 第五种情况：飞系方案和双拼方案在 ss 码位上，提示声声笔词
		if core.ss(input) and (core.feixi(id) or core.sp(id)) then
			for _, bihua in ipairs(hint_b) do
				local ssb = candidate.preedit .. bihua
				memory:dict_lookup(ssb, false, 1)
				local entry1 = nil
				for entry in memory:iter_dict() do
					entry1 = entry
					break
				end
				if not entry1 or utf8.len(entry1.text) == 1 then
					goto continue
				end
				local forward = rime.Candidate("hint", candidate.start, candidate._end, entry1.text, bihua)
				rime.yield(forward)
				::continue::
			end
		end
		::continue::
		i = i + 1
	end
end

return this
