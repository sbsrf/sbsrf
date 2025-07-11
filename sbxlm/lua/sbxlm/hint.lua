-- 提示过滤器
-- 适用于：声笔的字词型方案
-- 本过滤器在不同的编码模式和不同的选项下分别提示数选字词、声笔字、缩减码

local rime = require "lib"
local core = require "sbxlm.core"

local this = {}

---@class HintEnv: Env
---@field enable_ssp boolean
---@field memory Memory
---@field reverse ReverseLookup

---@param env HintEnv
function this.init(env)
	local id = env.engine.schema.schema_id
	if core.zici(id) then
		env.memory = rime.Memory(env.engine, env.engine.schema)
	else
	    env.memory = rime.Memory1(env.engine, env.engine.schema, "")
	end
	-- 声笔飞单和声笔飞延采用了声笔飞码的词典，所以反查词典的名称与方案 ID 不相同，需要特殊判断
	local dict_name = (id == "sbfd" or id == "sbfy") and "sbfm" or id
	-- 声笔简拼和声笔拼音用声笔简码的简码
	if (id == 'sbjp' or id == 'sbpy') then dict_name = 'sbjm' end
	-- 声笔自整用声笔自然的简码
	if id == 'sbzz' then dict_name = 'sbzr' end
	-- 声笔鹤整用声笔小鹤的简码
	if id == 'sbhz' then dict_name = 'sbxh' end
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
	local ctx = env.engine.context
	local is_enhanced = ctx:get_option("is_enhanced")
	--[[
		0：隐藏，为不显示，即完全隐藏
		1：有理，为显示23789有理组
		2：无理，为显示14560无理组
		3：显示，为显示所有数选字词
	]]
	local is_hidden = ctx:get_option("hide")
	local id = env.engine.schema.schema_id
	local hint_n1 = { "2", "3", "7", "8", "9" }
	local hint_n2 = { "1", "4", "5", "6", "0" }
	local hint_b = { "a", "e", "u", "i", "o" }
	local i = 1
	local memory = env.memory
	for candidate in translation:iter() do
		local input = candidate.preedit
		-- 飞系方案 sxbb 格式上的编码需要提示 sbb 或者 sbbb 格式的缩减码
		if core.feixi(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z][aeuio]*") then
			local codes = env.reverse:lookup(candidate.text)
			candidate.comment = ""
			for code in string.gmatch(codes, "[^ ]+") do
				if input ~= code and input:len() >= code:len() then
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z;']+") then
						candidate.comment = candidate.comment .. " " .. code
					end
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0-9][aeuio]?") and is_enhanced then
						candidate.comment = candidate.comment .. " " .. code
					end
				end
			end
		end
		-- 飞系和双拼在常规码位上，提示声声词和声声笔词，在增强模式下还提示数选字词
		if ((core.fm(id) or core.fy(id) or core.fd(id) or core.fj(id) or core.sp(id))
		and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z][bpmfdtnlgkhjqxzcsrywvBPMFDTNLGKHJQXZCSRYWV][a-zA-Z]?[aeuio]{0,2}")
		or core.fx(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z][bpmfdtnlgkhjqxzcsrywvBPMFDTNLGKHJQXZCSRYWV][0-9aeuio]{0,4}")
		and not is_hidden) then
			local codes = env.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if not is_enhanced and rime.match(code, ".*[0-9].*") then
					;
				elseif candidate.preedit ~= code then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end
		-- 声笔简拼和声笔拼音在非自由模式下在常规码位上提示简码
		-- 注意ctx:input和input(candidate.preedit)是不一样的，后者在音节间含有空格
		if (id == 'sbpy' or id == 'sbjp') and not ctx:get_option("free")
		and rime.match(ctx.input, "[bpmfdtnlgkhjqxzcsrywv][a-z]{2,}") then
			local codes = env.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if ctx.input ~= code then
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv]{2}[0-9]?") then
						candidate.comment = candidate.comment .. " " .. code
					elseif rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z0-9;']?") then
						candidate.comment = candidate.comment .. " " .. code
					elseif id == 'sbjp' and rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][aeuio][0-9;']") then
						candidate.comment = candidate.comment .. " " .. code					end
				end
			end
		end

		if (id == 'sbzz' or id == 'sbhz') and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv].+") then
			local codes = env.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if ctx.input ~= code then
					if rime.match(ctx.input, "[bpmfdtnlgkhjqxzcsrywv][a-z][aeuio][a-z]*")
					and code:len() < ctx.input:len()
					or rime.match(ctx.input, "[bpmfdtnlgkhjqxzcsrywv][a-z][bpmfdtnlgkhjqxzcsrywv][a-z]*")
					and utf8.len(candidate.text) > 1 then
						candidate.comment = candidate.comment .. " " .. code
					end
				end
			end
		end

		-- 简码正码时提示一二简数选字词
		if core.jm(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{1,2}[aeuio]{1,}") then
			local codes = env.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if (rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0-9;']") and is_enhanced) then
					candidate.comment = candidate.comment .. " " .. code
				elseif (rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][;'][aeuio]") and is_enhanced) then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end

		-- 除了以上情况之外，其他的提示都只需要用到首选字词的信息，所以其他字词可以直接通过
		if i > 1 then
		    -- 如果是双拼的声声词，也直接通过
		    if core.sp(id) and core.ss(input) then
		      goto continue
		    end
			rime.yield(candidate)
			goto continue
		end
		-- 字词型方案 s 和 ss 格式输入需要提示加; 和 ' 格式的二字词
		if core.zici(id) and (core.s(input) or core.sx(input)) then
			if core.jm(id) and is_hidden then
				; -- 简码只在非隐藏模式且兼容飞系时提示
			elseif core.feixi(id) and is_hidden then
				; -- 飞系在隐藏模式时不提示声声词 
			else
				memory:dict_lookup(candidate.preedit .. "'", false, 1)
				local e = ''
				for entry in memory:iter_dict()
				do
					e = entry.text
					candidate:get_genuine().comment = candidate:get_genuine().comment .. ' ' .. entry.text
					break
				end
				memory:dict_lookup(candidate.preedit .. ";", false, 1)
				for entry in memory:iter_dict()
				do
					candidate:get_genuine().comment = ' ' .. entry.text .. ";" .. e .. "'"
					break
				end
			end
		end
		if core.jm(id) and (core.sxb(input) or core.sxbb(input)) and not is_hidden then
			memory:dict_lookup(candidate.preedit .. "'", false, 1)
			for entry in memory:iter_dict()
			do
				if candidate:get_genuine().text ~= entry.text then
				  candidate:get_genuine().comment = candidate:get_genuine().comment..  ' ' .. entry.text
				  break
				end
			end
		end
		rime.yield(candidate)
		-- 字词型方案 s 加数字或 ; 或 ' 后用aeuio选择的自定义字词
		if core.zici(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][;'0-9]") and not is_hidden then
			local forward
			for j = 1, #hint_b do
				memory:dict_lookup(candidate.preedit .. hint_b[j], false, 1)
				for entry in memory:iter_dict() do
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry.text, hint_b[j])
					rime.yield(forward)
				end
			end
		end

		-- 飞系方案和声笔简码在 s, sx, sxb 格式的编码上提示 23789 和 14560 两组数选字词
		if (core.s(input) or core.sx(input) or core.sxb(input)) and is_enhanced and not is_hidden then
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
				if ctx:get_option("irrational") then
					comment = n2
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n2.text, comment)
				elseif entry_n2 and ctx:get_option("both") then
					comment = comment .. entry_n2.text .. n2
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n1.text, comment)
				end
				rime.yield(forward)
				::continue::
			end
		end

		-- 飞系在隐藏模式下不提示声笔字
		if core.feixi(id) and (core.s(input) or core.sxs(input)) and is_hidden then
			goto continue
		elseif core.fj(id) and core.sxs(input) then
			goto continue
		end
		-- 飞系方案和双拼方案在 s 和 sxs 码位上，提示声笔字
		-- 对于飞系，所有 sb 都提示
		-- 对于小鹤和自然，只有几个 sb 格式的编码是真正的声笔字，通过声韵拼合规律判断出来
		if ((core.s(input) or core.sxs(input)) and (core.feixi(id) or core.sp(id))
		or rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0123456789]")) then
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
		-- 飞系方案和双拼方案在 sx 码位上，进行后码提示
		if core.sx(input) and (core.feixi(id) and not is_hidden or core.sp(id)) then
			for _, bihua in ipairs(hint_b) do
				local ssb = candidate.preedit .. bihua
				memory:dict_lookup(ssb, false, 1)
				local entry1 = nil
				for entry in memory:iter_dict() do
					entry1 = entry
					break
				end
				if not entry1 then
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

function this.fini(env)
	if env.memory.disconnect then
		env.memory:disconnect()
	else
		env.memory = nil
	end
end

return this
