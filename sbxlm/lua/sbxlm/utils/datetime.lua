local rime = require "lib"

-- =====================================================================
-- 农历核心数据与算法模块 (基于 Rata Die 绝对天数算法，支持 1900-2099)
-- =====================================================================

local tianGan = { "甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸" }
local diZhi = { "子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥" }
local animalSign = { "鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪" }

local lunarDayShuXu = {
    "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
    "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
    "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
}
local lunarMonthShuXu = { "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊" }

local daysToMonth365 = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
local daysToMonth366 = { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335 }

local BEGIN_YEAR = 1900
local NUMBER_YEAR = 200

-- 农历数据表: { 闰月, 春节月, 春节日, 大小月标志(十进制) }
local dateLunarInfo = {
    { 8,  1, 31, 37600 }, { 0,  2, 19, 19168 }, { 0,  2, 8,  42352 }, { 5,  1, 29, 21096 },
    { 0,  2, 16, 53856 }, { 0,  2, 4,  55632 }, { 4,  1, 25, 27304 }, { 0,  2, 13, 22176 },
    { 0,  2, 2,  39632 }, { 2,  1, 22, 19176 }, { 0,  2, 10, 19168 }, { 6,  1, 30, 42200 },
    { 0,  2, 18, 42192 }, { 0,  2, 6,  53840 }, { 5,  1, 26, 54568 }, { 0,  2, 14, 46400 },
    { 0,  2, 3,  54944 }, { 2,  1, 23, 38608 }, { 0,  2, 11, 38320 }, { 7,  2, 1,  18872 },
    { 0,  2, 20, 18800 }, { 0,  2, 8,  42160 }, { 5,  1, 28, 45656 }, { 0,  2, 16, 27216 },
    { 0,  2, 5,  27968 }, { 4,  1, 24, 44456 }, { 0,  2, 13, 11104 }, { 0,  2, 2,  38256 },
    { 2,  1, 23, 18808 }, { 0,  2, 10, 18800 }, { 6,  1, 30, 25776 }, { 0,  2, 17, 54432 },
    { 0,  2, 6,  59984 }, { 5,  1, 26, 27976 }, { 0,  2, 14, 23248 }, { 0,  2, 4,  11104 },
    { 3,  1, 24, 37744 }, { 0,  2, 11, 37600 }, { 7,  1, 31, 51560 }, { 0,  2, 19, 51536 },
    { 0,  2, 8,  54432 }, { 6,  1, 27, 55888 }, { 0,  2, 15, 46416 }, { 0,  2, 5,  22176 },
    { 4,  1, 25, 43736 }, { 0,  2, 13, 9680 },  { 0,  2, 2,  37584 }, { 2,  1, 22, 51544 },
    { 0,  2, 10, 43344 }, { 7,  1, 29, 46248 }, { 0,  2, 17, 27808 }, { 0,  2, 6,  46416 },
    { 5,  1, 27, 21928 }, { 0,  2, 14, 19872 }, { 0,  2, 3,  42416 }, { 3,  1, 24, 21176 },
    { 0,  2, 12, 21168 }, { 8,  1, 31, 43344 }, { 0,  2, 18, 59728 }, { 0,  2, 8,  27296 },
    { 6,  1, 28, 44368 }, { 0,  2, 15, 43856 }, { 0,  2, 5,  19296 }, { 4,  1, 25, 42352 },
    { 0,  2, 13, 42352 }, { 0,  2, 2,  21088 }, { 3,  1, 21, 59696 }, { 0,  2, 9,  55632 },
    { 7,  1, 30, 23208 }, { 0,  2, 17, 22176 }, { 0,  2, 6,  38608 }, { 5,  1, 27, 19176 },
    { 0,  2, 15, 19152 }, { 0,  2, 3,  42192 }, { 4,  1, 23, 53864 }, { 0,  2, 11, 53840 },
    { 8,  1, 31, 54568 }, { 0,  2, 18, 46400 }, { 0,  2, 7,  46752 }, { 6,  1, 28, 38608 },
    { 0,  2, 16, 38320 }, { 0,  2, 5,  18864 }, { 4,  1, 25, 42168 }, { 0,  2, 13, 42160 },
    { 10, 2, 2,  45656 }, { 0,  2, 20, 27216 }, { 0,  2, 9,  27968 }, { 6,  1, 29, 44448 },    { 0,  2, 17, 43872 }, { 0,  2, 6,  38256 }, { 5,  1, 27, 18808 }, { 0,  2, 15, 18800 },
    { 0,  2, 4,  25776 }, { 3,  1, 23, 27216 }, { 0,  2, 10, 59984 }, { 8,  1, 31, 27432 },
    { 0,  2, 19, 23232 }, { 0,  2, 7,  43872 }, { 5,  1, 28, 37736 }, { 0,  2, 16, 37600 },
    { 0,  2, 5,  51552 }, { 4,  1, 24, 54440 }, { 0,  2, 12, 54432 }, { 0,  2, 1,  55888 },
    { 2,  1, 22, 23208 }, { 0,  2, 9,  22176 }, { 7,  1, 29, 43736 }, { 0,  2, 18, 9680 },
    { 0,  2, 7,  37584 }, { 5,  1, 26, 51544 }, { 0,  2, 14, 43344 }, { 0,  2, 3,  46240 },
    { 4,  1, 23, 46416 }, { 0,  2, 10, 44368 }, { 9,  1, 31, 21928 }, { 0,  2, 19, 19360 },
    { 0,  2, 8,  42416 }, { 6,  1, 28, 21176 }, { 0,  2, 16, 21168 }, { 0,  2, 5,  43312 },
    { 4,  1, 25, 29864 }, { 0,  2, 12, 27296 }, { 0,  2, 1,  44368 }, { 2,  1, 22, 19880 },
    { 0,  2, 10, 19296 }, { 6,  1, 29, 42352 }, { 0,  2, 17, 42208 }, { 0,  2, 6,  53856 },
    { 5,  1, 26, 59696 }, { 0,  2, 13, 54576 }, { 0,  2, 3,  23200 }, { 3,  1, 23, 27472 },
    { 0,  2, 11, 38608 }, { 11, 1, 31, 19176 }, { 0,  2, 19, 19152 }, { 0,  2, 8,  42192 },
    { 6,  1, 28, 53848 }, { 0,  2, 15, 53840 }, { 0,  2, 4,  54560 }, { 5,  1, 24, 55968 },
    { 0,  2, 12, 46496 }, { 0,  2, 1,  22224 }, { 2,  1, 22, 19160 }, { 0,  2, 10, 18864 },
    { 7,  1, 30, 42168 }, { 0,  2, 17, 42160 }, { 0,  2, 6,  43600 }, { 5,  1, 26, 46376 },
    { 0,  2, 14, 27936 }, { 0,  2, 2,  44448 }, { 3,  1, 23, 21936 }, { 0,  2, 11, 37744 },
    { 8,  2, 1,  18808 }, { 0,  2, 19, 18800 }, { 0,  2, 8,  25776 }, { 6,  1, 28, 27216 },
    { 0,  2, 15, 59984 }, { 0,  2, 4,  27424 }, { 4,  1, 24, 43872 }, { 0,  2, 12, 43744 },
    { 0,  2, 2,  37600 }, { 3,  1, 21, 51568 }, { 0,  2, 9,  51552 }, { 7,  1, 29, 54440 },
    { 0,  2, 17, 54432 }, { 0,  2, 5,  55888 }, { 5,  1, 26, 23208 }, { 0,  2, 14, 22176 },
    { 0,  2, 3,  42704 }, { 4,  1, 23, 21224 }, { 0,  2, 11, 21200 }, { 8,  1, 31, 43352 },
    { 0,  2, 19, 43344 }, { 0,  2, 7,  46240 }, { 6,  1, 27, 46416 }, { 0,  2, 15, 44368 },
    { 0,  2, 5,  21920 }, { 4,  1, 24, 42448 }, { 0,  2, 12, 42416 }, { 0,  2, 2,  21168 },
    { 3,  1, 22, 43320 }, { 0,  2, 9,  26928 }, { 7,  1, 29, 29336 }, { 0,  2, 17, 27296 },
    { 0,  2, 6,  44368 }, { 5,  1, 26, 19880 }, { 0,  2, 14, 19296 }, { 0,  2, 3,  42352 },
    { 4,  1, 24, 21104 }, { 0,  2, 10, 53856 }, { 8,  1, 30, 59696 }, { 0,  2, 18, 54560 },
    { 0,  2, 7,  55968 }, { 6,  1, 27, 27472 }, { 0,  2, 15, 22224 }, { 0,  2, 5,  19168 },
    { 4,  1, 25, 42216 }, { 0,  2, 12, 42192 }, { 0,  2, 1,  53584 }, { 2,  1, 21, 55592 },
    { 0,  2, 9,  54560 }
}

-- 极简年份转中文 (替代外部 n2cn 依赖，如 2026 -> 二〇二六)
local cn_digits = { "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
local function year_to_cn(year)
    local res = ""
    local str_year = tostring(year)
    for i = 1, #str_year do
        res = res .. cn_digits[tonumber(str_year:sub(i, i)) + 1]
    end
    return res
end

local function isLeapYear(y)
    return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

-- Rata Die 算法：计算绝对天数，完美避开 os.time 的 1970 年限制
local function dateToAbsDay(y, m, d)
    local y1 = y - 1
    return 365 * y1 + math.floor(y1 / 4) - math.floor(y1 / 100) + math.floor(y1 / 400)        + (isLeapYear(y) and daysToMonth366[m] or daysToMonth365[m]) + d
end

local BASE_ABS_DAY = dateToAbsDay(2000, 1, 7) -- 甲子记日起点

local function bitAnd(num1, num2)
    local result, bit = 0, 1
    while num1 > 0 and num2 > 0 do
        if num1 % 2 == 1 and num2 % 2 == 1 then result = result + bit end
        num1, num2, bit = math.floor(num1 / 2), math.floor(num2 / 2), bit * 2
    end
    return result
end

local function getYearInfo(lunarYear, index)
    if lunarYear < BEGIN_YEAR or lunarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then return nil end
    return dateLunarInfo[lunarYear - BEGIN_YEAR + 1][index]
end

local function daysCntInSolar(solarYear, solarMonth, solarDay)
    return (isLeapYear(solarYear) and daysToMonth366 or daysToMonth365)[solarMonth] + solarDay
end

-- 核心转换函数：阳历转阴历
local function solar2Lunar(solarYear, solarMonth, solarDay)
    local lunarDate = {
        solarYear = solarYear, solarMonth = solarMonth, solarDay = solarDay,
        year = solarYear, month = 0, day = 0, leap = false
    }
    
    lunarDate.daysToBase = dateToAbsDay(solarYear, solarMonth, solarDay) - BASE_ABS_DAY
    if lunarDate.solarYear < BEGIN_YEAR or lunarDate.solarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return lunarDate
    end

    local springM, springD = getYearInfo(lunarDate.year, 2), getYearInfo(lunarDate.year, 3)
    local daysInSolar = daysCntInSolar(solarYear, solarMonth, solarDay)
    local daysInSolarSpring = daysCntInSolar(solarYear, springM, springD)
    local daysInLunar = daysInSolar - daysInSolarSpring + 1

    if daysInLunar <= 0 then
        lunarDate.year = lunarDate.year - 1
        if lunarDate.year < BEGIN_YEAR then return lunarDate end
        springM, springD = getYearInfo(lunarDate.year, 2), getYearInfo(lunarDate.year, 3)
        local daysInPrevSolar = isLeapYear(solarYear - 1) and 366 or 365
        local daysInPrevSpring = daysCntInSolar(solarYear - 1, springM, springD)
        daysInLunar = daysInSolar + daysInPrevSolar - daysInPrevSpring + 1
    end

    local m, daysInMonth, bitMask = 1, 0, 32768    local month30Flg = getYearInfo(lunarDate.year, 4)

    while m <= 13 do
        daysInMonth = bitAnd(month30Flg, bitMask) ~= 0 and 30 or 29
        if daysInLunar <= daysInMonth then
            lunarDate.month, lunarDate.day = m, daysInLunar
            break
        else
            daysInLunar, m, bitMask = daysInLunar - daysInMonth, m + 1, math.floor(bitMask / 2)
        end
    end

    local leapM = getYearInfo(lunarDate.year, 1)
    if leapM > 0 and leapM < lunarDate.month then
        lunarDate.month = lunarDate.month - 1
        if leapM == lunarDate.month then lunarDate.leap = true end
    end

    -- 组装输出格式
    lunarDate.lunarDate_YMD = year_to_cn(lunarDate.year) .. "年" .. 
                              (lunarDate.leap and "闰" or "") .. lunarMonthShuXu[lunarDate.month] .. "月" .. 
                              lunarDayShuXu[lunarDate.day]
    
    local ganZhiYear = tianGan[((lunarDate.year - 4) % 60) % 10 + 1] .. diZhi[((lunarDate.year - 4) % 60) % 12 + 1]
    local animal = animalSign[((lunarDate.year - 4) % 60) % 12 + 1]
    local monthStr = (lunarDate.leap and "闰" or "") .. lunarMonthShuXu[lunarDate.month]
    local dayStr = lunarDayShuXu[lunarDate.day]
    local dayGanZhi = tianGan[(lunarDate.daysToBase % 60) % 10 + 1] .. diZhi[(lunarDate.daysToBase % 60) % 12 + 1]

    -- 优化：使用全角括号 （） 替代半角 ()，更符合中文排版
    lunarDate.lunarDate_1 = ganZhiYear .. "年" .. monthStr .. "月" .. dayStr
    lunarDate.lunarDate_2 = animal .. "年" .. monthStr .. "月" .. dayStr
    lunarDate.lunarDate_3 = ganZhiYear .. "年" .. monthStr .. "月" .. dayGanZhi .. "日"
    lunarDate.lunarDate_4 = ganZhiYear .. "（" .. animal .. "）年" .. monthStr .. "月" .. dayStr

    return lunarDate
end

-- =====================================================================
-- 主翻译器逻辑
-- =====================================================================

local function translator(input, seg)
   ---@type string[]
   local datetimes = {}
   
   if (input == "orq") then
      local now = os.time()
      local clean_date = os.date("%Y年%m月%d日", now):gsub("([年月])0(%d)", "%1%2")
      table.insert(datetimes, clean_date)      table.insert(datetimes, os.date("%Y-%m-%d", now))
      table.insert(datetimes, os.date("%Y%m%d", now))
      
   elseif (input == "osj") then
      local now = os.time()
      local clean_time = os.date("%H时%M分%S秒", now):gsub("0(%d)", "%1")
      table.insert(datetimes, clean_time)
      table.insert(datetimes, os.date("%H:%M:%S", now))
      table.insert(datetimes, os.date("%H%M%S", now))
      
   elseif (input == "oxq") then
      local now = os.time()
      local week_tab = {'日', '一', '二', '三', '四', '五', '六'}
      local text = week_tab[tonumber(os.date("%w", now)) + 1]
      table.insert(datetimes, "星期" .. text)
      
   elseif (input == "ors") then
      local now = os.time()
      local clean_datetime = os.date("%Y年%m月%d日%H时%M分%S秒", now):gsub("([年月日时分])0(%d)", "%1%2")
      table.insert(datetimes, clean_datetime)
      
      local week_tab = {'日', '一', '二', '三', '四', '五', '六'}
      local text = week_tab[tonumber(os.date("%w", now)) + 1]
      local final_str = clean_datetime:gsub("(日)", "%1（星期" .. text .. "）")
      table.insert(datetimes, final_str)
      
      table.insert(datetimes, os.date("%Y-%m-%d %H:%M:%S", now))   
      
      local datetime_str = os.date("%Y-%m-%dT%H:%M:%S", now)
      local utc_date, local_date = os.date("!*t", now), os.date("*t", now)
      utc_date.isdst, local_date.isdst = false, false
      local diff_seconds = os.time(local_date) - os.time(utc_date)
      
      local sign = diff_seconds < 0 and "-" or "+"
      if diff_seconds < 0 then diff_seconds = -diff_seconds end
      local timezone_str = string.format("%s%02d:%02d", sign, math.floor(diff_seconds / 3600), math.floor((diff_seconds % 3600) / 60))
      table.insert(datetimes, datetime_str .. timezone_str)
      
      table.insert(datetimes, os.date("%Y%m%d%H%M%S", now))
      table.insert(datetimes, tostring(now))

   elseif (input == "onl") then
      -- 获取当前公历日期并转换
      local today = os.date("%Y%m%d")
      local y, m, d = tonumber(today:sub(1,4)), tonumber(today:sub(5,6)), tonumber(today:sub(7,8))
      local lunar = solar2Lunar(y, m, d)
      
      if lunar and lunar.lunarDate_YMD and lunar.lunarDate_YMD ~= "" then
         -- 1. 简洁版 (优先): 二〇二六年九月初三
         table.insert(datetimes, lunar.lunarDate_YMD)         -- 2. 详细版: 丙午（马）年九月初三
         table.insert(datetimes, lunar.lunarDate_4)
         -- 3. 干支日版: 丙午年九月丙寅日
         table.insert(datetimes, lunar.lunarDate_3)
      end
   end
   
   for _, entry in ipairs(datetimes) do
      ---@cast entry string
      rime.yield(rime.Candidate("datetime", seg.start, seg._end, entry, ""))
   end
end

return translator