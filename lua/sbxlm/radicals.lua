-- 飞系部首反查过滤器
-- 适用于：声笔飞码、声笔飞单、声笔飞讯
-- 本过滤器在编码段打上反查标签的时候，给单字候选加注部首信息，以便用户学习
-- 部首信息的数据存放在同一目录下的 radicals.txt

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.lookup_tags = { "sbjm_lookup", "bihua_lookup", "pinyin_lookup", "zhlf_lookup" }
  ---@type { string : string }
  this.radicals = {}
  local path = rime.api.get_user_data_dir() .. "/lua/sbxlm/radicals.txt"
  local file = io.open(path, "r")
  if not file then
    return
  end
  for line in file:lines() do
    local char, radical = line:match("([^\t]+)\t([^\t]+)")
    this.radicals[char] = radical
  end
  file:close()
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  for _, value in ipairs(this.lookup_tags) do
    if segment.tags[value] then
      return true
    end
  end
  return false
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  for candidate in translation:iter() do
    candidate.comment = candidate.comment .. string.format("【%s】", this.radicals[candidate.text] or "")
    rime.yield(candidate)
  end
  return
end

return this
