# ForeverCraftTimers handoff

Goal: track Transmute (shared cooldown, all transmutes), Mooncloth and Salt Shaker cooldowns on every
character; big on-screen alert on whichever character you're on when any of them is ready (also at
login for ones that ran out while offline); minimap button whose tooltip lists each character's timers.

Personal use only: no release workflow, no remote yet.

## Files
- `Timers.lua`: saved records (`ForeverCraftTimersDB.chars["Name-Realm"].cds[key]`, epoch `expires`) and pure logic.
- `Scanner.lua`: reads live cooldowns (`C_Spell.GetSpellCooldown`, `C_Container.GetItemCooldown`) at login,
  on SPELL/BAG_UPDATE_COOLDOWN, and after UNIT_SPELLCAST_SUCCEEDED (which first stores a fallback duration).
- `Alerts.lua`: `RaidWarningUtil.AddMessage` (Forever: Blizzard_RaidWarning/RaidWarningUtil.lua:28), 15 s ticker.
- `Launcher.lua`: LDB + LibDBIcon (vendored in `Libs/`, copied from ForeverBossAnalyzer).
- Slash: `/fct`, `/fct set <transmute|mooncloth|salt> <2d5h|ready>`, `/fct forget <Name>`, `/fct scan`, `/fct test`.

## Commands
- `lua tests/run.lua`
- `dev/forever/install.sh`, then `/reload`

## Still to verify in game
- Does `C_Spell.GetSpellCooldown` report profession cooldowns (Arcanite 17187, Mooncloth 18560) with the
  trade window closed? If not, `/fct set` is the fallback; consider adding a TRADE_SKILL_SHOW scan.
- Salt Shaker: item 15846 cooldown via `C_Container.GetItemCooldown`; the cast is matched by the name "Salt Shaker"
  or spell 19566 (ID unverified).
- Fallback durations (transmute 2d, Mooncloth 4d, Salt Shaker 3d) are only used until the live cooldown is
  read; check they match Forever.
- Transmute spell IDs other than 17187/11479/11480 are from memory; the cast is matched by the "Transmute" name.
