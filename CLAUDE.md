# SuperSocial

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer. Forever APIs are called directly.
- `main` holds the Forever version. `1.15.x-backup` keeps the dual-client 4.1.0 and stays untouched.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`.

## Rules

- Send with `C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)`, which is not protected, and filter with `ChatFrameUtil.AddMessageEventFilter`. The bare `SendChatMessage` and `ChatFrame_AddMessageEventFilter` exist only in `Blizzard_Deprecated*`.
- Guard every secret with `value == nil or canaccessvalue(value)`, never `issecretvalue`.
- Every command checks `C_ChatInfo.InChatMessagingLockdown()` before it starts. On `ADDON_RESTRICTION_STATE_CHANGED` the lockdown is re-read one frame later, since an activating restriction is enforced once the dispatch completes. The payload is not read, because no source says which restriction types hide chat, and the 10 s echo sweep stays as the backstop.
- No Blizzard hooks and no writes to `ChatTypeInfo`. A write to `ChatTypeInfo.WHISPER` taints Blizzard's secret-sender comparison in `ChatFrameOverrides.lua`.
- Every name comparison goes through the one name rule in `Core/Names.lua`: echo confirmation, block and cooldown lists, group skip, the self skip, `/rr` and the echo mute filter.
- `ns.UnitFullName` mirrors Blizzard's `GetFullPlayerName` (`UnitPopupUtils.lua`), and `/wt` sends that form. An exact `/who` needs the hyphen form (`C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator`).
- `/ww`, `/wf`, `/ws` and `/rr` skip groupmates through the one `ns.GroupSkip` in `Core/Group.lua`. `/ww` and `/wf` leave you out of the pool silently, and `/wf` does the same with rows outside its preset, so the opening line counts only the class and level it names.
- `/wf` presets build a `/who` query from `WHO_TAG_CLASS`, `LOCALIZED_CLASS_NAMES_MALE`, `GetMaxPlayerLevel()` and `WHO_TAG_ZONE` with `GetAreaText()`, the way Blizzard's Who panel writes its default query, and run it through the same `runWho` and `dispatchWho` as `/ww -who`. Rows are post-filtered on `WhoInfo.filename` and `level`. Service levels come from Wowhead Forever spell pages. Defaults are `-limit 10` and `-cd 15`; the last message per kind is kept in `SuperSocialDB.findMessages`.
- `-in` belongs to `/wf` only. Every other command rejects it by name, like `-who` on `/ws` and `/rr`.
- Run echoes are always muted. There is no quiet toggle.
- `/ss` and `/supersocial` are the one short and one long admin command. The bare form toggles the cheat sheet.
- `/ws` reads sellers only from `ItemSearchResultInfo.owners` and `CommoditySearchResultInfo.owners`. It tracks the listing by `ITEM_SEARCH_RESULTS_UPDATED` and `COMMODITY_SEARCH_RESULTS_UPDATED`, not off Blizzard's window, because Auctionator's tabs clear `AuctionHouseFrame.displayMode`.
- No literal colour codes. Every chat line opens with the shared `YELLOW_FONT_COLOR:WrapTextInColorCode("[Super Social]:") .. " "`. Lead tints: `GREEN_FONT_COLOR` sent or done, `RED_FONT_COLOR` skipped or failed, `LIGHTBLUE_FONT_COLOR` bookkeeping.
- UI goes through the embedded LibNativeUI-1.0 (load LibStub first, never edit `Libs/`). The `/ss` window is a cheat sheet: one 12 px line per command and flag, no examples, no scroll frame, 4 px grid. The addon menu entry opens a `MenuUtil` context menu whose find rows call `ChatFrameUtil.OpenChat`.
- Menu entries and headings use Title Case, chat lines sentence case ending with a period. No em or en dashes and no `|` in chat strings.
- Left out on purpose: the Questie integration, and the whisper colour blend, which would need that `ChatTypeInfo.WHISPER` write.
- The toc version stays 1.0.0 until the first CurseForge release.

## Checks

- Run both harness modes from `Tools/README.md` after every change. Both must pass.
- Turn on `/console scriptErrors 1` before testing in game. In-game tests need an alt and a second player.
