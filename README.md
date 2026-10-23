# Super Social

Run a `/who` search, then `/ww MESSAGE` whispers everyone in the results. That's the whole idea.

## Features

- One command whispers every result of your last `/who`, paced at the fastest rate the server allows.
- `/wf` finds a warlock to summon you, a mage for a portal or water, or clickers in your zone, and whispers them.
- Filters cap the count, skip or target classes, zones and names, and fold the `/who` search into the command.
- Recipient cooldowns keep a repeated broadcast from reaching the same person twice. They are account-wide and survive relogs.
- `/rr` answers everyone who whispered you back and hasn't been answered yet, across several runs, never twice.
- `/ws` whispers every seller in the item listings open in the auction house.
- A permanent block list names players no command will whisper.
- A run shows one status line that rewrites itself in place instead of fifty `To Playername:` lines.
- Sends count only once the server echoes them, so "sent" means the server took it.
- A `;` in the message sends it as two back-to-back whispers.
- Never whispers you. `/ww`, `/wf`, `/ws` and `/rr` also skip your party or raid and anyone grouped with you in the last 15 minutes.

## Installation

1. Copy the `SuperSocial/` folder into `_classic_beta_/Interface/AddOns/` of your WoW Forever install.
2. Restart the game or `/reload`.
3. Enable Super Social in the AddOns list.

## Try it

1. Type `/who 25-30` in chat, or any filter you like.
2. When the results appear, type `/ww WTB Wool Cloth 1g/stack`.
3. Everyone in your results gets the whisper.

## Find a service

`/wf KIND MESSAGE` runs a preset `/who`, keeps only the class and levels it asked for and whispers up to 10 of them on a 15-minute cooldown. Running it again reaches the next 10.

| Kind | Who it finds |
| --- | --- |
| `summon` | Warlocks level 20 to 60, anywhere. Ritual of Summoning needs the warlock plus two clickers in your group. |
| `port` | Mages level 40 to 60 in your zone. City portals start at 40, Darnassus and Thunder Bluff at 50. |
| `water` or `food` | Mages from your level to 60 in your zone, so the water they conjure is one you can drink. |
| `click` | Every player in your zone. |

- `-in (Zone Name)` searches that zone instead of yours, for example `/wf summon -in (Searing Gorge) need a summon`.
- `-limit` and `-cd` override the defaults. `-skip` and `-only` work as on `/ww`.
- A bare `/wf port` repeats the last message you sent with that kind.
- The addon menu at the minimap opens a menu with Find Warlock (Summon), Find Clickers Here, Find Mage (Portal), Find Mage (Food and Water) and Command Reference. Each find row opens the chat box with the command typed.

## Flags for /ww

Use any, all or none. Order doesn't matter, but flags go before the message. A single number stands bare, anything longer goes in brackets.

| Flag | Example | Effect |
| --- | --- | --- |
| `-limit N` | `-limit 10` | Whisper only the first N results |
| `-skip (…)` | `-skip (warlock maraudon)` | Drop anyone whose class, zone or name contains a word in the brackets |
| `-only (…)` | `-only (priest paladin)` | Whisper only people matching a word in the brackets |
| `-cd D` | `-cd 30`, `-cd 2h`, `-cd 30d` | Skip anyone on cooldown, then put each recipient on cooldown for the duration |
| `-cd` | `-cd` | Honour existing cooldowns without adding anyone new to the list |
| `-who (…)` | `-who (mage 50-60 stormwind)` | Run the `/who` as part of the command, quietly |
| `-in (…)` | `-in (Searing Gorge)` | `/wf` only: search that zone instead of yours |

To aim a `-skip` or `-only` word at one field, lead it with the key `/who` uses: `c-` class, `z-` zone, `n-` name. Phrases with spaces go in quotes: `-skip (z-"Blackrock Depths")`.

A bare `-cd` number is minutes; `s`, `m`, `h` and `d` set seconds, minutes, hours and days. Leaving `-cd` off entirely ignores the cooldown list: everyone gets whispered and nobody is recorded. `/wf` is the exception and defaults to `-cd 15`.

`-limit` and `-cd` also work on `/ws`, and `-limit` on `/rr`. `/rr` refuses `-cd`, because cooldowns guard new whispers, not answers. `/ws` refuses `-skip`, `-only` and `-who`, because sellers carry no class or zone.

```
/ww -who (55-60) -limit 20 -skip (c-warlock) -cd 15 LFM SM live, need 1 tank
```

Up to 20 non-warlocks between 55 and 60, on a 15-minute cooldown.

## Commands

| Command | What it does |
| --- | --- |
| `/ww MESSAGE` | Whisper everyone in your `/who` results |
| `/wf KIND MESSAGE` | Find warlocks, mages or players for a service and whisper them |
| `/wt MESSAGE` | Whisper your current target |
| `/ws MESSAGE` | Whisper every seller in the item listings open in the auction house |
| `/rr MESSAGE` | Reply to everyone whispered via `/ww` or `/wf` who answered and is still waiting |
| `/rr` | Report how many people are waiting, naming them when there are ten or fewer |
| `/rr reset` | Forget all tracked recipients and their replies |
| `/ss` or `/supersocial` | Open the command reference (also from Command Reference in the addon menu at the minimap) |
| `/ss stop` | Cancel any whispers still queued |
| `/ss rate` | Show the learned send rate, `/ss rate reset` restores the default |
| `/ss -cd` | Show how many names are on cooldown and how long the longest runs |
| `/ss -cd NAME [DURATION]` | Put a player on cooldown by hand (30 days by default) |
| `/ss -cd clear` | Empty the cooldown list |
| `/ss -block NAME` | Block a player permanently; `-block list` and `-unblock NAME` manage the list |

## Requirements

WoW Forever 1.60.x (`## Interface: 16001`). No dependencies. LibStub and LibNativeUI-1.0 are embedded.

## Restrictions

- The server rate-limits whispers: roughly 10 of burst, then under one per second. The queue paces itself to stay just under that limit and calibrates the exact rate over a few runs, so a long run takes as long as the server makes it take.
- `/who` itself is throttled to about one search every few seconds. A `-who` run that gets throttled aborts with a notice rather than whispering the previous search's list.
- `/who` results are capped by the server. A capped answer reports the total so you can narrow the filter.
- `/wf` reads your zone from the client and asks `/who` for it by name. Whether the server matches every zone name that way is still to be confirmed in game.
- Offline players, players ignoring you and ambiguous names are dropped from the run rather than retried.
- The auction house names sellers only in an item's own listings, on the Buy, Sell or Auctions tab, never on the Browse list. Open an item first, then `/ws`. It reads the rows loaded so far, skips your own auctions and your groupmates like `/ww` does, and can't reach sellers a row leaves unnamed ("Sellers: A, B, and 3 more"). Whether the server fills in seller names on WoW Forever is still to be confirmed in game.
- Whisper echoes and sender names are hidden from addons inside encounters, PvP matches and restricted maps such as dungeons and raids. `/ww`, `/wf`, `/wt`, `/ws` and `/rr` refuse to start there with `Chat restricted here.`, and a run that walks into such content stops before anything is resent.
- A character has a first name and a surname. `/wt` whispers `First Surname`, and every name comparison treats `First Surname`, `First-Surname` and `First` as one player. A bare first name on the block or cooldown list covers every player with that first name; add the surname with a hyphen (`/ss -block Thrall-Stormborn`) to name one player.
- The modifier-click shortcuts (whisper, invite, add friend) live in the separate SocialShortcuts addon.

## Development

`Tools/harness.lua` runs the addon offline against a stub 1.60.1 client. See `Tools/README.md`.
