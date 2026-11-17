local addonName, ns = ...

local strbyte, strsub, strfind, strgsub = string.byte, string.sub, string.find, string.gsub
local concat, tinsert = table.concat, table.insert

----------------------------------------------------------------------
-- build the lookup tables from the data blobs
----------------------------------------------------------------------
local charMap, twMap, phraseMap, fixes = {}, {}, {}, {}
local firstLen = {}        -- longest phrase starting with a given character
local MAXLEN = ns.MAXLEN or 16

local function charLen(s, i)
    local b = strbyte(s, i)
    if not b then return nil end
    if b < 0x80 then return 1 elseif b < 0xE0 then return 2
    elseif b < 0xF0 then return 3 else return 4 end
end

-- CHARS / TWVARIANTS are consecutive pairs: simplified then traditional
local function loadPairs(blob, target)
    local i, len, count = 1, #blob, 0
    while i <= len do
        local l1 = charLen(blob, i); if not l1 then break end
        local a = strsub(blob, i, i + l1 - 1); i = i + l1
        local l2 = charLen(blob, i); if not l2 then break end
        local b = strsub(blob, i, i + l2 - 1); i = i + l2
        target[a] = b
        count = count + 1
    end
    return count
end

local nChars = loadPairs(ns.CHARS, charMap)
local nTw = loadPairs(ns.TWVARIANTS, twMap)

local nPhrases = 0
for src, dst in ns.PHRASES:gmatch("([^\t\n]+)\t([^\t\n]+)") do
    phraseMap[src] = dst
    nPhrases = nPhrases + 1
    local l = charLen(src, 1)
    local head = strsub(src, 1, l)
    -- length in characters, not bytes
    local cl, i = 0, 1
    while i <= #src do
        local c = charLen(src, i); if not c then break end
        cl = cl + 1; i = i + c
    end
    if (firstLen[head] or 0) < cl then firstLen[head] = cl end
end

for src, dst in ns.FIXES:gmatch("([^\t\n]+)\t([^\t\n]+)") do
    tinsert(fixes, {src, dst})
end

ns.CHARS, ns.TWVARIANTS, ns.PHRASES, ns.FIXES = nil, nil, nil, nil

----------------------------------------------------------------------
-- the converter
----------------------------------------------------------------------
local cache = {}
local cacheCount = 0

local function convert(s)
    if type(s) ~= "string" or s == "" then return s end
    local hit = cache[s]
    if hit then return hit end
    if not strfind(s, "[\128-\255]") then      -- pure ASCII, nothing to do
        cache[s] = s
        return s
    end

    -- split into characters once
    local chars, n = {}, 0
    local i, len = 1, #s
    while i <= len do
        local l = charLen(s, i); if not l then break end
        n = n + 1
        chars[n] = strsub(s, i, i + l - 1)
        i = i + l
    end

    local out, k, pos = {}, 0, 1
    while pos <= n do
        local c = chars[pos]
        local maxTry = firstLen[c]
        local matched
        if maxTry then
            if pos + maxTry - 1 > n then maxTry = n - pos + 1 end
            for L = maxTry, 2, -1 do
                local seg = concat(chars, "", pos, pos + L - 1)
                local v = phraseMap[seg]
                if v then
                    k = k + 1; out[k] = v
                    pos = pos + L
                    matched = true
                    break
                end
            end
        end
        if not matched then
            k = k + 1; out[k] = charMap[c] or c
            pos = pos + 1
        end
    end
    local r = concat(out)

    -- second pass: Taiwan variants (single characters)
    if strfind(r, "[\128-\255]") then
        local o2, k2 = {}, 0
        local j, rl = 1, #r
        while j <= rl do
            local l = charLen(r, j); if not l then break end
            local ch = strsub(r, j, j + l - 1)
            k2 = k2 + 1; o2[k2] = twMap[ch] or ch
            j = j + l
        end
        r = concat(o2)
    end

    for idx = 1, #fixes do
        local f = fixes[idx]
        if strfind(r, f[1], 1, true) then
            r = strgsub(r, f[1], f[2])
        end
    end

    if cacheCount > 20000 then        -- keep memory bounded
        cache = {}
        cacheCount = 0
    end
    cache[s] = r
    cache[r] = r                      -- converting again is a no-op
    cacheCount = cacheCount + 2
    return r
end

ns.Convert = convert

----------------------------------------------------------------------
-- hook RXP's display path
----------------------------------------------------------------------
local hooked = {}

local function hookStepText()
    local RXP = _G.RXP
    if hooked.steps or not RXP or type(RXP.ReplaceNpcIds) ~= "function" then return end
    local orig = RXP.ReplaceNpcIds
    RXP.ReplaceNpcIds = function(text, element)
        local r = orig(text, element)
        if type(r) == "string" then return convert(r) end
        return r
    end
    hooked.steps = true
end

local function hookMenuNames()
    local RXP = _G.RXP
    if hooked.menu or not RXP then return end
    -- SwapNames() consults RXP.GuideNames first; a metatable converts on demand
    local existing = RXP.GuideNames or {}
    RXP.GuideNames = setmetatable({}, {
        __index = function(t, key)
            if type(key) ~= "string" then return nil end
            local v = existing[key]
            if v then return v end
            v = convert(key)
            if v == key then return nil end
            rawset(t, key, v)
            return v
        end,
    })
    hooked.menu = true
end

local function hookGuideName()
    local RXP = _G.RXP
    if hooked.name or not RXP or type(RXP.GetGuideName) ~= "function" then return end
    local orig = RXP.GetGuideName
    RXP.GetGuideName = function(...)
        local r = orig(...)
        if type(r) == "string" then return convert(r) end
        return r
    end
    hooked.name = true
end

local function hookHeader()
    if hooked.header then return end
    local frame = _G.RXPFrame
    local gn = frame and frame.GuideName
    local fs = gn and gn.text
    if not fs or type(fs.SetText) ~= "function" then return end
    local orig = fs.SetText
    fs.SetText = function(self, txt, ...)
        if type(txt) == "string" then txt = convert(txt) end
        return orig(self, txt, ...)
    end
    hooked.header = true
end

local function applyHooks()
    hookStepText()
    hookMenuNames()
    hookGuideName()
    hookHeader()
    return hooked.steps and hooked.menu and hooked.name and hooked.header
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    if applyHooks() then self:UnregisterAllEvents() end
end)

----------------------------------------------------------------------
-- /rxptc  — status and a quick self-test
----------------------------------------------------------------------
SLASH_RXPTC1 = "/rxptc"
SlashCmdList["RXPTC"] = function(msg)
    local function say(s) print("|cff46bf72RXP 繁化|r " .. s) end
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    if msg ~= "" then
        say(msg .. "  ->  " .. convert(msg))
        return
    end
    say(("字典：單字 %d、台灣變體 %d、詞組 %d"):format(nChars, nTw, nPhrases))
    say(("掛鉤：步驟 %s｜選單 %s｜攻略名 %s｜標題 %s"):format(
        hooked.steps and "OK" or "未掛", hooked.menu and "OK" or "未掛",
        hooked.name and "OK" or "未掛", hooked.header and "OK" or "未掛"))
    say("測試：无限指南 22-30级  ->  " .. convert("无限指南 22-30级"))
    say("用法：/rxptc <要測試的文字>")
end
