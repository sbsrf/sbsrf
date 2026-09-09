-- 飞系部首反查过滤器
-- 适用于：声笔飞码、声笔飞单、声笔飞讯
-- 本过滤器在编码段打上反查标签的时候，给单字候选加注部首信息，以便用户学习
-- 部首信息的数据存放在用户目录下的 radicals.txt

local rime = require "lib"

local this = {}

---@class RadicalsEnv: Env
---@field lookup_tags string[]
---@field radicals { string : string }

---@param env RadicalsEnv
function this.init(env)
  env.radicals = {}
  local path = rime.api.get_user_data_dir() .. "/lua/sbxlm/radicals.txt"
  if env.engine.schema.schema_id == "sbxm" then
    path = rime.api.get_user_data_dir() .. "/lua/sbxlm/sbxmcf.txt"
  end
  local file = io.open(path, "r")
  if not file then
    return
  end
  for line in file:lines() do
    ---@type string, string
    local char, radical = line:match("([^\t]+)\t([^\t]+)")
    env.radicals[char] = radical
  end
  file:close()
end

---@param segment Segment
---@param env RadicalsEnv
function this.tags_match(segment, env)
  local tags = rime.get_string_list(env.engine.schema.config, "reverse_lookup/tags")
  for _, value in ipairs(tags) do
    if segment.tags[value] then
      return true
    end
  end
  return false
end

---@param translation Translation
---@param env RadicalsEnv
function this.func(translation, env)
  local context = env.engine.context
  local segment = context.composition:back()
  local input = rime.current(context) or ""
  -- 声笔反查时，comment 中可能包含与输入相同的简码以及重复编码，需去除冗余项
  local is_sbfc = segment and segment:has_tag("sbfc")

  for candidate in translation:iter() do
    if is_sbfc and input ~= "" and candidate.comment:len() > 0 then
      local seen = {}
      local tokens = {}
      for token in candidate.comment:gmatch("%S+") do
        if token ~= input and not seen[token] then
          seen[token] = true
          table.insert(tokens, token)
        end
      end
      candidate.comment = table.concat(tokens, " ")
    end

    local radical = env.radicals[candidate.text]
    if radical then
      candidate.comment = candidate.comment .. string.format(" [%s]", env.radicals[candidate.text])
    end
    rime.yield(candidate)
  end
  return
end

function this.fini(env)
  env.radicals = nil
end

return this
