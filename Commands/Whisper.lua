local _, ns = ...

-- The outgoing commands: /ww blasts the current or a fresh /who list, /wf runs a preset /who for a service and blasts it, /wt whispers the selected player, and /ws whispers the sellers of the auction house listing on screen. All hand every whisper to the queue.

local ok = ns.Ok
local fail = ns.Fail
local note = ns.Note
local plural = ns.Plural
local trim = ns.Trim
local parseDuration = ns.ParseDuration
local DURATION_HINT = ns.DurationHint
local refuseRestricted = ns.RefuseRestricted

local function whisperTarget(input)
    input = trim(input)
    local tokens = {}
    for t in input:gmatch("%S+") do tokens[#tokens + 1] = t end
    local cursor = 1
    local cooldownSeconds
    if tokens[cursor] and tokens[cursor]:lower() == "-cd" then
        cooldownSeconds = tokens[cursor + 1] and parseDuration(tokens[cursor + 1])
        if not cooldownSeconds then
            fail("-cd needs a duration.", DURATION_HINT)
            return
        end
        cursor = cursor + 2
    end
    local parts = ns.SplitWhisper(table.concat(tokens, " ", cursor))
    if #parts == 0 then
        note("Usage: /wt MESSAGE whispers your target, e.g. /wt got room for one more? Add -cd 30d to put them on cooldown.")
        return
    end
    if refuseRestricted() then return end
    if not (UnitExists("target") and UnitIsPlayer("target")) then
        fail("No target selected.", "Pick a player first.")
        return
    end

    -- Built the way Blizzard's own whisper menu builds it: the target keeps its surname, or every namesake with another surname could hear it.
    local targetName, hidden = ns.UnitFullName("target")
    if hidden then
        fail("Target name hidden.", "This map keeps player names from addons.")
        return
    end
    if not targetName then
        fail("No target selected.", "Pick a player first.")
        return
    end
    if ns.IsBlocked(ns.LoadBlocked(), targetName) then
        -- The slash command takes one token, so a "First Surname" is offered in its hyphen spelling.
        local typed = targetName:gsub("%s+", "-")
        fail("Blocked.", targetName .. " is on the block list (/ss -unblock " .. typed .. ").")
        return
    end

    -- Through the queue for cap rescue, flagged personal so /rr treats it as an answer, not a blast.
    for _, part in ipairs(parts) do
        ns.QueueWhisper(part, targetName, "personal")
    end
    if cooldownSeconds then
        ns.LoadCooldowns()[ns.NameKey(targetName)] = time() + cooldownSeconds
        ok("Whispered", targetName .. ", " .. ns.FormatDuration(cooldownSeconds) .. " cooldown.")
    else
        ok("Whispered", targetName .. ".")
    end
end

-- Load the lists a blast reads and writes, once per command.
local function loadLists(opts)
    local lists = { blocked = ns.LoadBlocked() }
    if opts.useCooldown then
        lists.cooldown = ns.LoadCooldowns()
        lists.cooldownSeconds = opts.cooldownSeconds
    end
    return lists
end

-- Cap to -limit, report one status line, queue the sends, stamp the persistent lists and hand the names to /rr.
local function sendBlast(opts, lists, eligible, counts, total, singular, multiple)
    local sendCount = opts.limit and math.min(opts.limit, #eligible) or #eligible
    counts.limit = #eligible - sendCount
    local pool = total .. " " .. plural(total, singular, multiple)

    if sendCount == 0 then
        fail("Nobody to whisper.", "None of " .. pool .. " qualify.")
        ns.SkipLine(counts, total)
        return
    end

    -- One fact per line, in the order they matter: who hears it, who doesn't and why, what the lists recorded, then the message itself. The queue's counter picks up from there.
    local eta = ns.SendEta(sendCount * #ns.SplitWhisper(opts.text))
    local tail = eta and (", " .. eta) or ""
    -- The cooldown rides on the opening line rather than taking one of its own: it is a property of this run, not an event in it.
    if lists.cooldownSeconds then tail = tail .. ", " .. ns.Tint("cool", ns.FormatDuration(lists.cooldownSeconds) .. " cooldown") end
    ok("Whispering", (sendCount == total and "all " or sendCount .. " of ") .. pool .. tail .. ".")
    ns.SkipLine(counts, total - sendCount)
    ns.QuoteMessage(opts.text)

    local sentNames = {}
    for i = 1, sendCount do
        local name = eligible[i]
        ns.QueueWhisper(opts.text, name)
        sentNames[#sentNames + 1] = name
        -- Only a timed -cd records new recipients; bare -cd just reads the list.
        if lists.cooldown and lists.cooldownSeconds then lists.cooldown[ns.NameKey(name)] = time() + lists.cooldownSeconds end
    end

    -- /rr replies to these names once they whisper back.
    ns.TrackWhispered(sentNames)
end

-- A /wf row must be the class and level the preset asked for, so a guild or zone name that merely contains "mage" never slips through the server's text match. filename is nilable, so a row without it trusts the server's class match.
local function fitsPreset(whoInfo, find)
    if not find then return true end
    if find.classFile and whoInfo.filename and whoInfo.filename ~= find.classFile then return false end
    if find.minLevel and whoInfo.level < find.minLevel then return false end
    return not find.maxLevel or whoInfo.level <= find.maxLevel
end

local function dispatchWho(opts)
    -- The who list is RequiresFriendList, which returns nothing while the friend list is unavailable.
    local count, total = C_FriendList.GetNumWhoResults()
    count = count or 0
    if count == 0 then
        fail("No /who results.", "Run /who first, or use -who (…).")
        return
    end
    if total and total > count then
        note(count .. " of " .. total .. " matches shown. Narrow the filter for the rest.")
    end

    local groupSet = ns.BuildGroupSet()
    local lists = loadLists(opts)
    local me = ns.UnitFullName("player")

    -- Keys are the ones ns.SkipLine reads, counted in the order the checks run. You and rows outside a /wf preset leave the pool without a skip reason, because neither is the pool the run names.
    local counts = { blocked = 0, cooldown = 0, filter = 0, group = 0, recentGroup = 0 }
    local eligible = {}
    local pool = count
    for i = 1, count do
        local whoInfo = C_FriendList.GetWhoInfo(i)
        local fullName = whoInfo and whoInfo.fullName
        if fullName and (ns.SameName(fullName, me) or not fitsPreset(whoInfo, opts.find)) then
            pool = pool - 1
        elseif fullName then
            local groupReason = ns.GroupSkip(groupSet, fullName)
            if groupReason then
                counts[groupReason] = counts[groupReason] + 1
            elseif ns.IsBlocked(lists.blocked, fullName) then
                counts.blocked = counts.blocked + 1
            elseif ns.IsFiltered(whoInfo, opts.terms) or not ns.IsIncluded(whoInfo, opts.includeTerms) then
                counts.filter = counts.filter + 1
            elseif lists.cooldown and ns.OnCooldown(lists.cooldown, fullName) then
                counts.cooldown = counts.cooldown + 1
            else
                eligible[#eligible + 1] = fullName
            end
        end
    end

    if opts.find and pool == 0 then
        fail("Nobody found.", "No " .. opts.find.multiple .. " online.")
        return
    end
    local find = opts.find or { singular = "/who result", multiple = "/who results" }
    sendBlast(opts, lists, eligible, counts, pool, find.singular, find.multiple)
end

local WHO_TIMEOUT = 6      -- Seconds to wait for the server's answer before aborting, since the who list still holds the previous search.
local PANEL_RESTORE = 8    -- The server answers some queries seconds late; re-arming the panel too early lets a straggler pop it open.

-- The Group Finder's Who tab is the only WHO_LIST_UPDATE listener, and an update can pop its window open (WhoList.lua UpdateWhoList). It is load-on-demand, so it is looked up per run. Restore wakes it only when the addon took its event away, never when it was not listening.
local deafened

local function deafenWhoUi()
    local panel = LFGWhoListFrame
    if panel and panel:IsEventRegistered("WHO_LIST_UPDATE") then
        panel:UnregisterEvent("WHO_LIST_UPDATE")
        deafened = panel
    end
    C_FriendList.SetWhoToUi(true)
end

-- Put the who plumbing back where the panel expects it: results to chat unless the panel is open, and the panel listening again. IsVisible, because the tab keeps its own shown flag when the Group Finder closes around it, and its OnHide has already sent results back to chat.
local function restoreWhoUi()
    C_FriendList.SetWhoToUi(LFGWhoListFrame ~= nil and LFGWhoListFrame:IsVisible())
    if deafened then deafened:RegisterEvent("WHO_LIST_UPDATE") end
    deafened = nil
end

-- One waiter for every -who run, because frames are never collected and a fresh one per run would leak. The run counter lets a stale timeout recognise that a newer run owns the frame.
local whoWaiter = CreateFrame("Frame")
local whoRun = 0

-- -who runs the search itself: results go to the API list instead of chat, the who panel is deafened so it can't pop open, and the blast waits for this query's own results. A timeout aborts rather than dispatching, because the who list still holds the previous search and whispering those people would be the wrong run.
local function runWho(opts)
    deafenWhoUi()

    whoRun = whoRun + 1
    local run = whoRun
    local function live()
        return run == whoRun and whoWaiter:IsEventRegistered("WHO_LIST_UPDATE")
    end
    local function stop()
        whoWaiter:UnregisterEvent("WHO_LIST_UPDATE")
        whoWaiter:SetScript("OnEvent", nil)
    end

    whoWaiter:RegisterEvent("WHO_LIST_UPDATE")
    -- A /who fires WHO_LIST_UPDATE twice: once to clear the old rows, then again when the server's answer lands. Only the second one carries results.
    whoWaiter:SetScript("OnEvent", function()
        local count = C_FriendList.GetNumWhoResults()
        if not count or count == 0 then return end
        stop()
        dispatchWho(opts)
    end)

    C_Timer.After(WHO_TIMEOUT, function()
        if not live() then return end
        stop()
        if opts.find then
            fail("Nobody found.", "No " .. opts.find.multiple .. " online, or /who is throttled. Retry in a minute.")
        else
            fail("Nobody found.", "\"" .. opts.who .. "\" came back empty or /who is throttled. Retry in a few seconds.")
        end
    end)
    -- Restore on a fixed clock rather than on completion, because a straggling answer after the timeout would otherwise pop the panel. A newer run owns the plumbing by then, so this one leaves it alone or it would route that run's results back to chat.
    C_Timer.After(PANEL_RESTORE, function()
        if run ~= whoRun then return end
        restoreWhoUi()
    end)

    C_FriendList.SendWho(opts.who)
end

local function whisperWho(input)
    local opts = ns.ParseFlags(trim(input))
    if ns.FlagMistake(opts, true) then return end
    if not opts.text or opts.text == "" then
        note("Usage: /ww MESSAGE whispers your /who results, e.g. /ww LFM SM live. /ss lists every flag.")
        return
    end
    if ns.UsedBracket(opts, "-in") then
        fail("-in applies to /wf only.", "Put the zone inside -who, e.g. -who (z-\"Searing Gorge\").")
        return
    end
    if refuseRestricted() then return end
    if opts.who then
        runWho(opts)
    else
        dispatchWho(opts)
    end
end

-- /wf defaults: one helper is enough for a service, and the cooldown makes a retry reach new people instead of the same ones.
local FIND_LIMIT = 10
local FIND_COOLDOWN = 15 * 60

-- Who can provide each service, per Wowhead Forever: Ritual of Summoning (spell 698) from 20, city portals (11417 and siblings) from 40, and water you can drink from a mage of at least your level. A summon reaches you anywhere; the rest need the mage or the clickers where you stand.
local FIND_PRESETS = {
    summon = { classFile = "WARLOCK", minLevel = 20, noun = "warlock", nouns = "warlocks" },
    port = { classFile = "MAGE", minLevel = 40, here = true, noun = "mage", nouns = "mages" },
    water = { classFile = "MAGE", ownLevel = true, here = true, noun = "mage", nouns = "mages" },
    click = { here = true, noun = "player", nouns = "players" },
}

local FIND_USAGE = "Usage: /wf KIND MESSAGE finds and whispers a warlock to summon, a mage to port or for water, or clickers here. KIND is summon, port, water or click, e.g. /wf port LF portal to Undercity. A bare /wf KIND repeats the last message."

-- The last message per kind, so a retry is just /wf port.
local function findMessages()
    SuperSocialDB = SuperSocialDB or {}
    SuperSocialDB.findMessages = SuperSocialDB.findMessages or {}
    return SuperSocialDB.findMessages
end

-- The /who query and the post-filter for one preset, the way Blizzard's Who panel writes its own zone query (FriendsFrame.lua WhoFrame_GetDefaultWhoCommand). Nil when the zone is unknown.
local function buildFind(preset, zone)
    local minLevel = preset.ownLevel and UnitLevel("player") or preset.minLevel
    local maxLevel = minLevel and GetMaxPlayerLevel()
    zone = zone or (preset.here and GetAreaText())
    if zone == "" then return nil end

    local query, scope = {}, {}
    if preset.classFile then query[#query + 1] = WHO_TAG_CLASS .. "\"" .. LOCALIZED_CLASS_NAMES_MALE[preset.classFile] .. "\"" end
    if minLevel then
        local range = minLevel < maxLevel and (minLevel .. "-" .. maxLevel) or tostring(maxLevel)
        query[#query + 1] = range
        scope[#scope + 1] = range
    end
    if zone then
        query[#query + 1] = WHO_TAG_ZONE .. "\"" .. zone .. "\""
        scope[#scope + 1] = "in " .. zone
    end
    local suffix = #scope > 0 and (" " .. table.concat(scope, " ")) or ""
    return {
        who = table.concat(query, " "),
        classFile = preset.classFile,
        minLevel = minLevel,
        maxLevel = maxLevel,
        singular = preset.noun .. suffix,
        multiple = preset.nouns .. suffix,
    }
end

local function whisperFind(input)
    local kind, rest = trim(input):match("^(%S*)%s*(.*)$")
    kind = kind:lower()

    -- food is the same mages as water, and shares its remembered message.
    if kind == "food" then kind = "water" end
    local preset = FIND_PRESETS[kind]
    if not preset then
        note(FIND_USAGE)
        return
    end
    local opts = ns.ParseFlags(rest)
    if ns.FlagMistake(opts, true) then return end
    if ns.UsedBracket(opts, "-who") then
        fail("-who doesn't apply to /wf.", "Each kind runs its own /who. -in (Zone) changes the zone.")
        return
    end
    local messages = findMessages()
    if opts.text == "" then opts.text = messages[kind] or "" end
    if opts.text == "" then
        fail("No message yet.", "Type it after /wf " .. kind .. ".")
        return
    end
    if refuseRestricted() then return end

    local find = buildFind(preset, opts.zone and (opts.zone:gsub("\"", "")))
    if not find then
        fail("Zone unknown.", "Retry once the zone name shows, or add -in (Zone).")
        return
    end
    messages[kind] = opts.text
    opts.find = find
    opts.who = find.who
    opts.limit = opts.limit or FIND_LIMIT
    if not opts.useCooldown then
        opts.useCooldown = true
        opts.cooldownSeconds = FIND_COOLDOWN
    end
    runWho(opts)
end

-- Every seller of the listing once, in listing order, minus yourself. The results already name you "player"; the name check also catches a listing that spells you out.
local function uniqueSellers(sellers)
    local me = ns.UnitFullName("player")
    local seen, names = {}, {}
    for _, name in ipairs(sellers) do
        local key = ns.NameKey(name)
        if key and not seen[key] and not ns.SameName(name, me) then
            seen[key] = true
            names[#names + 1] = name
        end
    end
    return names
end

-- One hint per reason no listing can be read, naming the one step that is missing.
local LISTING_HINTS = {
    closed = { "Auction house closed.", "Open it, then open an item's listings." },
    browse = { "No item listings open.", "Browse rows name no sellers. Open an item's listings first." },
}

local function whisperSellers(input)
    local opts = ns.ParseFlags(trim(input))
    if ns.FlagMistake(opts, true) then return end
    local foreign = ns.UsedBracket(opts, "-who") and "-who" or ns.UsedBracket(opts, "-in") and "-in"
    if foreign then
        fail(foreign .. " doesn't apply to /ws.", "It reads the auction house listings.")
        return
    end

    -- Sellers carry no class or zone, so the term filters can't apply here.
    if #opts.terms > 0 or #opts.includeTerms > 0 then
        fail("-skip and -only don't apply to /ws.", "Sellers carry no class or zone.")
        return
    end
    if not opts.text or opts.text == "" then
        note("Usage: /ws MESSAGE whispers every seller in the item listings open in the auction house, e.g. /ws still selling your Black Lotus?")
        return
    end
    if refuseRestricted() then return end
    local problem = ns.ListingProblem()
    if problem then
        fail(LISTING_HINTS[problem][1], LISTING_HINTS[problem][2])
        return
    end
    local sellers, unnamed = ns.ListingSellers()
    if unnamed > 0 then
        note("Up to " .. unnamed .. " " .. plural(unnamed, "seller", "sellers") .. " unnamed by the auction house, not whispered.")
    end
    local names = uniqueSellers(sellers)
    if #names == 0 then
        fail("No other sellers", "in the open listings.")
        return
    end

    local groupSet = ns.BuildGroupSet()
    local lists = loadLists(opts)

    -- Keys are the ones ns.SkipLine reads, counted in the order the checks run, the same order as /ww.
    local counts = { blocked = 0, cooldown = 0, group = 0, recentGroup = 0 }
    local eligible = {}
    for _, sellerName in ipairs(names) do
        local groupReason = ns.GroupSkip(groupSet, sellerName)
        if groupReason then
            counts[groupReason] = counts[groupReason] + 1
        elseif ns.IsBlocked(lists.blocked, sellerName) then
            counts.blocked = counts.blocked + 1
        elseif lists.cooldown and ns.OnCooldown(lists.cooldown, sellerName) then
            counts.cooldown = counts.cooldown + 1
        else
            eligible[#eligible + 1] = sellerName
        end
    end

    local item = ns.ListingItem()
    local of = item and (" of " .. item) or ""
    sendBlast(opts, lists, eligible, counts, #names, "seller" .. of, "sellers" .. of)
end

SLASH_WHISPERTARGET1 = "/wt"
SlashCmdList["WHISPERTARGET"] = whisperTarget

SLASH_WHISPERWHO1 = "/ww"
SlashCmdList["WHISPERWHO"] = whisperWho

SLASH_WHISPERFIND1 = "/wf"
SlashCmdList["WHISPERFIND"] = whisperFind

SLASH_WHISPERSELLERS1 = "/ws"
SlashCmdList["WHISPERSELLERS"] = whisperSellers
