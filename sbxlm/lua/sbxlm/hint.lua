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
---@field xd_chars { string : string }

---@param env HintEnv
function this.init(env)
	local id = env.engine.schema.schema_id
	if core.zici(id) then
		env.memory = rime.Memory(env.engine, env.engine.schema)
	else
	    env.memory = rime.Memory1(env.engine, env.engine.schema, "")
	end
	-- 声笔飞单和声笔飞延采用了声笔飞码的词典，所以反查词典的名称与方案 ID 不相同，需要特殊判断
	local dict_name = (id == "sbfd" or id == "sbmd" or id == "sbfy") and "sbfm" or id
	if id == "sbxd" then dict_name = "sbxm" end
	-- 声笔简拼和声笔拼音用声笔简码的简码
	if (id == 'sbjp' or id == 'sbpy') then dict_name = 'sbjm' end
	-- 声笔自整用声笔自然的简码
	if id == 'sbzz' then dict_name = 'sbzr' end
	-- 声笔鹤整用声笔小鹤的简码
	if id == 'sbhz' then dict_name = 'sbxh' end
	env.reverse = rime.ReverseLookup(dict_name)
	env.xd_chars = {}
	local path = rime.api.get_user_data_dir() .. "/lua/sbxlm/xd_chars.txt"
	local file = io.open(path, "r")
	if not file then
	  return
	end
	for line in file:lines() do
	  ---@type string, string
	  local char, code = line:match("([^\t]+)\t([^\t]+)")
	  env.xd_chars[code] = char
	end
	file:close()
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
	local id = env.engine.schema.schema_id
	local is_hidden = ctx:get_option("hide")
	if core.xiangxi(id) then is_hidden = ctx:get_option("is_hidden") end
	local hint_n1 = { "2", "3", "7", "8", "9" }
	local hint_n2 = { "1", "4", "5", "6", "0" }
	local hint_n3 = { "1", "2", "3", "4", "5" }
	local hint_b = { "a", "e", "u", "i", "o" }
	local hint_p = { ";", "'", ",", ".", "/" }
	local i = 1
	local j = 1
	local memory = env.memory
	for candidate in translation:iter() do
		-- 猛码提示
		local input = candidate.preedit
		if core.mm(id) and rime.match(input, "[a-z]{3}[;',./]") then
			local codes = env.reverse:lookup(candidate.text)
			candidate.comment = ""
			for code in string.gmatch(codes, "[^ ]+") do
				if input ~= code and input:len() >= code:len() then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end		
		-- 象系单字在全码时提示简码
		if (core.xiangxi(id)) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]{2}[aeuio;',./]") then
			local codes = env.reverse:lookup(candidate.text)
			candidate.comment = ""
			for code in string.gmatch(codes, "[^ ]+") do
				if input ~= code and input:len() >= code:len() then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end
		-- 飞系方案 sxbb 格式上的编码需要提示 sbb 或者 sbbb 格式的缩减码
		if core.feixi(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z][aeuio]*") then
			local codes = env.reverse:lookup(candidate.text)
			candidate.comment = ""
			for code in string.gmatch(codes, "[^ ]+") do
				if input ~= code and input:len() >= code:len() then
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z;',./]+") then
						candidate.comment = candidate.comment .. " " .. code
					end
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0-9][aeuio]?") and is_enhanced then
						candidate.comment = candidate.comment .. " " .. code
					end
				end
			end
		end
		-- 飞系方案 sxb[;'] 格式上的编码需要提示 s 或者 sb 字
		if core.feixi(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{2}[aeuio][;']") then
			local codes = env.reverse:lookup(candidate.text)
			candidate.comment = ""
			for code in string.gmatch(codes, "[^ ]+") do
				if input ~= code and input:len() >= code:len() then
					if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][aeuio]?") then
						candidate.comment = candidate.comment .. " " .. code
					end
				end
			end
		end
		-- 飞系和双拼在常规码位上，提示声声词和声声笔词，在增强模式下还提示数选字词
		if ((core.fm(id) or core.fy(id) or core.fd(id) or core.fj(id) or core.sp(id))
		and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-zA-Z][bpmfdtnlgkhjqxzcsrywvBPMFDTNLGKHJQXZCSRYWV][a-zA-Z]?[aeuio]{0,2}")
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
		if core.xiangxi(id) and (core.s(input) or core.sxs(input)) and not is_hidden then
			candidate:get_genuine().comment = ''
			local x = input:len()
			for j = 1, 5 do
				memory:dict_lookup(candidate.preedit:sub(x,x) .. hint_p[j], false, 1)
				for entry in memory:iter_dict()
				do
					candidate:get_genuine().comment = candidate:get_genuine().comment .. entry.text .. hint_p[j]
					break
				end	
			end
			local chars = env.xd_chars
			for code, char in pairs(chars) do
				if code and code:sub(1,1) == input:sub(x,x) and code:len() == 2 then
					candidate:get_genuine().comment = candidate:get_genuine().comment .. char .. code:sub(2,2)
				end
			end
		end
		-- 字词型方案 s 和 ss 格式输入需要提示加; 和 ' 格式的二字词
		if core.zici(id) and (core.s(input) or core.sx(input)) then
			if core.jm(id) and is_hidden then
				; -- 简码只在非隐藏模式且兼容飞系时提示
			elseif core.feixi(id) and is_hidden then
				; -- 飞系在隐藏模式时不提示声声词 
			elseif not ((core.feixi(id) or core.xiangxi(id)) and core.s(input)) then
				candidate:get_genuine().comment = ''
				memory:dict_lookup(candidate.preedit .. ";", false, 1)
				for entry in memory:iter_dict()
				do
					candidate:get_genuine().comment = ' ' .. entry.text .. ";"
					break
				end
				memory:dict_lookup(candidate.preedit .. "'", false, 1)
				for entry in memory:iter_dict()	do
					candidate:get_genuine().comment = candidate:get_genuine().comment .. entry.text .. "'"
					break
				end						
			end
		end
		--象系在sxx时提示无理四码字
		if core.xiangxi(id) and core.sxx(input) and not is_hidden then
			local char
			if core.sxb(input) then
				for j = 1, 5 do
					char = env.xd_chars[input .. hint_b[j]]
					if char then
						candidate:get_genuine().comment = candidate:get_genuine().comment .. char .. hint_b[j]
					end
				end
			else
				for j = 1, 5 do
					char = env.xd_chars[input .. hint_p[j]]
					if char then
						candidate:get_genuine().comment = candidate:get_genuine().comment .. char .. hint_p[j]
					end
				end
			end
		end
		--象码和象单在sxsx时提示标点字
		if core.xiangxi(id) and core.sxsx(input) and not is_hidden then
			candidate:get_genuine().comment = ''
			memory:dict_lookup(candidate.preedit:sub(3,4) .. ";", false, 1)
			for entry in memory:iter_dict()
			do
				candidate:get_genuine().comment = ' ' .. entry.text .. ";"
				break
			end
			memory:dict_lookup(candidate.preedit:sub(3,4) .. "'", false, 1)
			for entry in memory:iter_dict()
			do
				candidate:get_genuine().comment = candidate:get_genuine().comment .. entry.text .. "'"
				break
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
		if core.zici(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][;',./0-9]") and not is_hidden then
			local forward
			for j = 1, #hint_b do
				memory:dict_lookup(candidate.preedit .. hint_b[j], false, 1)
				for entry in memory:iter_dict() do
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry.text, hint_b[j])
					rime.yield(forward)
				end
			end
		end

		-- 猛码提示
		if core.mm(id) and rime.match(input, "[a-z]{1,3}") then
			local forward, x, y
			---@type { string: number }
			local candidates = {}
			if rime.match(input, "[a-z]") then
				x = hint_n3
			else
				x = hint_p
			end
			for j = 1, 5 do
				memory:dict_lookup(candidate.preedit .. x[j], false, 1)
				for entry in memory:iter_dict() do
					local cand = candidates[x[j]] 
					if cand and cand > 0 then
						break
					end
					candidates[x[j]] = 1
					forward = rime.Candidate("hint", candidate.start, candidate._end, entry.text, x[j])
					rime.yield(forward)
				end
			end
		end

		-- 象系提示
		if core.xiangxi(id) then
			if rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]{2}") then
				local forward
				---@type { string: number }
				local candidates = {}
				if core.sxb(input) then
					for j = 1, 5 do
						memory:dict_lookup(candidate.preedit .. hint_b[j], false, 1)
						for entry in memory:iter_dict() do
							local cand = candidates[hint_b[j]] 
							if cand and cand > 0  or entry.text == env.xd_chars[input .. hint_b[j]] then
								break
							end
							candidates[hint_b[j]] = 1
							forward = rime.Candidate("hint", candidate.start, candidate._end, entry.text, hint_b[j])
							rime.yield(forward)
						end
					end		
				else
					for j = 1, 5 do
						memory:dict_lookup(candidate.preedit .. hint_p[j], false, 1)
						for entry in memory:iter_dict() do
							local cand = candidates[hint_p[j]] 
							if cand and cand > 0 or entry.text == env.xd_chars[input .. hint_p[j]] then
								break
							end
							candidates[hint_p[j]] = 1
							forward = rime.Candidate("hint", candidate.start, candidate._end, entry.text, hint_p[j])
							rime.yield(forward)
						end
					end
				end
			end
		end

		-- 飞系在spb时用注释提示扩展标点字
		if core.feixi(id) and core.ssb(input) then
			for j = 1, #hint_p do
				memory:dict_lookup(candidate.preedit .. hint_p[j], false, 1)
				for entry in memory:iter_dict()
				do
					candidate:get_genuine().comment = candidate:get_genuine().comment .. entry.text .. hint_p[j]
					break
				end	
			end
		end

		-- 飞系方案和声笔简码在 s, sx, sxb 格式的编码上提示 23789 和 14560 两组数选字词
		if (core.s(input) or core.sx(input) or core.sxb(input)) and not core.xiangxi(id) and is_enhanced and not is_hidden then
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
			for idx, bihua in ipairs(hint_b) do
				local shengmu = candidate.preedit:sub(-1)
				-- hack，假设 UTF-8 编码都是 3 字节的
				local text = candidate.text:sub(1, -4)
				if core.sp(id) and not core.invalid_pinyin(shengmu .. bihua) then
					goto continue
				end
				memory:dict_lookup(shengmu .. bihua, false, 1)
				for entry in memory:iter_dict() do
					text = text .. entry.text
					break
				end
				memory:dict_lookup(shengmu .. hint_p[idx], false, 1)
				for entry in memory:iter_dict() do
					-- 飞码的sxs上不提示标点字
					if not (core.fm(id) and core.sxs(input)) then
						bihua = bihua .. entry.text .. hint_p[idx]
					end
					local forward = rime.Candidate("hint", candidate.start, candidate._end, text, bihua)
					rime.yield(forward)
					break
				end
				::continue::
			end
		end
		-- 飞系方案、双拼方案和象码在 sx 码位上，进行后码提示
		if core.sx(input) and (core.feixi(id) and not is_hidden or core.sp(id) or core.xiangxi(id)) then
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
		--象码和象单在sxsx上时的提示
		if core.sxsx(input) and core.xiangxi(id) and not is_hidden then
			for _, bihua in ipairs(hint_b) do
				local ssb = candidate.preedit:sub(3,4) .. bihua
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
		-- 飞系方案在 ssb 码位上，提示spbb缩减字
		if core.ssb(input) and core.feixi(id) and not is_hidden then
			for _, b in ipairs(hint_b) do
				local ssbx = candidate.preedit .. b
				memory:dict_lookup(ssbx, false, 1)
				local entry1 = nil
				for entry in memory:iter_dict() do
					entry1 = entry
					break
				end
				if not entry1 then
					goto continue
				end
				local forward = rime.Candidate("hint", candidate.start, candidate._end, entry1.text, b)
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
