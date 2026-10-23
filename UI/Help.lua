local _, ns = ...

-- The /ss cheat sheet, one line per command and flag, and the addon menu entry that opens the find shortcuts.

local UI = LibStub("LibNativeUI-1.0")

local TITLE = "Super Social"

-- Matches the toc IconTexture.
local ICON = 134149
local PANEL_WIDTH = 480

-- 60 native title and attic, 16 + three sections 24 apart + 16, 4 native inset bottom.
local PANEL_HEIGHT = 572
local LABEL_WIDTH = 128

-- One 12 px line plus a tight gap, so 23 rows fit without a scroll frame.
local LINE_PITCH = 16

local SECTIONS = {
    {
        title = "Commands",
        rows = {
            { "/ww MESSAGE", "Whisper everyone in your /who results." },
            { "/wf KIND MESSAGE", "Find and whisper: summon, port, water or click." },
            { "/wt MESSAGE", "Whisper your target." },
            { "/ws MESSAGE", "Whisper the sellers of the open AH listing." },
            { "/rr MESSAGE", "Answer everyone who replied." },
            { "/rr", "List who is still waiting." },
            { "/rr reset", "Forget every tracked reply." },
            { "/ss stop", "Cancel the whispers still queued." },
            { "/ss rate [reset]", "Show or reset the learned send rate." },
        },
    },
    {
        title = "Flags",
        rows = {
            { "-limit N", "Whisper the first N only." },
            { "-cd D", "Skip and set cooldowns: 30, 30m, 2h or 30d." },
            { "-cd", "Skip cooldowns without recording anyone." },
            { "-skip (…)", "Drop class, zone or name matches." },
            { "-only (…)", "Keep only class, zone or name matches." },
            { "-who (…)", "Run the /who first, quietly." },
            { "-in (…)", "Search this zone instead of yours. /wf only." },
            { ";", "Split the message into two whispers." },
        },
    },
    {
        title = "Lists",
        rows = {
            { "/ss -block NAME", "Never whisper this player." },
            { "/ss -unblock NAME", "Remove a player from the block list." },
            { "/ss -block list", "Show the block list." },
            { "/ss -cd NAME [D]", "Put a player on cooldown, 30d by default." },
            { "/ss -cd", "Show how many are on cooldown." },
            { "/ss -cd clear", "Empty the cooldown list." },
        },
    },
}

-- One row: the gold command, then its white meaning. Word wrap is off, so a long line truncates instead of pushing the next row down.
local function addRow(body, index, command, meaning)
    local y = -(index - 1) * LINE_PITCH

    local label = UI.CreateText(body, "heading")
    label:SetPoint("TOPLEFT", 0, y)
    label:SetWidth(LABEL_WIDTH)
    label:SetWordWrap(false)
    label:SetText(command)

    local text = UI.CreateText(body, "body")
    text:SetPoint("TOPLEFT", LABEL_WIDTH + UI.Space.gap, y)
    text:SetPoint("TOPRIGHT", 0, y)
    text:SetWordWrap(false)
    text:SetText(meaning)
end

local function addSection(inset, spec, above)
    local section = UI.CreateSection(inset, spec.title)
    if above then
        UI.StackBelow(section, above)
    else
        section:SetPoint("TOPLEFT", UI.Space.padding, -UI.Space.padding)
        section:SetPoint("TOPRIGHT", -UI.Space.padding, -UI.Space.padding)
    end
    for index, row in ipairs(spec.rows) do
        addRow(section.body, index, row[1], row[2])
    end
    section:SetBodyHeight(#spec.rows * LINE_PITCH - UI.Space.tight)
    return section
end

local function buildPanel()
    SuperSocialDB = SuperSocialDB or {}
    SuperSocialDB.position = SuperSocialDB.position or {}
    local panel = UI.CreateWindow({
        name = "SuperSocialFrame",
        title = TITLE,
        icon = ICON,
        width = PANEL_WIDTH,
        height = PANEL_HEIGHT,
        position = SuperSocialDB.position,
        buttonBar = false,
    })
    local above
    for _, spec in ipairs(SECTIONS) do
        above = addSection(panel.Inset, spec, above)
    end
    return panel
end

ns.TogglePanel = UI.CreateToggle(buildPanel)

-- Each find row opens the chat box with the command typed, so the player only adds the message, or presses Enter to repeat the last one.
local function openFind(kind)
    return function() ChatFrameUtil.OpenChat("/wf " .. kind .. " ") end
end

local function fillMenu(_, root)
    root:CreateTitle(TITLE)
    root:CreateButton("Find Warlock (Summon)", openFind("summon"))
    root:CreateButton("Find Clickers Here", openFind("click"))
    root:CreateButton("Find Mage (Portal)", openFind("port"))
    root:CreateButton("Find Mage (Food and Water)", openFind("water"))
    root:CreateDivider()
    root:CreateButton("Command Reference", ns.TogglePanel)
end

-- Addon Compartment entry points named in the toc. The click hands over only the mouse button, no frame, so the menu opens at the cursor.
function SuperSocial_CompartmentClick()
    MenuUtil.CreateContextMenu(nil, fillMenu)
end

function SuperSocial_CompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, TITLE)
    GameTooltip_AddInstructionLine(GameTooltip, "Click to find a warlock, mage or clickers.")
    GameTooltip:Show()
end

function SuperSocial_CompartmentLeave()
    GameTooltip:Hide()
end
