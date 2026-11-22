# ForeverCraftTimers

Tracks the **Transmute** (all transmutes share one cooldown), **Mooncloth** and **Salt Shaker** cooldowns on
all your characters, and tells you on whichever character you're playing when one is ready.

## Install
Unzip into `World of Warcraft/_forever_/Interface/AddOns`, so you get `AddOns/ForeverCraftTimers/ForeverCraftTimers.toc`.

## Use
- Log in once on each crafter. Cooldowns that are already running are picked up then.
- Hover the minimap button (clock icon) to see every character's timers. With a minimap addon that groups
  buttons (e.g. EllesmereUI), it's in that addon's button menu.
- When a cooldown is ready you get big text in the middle of the screen. Ones that came off while you were
  offline show a few seconds after login. Alerts wait until you're out of combat.
- A time with `~` is an estimate made when you cast. Opening the profession window reads the real time.

## Commands
- `/fct`: list everything in chat
- `/fct set mooncloth 2d5h` (or `transmute`, `salt`; `ready`): fix this character's timer by hand
- `/fct forget Name`: remove a character
- `/fct debug`: what the game reports, for bug reports
- `/fct options`: turn the alerts or the minimap button on or off

## Limits
- Characters are shared only within one WoW account (saved variables are per account). Alts on a second
  account on the same Battle.net have their own list.
- A Salt Shaker kept in the bank shows as Ready until it's back in your bags and its cooldown can be read.
