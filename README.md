# EzAcquaintances

A roleplay contact book for WoW Forever and Classic Era. The addon logs who you met; you write who they are.

Forever turned off the old friend list, so there's nowhere to remember the people you roleplayed with. EzAcquaintances fills that gap without filling up with every passerby: only meaningful contact counts.

## Recent faces (automatic)

Someone lands in **Recent faces** when you:

- group with them (parties and raids),
- whisper each other, both ways, within 10 minutes,
- trade with them,
- duel them (either of you asks),
- they buff you (the game names the caster when it's your target or in your group, as when you ask with Buff Me Please or order them with EzMinion; Classic Era also catches anyone in range through the combat log), or you thank your target with Buff Me Please's or EzMinion's thanks button,
- they emote at you (`/wave` at you, or an `/e` line with your name in it),
- you target them and you both speak in `/say` within a minute.

For each person it keeps where and when you first met (zone, subzone, date) and how, when you last saw them, how many times you've met (contacts more than 30 minutes apart), and their race, class and level when the game tells us (targeting, mouseover, group, chat). Names the game hides (Forever dungeons and raids) are skipped. EzAcquaintances never sends chat.

Recent faces you never add to the Book are forgotten after 14 days.

## The Book (by hand)

Click **Add to book** and fill in:

- **Known as**: an alias or title,
- **Relationship**: stranger, friend, rival, sweetheart, employer...,
- **Tags**: ally, rival, suspicious, owes me gold, ... or type your own,
- **Note**: free text.

People in your book show your alias, relationship, tags and the start of your note on their tooltip, and a small badge by the target frame while you target them (drag it where you like, click it to open them in your book).

Right-click a name in the list to target them when they're nearby (out of combat; you keep your current target if they aren't in view).

Each character keeps its own book. An account-wide index remembers which of your characters met whom, so the book can tell you "Bob met them 2026-09-10 in Goldshire".

Other addons can add a tab of their own to the book with `EzAcquaintancesAPI.AddTab` (see the end of `UI.lua`): EzMinion lists a warlock's graduates there.

## Commands

| Command | |
| --- | --- |
| `/acq` (`/ezacq`) | open or close the book |
| `/acq add [name] [note]` | add someone (or your target) to the book |
| `/acq note <name> <text>` | set their note (empty clears it) |
| `/acq tag <name> <tag>` | toggle a tag; a new word becomes a tag of your own |
| `/acq forget <name>` | remove them completely |
| `/acq who <name>` | print what you know about them |
| `/acq icon`, `badge`, `tooltip`, `quiet` | toggle the launcher icon, target badge, tooltip line, new-face messages |
| `/acq reset` | reset window, icon and badge positions |

Names with a surname go in quotes: `/acq note "Sephrina Gam" owes me 5g`. A first name alone works too.

Key binding: Options > Keybindings > EzAcquaintances. Right-click the launcher icon for options, where each way of meeting someone can be switched off.
