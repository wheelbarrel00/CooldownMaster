# Cooldown Master Changelog

## 1.11.0 (2026-08-18) — Five languages, all the way through

### New Features

- **Cooldown Master is now fully translated in all five languages.** French, Russian and Korean went from covering only the phrases shared with my other addons to covering the whole addon, and Traditional Chinese went from a third of it to all of it. Every options label, tooltip, message and popup now reads in your client's language. Written in-house with each translator's permission and in their own style, then reviewed end to end.
- **The tag help now translates.** The panel you get when you hover a Text or Label Text box — the one listing `[cd.name]`, `[cd.next]` and the rest — was English for everyone. It was the largest block of untranslated text left in the addon.

### A note on the translations

I am not able to test these in a non-English client — I do not have the other languages installed. Everything passes the automated checks (format specifiers, colour codes, key coverage, cross-references), but those cannot catch a label that runs off its button or a tooltip that sends you to a setting you cannot find.

**So if you see anything off, please tell me and I will fix it.** The Discord button on the addon's About tab, the comments on the CurseForge page, or a [GitHub issue](https://github.com/wheelbarrel00/CooldownMaster/issues) all reach me. Corrections from native speakers are very welcome — a screenshot and the language is plenty to go on.

### Bug Fixes

- **Fixed the Default Lane dropdown in Filters falling back to English.** It was built with translated lane names and then quietly overwritten with hardcoded English ones every time the list refreshed, so on any translated client it reverted the moment you toggled a lane.
- The **Edit** button on each custom cooldown, and the message shown when a profile export fails, were hardcoded English. Both translate now.
- The icon nudge slider on the Lanes and Ready tabs shared a name with the **Offset** stacking style, so one word had to serve as both an adjective and a noun. It has its own name now and reads correctly in every language.
- Corrected three Simplified Chinese tooltips that pointed you at controls using words those controls do not use, so following the instructions led nowhere.

### Improvements

- Swept every language for tooltips naming a setting differently from that setting's own label, for two different settings ending up with the same name on one panel, and for text overflowing its button.
- Simplified Chinese had its machine-assisted first pass reviewed against the English throughout. Wording, terminology and punctuation are consistent with the human-translated phrases now, rather than sitting beside them in a different register.

## 1.10.0 (2026-08-15) — Cooldown Master speaks five languages

### New Features

- **Cooldown Master is now translated.** Every piece of text the addon draws — options, tooltips, ready boxes, the What's New popup — reads in your client's language where a translation exists, and falls back to English where it does not. French, Russian and Korean cover the phrases Cooldown Master shares with my other addons, and will fill in over time.
- **Simplified Chinese covers the whole addon**, but honestly: only the phrases shared with my other addons are human-translated, from 失眠啤酒's work there. The rest is a machine-assisted first pass that no native speaker has reviewed yet. It should be understandable throughout and wrong in places. Corrections are very welcome — see the repo, or the Discord.
- Translations are bundled in the addon itself, so there is nothing to install and nothing to download. Your client language decides, and switching languages switches the addon with it.

### Bug Fixes

- **Fixed custom cooldowns never picking up their real name on a non-English client.** A new custom cooldown starts life called "New Custom", and entering a Trigger ID is supposed to replace that with the ability's actual name. The placeholder was being translated while the check that looked for it was not, so on a translated client the two never matched and the custom kept the placeholder name forever — on its icon tooltip, its bar, and in the custom list.
- **Fixed translated frame names being written into your saved settings.** The default names for lanes, ready boxes and bar frames were being saved in whatever language you first logged in with. Switching your client to another language afterwards would have left them stuck in the old one permanently, because they were no longer defaults but saved values. Frame names are stored in plain English again and are yours to rename as always.
- The Filters column headers (Show, Lane, Bar, Ready Box, Flags) were left in English while the Remove and Buff headers beside them were translated, so a single header row read as two languages at once.
- Several strings that had been missed now translate too, including the lane tooltip for a custom cooldown, the profile import failure message, the on/off button on each custom, and the copy-a-link hint.

### Improvements

- Authored Lua is pinned to LF line endings, so regenerating a translation no longer reports every line in the file as changed and buries the real edit.

### Bug Fixes

- **Retail: fixed an error that fired every time one of your tracked effects on a target ran out.** A tidy-up step added in 1.9.2 for the Classic flavors reached for your target's unique ID, which Midnight keeps secret on a hostile target, and looking it up at all was enough to trigger the error. That step never did anything useful on retail, and the case it was guarding against is now handled where it belongs — when a dot is restored after you switch targets. Your ready boxes and lanes kept working throughout. The cost was an error in your log on each expiry, and a dropped frame of movement with it. Retail only, and only with Offensives switched on.
- **Classic: an effect that leaves nothing to read on your target now keeps improving its own timing.** Something like a Paladin's Consecration puts nothing on your target that Cooldown Master can inspect, so it works out how long the effect lasts by watching when the combat log says it ended, and revises upward as it sees longer runs. The same 1.9.2 tidy-up step was discarding the record it needed to do that, so the estimate was pinned to whatever the first run happened to give — and if that run was cut short, the ready box fired early on every cast afterwards. Estimates now keep correcting themselves as you play.

## 1.9.2 (2026-08-13) — Offensives explains itself, and a Classic dot stops vanishing

### Bug Fixes

- **Classic: an effect that puts no debuff on your target no longer flashes onto a lane and disappears.** A Paladin's Consecration is the clearest case — the combat log reports it, but it never shows up in your target's debuff list, so the once-a-second check that looks for it there found nothing and removed the icon about a second after it appeared. That check now only removes an effect it has actually been able to see. Anything else is ended by the combat log or by its own length running out.
- **The Offensives tab no longer claims it is looking when it isn't.** Offensives is the one category that ships switched off, so if you went hunting for your effects on a target and found nothing tracked, this is why. The tab said "No harmful effects discovered yet", which reads as Cooldown Master searching for them and failing — it was never searching at all. It now says the category is off and points at the tick box that turns it on. Thanks to yisisixu for the report, and for narrowing it down on a second character.
- **Turning a category on or off updates the panel immediately.** The tick box and the matching Enabled setting on the Defaults tab used to drift apart until you reloaded, so one could show a category as tracked while the other had it switched off, and your first click on the stale one appeared to do nothing.
- **Classic: the Buff Bars tab stops giving advice that cannot work.** It told you to log in or reload to fill the list. That category is Blizzard's own bar-style tracked buffs, which only exist on retail, so no amount of reloading would ever fill it. It now explains that and points you at Offensives, which is where your effects on a target live.
- **Retail: the Offensives tab no longer walks you through a setup that your client will refuse.** It laid out a four-step `/cm offlearn` procedure for teaching Cooldown Master your effects. On 12.1 the game withholds the information that procedure reads, so it could only ever end in `/cm offlearn` reporting it could not read anything. The tab now says plainly that an effect it has not already learned cannot be picked up on such a client, that anything already learned keeps working, and it still describes the guided procedure for clients where the game does allow it. Measured on a live 12.1 client rather than assumed.
- **A long line of explanatory text no longer runs off the edge of the options panel.**

### Improvements

- **Offensives is described as what it actually tracks.** The panel and the README both called it "your damage-over-time effects", but it tracks every harmful effect you put on your target — a stun like Hammer of Justice counts, and always did. The wording now matches the behaviour.

## 1.9.1 (2026-08-11) — A retail combat error, and diagnostics that survive it

### Bug Fixes

- **Retail: fixed an error that fired every time your target's auras changed in combat.** Midnight hands addons the target's aura update in a form they aren't allowed to read while you're in combat, and Cooldown Master tested one of those values directly, which the game now treats as an error. Every value in that update is checked before it is used. When the whole update is unreadable, Cooldown Master falls back to the once-a-second sweep it already runs, so your dots keep appearing and keep clearing on their own.
  - **Heads up:** while the game withholds that data in combat, a dot Cooldown Master has never seen before can't be learned mid-fight. Cast the ability once out of combat — a training dummy is ideal — and it's learned from then on. Dots you've already learned are unaffected.
- **`/cm offlearn` tells you when your client won't let it read the dots.** It used to answer "could not read that dot yet, still armed" after every attempt, which gave you no way to tell a mistimed cast from a client that can never answer. It now says so plainly and stops. It also no longer disarms on a later ability because an earlier one happened to hit an unreadable value.

### Improvements

- **Diagnostics survive what they were built to diagnose.** `/cm auraprobe` could itself be taken down by an unreadable aura update. It now names which part of the update was unreadable instead. `/cm off` traces say when an aura stream arrived unreadable rather than falling silent.

## 1.9.0 (2026-08-08) — Offensives learn the right dots, and Classic Era finds your potions

### Bug Fixes

- **Retail: other players' damage-over-time effects no longer end up in your Offensives list.** Cooldown Master learns which of your abilities applies which dot by watching what lands right after you cast. In a group, a teammate's dot landing at that moment could be attributed to one of your abilities instead — and once learned it stayed learned, so their dot appeared on your lanes as if it were yours. The game reports a debuff as coming from you even when it doesn't, and that was what the check relied on. It now confirms the source directly and refuses anything it cannot positively tie to you.
  - **Heads up:** because every existing mapping was learned through the faulty check, the learned dot list is cleared once on your first login after updating. Filters > Offensives will be empty until your own dots relearn, which happens as you cast them. Anything you had set up for those dots is kept — a dot you routed to Lane 3, sent to a particular bar or ready box, or unticked Show on, comes straight back to that setting the moment it is relearned. Cooldown Master tells you in chat when the reset happens. Retail only, and only if you turned Offensives on.
- **Classic Era: your potions are tracked at all now.** Era doesn't tell addons whether a consumable is a potion, an elixir or a piece of food — everything comes back as simply "consumable" — so the filter that picks out potions matched nothing and Filters > Potions was permanently empty. Every consumable is now listed on Era.
  - **Heads up:** food and drink are listed there too, because Era gives nothing to tell them apart. They have no cooldown, so they never draw an icon or a ready box. Untick **Show** on their rows if you'd rather not see them in the list.
- **TBC: Fishliver Oil is tracked.** It carries a real two minute cooldown, but Blizzard files it outside the potion and elixir categories, so it was never picked up.
- **Items looted or used during Test Mode are picked up when you leave it.** Anything you looted or drank while Test Mode was running was ignored until an unrelated bag change happened to trigger a rescan. Drinking a potion during Test Mode could also hand its cooldown to the wrong potion's icon for the rest of that cooldown.

### New Features

- **Font dropdowns show each font in its own typeface.** Every font list in the options now draws each name in the font it names, and the closed dropdown previews your current choice, so you can see what you are picking before you apply it.

### Improvements

- **The download is about 728 KB smaller.** Four bundled libraries — AceGUI, AceConfig, AceDBOptions and the shared-media widgets — were being loaded on every login without anything using them. The options panel is hand-built and never needed them.
- **Dropdown lists size themselves to their longest entry.** Options like "Lane 3 (off)" no longer run past the edge of the list they sit in.
- **Better diagnostics.** `/cm off arm` now takes a length, so `/cm off arm 45` traces long enough to cover combat ending, which is when dot learning actually happens, and it reports exactly why a dot was learned or refused. `/cm bagscan` and `/cm itemcd` now describe the rule your flavor uses.

## 1.8.0 (2026-08-03) — Ready boxes land on time, plus a batch of fixes

### Bug Fixes

- **Retail: ready boxes no longer pop before the cooldown is actually up.** When a cooldown's last second ran out underneath the global cooldown, the game reported it identically to a spell that was already ready, and Cooldown Master read that as the cooldown ending. The ready box fired early and the lane icon vanished before finishing its travel. Measured at 0.7 to 0.9 seconds early on a 9.3 second cooldown. Any cooldown whose real length has been learned now holds until it genuinely finishes.
- **Lane time markers line up with the icons again.** The 25% and 75% labels sat about 9 pixels off the icons they were labelling, in opposite directions. Markers measured across the whole lane, while an icon travels across the lane minus its own width. All five markers ship switched on, so every lane showed this out of the box. They now stay aligned at any icon size.
- **Frame Scale no longer knocks your frames out of place.** Rescaling rewrites every lane, box and bar offset so they hold their position on screen, and at smaller scales those numbers could run past what the X and Y Offset sliders were able to represent. The next nudge of one of those sliders then clamped your frame somewhere else entirely. Those sliders now widen as the scale shrinks, so the value always fits.
- **Turning off a Masque group gives Cooldown Master its icon zoom and border back.** Unticking Enabled on one of its groups in Masque left the icons stripped of the skin *and* of Cooldown Master's own zoom and border, with no way to recover them. Masque re-skins a disabled group with its default skin rather than releasing it, which was being read as still skinned.
- **Your pet dying no longer pops a ready box for each of its abilities.** A dead pet stops reporting its cooldowns all at once, which read as every pet ability coming off cooldown together. They now leave quietly while the pet is down.
- **Classic: dying no longer pops a ready box for every buff you were tracking.** Death strips your buffs in a single pass, and each one fired its own box and sound, filling the display and pushing out anything real. They now clear silently.
- **Hovering a stacked lane icon no longer drops it underneath its neighbours.** Moving the mouse away returned the icon to the bottom of the stack instead of its own layer, where it stayed until its position in the stack happened to change. Needs Stacking and Raise On Mouseover, both off by default.
- **A frame that hides mid-drag no longer chases your cursor.** If a lane, ready box or bar frame hid while you were dragging it, it kept believing the drag was still going and snapped to wherever your cursor had reached by the time it reappeared.
- **A dragged lane's border is crisp again.** Dropping a lane left it sitting between physical pixels, which smears a one-pixel border across two rows until some unrelated setting changed. Lanes, ready boxes and bar frames all re-align the moment you let go now.

### Improvements

- **Sharper diagnostics for cooldown timing.** `/cm anchor arm` now takes a length and a spell name, so `/cm anchor arm 30 blade of justice` traces one spell for 30 seconds instead of your entire tracked set, short enough to read and to paste into a bug report. `/cm masque` reports a group you have disabled in Masque and no longer claims a failed group registered fine, and `/cm petprobe` reports whether your pet is alive.

## 1.7.0 (2026-07-31) — Conjured items, and a tidier potion list

### New Features

- **Conjured mana gems and healthstones are now tracked.** A Mage's Mana Agate through Mana Emerald, and a Warlock's healthstones including the Improved and Master ranks, now appear under Filters > Potions without you adding them by hand. CDM only recognised what Blizzard files as a potion, elixir or flask, and conjured items sit outside all three — so they were invisible to it. They also tend to carry their cooldown on the spell they cast rather than on the item itself, which CDM now reads as well. Thanks to Dr. Hangover for the report.
  - **Heads up:** if you play a Warlock, your healthstone will start appearing where it didn't before. Untick **Show** on its row under Filters > Potions if you'd rather it stayed hidden.

### Bug Fixes

- **Retail: the Potions list no longer shows potions you aren't carrying.** CDM was seeding a small built-in set of retail potion IDs on top of scanning your bags. One of them no longer exists in the game and appeared as a nameless "Item 258318" row that could never do anything. Two others were alternate versions sharing a name with potions you'd actually have, so Light's Potential and Flask of the Magisters each showed up twice. Your bags are the only source now, on every flavor.
- **Hiding one potion no longer hides another.** All combat potions share a single cooldown, and unticking Show on one could leave a potion you hadn't hidden with no icon, no bar and no ready box at all. Hidden items now step aside instead of claiming the shared cooldown, which is how spells have always behaved.
- **Using the last of a potion no longer loses its icon.** Drinking your final one removes the item from your bags, and the timer used to vanish with it about half a second later — or hand the countdown to a different potion, so a mana potion you drank would finish its run wearing another potion's name. It now runs to the end as itself and pops a ready box when the cooldown is up.

### Improvements

- **Two new diagnostics for "why isn't this item showing".** `/cm bagscan` lists every consumable in your bags with what CDM decided about it and why, and `/cm itemcd <itemID>` reads a single item's cooldown even after you've used your last one.

## 1.6.0 (2026-07-28) — Ignore Threshold works on Classic, plus a long list of fixes

### New Features

- **Ignore Threshold now works on the Classic flavors** — and on every flavor for potions and trinkets. The slider under Filters has always promised to stop tracking anything whose full cooldown runs longer than the number you set, but on Era, TBC and MoP it never had a length to compare against, so it quietly did nothing at all. It now learns each ability's real cooldown the first time you use it and remembers that between sessions.
  - **Heads up:** with the default threshold of 1800 seconds, abilities longer than 30 minutes will now start dropping off your lanes where they used to show. Shaman Reincarnation is the usual example. Tick **Show** on the spell's row under Filters to keep any of them.

### Bug Fixes

- **Ready icons no longer double or triple up for abilities with charges.** On retail, spending one charge of something like Blade of Justice looks briefly identical to the ability going on cooldown, and under a fast rotation that could pop a ready box for a cooldown that hadn't finished — sometimes two or three times over. The false pops are gone, and a ready box now shows one icon per cooldown regardless.
- **The profile import window opens again on retail.** Midnight renamed part of Blizzard's popup dialog, which made the Import window throw an error the instant it appeared, so importing a profile was impossible. Exporting was never affected.
- **The color picker's opacity slider runs the right way round on retail.** It was treating the value as transparency where Midnight reports opacity, so the slider opened at the inverse of your real setting and dragging it to full made things disappear. Cancel now restores the transparency you started with, too.
- **Bar frames no longer vanish part-way through a cooldown.** If the estimated length came in short, a bar could disappear while the lane still showed the same spell running. It now holds until the cooldown genuinely ends, matching the lanes.
- **Locked ready boxes and bar frames stop swallowing mouse clicks.** Both kept taking the mouse after you locked your frames, so clicking where an invisible box sat did nothing in the world behind it. The lanes already handled this correctly.
- **Importing a profile no longer risks breaking your settings.** An import built from an older version could permanently drop any setting that string didn't carry, which left blanks behind and could error. An import now starts from a clean set of defaults and layers the imported values over it, so anything the string omits simply keeps its default.
- **Right-clicking the minimap icon now unlocks bar frames too**, and **Test Mode brings your ready boxes up straight away** instead of leaving them hidden until a sample expired.
- **The Unlock Frames checkbox no longer ignores your first click** after you'd locked or unlocked from the minimap button or `/cm lock`. The Options panel was showing a stale tick.
- **The Options panel no longer leaks frames while it's closed.** Looting, changing spec or switching profiles rebuilt hidden option lists every time, and those frames stack up for the rest of your session. Rebuilds now wait until the panel is actually open.

### Improvements

- **Profile exports no longer carry per-character learning.** Exported strings were including the cooldown lengths and dot attribution your character had picked up, which is personal runtime data rather than a setting. Exports are smaller now, and importing someone's profile leaves your own learning untouched.
- **The frame Status Line explains what it can't do.** Per-cooldown tags like `[cd.name]` have no single cooldown to name on a frame-wide line, so they render blank there. The box now says so — put those on an Icon Label instead.

## 1.5.1 (2026-07-22) — Classic Era 1.15.9 compatibility

### Compatibility

- **Updated for Classic Era 1.15.9.**

## 1.5.0 (2026-07-22) — Track a cooldown's buff, and a Masque visibility fix

### New Features

- **Track a spell's buff alongside its cooldown.** On the Classic flavors, a spell that has a cooldown *and* gives you a buff — Icy Veins, Arcane Power, and the like — can now show a second icon that counts down the buff itself, separate from the cooldown timer. Tick **Buff** on the spell's row under Filters > Spells, then set where it goes (its own lane, a bar) under Filters > Buffs. Off by default, so nothing new appears until you ask for it. (Retail surfaces tracked buffs through Blizzard's own list already, so this is Classic-only.)

### Bug Fixes

- **Cooldown Master shows up in Masque even with an empty timeline.** It was only registering its skinnable groups once an icon had been drawn, so opening Masque before any cooldown appeared left "CooldownMaster" missing from the Skin Settings list. Its three groups — Lane Icons, Ready Icons, Bar Icons — are now registered up front.

### Compatibility

- **Updated for Burning Crusade Classic 2.5.6.**

### Thanks

- **Dr. Hangover** — for the idea of tracking a cooldown's buff as its own icon.

## 1.4.1 (2026-07-20) — Custom Detect fills in the buff's duration

### Bug Fixes

- **The Detect button on a custom cooldown now fills in the buff's real duration** instead of always defaulting to 30 seconds. It already had the value from the buff you gained — it just wasn't using it. On Classic the duration reads straight off the buff, and on retail it fills in whenever the game will let an addon read it.

### Thanks

- **Dr. Hangover** — for spotting that the custom Detect button was ignoring the buff's duration.

## 1.4.0 (2026-07-19) — Offensives leak fixed, guided dot learning, and a custom-cooldown list

### Bug Fixes

- **Offensives no longer pick up other players' damage-over-time effects.** This is the raid leak from 1.3.0's Known Issues — target a mob other people have already dotted and their Flame Shock or Ignite could land in your Filters > Offensives list. A dot now only enters your list once one of *your own* casts has claimed it, so someone else's dots stay out even on a shared target. Anything already collected clears itself on your next login, or `/cm offreset` wipes it now.
- **Offensive dots track more cleanly under a busy rotation.** The way a dot is matched to the ability that applied it was reworked, so dots learned mid-fight no longer intermittently vanish, freeze at the start of the lane, or double up — which mostly showed on abilities that apply more than one debuff at once.

### New Features

- **`/cm offlearn` — a guided way to teach your dots.** Because the game hides a debuff's identity in combat, Offensives are learned out of combat. Type `/cm offlearn`, cast one dot ability, then stop and let combat end — it reads what that ability applied, learns it, and tells you what it learned. Repeat for each ability, then `/cm offlearn stop`. Especially handy for an ability that applies more than one debuff at once. Retail only — on the Classic flavors dots are still detected automatically.

### Improvements

- **Custom cooldowns are a clean list now.** After a few of them the old layout stacked into a long scroll. They now show as a compact list — icon, name, an on/off toggle, Edit and a delete button on each row — and only the one you're editing opens its full editor below. Adding one opens its editor straight away. Filters > Custom.
- **The Offensives tab explains how to learn your dots**, with the `/cm offlearn` steps right there on the panel.

## 1.3.0 (2026-07-17) — Masque, ready box text, and a new default layout

### Changed Defaults

- **A fresh install now starts with all three lanes on, and potions in their own lane.** Lane 1 carries your spells, utility, buffs and trinkets. Lane 2 carries potions, flasks and elixirs, so your consumables stop competing with your rotation. Lane 3 is switched on but deliberately has nothing routed to it — it is a spare, so you can send something to it or just turn it off, whichever suits you. This mirrors the layout a lot of people already expect from a timeline tracker, and it is meant to make the first five minutes make sense for someone who just installed the addon.
- **This will reach you even if you have been using the addon a while.** Any setting you have actually changed is kept — but anything you never touched picks up the new default, so if you never went near Lane 2 or Lane 3 you will see them switch on, and potions move to Lane 2. Turning a lane back off is one tick under Lanes > (that lane) > General > Enabled, and potions go back under Filters > Defaults > pick Potions > Default Lane.
- **This is the last time I change the defaults.** I am sorry for any re-setup this costs you. It is only to give new users a sensible starting layout, and it will not happen again.

### New Features

- **Masque support.** If you use Masque, Cooldown Master now registers three groups you can skin or disable independently in Masque's own options: **Lane Icons**, **Ready Icons**, and **Bar Icons**. Nothing changes until you pick a skin for a group. While a group is skinned, the skin owns that icon's border and crop, so Cooldown Master's own icon border and zoom step aside for it. Masque was listed as an optional dependency long before it actually did anything — that is now real.
- **Ready boxes now do text, like lanes and bars.** Ready boxes were the last display without it. They now support both an **icon label** on each ready icon (the ability name by default) and a **status line** on the box itself, with the same click-to-insert tag picker and full font, size, outline and color control. Both are off by default. Find them under Ready > (a box) > Icons > Icon Label, and Ready > (a box) > Text > Status Line.
- **Elixirs are tracked now.** Potions and flasks were tracked, elixirs were quietly skipped. They now show up alongside them under Filters > Potions.

### Bug Fixes

- **Health and resource tags never worked on retail, and no longer pretend to.** `[player.hp.pct]` and `[player.power.pct]` rendered blank for every retail user since 1.2.0. Retail returns your health and power as protected values that addons are not allowed to read — even out of combat — so a percentage cannot be worked out at all. Those tags are now offered on the Classic flavors only, where they work, instead of sitting in the picker doing nothing. `[cd.time]` has always been Classic-only for the same reason. On retail the icon's own countdown covers it.
- **A stale status line no longer flashes when a ready box comes back.** A box that had auto-hidden could show the text it froze at for a fraction of a second when it reappeared.
- **The About tab no longer claims to complement Blizzard's Cooldown Manager on Classic**, which does not have one. Same for the addon list description on the three Classic flavors.

### Improvements

- **Every row in Filters has tooltips now.** Hover a spell or item's name to see its real in-game tooltip, and hover Show, Lane, Bar, Ready Box or Flags to find out exactly what each one does — including what Important and Pinned really mean.
- **`/cm tagprobe`** joins the diagnostic commands, reporting what each text tag resolves to on your client.

### Known Issues

- **Offensives can pick up other players' damage-over-time effects in a raid.** If you target a boss or a trash pack that other people have already put dots on, those dots can end up in your Filters > Offensives list — Flame Shock or Ignite or Sunfire showing up on a Paladin, for example. It only happens on a target someone else has already dotted, which is why it shows up in raids and never when you are out solo. I have tracked down the cause and a fix is coming very soon in the next update. Until then, `/cm offreset` clears the whole list, and the per-spell **Remove (X)** button clears them one at a time. Sorry about this one.

### Thanks

- **Rocker57** — for pointing out that the default lanes were wrong, and for all the help along the way making this a better addon. Genuinely appreciated.

## 1.2.0 (2026-07-15) — Icon labels, status lines, and filter cleanups

### New Features

- **Icon labels.** You can now show text on each cooldown icon in a lane — by default the ability name. Build it from tags like `[cd.name]` and `[cd.type]`, with a click-to-insert picker so you don't have to remember them, plus full font, size, outline, and color control. Turn it on under Lanes > (a lane) > Icons > Icon Label. Off by default.
- **Status line.** A line of live text you can add to any lane or bar frame — the name of the next cooldown coming up, how many are on cooldown, your target's name, and more. Same click-to-insert tag picker. Turn it on under a lane's Text tab or a bar's Bar tab. Off by default.
- **Remove button on Offensives.** Each spell in the Offensives category now has a small **Remove (X)** button. Use it to clear a damage-over-time effect that got picked up from another player on a shared target dummy. If the spell is really yours, it comes back the next time you cast it.

### Improvements

- **The "Debuffs" filter tab is now labeled "Buff Bars."** It was always a mislabel — that category is Blizzard's bar-style tracked buffs (what the built-in Cooldown Manager shows as bars), not debuffs. Your own damage-over-time effects live in the **Offensives** category. Your existing settings for the category are kept.

## 1.1.0 (2026-07-14) — Offensives, Pet Spells, and scale controls

### New Features

- **Offensives** — a new Filters category that tracks your own damage-over-time effects and debuffs on your current target, so you can see when a dot is about to fall off. Off by default. Turn it on under Filters > Offensives. On retail the game hides a target's auras from addons in combat, so Offensives learns each dot from the spell you cast rather than by reading the target. A brand-new dot may take a cast or two to start showing, and it follows your current target only.
- **Pet Spells** — a new Filters category that tracks your pet's ability cooldowns, for Hunters, Warlocks, Death Knights, and anyone with a pet bar. On by default. Your pet's basic attack and its command and stance buttons are left out, so only real cooldowns show.
- **Scale controls**, on the Global tab. **Cooldown Frames** resizes all of your lanes, bars, and ready boxes together while keeping them where they are. **Options Window** resizes this settings window itself. Both run from half size to double size.

### Improvements

- Each Filters category now has its own **Track this category** checkbox on its own tab, instead of only being reachable from the Defaults tab.
- Disabled lanes now read "Lane N (off)" in the lane dropdowns, so it's clear why a routed spell isn't showing.
- The Custom cooldown editor keeps its scroll position while you add or edit entries.

### Bug Fixes

- **Custom "aura gained" triggers are reliable on retail now.** In combat they could fire only every other time, and a buff first gained during a fight could fire late once combat ended. On retail your own buffs are hidden from addons in combat, so an aura-gained custom can't start mid-combat at all — the editor now says so and points you to the Spell cast trigger, which does work in combat.
- A cooldown could travel the whole lane with **no countdown and no swipe** if it was recast the instant it came off cooldown (easiest to see with a pet ability the pet recasts on its own, like Growl).
- A potion or other consumable could show the **wrong name** when several of them shared a single cooldown.

### Thanks

- Thanks to user_1y22hxslizrfxfxf4w on CurseForge for suggesting the UI scale slider.

## 1.0.0 (2026-07-12) — Out of beta: bar frames, custom cooldowns, and a new default look

Cooldown Master is officially out of beta.

### A note on the new defaults

**Your settings are safe.** AceDB only fills in defaults for keys you never touched, so anything you have personally changed stays exactly as it is. If you've customized heavily, this release will barely look different to you.

But anything you left alone follows the default, and the defaults have all moved. If you've been running Cooldown Master roughly as it came out of the box, here's what will look different on your next login:

- **Lane 2 and Lane 3 are off.** They used to be on by default, so if you never touched them, they will simply not be there anymore. Tick Enabled under Lanes > Lane 2 / Lane 3 to bring them back.
- **Lanes are thinner** — 10px tall instead of 17.
- **Icons have a thin border now**, on both lanes and ready boxes.
- **Backgrounds and borders are much lighter.** The background went from near-black at 85% opacity to a paler grey at 58%, and the border from a solid 2px black to a soft 1px at about half opacity. The overall effect is a lot quieter.
- **A Bars 1 frame shows up.** Bar frames are new in this release and the first one is on by default.

**Why:** the beta defaults accumulated one release at a time across about thirty versions, and nobody ever stopped to ask what a brand-new user should actually see on their first login. Three lanes stacked up behind heavy black borders was a lot to hand someone before they'd changed a single setting. 1.0 is a deliberate pass at a clean, quiet starting point.

Every one of these is a normal option, and the in-game What's New popup spells out exactly where each one lives. If you'd rather start fresh, Profiles > Reset Profile gives you the new defaults from a clean slate.

### New Features

- **Bar frames** — a third display surface alongside the lanes and ready boxes. Up to 3 frames of depleting status bars, each with icon, spell name, and live countdown, sorted by what's coming up next. Per-frame fill texture/color (or class color), icon side, bar cap, and an emphasis highlight for Important spells. Route any category or individual spell to a bar from the Filters tab.
- **Custom cooldowns** — define your own tracked cooldown from a duration plus a trigger (a spell you cast, or a buff you gain). Runs on a purely local timer, so it covers things the cooldown API doesn't expose. Aura triggers get a **Detect** button that captures the next buff you gain and fills in the ID, name, and icon. Lives under Filters > Custom.
- **Configurable Test Mode** — sample type, count (1-20), first/last duration range, and a loop toggle. Applies live, and the samples honor your real Filters routing.
- **Set All** — bulk-apply a category's Default Lane / Ready Box / Default Bar to every cooldown in it at once.
- **Bundled textures** — three original CDM textures (Gradient, Glass, Soft Edge), registered through LibSharedMedia.
- **Text styling** — font, size, outline, and color for lane markers, frame name tags, and the bar countdown number.

### Bug Fixes

- **A passive talent could appear as a tracked cooldown.** Some talents (e.g. the Paladin talent Undisputed Ruling) are exposed by `C_CooldownViewer` as their own entry, flagged `HideByDefault`, and carry their parent ability's icon art. Blizzard's own Cooldown Manager skips those rows. We weren't. The passive rendered as a bar/lane icon wearing Judgment's icon with the wrong name and its own internal proc timer. Hidden rows are now skipped — which also fixes the wrong spell tooltip on hover and the wrong name (and sort position) in the Filters list.
- A spell still on cooldown across a spec or talent change kept its pre-swap name and icon until it expired. Entries now re-sync on rebuild.
- **Color opacity never took effect on text.** Two separate bugs: the color picker's opacity value is transparency (not alpha) and was being stored inverted, and a FontString's `SetAlpha` overrides the alpha passed to `SetTextColor`. Both fixed. This also corrects background, border, and highlight opacity at the extremes.
- Identically configured frames could show visibly different border darkness depending on their screen position (sub-pixel grid misalignment). Frames are now snapped to the physical pixel grid.
- A ready box could briefly render as two concentric boxes when two cooldowns came up in the same tick (only visible with Auto-hide on).
- Changing a cooldown's lane or bar routing now moves it immediately, instead of only taking effect the next time that cooldown is used.
- The global Unlock Frames and Auto-hide toggles now apply to bar frames, which previously ignored both.

### Thanks

Thanks to everyone who ran the beta and sent feedback, and to cliffclive, whose CooldownTimeline2 is the reason this addon exists.

## 0.21.0 (2026-07-11) — Auto-hide while unlocked, plus a shared-cooldown fix

### New Features
- **Auto-hide now works while frames are unlocked.** Previously Auto-hide only took effect once you locked your frames. Now, with Auto-hide on, empty lanes and ready boxes hide out of combat even while unlocked — and each hidden frame shows a small labeled tag you can grab to drag it into place. Lock your frames and the tags disappear, as before.

### Bug Fixes
- **Shared cooldowns no longer hide a different ability.** With Detect Shared Cooldowns on, two unrelated abilities that happened to share a cooldown length and were used together (for example Arcane Power and Icy Veins from one macro) were merged into a single icon, hiding one of them. Abilities now merge only when they are genuinely the same cooldown, so every ability shows.
- **Drag tag could follow the cursor.** A repositioning tag hidden in the middle of a drag (for example when a cooldown popped into the box you were moving) could keep chasing the cursor afterward. The drag now finalizes cleanly.
- **Ready-box tags in combat.** Ready-box repositioning tags now hide in combat, matching the lane tags.

### Thanks
- Thanks to Agaman for knocking this one out for me.

## 0.20.0 (2026-07-09) — Stacking: Center, Overlap, and Offset styles, plus fixes

### New Features
- **Center-stacked cooldowns.** A new **Center** grow direction makes stacked icons straddle the lane line and grow both ways (Up / Down / Center on horizontal lanes, Left / Right / Center on vertical lanes), so a busy lane stays balanced instead of piling in one direction.
- **Offset stacking style.** A new **Offset** style fans every stacked icon evenly across the stack Height, as an alternative to Grouped (rows) and Spread (along the lane).

### Bug Fixes
- **Reliable login.** The What's New popup, the first-run welcome message, and automatic profile switching by specialization now run reliably on a fresh login instead of only after a `/reload`.
- **Color-picker opacity on 12.0.** A color's transparency was inverted on modern clients. It now matches what you set, and Cancel restores the correct alpha.
- **Filters options no longer leak.** Every spec, talent, or spellbook change rebuilt the Filters options even while the window was closed, orphaning UI frames for the rest of the session. The rebuild now happens only while the panel is open.
- **Blank Filters tab.** After a profile change or options rebuild, the Filters tab could come up empty. It now rebuilds cleanly.
- **No stray override tables.** Merely viewing a spell in Filters no longer saves an empty per-spell override into your settings.
- **Vertical secondary tracking.** The GCD / Swing secondary bar was sized and oriented for a horizontal lane. It now travels correctly along the full length of vertical lanes.
- **Ready-box flicker.** A ready box holding a pinned icon no longer flickers after combat and no longer relayouts every frame. Pinned icons stay shown while unpinned ones clear.
- **Selected-tab highlight.** The selected Options tab keeps its yellow highlight when you hover or click it instead of briefly flashing red.
- **Classic spec tracking.** Classic Era and Burning Crusade (Anniversary) no longer set up specialization-change tracking that does not apply on those flavors.

### Improvements
- **Stacking overlaps to fit.** Grouped stacking now compresses its rows to keep the whole pile within the configured Height, so stacked icons overlap instead of spilling off the lane. Raise Height to reduce the overlap.
- **Taller default stack.** The default stacking Height is now 150, giving stacked icons more room before they overlap.
- **Consistent stack layering.** Overlapping stacked icons now draw in a stable front-to-back order.
- **Clearer stacking tooltips.** New hover tooltips explain the Grouped, Offset, and Spread styles, the Center grow direction, and how Height controls overlap.
- **Smoother Classic / MoP combat.** On Classic and Mists of Pandaria, buff tracking batches rapid aura changes into a single scan instead of scanning on every change, cutting allocation churn.
- **Current Classic clients.** Updated the interface versions for Classic Era, Burning Crusade (Anniversary), and Mists of Pandaria so Cooldown Master loads cleanly and is no longer flagged out of date.

## 0.19.0 (2026-07-05) — What's New popup, icon borders, vertical lanes

### New Features
- **What's New popup.** After an update, Cooldown Master shows a short summary of what changed. Choose how you're notified under **Global > After an update**: a **Popup window**, a quiet clickable **Chat link** in your chat, or **Off**. Reopen it any time with `/cm whatsnew`, or tick "Don't show these again" to silence it for good.
- **Per-lane icon borders.** Each cooldown icon can now have a solid border in a size and color you choose, on both lanes (**Lanes > Appearance**) and ready boxes (**Ready > Icons**). Off by default.
- **Vertical lanes.** A new **Vertical** toggle (**Lanes > General**) runs a lane top-to-bottom instead of left-to-right, swapping its Width and Height so the bar keeps its shape.
- **Sound preview.** A **Play** button next to Ready Sound and Highlight Sound (Ready tab) lets you audition the sound without waiting for a cooldown to pop.

### Bug Fixes
- **Fixed icon shake in Spread stacking.** In Linear mode with Spread stacking, an icon catching up to the one ahead would bump and shake several times before passing it. Stacked icons now slide smoothly at full frame rate.

### Improvements
- **The Ignore Threshold now works.** Previously a dead slider, it now hides any spell whose full base cooldown is longer than its category's Ignore Threshold (a per-spell override still wins) — handy for keeping very long cooldowns off a short lane.
- **Empty ready boxes honor Auto-hide.** They used to disappear whenever empty and locked. Now they follow your global Auto-hide setting. With Auto-hide off (the default), empty ready boxes stay visible.
- **Stronger Important-spell highlight.** The highlight for spells flagged Important is now a full-icon glow instead of a thin hollow border, so it stands out at a glance.
- **Global-tab tooltips.** Every option on the Global tab now has a hover tooltip explaining what it does.
- **Clearer Filters list.** The per-spell Filters list now has an aligned **Show / Lane / Ready Box / Flags** column header.
- **Tidier Countdown Timer option.** The lane icon-text settings were simplified to a single **Show Timer** toggle under a **Countdown Timer** header.

## 0.18.1 (2026-07-04) — Cooldown fixes & smoother lane travel

### Bug Fixes
- Fixed a Lua error that could fire repeatedly in dungeons and instances and quietly interrupt cooldown tracking (a combat-protected value was being read at the wrong moment).
- Fixed cooldown icons sometimes appearing at the **front** of the lane already counting down, instead of traveling from the start — most noticeable on charge and builder abilities (e.g. Blade of Justice, Templar Strike) during fast rotations. The lane now anchors each cooldown to when it actually started.
- Fixed a brief one-frame "ghost" an icon could flash at the wrong spot when cooldowns started or reordered.
- Newly talented abilities are now picked up without a `/reload`.

### Improvements
- **Smoother lane travel.** Trimmed redundant per-frame work and spread the periodic background scan across frames, removing a faint recurring stutter as icons move.
- **Steadier countdown text.** The number on each icon now holds to the pixel grid, so it stays crisp while the icon glides.
- **Self-healing learned durations.** Stale or GCD-length cooldown values saved by older versions are cleaned up on load, and learned durations reload correctly when you switch profiles.

## 0.18.0 (2026-07-04) — GCD/Swing tracking, ready-icon cap, Classic fixes

### New Features
- **GCD & Swing tracking on the lanes.** Each lane can now show your global cooldown or main-hand swing timer as a recurring indicator — either a fill across the whole lane (Primary Tracking) or a small bar that slides along it (Secondary Tracking), configurable under Lanes > General with its own size, color, and direction. (Classic flavors, on retail this is handled by Blizzard's built-in Cooldown Manager.)
- **Max Ready Icons.** Each ready box now caps how many ready icons show at once (Ready > General), so a burst of cooldowns coming off at the same time no longer floods the box. Newest readies take priority.
- **`/cm` shortcut.** Every slash command now also works as `/cm` (e.g. `/cm`, `/cm lock`, `/cm test`) in addition to `/cdmaster`.

### Bug Fixes
- Fixed the Filters list on Classic showing the same spell multiple times — for example **Soul Reaper appearing three times** on a Mists Death Knight — and listing **off-spec abilities** you can't use, like a Frost ability on a Blood Death Knight. The list now shows only what your current specialization can actually cast.

### Improvements
- **Death Gate** is now filed under the **Utility** filter instead of Spells on Classic.
- Added hover tooltips to several options: Mode, Primary/Secondary Tracking, ST Height, Stack Style, Highlight Style, and the ready-box Anchor.

## 0.17.0 (2026-07-03) — Mists of Pandaria Classic support

### New Features
- **Mists of Pandaria Classic support.** Cooldown Master now runs on the MoP Classic client (5.5.x), using the same spellbook-scan cooldown tracking as the other Classic flavors. The Colors tab covers MoP's full class list, including Death Knight and Monk. The addon now ships a Mists TOC so it loads without an out-of-date warning.

### Bug Fixes
- Fixed the **Profiles tab showing blank** (with a Lua error) on Mists of Pandaria Classic. The per-specialization auto-switch controls now use that client's specialization API. The same fix also covers spec-based profile auto-switching at login.

### Improvements
- Renamed the lane's **"Background" appearance settings to "Lane"** (Lane, Lane Texture, Lane Color, Use Class Color), since they control the visible lane strip.
- Removed the non-functional **"Foreground"** lane appearance controls, a leftover from an unused bar-style display model.

## 0.16.8 (2026-07-03) — Classic potions, class-color opacity, ready sound

### Bug Fixes
- **Classic potions now show properly.** On Classic Era and Burning Crusade Classic, tracked potions previously appeared as unnamed "Item ######" placeholder rows that never resolved. Potions are now discovered from your bags and display their real name and icon. (Retail was unaffected.)
- Fixed editing a class color on the Colors tab being able to alter the built-in default colors shared by other profiles.

### New Features
- **Class-color opacity.** The class-color pickers on the Colors tab now include an opacity slider, so a class-tinted lane background can be made semi-transparent.

### Improvements
- **Ready frames now have a default sound.** When a cooldown becomes ready it plays a short click by default, instead of being silent. Change it — or turn it off — under Ready > Sound for each ready box.

## 0.16.7 (2026-07-03) — Hidden-spell ready-pop fix

### Bug Fixes
- Fixed a spell hidden in Filters still popping into a ready frame (or suppressing a visible spell) when **Detect Shared Cooldowns** was enabled. Hidden spells are now excluded from the ready-frame logic entirely, matching how the lanes already hide them.

## 0.16.6 (2026-07-03) — Live Test Mode preview

### Improvements
- **Test Mode is now a live preview.** Clicking Test (Global tab) plays a looping demo: sample cooldowns — drawn from your own tracked spells and buffs — travel the lane timeline and then pop into the ready frame at the finish, so you can watch the full cooldown-to-ready flow and fine-tune your settings against it. The samples route through your actual lane, ready-box, and filter settings, on both retail and Classic.
- Added a **Stop Test** button next to Test, and closing the options window now ends the test automatically.

## 0.16.5 (2026-07-03) — WoW Classic support

### New Features
- **WoW Classic support.** Cooldown Master now runs on Classic flavors that don't have retail's Cooldown Viewer. It scans your spellbook and tracks every ability whose cooldown is longer than the global cooldown, reading live cooldown times directly (which stay readable in combat on Classic). Class buffs that have no cooldown — Paladin Seals and Blessings, and the like — are tracked by their remaining duration under the Buffs category. The tracked set refreshes automatically as you learn spells or swap talents.

### Improvements
- **Lane transparency now fades the bar, not the icons.** A lane's Box Alpha now dims only the bar background, border, name, and markers. The cooldown icons keep their own Icon Alpha and stay fully visible. Previously, lowering a lane's alpha faded the icons along with it.
- **Refreshed default layout.** Fresh installs start with a cleaner look — thinner, wider lanes with tighter borders, slightly smaller icons, and a repositioned first ready box. Existing profiles are left untouched.
- Lane and ready-box names now float just above the frame instead of sitting centered inside it, so the label never overlaps the bar or its percent markers at any size.

## 0.16.4 (2026-07-03) — Now on CurseForge

### Improvements
- Cooldown Master is now available on CurseForge.
- Added a Credits section to the in-game About tab acknowledging CooldownTimeline2 (CDTL2) by cliffclive, whose addon inspired this one.

## 0.16.3 (2026-07-03) — Code cleanup

### Maintenance
- Internal code comment cleanup and tidying. No functional, gameplay, or settings changes.

## 0.16.2 (2026-07-02) — Auto-hide keeps your icons

### Improvements
- **Auto-hide Frames** now hides only each lane's background, border, name, and markers. Your tracked cooldown icons stay visible out of combat and return with the chrome when you enter combat. Use a lane's Override Autohide to keep its chrome pinned.
- Added plain-language tooltips to the Auto-hide Frames, Override Autohide, and per-category Enabled / Show by Default options, so their effect is clear at a glance.

### Bug Fixes
- Locked lanes no longer capture mouse clicks over their area — clicks now pass through to the game world beneath them.

## 0.16.1 (2026-07-02) — New icon

### Improvements
- **New icon**: now shown on the minimap button, addon list, and data-broker displays.

## 0.16.0 (2026-06-30) — Smoother motion, Split mode, lane highlights, textures, and labels

A pass focused on matching the look and feel of CooldownTimeline2 (with the author's blessing): smoother icon motion, a new Split lane mode, lane highlights, texture options, and editable lane labels.

### New Features
- **Split lane mode** (Lanes > General > Mode): a timeline mode where you set the time curve yourself. Place up to three control points — "a cooldown with this many seconds left sits at this percent along the lane" — to spread imminent cooldowns near the ready edge and compress far ones at the back.
- **Lane icon highlights** (Lanes > Icons > Highlight): spells flagged Important can now stand out on the lane with a Border, Glow, Flash, or Border + Flash style in a color you pick — the same styles the ready frames use. Off by default per lane.
- **Background and border textures** (Lanes > Appearance): the lane background and border are now selectable from any LibSharedMedia texture you have installed, instead of the single built-in fill.
- **Editable lane labels** (Lanes > Text): each of the five lane labels now has its own text and position, so you can rename and reposition the markers (Ready / 25% / 50% / 75% / 100% are just the defaults).

### Improvements
- **Smoother lane motion.** Icons now glide along the lane at sub-pixel precision every frame instead of stepping a whole pixel at a time, so slow-moving cooldowns travel smoothly. Most noticeable on long cooldowns and in Logarithmic mode.
- **Ready-pop fade-in.** Icons popping into a ready frame now fade in softly alongside the existing pop animation, instead of appearing instantly.
- Logarithmic mode does a little less work per frame (no behavior change).

## 0.15.0 (2026-06-24) — Shared-cooldown ready-pop dedupe

### Improvements
- **Detect Shared Spell Cooldowns** now also de-duplicates ready-frame pops. An ability tracked under two spell IDs that share a cooldown (a base spell and its override, or the same ability in two Cooldown Viewer categories) now pops a single ready icon instead of one per ID, mirroring how the lanes already collapse it. Off by default, gated on the same Global option.
- Minor internal code cleanup (comment tidy-up, no behavior change).

## 0.14.1 (2026-06-22) — Charge-spell display hotfix

### Bug Fixes
- Fixed multi-charge spells (such as Roll) not appearing on the lane when fully out of charges. A check added in 0.14.0 was hiding them in every case. Depleted charge spells now correctly show their recharge again, while still not flickering on individual charge uses.

## 0.14.0 (2026-06-22) — Icon zoom, unusable tint, and cooldown-tracking fixes

New display options for lane and ready icons, plus fixes for cooldown position and charge-spell tracking.

### New Features
- **Icon Zoom** (Global tab): a slider to zoom lane and ready-frame icons in. 1 = the default look. Higher crops the icon border further.
- **Unusable icon tint** (Global tab): tint and/or desaturate icons for spells you currently can't cast (not enough resources, wrong form, and so on), in a color you choose — "Tint Unusable Icons", "Desaturate Unusable Icons", and "Unusable Tint Color".
- **Spread stacking** (Lanes > Stacking): a new stacking style that pushes overlapping icons apart along the lane instead of stacking them into rows, so clustered cooldowns stay readable in sequence.
- **Detect Shared Spell Cooldowns** (Global tab): collapse spells that share a cooldown into a single lane icon instead of showing duplicates.

### Bug Fixes
- Fixed certain cooldowns (such as Rising Sun Kick and Strike of the Windlord) tracking at the wrong spot on the lane. The addon now uses the exact learned cooldown length, re-anchors the timer to each cast, and re-learns lengths that changed in a patch. The countdown number was always correct.
- Fixed multi-charge spells (such as Roll) briefly flashing onto the lane and popping a ready frame on each charge use. They now appear only once you're fully out of charges.

## 0.13.1 (2026-06-22) — Countdown font options and a cooldown-position fix

Customizable countdown text on lane icons, plus a fix for some cooldowns showing at the wrong spot on the lane.

### New Features
- **Countdown font** (Lanes > Icons > Timer Font): set the font face, size, outline, and color of the timer text on each lane's icons. Size 0 = auto, scaling with the icon size.

### Bug Fixes
- Fixed certain cooldowns (such as Supernova and Arcane Orb) sliding to the "ready" end of the lane and staying there while still on cooldown. The addon now learns each cooldown's true length from how long it actually runs, so the icon tracks the right position. The countdown number and swipe were always correct.

## 0.13.0 (2026-06-21) — Logarithmic lane mode and icon stacking

Two new lane display options: a logarithmic timeline mode and grouped icon stacking.

### New Features
- **Logarithmic lane mode.** A new per-lane Mode (Lanes > General) that lays cooldowns out on a logarithmic seconds axis: the last several seconds of any cooldown spread across most of the lane while long cooldowns compress toward the far end, so abilities about to come up are easy to read. Shares the lane's Max Time setting.
- **Grouped icon stacking.** Turn on Stacking (Lanes > Stacking) and lane icons that would overlap are packed into rows instead of sitting on top of each other, within the Height you set and laid out in your chosen Grow Direction. The Raise On Mouseover option brings a stacked icon to the front when you hover it.

## 0.12.0 (2026-06-21) — Profiles, consumables, and visibility fixes

New profile tools, potion and trinket tracking, a cooldown-tint control, and two visibility fixes.

### New Features
- **Per-spec profile auto-switch.** On the Profiles tab, map each specialization to a profile and the addon switches to it when you change spec (and on login).
- **Profile import/export.** Export the current profile to a copy-paste string and import one back, from the Profiles tab.
- **Potion auto-discovery and trinket tracking.** Potions and flasks in your bags are found automatically, and equipped on-use trinkets (slots 13 and 14) are tracked under a new Trinkets filter category.
- **Cooldown Tint slider** (Lanes > Appearance > Icons) to lighten the cooldown darkening so you can see the spell art, or set it to 0 to turn it off.

### Bug Fixes
- Locking the frames no longer hides lanes. It now only disables dragging. Lane visibility follows your Always / In Group / In Instance and Auto-hide settings.
- Using a single potion no longer pops several ready frames at once. Combat potions share one cooldown, so they now show and notify as a single icon.

## 0.11.0 (2026-06-21) — Minimap toggle and icon tooltips

Two new options: a checkbox to show or hide the minimap button, and tooltips when you hover a lane icon.

### New Features
- **Show Minimap Button** checkbox on the Global tab to hide or show the minimap icon.
- **Icon tooltips.** Hovering a lane icon now shows the spell or item tooltip. Turn it on with the "Enable tooltips" option on the Global tab (off by default). While frames are unlocked the icons stay click-through, so you can still drag lanes freely.

## 0.10.2 (2026-06-21) — Stability and performance

A maintenance release: fixes a ready-frame bug on loading screens, cuts memory use when switching profiles, smooths the lane display, and shows release dates in the in-game changelog.

### Bug Fixes
- Fixed every tracked spell flooding the ready frames at once after a loading screen or zone change. The cooldown state the game reports during a loading screen is briefly unreliable. The addon now waits for it to settle instead of treating every cooldown as ready.

### Improvements
- Switching, copying, or resetting profiles no longer leaks frames. Lane and ready boxes are now reused instead of destroyed and recreated, and the About tab is no longer rebuilt each time.
- Lane icons reposition only when they actually move, instead of on every frame, and now keep a stable order so they no longer reshuffle as cooldowns come and go.
- The in-game changelog (About tab) now shows the release date for each version.

## 0.10.1 (2026-06-21) — Combat crash fix

Fixes a Lua error that could spam in combat for multi-charge spells, and adds feedback to the profile creation flow.

### Bug Fixes
- Fixed a repeating "secret number value" Lua error that fired in combat for multi-charge spells (such as Shimmer). The addon no longer reads the protected in-combat charge count. Multi-charge spells are detected from their maximum charges instead, so their recharge still shows once the spell is fully on cooldown.
- Creating a profile now gives feedback: it warns on an empty, duplicate, or current name, and clears the box with a confirmation on success.
- Hardened active-profile switching so the dropdown can't tear itself down mid-click.

### Maintenance
- Removed charge-count text code paths that can't work under Midnight's in-combat value protection.

## 0.10.0 (2026-06-21) — Ready Frames parity

Ready Frames gains the full feature set it was known for: spells route to any of the three boxes, important cooldowns can be highlighted, and boxes lay out and animate the way you'd expect.

### New Features
- **Per-box ready routing.** Each Filters category now has a Ready Box setting, and any spell can override it, so ready notifications can be split across boxes 1, 2, and 3 (or turned off per spell) instead of all landing in one box.
- **Highlight for important cooldowns.** Flag a spell as Important (Filters tab) to make its ready popup stand out with a Border, Glow, or Flash style in a color you pick, using its own hold duration and sound. Each box configures these on a new Highlight section.
- **Pinned spells.** Flag a spell as Pinned to keep its ready icon up until the box is rebuilt, instead of fading on the normal timer.
- **More grow directions.** Ready boxes can grow Down, Up, Left, Right, or centered vertically/horizontally.
- **Pop-in flash.** Ready icons now bounce in when they appear.
- **Post-Combat Hide.** An optional per-box timer that clears the box a set number of seconds after combat ends (0 = off).
- **Built-in ready sounds.** The Ready Sound list now includes a few built-in chimes, so you can hear a ready alert without installing extra sound media. Any LibSharedMedia sounds you have are still listed.

### Bug Fixes
- The minimap button's hide state and position now follow profile switches instead of staying stuck on the profile you logged in with.
- Cooldowns first seen during combat no longer keep an approximate resting position after their real length is learned. The icon re-centers once the true cooldown is known. The countdown number was always exact.
- Charge-based spells (Shimmer, Fire Blast) once again appear only when the spell is fully on cooldown, not while a charge is still available. A partial recharge isn't a cooldown, so it no longer shows in a lane or pops a ready frame.

### Improvements
- Ready boxes fade out smoothly when they empty instead of snapping off.

## 0.9.0 (2026-06-21) — Ready Frames

The timeline-style **Ready Frames** display is back, the lane visibility and auto-hide settings now work, lanes gain a Timeline mode, and charge-based spells display correctly.

### New Features
- **Ready Frames.** When a tracked spell or item comes off cooldown, its icon pops into a dedicated on-screen box, holds for a configurable time, then fades. Three independent, movable boxes, each configured on a new **Ready** tab with General / Appearance / Icons sections (size, position, grow direction, hold duration, sound, background, border, alpha). Built on the same combat-safe engine that drives the lanes.
- **Lane visibility** — Always / In Group / In Instance now control when each lane shows, re-evaluated on combat, group, and zone changes.
- **Auto-hide out of combat**, with a per-lane Override Autohide toggle.
- **Lane Timeline mode** — a new per-lane mode that positions every icon by real seconds-until-ready on a shared Max Time axis, so abilities can be compared directly. The default per-spell mode is unchanged.

### Bug Fixes
- Multi-charge spells such as Shimmer and Fire Blast now show their recharge swipe and countdown instead of a blank icon, and appear while a charge is regenerating rather than only once fully depleted.

### Maintenance
- Removed dead code: the unused Bar Frames file, undefined frame-discovery calls and their slash subcommands, and stale diagnostic counters.

## 0.8.1 (2026-06-21) — Some code clean up

Some code clean up.

## 0.8.0 (2026-06-18) — Midnight 12.0.7 compatibility

A maintenance release that brings the retail build current with the latest Midnight patch and tidies packaging metadata on the Classic builds. No gameplay or tracking behavior changes.

### Improvements
- Retail interface compatibility updated to WoW 12.0.7, so the addon loads without the out-of-date warning on the current Midnight patch.

### Maintenance
- Corrected the Author field on the Burning Crusade Classic and Vanilla Classic builds to match the retail build.

## 0.7.0 (2026-06-10) — All-class coverage and a reliability pass

Cooldown position baselines now cover every class and spec instead of just Paladin and Mage, so icons land in sensible places on first sight regardless of what you play. This release also fixes a cluster of Filters and spec-swap bugs, makes test mode actually work, and includes a substantial allocation-reduction pass on the live engine.

### New Features
- Baseline cooldown coverage for all classes and specs. The addon already discovered every class's spells dynamically, but the first-impression icon position relied on a hardcoded duration table that only covered Paladin and Mage. Every other class fell back to a flat default until each spell was seen once. Positions are now seeded from the game's own base-cooldown data for whatever you're playing, so icons start in the right place on any class. The countdown number on each icon was already exact in all cases. This improves only the icon's resting position along the lane.

### Bug Fixes
- Filters: spells that Blizzard lists in more than one Cooldown Viewer category (for example an Essential cooldown that is also a tracked buff) no longer get reassigned to the wrong sub-tab. Each spell now keeps its primary category, so it appears in the expected Filters list and routes to the lane you'd expect.
- Filters: the per-category spell lists were a one-time snapshot taken the first time you opened a sub-tab. Opening Filters before spell discovery finished left "No spells discovered yet" stuck for the session, and the lists didn't refresh after a spec change. They now rebuild whenever the spell registry does.
- Test mode now works from all three entry points (the `/cdmaster test` command, the Global tab button, and a minimap middle-click). Previously these printed "Test mode on" but nothing happened, because the toggle never reached the engine.
- Learned cooldown durations now persist between sessions as intended. The save step was never being called, so the addon re-learned every spell from scratch on each login instead of remembering them permanently.
- Changing specialization no longer leaves cooldown positions wrong until a `/reload`. The addon was clearing its learned durations on spec change without reloading the saved and baseline values, so every cooldown briefly extrapolated from a flat default.
- A party member changing spec no longer wipes your own learned durations. The specialization event is now filtered to the player.

### Improvements
- Engine allocation pass. The cooldown scan no longer runs on every frame tick. Cooldown changes are caught by game events (cast, cooldown-change, and bag-cooldown for potions) with a low-frequency safety sweep behind them. A cast that fires two events now collapses into a single scan instead of two. Together this removes the bulk of the addon's steady-state memory churn during sustained combat.
- Lane configuration (size, position, colors, markers) is no longer re-applied on every render frame. It is now applied once when a lane is built and again only when you actually change a setting, removing redundant layout work at roughly 30 updates per second across three lanes.
- Dragging the Width, Height, X, Y, or Anchor sliders in a lane's Appearance settings no longer leaks a frame per slider step. These now update the existing lane in place instead of destroying and recreating it.

### Developer notes
- Added `/cdmaster seedtest`, a diagnostic that reports how many of the current spec's tracked spells have a learned, hardcoded, or game-seeded baseline, with sample values to sanity-check against tooltips.
- Duration precedence is now explicit: learned (talent-adjusted, observed out of combat) takes priority over hardcoded fallbacks and game-seeded baselines, which take priority over a flat default. Hardcoded and seeded baselines no longer suppress learning the real value.

## 0.6.0 (2026-05-30) — Combat-accurate cooldowns

A ground-up engine rewrite so cooldowns display correctly in combat under Midnight's "secret value" API restrictions. Previously, in-combat timers were extrapolated guesses that were often wrong. Now each lane icon shows the real cooldown swipe and countdown, tracks the true cooldown state, and reads as a continuous clock.

### New Features
- Combat-accurate cooldown display. Under Midnight, addons can no longer read remaining cooldown time in combat — it is a protected value. Each lane icon now renders Blizzard's native cooldown swipe and countdown, fed the cooldown object directly, so the swipe and number stay exact in combat without the addon ever reading the number.
- Real-time lifecycle driven by the live cooldown state: icons appear and clear exactly when the real cooldown starts and ends, including early clears when a proc or talent resets a cooldown.
- Continuous M:SS countdown text (4:59, 4:58, ...), with whole seconds under a minute, instead of the default that collapses to bare minutes like "4m". Applies to spells and potions.

### Improvements
- Engine performance: replaced the per-tick numeric cooldown poll with an event-driven model keyed on cooldown-state changes (`SPELL_UPDATE_COOLDOWN` / `UNIT_SPELLCAST_SUCCEEDED`), and removed the unused curve-evaluation code from the live path.
- Removed developer chat output that printed on every login and reload ("Engine started", "Tracking N spells", "Curves built"). Engine state is still available on demand via `/cdmaster api`.

### Known limitations
- Icon position along the lane is approximate for haste- or talent-scaled cooldowns: the exact remaining time is unreadable in combat, so position is estimated from the base duration. The countdown number on the icon is always exact.
- Charge-based spells may not show their recharge until fully on cooldown.

### Developer notes
- Added `docs/EXPERIMENTS.md` recording the Midnight secret-value investigation (no readable cooldown number exists in combat, only `isActive`/`isOnGCD` are usable) and the `/cdmaster curvetest` diagnostic that established it.

## 0.5.0 (2026-05-23) — Potions, Mage support, and a performance pass

Adds item-cooldown tracking (potions), extends fallback duration coverage to Mage, and includes a broad allocation-reduction pass across the engine and the lane renderer. Also fixes a load-blocking syntax error and a backdrop live-update bug.

### New Features
- Potions category: the engine now polls a hardcoded list of potion item cooldowns directly via `C_Container.GetItemCooldown`. Items don't come from Blizzard's Cooldown Viewer (which only enumerates spells), so they're tracked in a parallel registry. A new `Filters > Potions` sub-tab lists tracked items with the same icon / visibility checkbox / per-item lane dropdown as spells. Item names and icons resolve asynchronously via `GET_ITEM_INFO_RECEIVED` and update their Filters row in place.
- Mage fallback durations: baseline cooldowns for all three Mage specs (Arcane, Fire, Frost) plus shared utility and defensives, so Mage cooldowns display correctly in combat before each spell has been observed once out of combat. The addon already discovered Mage spells dynamically from the Cooldown Viewer. This fills the in-combat seed gap that previously only covered Paladin.
- The `Filters > Items` sub-tab is relabeled `Utility` to reflect its real contents — Blizzard's Utility-tagged spells (Hammer of Justice, Lay on Hands, etc.), not inventory items. The internal saved-variable key stays `items` for compatibility. Actual consumables now live under Potions.

### Bug Fixes
- Fixed a stray token at the end of `Core/Init.lua` that produced a Lua compile error (`'=' expected near '<eof>'`) and prevented the addon from loading at all.
- Backdrop changes (border size, border color, padding) now take effect immediately instead of requiring a `/reload`. Blizzard's `BackdropTemplateMixin` reference-compares the backdrop table and skipped re-applying when the same reference came back. Lane code now swaps in a fresh table only when border settings actually change.

### Improvements
- Engine performance: hoisted per-tick `pcall` closures to module-level functions, switched the hot pollers (`PollOneSpell` / `PollOneItem`) to multi-value returns instead of allocating a result table per call, and reused scratch tables (`_seenSpells` / `_seenItems`) across ticks. `SPELL_UPDATE_COOLDOWN` is now debounced so cooldown-change bursts collapse into a single deferred poll.
- Lane renderer performance: pre-built integer/decimal time-string lookup tables to eliminate roughly 450 `string.format` allocations/sec from the per-icon `OnUpdate` and per-tick refresh. Extracted the `ApplyConfig` and `Refresh` bodies to module-level functions so their `pcall` wrappers no longer allocate a closure at ~30 Hz across three lanes. The backdrop table is cached for the steady-state case.

## 0.4.0 (2026-05-03) — Filters

The Filters tab is now functional. Users can decide which discovered spells, items, buffs, and debuffs render in lanes, and override per-spell lane routing on a case-by-case basis.

### New Features
- `Filters > Defaults` sub-tab: per-category Enabled toggle, Show by Default flag (controls whether brand-new discovered spells start visible), Ignore Threshold slider, and Default Lane dropdown.
- `Filters > Spells / Items / Buffs / Debuffs` sub-tabs: scrollable list of every spell the engine has discovered for that category, each row with an icon, spell name, visibility checkbox, and per-spell lane dropdown ("Default" or Lane 1/2/3).
- Three-layer visibility model in the engine: category-enabled → per-spell override → category `showByDefault` fallback.
- Per-spell lane override stored in `spellOverrides[spellID].lane`. Falls back to `filters[category].defaultLane`, then the engine's hardcoded category default.

### Bug Fixes
- Multi-lane rendering: the entries loop now correctly gates each entry by its resolved `laneIndex`, so spells only appear in the lane they're routed to. Previously every spell rendered in every enabled lane (latent bug — only invisible because most users ran a single lane).

### Migration
- `MigrateV030` extended to fold the legacy `perSpellRouting[spellID] = laneIndex` map into `spellOverrides[spellID].lane`, then strip the obsolete `perSpellRouting` key. Idempotent.

### Not yet implemented
- Filters sub-tabs for Offensives, Pet Spells, and Custom render a "Coming in v0.5" placeholder. Custom in particular requires an "add spell ID by hand" input flow, which is a feature unto itself.

## 0.3.0 (Undated) — Scope refocus: lanes only

Realized that Blizzard's built-in Cooldown Manager already covers the icon,
status bar, and "ready" notification use cases natively. What it does not
provide is a timeline-style **lane** display. Cooldown Master is now refocused
on that one job — and on doing it well.

### Removed
- Bar Frames feature and all related UI (`UI/BarFrames.lua` deleted, Bars tab
  removed from the options panel).
- Ready Frames feature and all related UI (`UI/ReadyFrames.lua` deleted, Ready
  tab removed from the options panel).
- Engine hook that fired ready transitions (no longer needed).
- `defaultBar` and `defaultReady` filter-routing fields (lanes only now).
- Sound enumeration helper from the options panel (was only used by Ready).

### Migration
- `OnInitialize` runs a one-time SavedVariables cleanup that strips the
  orphaned `barFrames` / `readyFrames` blocks and the obsolete
  `defaultBar` / `defaultReady` keys from each filter category. Idempotent —
  safe to run repeatedly. Nothing for users to do. Just `/reload` after
  upgrading.

### Kept and unchanged
- Lanes tab (General, Appearance, Icons, Stacking, Text sub-tabs).
- Global, Filters, Colors, Profiles, Import/Export, Changelog tabs.
- Curve-evaluation cooldown engine and persistent learning.
- LibDataBroker launcher, minimap button, slash commands.

## 0.2.0 (2026-05-03) — Engine cracked

Cooldown engine is live. Cracked the Midnight 12.0 secret-value problem by
routing all numeric math through Blizzard's privileged
`DurationObject:EvaluateRemainingDuration()` method (curve-evaluation
architecture, originally explored in the BetterCooldownManager and TweaksUI
Cooldowns research). The addon now produces real countdown values for tracked
spells without ever touching tainted secret values directly.

### New Features
- `Core/Engine.lua`: full curve-evaluation pipeline. Builds a Linear progress
  curve and a Step ready curve once at login, then per tick calls
  `dObj:EvaluateRemainingDuration(curve, default)` for every tracked spell.
- Hardcoded fallback duration table for 23 Paladin spells (Retribution focus)
  plus universal items like Hearthstone — used only when no learned duration
  exists.
- Persistent learning via SavedVariables: each spell only needs to be observed
  once (ever) for its true talent-adjusted duration to be remembered across
  `/reload` and login.
- Three-tier resolution hierarchy:
    1. Direct read via `EvaluateRemainingDuration` (most accurate, talent-aware).
    2. Cache extrapolation from a stored `cdStart`/`cdDuration` pair (used in
       combat when the curve method is unavailable).
    3. Fresh-cast inference via `UNIT_SPELLCAST_SUCCEEDED` (last resort, learns
       new spells the moment the player casts them).
- Diagnostic counters (`_curveEvalSuccess`, `_curveEvalFail`, `_fallbackUsed`)
  for verifying which strategy is firing in live play.

### Not yet implemented (next milestones)
- Stacking renderer in `UI/Lanes.lua` (defaults, options form, and hover-raise
  scripts are in place — only the `GROUPED` placement algorithm is missing).
- Bar frame status bar pool with transition animation.
- Ready frame fade animation and sound playback.
- Tab content: Lanes, Ready, Bars, Filters, Colors, Profiles, Import/Export, Changelog.
- Per-spell overrides, custom spell entry, import/export via LibDeflate.
- Fallback duration tables for the remaining 12 classes.

## 0.1.0 (Undated) — Scaffolding

First playable build. Loads cleanly on Mainline (Midnight 12.0+), Classic Era,
and TBC Classic. The structural skeleton is in place. Engine and tab content
are filled in incrementally from here.

### Implemented
- Project layout: `Core/`, `UI/`, `Libs/` with `.pkgmeta` and three TOC files.
- Ace3-based addon object, account-wide `AceDB` profile.
- Slash commands: `/cdmaster`, `/cdmaster lock`, `/cdmaster unlock`, `/cdmaster test`, `/cdmaster reset`, `/cdmaster version`.
- LibDataBroker launcher with left/right/middle click actions, plus minimap
  button via LibDBIcon (visible in Titan Panel, Bazooka, ChocolateBar).
- Themed options panel (red `#6D0501` tabs, yellow `#EBB706` text), with
  horizontal tab bar across the top.
- Global tab populated as a working example (Always / In Group / In Instance,
  Unlock Frames, Auto-hide, Tooltips, Shared CDs, Tint Unusable, Test button).
- Lane / Bar Frame / Ready Frame stub frames spawn on PLAYER_ENTERING_WORLD.
- Flavor-aware compatibility layer (`Core/Compat.lua`) gating Cooldown Manager
  hooks behind `HAS_BLIZZ_CDM`.

### Not yet implemented (next milestones)
- Cooldown engine: subscribing to Blizzard's Cooldown Manager on retail and
  legacy spell-cooldown polling on Classic / TBC.
- Lane icon rendering and timeline layout (the actual moving icons).
- Bar frame status bar pool with transition animation.
- Ready frame fade animation and sound playback.
- Tab content: Lanes, Ready, Bars, Filters, Colors, Profiles, Import/Export, Changelog.
- Per-spell overrides, custom spell entry, import/export via LibDeflate.
