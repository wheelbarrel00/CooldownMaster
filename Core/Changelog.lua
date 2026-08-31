local ADDON_NAME, ns = ...

ns.Changelog = {
	{
		version = "1.14.1",
		date = "2026-08-30",
		sections = {
			{ head = "Improvements", items = {
				"Lanes can now be up to 1300 wide. The Width slider stopped at 600, which was simply the number I picked when I first built the lane and never went back to. It reaches 1300 now. Height moves with it, because a vertical lane travels along its height rather than its width. Requested by cloudcaller on CurseForge.",
				"A Linear lane no longer offers a label anchor it cannot honor. Linear gives every icon its own clock, so there is no single number of seconds a label could name, and the two Time choices under Lanes > a lane > Text > Anchor By quietly drew a percent instead. The dropdown said one thing and the lane did another. Those choices are now withheld on a Linear lane and Position (seconds) is dimmed, so the panel shows what the lane actually does. A Time anchor you already saved is kept, and comes back the moment you move that lane to Timeline, Logarithmic or Split.",
			} },
			{ head = "Bug Fixes", items = {
				"Refreshed debuffs no longer read 30 percent long on Era and TBC. When a debuff you applied was refreshed, Cooldown Master rolled the unspent remainder into the new timer, capped at 30 percent of the base length. That is how the modern game works, but it arrived in Mists of Pandaria. On Era and TBC a refresh throws the remainder away and starts clean. So a 10 second Judgement of the Crusader showed 13 and jumped back up every time a melee swing refreshed it.",
				"Debuffs you put on yourself no longer show up under Offensives. Offensives tracks the harmful effects you apply to somebody else, and the check that you were the source had no matching check on who received it. Anything you were both the source and the target of was picked up too, so Forbearance from your own Divine Shield or Lay on Hands sat in the list alongside the Fall down and Dropped Weapon effects from falling. The list rebuilds itself every session, so those clear on their own after the next login.",
				"An offensive dot no longer strands an icon on the lane after a target swap. Cooldown Master keeps a backstop for a dot that vanished without the combat log saying so, dispelled while you were out of range or dropped when a mob reset. That backstop only arms for a dot it has watched on the target, and swapping targets rebuilt the tracking from scratch and lost that state, so it never armed again. The icon then rode out its full length and popped a ready box for a dot that had been gone for a while.",
				"A learned debuff length can no longer run away. For a dot Cooldown Master cannot read a timer off directly, it learns the length by timing one from application to removal. If the refresh in the middle never reaches you, that measurement covers the whole time you kept the dot up, so a 12 second dot maintained for three minutes could teach itself three minutes and hold onto it. A single measurement can now at most double what it already knows.",
			} },
		},
	},
	{
		version = "1.14.0",
		date = "2026-08-25",
		sections = {
			{ head = "New Features", items = {
				"Route cooldowns to lanes by how long they are. A new Route by Cooldown Length section at the top of Filters > Defaults. Tick Sort cooldowns into lanes by length, set a Short Up To and a Medium Up To threshold, and pick the lane each band goes to. The reason to want this is a fast lane and a slow lane: send everything under a minute to Lane 1 with a short Max Time so it reads like a rotation helper, and everything longer to Lane 2 with a long Max Time so your big cooldowns get their own space. It routes on the cooldown's real length, so it covers spells, potions and trinkets, pet abilities, and your own custom cooldowns alike. A lane you picked for an individual spell still wins over it, and anything whose length has not been learned yet falls back to the category defaults. Test mode previews it too. Off by default.",
				"Icons can pulse as they travel. Lanes > a lane > Icons > Pulse makes an icon breathe in and out, so a lane you care about is easier to catch out of the corner of your eye. Pulse Within (sec) holds the pulsing back until a cooldown is that close to ready, or set it to 0 to pulse the whole way along the lane, and Pulse Strength is how many pixels the icon grows at the peak. A Masque skin draws its own icon, so the pulse stands down while one is active.",
				"Textures and borders now preview in their dropdowns. A media list used to give you a name and nothing else, which is no help when the names are things like Glass and Gradient. Statusbar textures now draw a filled swatch of the actual texture beside each name, and border textures draw a small box with that border around it. Fonts have previewed themselves for a while, and this brings the rest of the media pickers up to match.",
			} },
			{ head = "Bug Fixes", items = {
				"Cooldown Master no longer resets Arcana's bar layout. Our TOC listed ChocolateBar as an optional dependency, dating from when ChocolateBar was the broker display addon. Arcana, which replaced it, now ships a load-on-demand stub folder under that same old name to migrate old profiles, and naming a load-on-demand addon as an optional dependency force-loads it. So every login, Cooldown Master was quietly triggering Arcana's migration path: Arcana re-ran its ChocolateBar import, replaced its own live database with the result, and re-initialized, which reset bar tile positions and display settings and threw an error about its options panel being registered twice. The entry is gone. It bought nothing, because broker displays pick up new data objects through a callback regardless of load order. Reported by RoadBlock.",
				"A font left behind by an addon you removed no longer errors. Font dropdowns draw each entry in the font it names, and that list comes from LibSharedMedia, which hands back a registered path without checking the file is still on disk. Opening a font dropdown called on every registered path including dead ones, which threw an invalid font asset error and, on the Ready and Bars pages, could leave the form half-built. Font paths are now checked before use and fall back to the default face. Reported by RoadBlock.",
				"The Classic options panel no longer runs out of time. This is the cost I said I was going after in 1.13.0. Every dropdown built one button and one backdrop for every option in its list the moment the panel was created, and with a media pack installed LibSharedMedia reports around 500 statusbar textures. A single lane's Appearance section was building thousands of frames before it drew anything, which is what pushed it past the game's script watchdog and left sections with controls missing. Dropdowns now build nothing until you first open one, and then only the rows you can see, repainting them as you scroll. The 1.13.0 fix stopped the panel breaking when this happened. This stops it happening.",
				"The label position sliders no longer offer time a lane cannot reach. Position (seconds) ran to 360 regardless of the lane's own Max Time, so on a three-minute lane typing 360 snapped back to 180 and looked like the sliders were fighting each other. It now stops at the lane's Max Time, and rebuilds when you change it. Reported by RoadBlock.",
				"Potions sharing a cooldown no longer go blank. Item IDs and spell IDs share one numeric range, so an item could land on a key a spell already held. The item then claimed the shared cooldown start on behalf of every potion grouped with it but could not draw anything itself, so all of them went empty for that cooldown.",
				"A cooldown that lost a shared-cooldown grouping no longer pops a false ready. Only one icon shows for a group, and the ones that lose were being left behind rather than cleared, so the next sweep read them as having just come up and fired a ready box for a cooldown that had not finished.",
				"A disabled lane reads (off) everywhere you can route to it. Turning a lane off updated the label in some routing dropdowns but not others, so a lane could look available on one screen and disabled on another.",
			} },
			{ head = "Improvements", items = {
				"All seven languages are complete again. The 1.13.0 features arrived faster than the translations did and left English showing through in places. French, German, Russian, Korean, Simplified Chinese, and Traditional Chinese are all back to full coverage, this release included.",
				"GCD and swing tracking is read once per frame rather than up to six times, once for each lane and bar asking separately.",
				"Ready box icons restyle a few times a second instead of on every frame. Nothing about them changes fast enough to need 60 readings a second.",
				"Cooldown Master now declares itself under the Combat category on the retail addon list.",
			} },
		},
	},
	{
		version = "1.13.0",
		date = "2026-08-23",
		sections = {
			{ head = "New Features", items = {
				"Lane labels can be moved off the bar. A new Label Placement setting - Above lane, On lane, Below lane - plus X and Y offsets. On a short lane with large icons the labels used to sit underneath the icons where you could not read them. On a vertical lane, Above and Below become right and left. Requested by RoadBlock.",
				"Lane labels can now write their own text. Until now a label was text you typed, pinned to a fixed spot, with no idea what the lane measured. So if you typed 30s and later changed the lane's Mode or Max Time, it stayed put and quietly became wrong.",
				"Each label now has an Anchor By setting. Percent of lane is what you have today: you type the text and pick the spot. Percent of lane (auto label) still lets you pick the spot, and Cooldown Master writes the text - park a label at the halfway mark of a two-minute Timeline lane and it reads 1m, switch that lane to Logarithmic and the same label re-reads itself as 10s, push Max Time to six minutes and it becomes 3m. Time (seconds) works the other way round: you pin the label to a number of seconds and it finds its own spot. Time (auto label) does both.",
				"On a Linear lane an auto label reads a percent rather than a time. Linear gives every icon its own clock - halfway along the bar means halfway through that spell's cooldown, which is thirty seconds for one spell and ninety for another. No single number of seconds is true there, but the percent is true for all of them, so that is what the label names.",
				"Lanes can now cover six minutes. Max Time used to stop at three. It reaches 360 seconds now, and Split mode's point timers go with it, so a long lane can still be shaped across its whole length.",
			} },
			{ head = "Bug Fixes", items = {
				"Tooltips on lane icons no longer block mouse-turning. With Enable Tooltips on and frames locked, hovering an icon swallowed the right mouse button, so you could not turn your character while the cursor sat over one. Icons now take mouse movement without taking clicks. Reported by RoadBlock.",
				"The Lanes options panel no longer garbles itself. Opening a lane's General or Appearance section can exceed the game's script watchdog on Classic clients and get cut short. A section's frame is created visible, so an interrupted build was left on screen but never registered, which meant nothing could hide it again and it stacked on top of every section opened afterwards until a reload. Interrupted builds are now contained and reported. This has been present since well before this release.",
				"Split points set past Max Time no longer strand the end of your lane. Such a point can never be reached, and it stopped the curve short of the bar's own end, leaving that tail as dead space no icon could occupy. Those points are now dropped from the curve. If you have a lane configured this way, your icons will spread across the full bar after updating.",
				"A split curve that folds back on itself is no longer honored. Setting a later point's position below an earlier one's made the curve double back, leaving no single answer for what a spot on the bar was worth. Points that fail to move forward on both axes are now ignored.",
				"Labels can no longer claim more time than the lane shows. A label anchored past Max Time parked itself at the end of the bar while still reading its original number.",
			} },
			{ head = "A note for Classic players", items = {
				"The cost behind that panel bug is still there. A lane's General and Appearance sections are heavy enough to reach the script watchdog on Classic clients, so they can come up with some controls missing. The panel no longer breaks when it happens, and the cost itself is the next thing I am fixing. Retail is not affected.",
			} },
			{ head = "Improvements", items = {
				"Labels pin to the end of a lane only when the text would genuinely run off it, so two labels near the same end no longer land on the same pixel. At default sizes the first and last labels now line up with their icons rather than sitting a few pixels from the bar's edge, which is most visible on a vertical lane.",
				"The two Position sliders mirror each other and re-check themselves whenever you open the Text page, so neither can show a number that is no longer true.",
			} },
		},
	},
	{
		version = "1.12.0",
		date = "2026-08-21",
		sections = {
			{ head = "New Features", items = {
				"German is here, and it covers the whole addon. Every options label, tooltip, message and popup reads in German, joining French, Russian, Korean, Simplified Chinese and Traditional Chinese. That makes six languages complete end to end. Contributed through the shared translation store by Stonetwist.",
				"The translators are credited on the About tab, under Translations, with a note about which part of the text is actually their work.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed a potion spending its whole cooldown wearing another potion's name. Every potion shares one cooldown, so Cooldown Master works out which one to show from the potion you actually drank. That did not survive a /reload or a login, so with a potion cooldown still running it fell back to whichever potion had the lowest item ID and kept that name for the rest of the run.",
				"Unequipping an on-use trinket no longer pops a ready box for it minutes early.",
				"/cm tracking no longer fills your chat with Lua errors on retail. It samples the global cooldown and swing timer, which are Classic-only, and asked you to be in combat to do it, where retail will not hand those numbers to addons at all. It now says so and stops.",
				"Closed a rare Lua error that could break cooldown tracking for the rest of a session. A cast whose spell ID retail declines to reveal was being used as a lookup key.",
				"Corrected the Simplified Chinese credit in the 1.10.0 entry below.",
			} },
		},
	},
	{
		version = "1.11.0",
		date = "2026-08-18",
		sections = {
			{ head = "New Features", items = {
				"Cooldown Master is now fully translated in all five languages. French, Russian and Korean went from covering only the phrases shared with my other addons to the whole addon, and Traditional Chinese went from a third of it to all of it. Every options label, tooltip, message and popup now reads in your client's language.",
				"The tag help you get when you hover a Text or Label Text box now translates too. It was English for everyone before, which made it the largest block of untranslated text left in the addon.",
			} },
			{ head = "A note on the translations", items = {
				"I am not able to test these in a non-English client - I do not have the other languages installed. Everything passes the automated checks, but those cannot catch a label that runs off its button or a tooltip that sends you to a setting you cannot find.",
				"So if you see anything off, please tell me and I will fix it. The Discord button on this About tab, the comments on the CurseForge page, or a GitHub issue all reach me. Corrections from native speakers are very welcome.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed the Default Lane dropdown in Filters falling back to English. It was built with translated lane names and then quietly overwritten with hardcoded English ones whenever the list refreshed, so on any translated client it reverted the moment you toggled a lane.",
				"The Edit button on each custom cooldown, and the message shown when a profile export fails, were hardcoded English and now translate.",
				"The icon nudge slider on the Lanes and Ready tabs shared a name with the Offset stacking style, so one word had to serve an adjective and a noun. It has its own name now and reads correctly in every language.",
				"Corrected three Simplified Chinese tooltips that pointed you at controls using words those controls do not use, so following the instructions led nowhere.",
				"Swept every language for tooltips that named a setting differently from the setting's own label, for two different settings that had ended up with the same name on one panel, and for text that overflowed its button.",
			} },
		},
	},
	{
		version = "1.10.0",
		date = "2026-08-15",
		sections = {
			{ head = "New Features", items = {
				"Cooldown Master is now translated. Everything the addon draws - options, tooltips, ready boxes, this popup - reads in your client's language where a translation exists, and falls back to English where it does not. French, Russian and Korean cover the phrases Cooldown Master shares with my other addons and will fill in over time. Simplified Chinese covers the whole addon, but only the shared phrases are the work of the translator credited on my other addons - the rest was a machine-assisted first pass that no native speaker had reviewed.",
				"Translations are bundled in the addon, so there is nothing to install and nothing to download. Your client language decides, and switching languages switches the addon with it.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed custom cooldowns never picking up their real name on a non-English client. A new custom starts out called \"New Custom\", and entering a Trigger ID is meant to replace that with the ability's actual name. The placeholder was being translated while the check looking for it was not, so the two never matched and the custom kept the placeholder name for good.",
				"Fixed translated frame names being written into your saved settings. The default names for lanes, ready boxes and bar frames were saved in whatever language you first logged in with, and switching your client language afterwards would have left them stuck in the old one permanently. They are stored in plain English again and are yours to rename as always.",
				"The Filters column headers (Show, Lane, Bar, Ready Box, Flags) stayed English while the Remove and Buff headers beside them were translated, so one header row read as two languages at once.",
				"Several strings that had been missed now translate too, including the lane tooltip for a custom cooldown, the profile import failure message, the on/off button on each custom, and the copy-a-link hint.",
			} },
		},
	},
	{
		version = "1.9.3",
		date = "2026-08-14",
		sections = {
			{ head = "Bug Fixes", items = {
				"Retail: fixed an error that fired every time one of your tracked effects on a target ran out. A tidy-up step added in 1.9.2 for the Classic flavors reached for your target's unique ID, which Midnight keeps secret on a hostile target, and looking it up at all was enough to trigger the error. Your ready boxes and lanes were behaving correctly throughout - the cost was the error itself. Retail only, and only with Offensives switched on.",
				"Classic: an effect that leaves nothing to read on your target now keeps improving its own timing. Something like a Paladin's Consecration puts nothing on your target that Cooldown Master can inspect, so it works out the length from when the combat log says the effect ended, and revises upward as it sees longer runs. The same 1.9.2 step was discarding the record it needed, so the estimate was pinned to whatever the first run gave - and if that run was cut short, the ready box fired early on every cast afterwards. Estimates now keep correcting themselves as you play.",
			} },
		},
	},
	{
		version = "1.9.2",
		date = "2026-08-13",
		sections = {
			{ head = "Bug Fixes", items = {
				"Classic: an effect with no debuff on the target, like a Paladin's Consecration, no longer flashes onto a lane for a second and vanishes. Cooldown Master checked your target for it once a second, could not find it there, and removed it. It now lets the combat log and the effect's own length decide when it ends.",
				"The Offensives tab no longer says \"No harmful effects discovered yet\" while the category is switched off. Offensives is the one category that ships switched off, so if you went looking for your effects on a target and found nothing, this is why. It now says so plainly and points at the tick box that turns it on. Thanks to yisisixu for the report.",
				"Turning a category on or off updates the panel straight away, and the same setting on the Defaults tab keeps in step instead of showing the old value until you reload.",
				"Classic: the Buff Bars tab no longer tells you to reload to fill a list that can never fill on this version of the game. It explains what the category is for and points you at Offensives.",
				"Retail: the Offensives tab no longer walks you through a /cm offlearn setup your client will refuse. On 12.1 the game withholds what that procedure reads, so it could only end in \"could not read anything\". The tab now says an effect it has not already learned cannot be picked up on such a client, and that anything already learned keeps working.",
			} },
			{ head = "Improvements", items = {
				"Offensives is described as what it actually tracks: the harmful effects you put on your target, damage-over-time effects and debuffs like stuns alike, not damage-over-time alone.",
			} },
		},
	},
	{
		version = "1.9.1",
		date = "2026-08-11",
		sections = {
			{ head = "Bug Fixes", items = {
				"Retail: fixed an error that fired every time your target's auras changed in combat. Midnight hands addons that update in a form they are not allowed to read mid-fight, and Cooldown Master read one of those values directly. It checks first now, and falls back to its once-a-second sweep, so your dots keep appearing and clearing as before. Heads up: a dot Cooldown Master has never seen cannot be learned mid-fight while the game withholds this - cast it once out of combat and it sticks.",
				"/cm offlearn says when your client will not let it read your dots, instead of answering \"could not read that dot yet\" every time.",
			} },
			{ head = "Improvements", items = {
				"/cm auraprobe and the /cm off traces survive an unreadable aura update, and name what they could not read.",
			} },
		},
	},
	{
		version = "1.9.0",
		date = "2026-08-08",
		sections = {
			{ head = "Bug Fixes", items = {
				"Retail: other players' damage-over-time effects no longer end up in your Offensives list. Cooldown Master learns which of your abilities applies which dot by watching what lands right after you cast, and in a group a teammate's dot landing at that moment could be attributed to one of your abilities instead. Once learned it stayed learned, so their dot appeared on your lanes as if it were yours. The game reports a debuff as coming from you even when it does not, and that is what the check relied on. It now confirms the source directly and refuses anything it cannot positively tie to you. Heads up: because every existing mapping was learned through the faulty check, the learned dot list is cleared once on your first login after updating. Filters > Offensives will be empty until your own dots relearn, which happens as you cast them. Anything you had set up for those dots is kept - a dot you routed to Lane 3, sent to a particular bar or ready box, or unticked Show on, comes straight back to that setting the moment it is relearned. Retail only, and only if you turned Offensives on.",
				"Classic Era: your potions are tracked at all now. Era does not tell addons whether a consumable is a potion, an elixir or a piece of food, so the filter that picks out potions matched nothing and Filters > Potions was permanently empty. Every consumable is now listed on Era. Heads up: food and drink are listed there too, because Era gives nothing to tell them apart. They have no cooldown, so they never draw an icon or a ready box - untick Show on their rows if you would rather not see them in the list.",
				"TBC: Fishliver Oil is tracked. It carries a real two minute cooldown, but Blizzard files it outside the potion and elixir categories, so it was never picked up.",
				"Items looted or used during Test Mode are picked up when you leave it. Anything you looted or drank while Test Mode was running was ignored until an unrelated bag change happened to trigger a rescan. Drinking a potion during Test Mode could also hand its cooldown to the wrong potion's icon for the rest of that cooldown.",
			} },
			{ head = "New Features", items = {
				"Font dropdowns show each font in its own typeface. Every font list in the options now draws each name in the font it names, and the closed dropdown previews your current choice, so you can see what you are picking before you apply it.",
			} },
			{ head = "Improvements", items = {
				"The download is about 728 KB smaller. Four bundled libraries - AceGUI, AceConfig, AceDBOptions and the shared-media widgets - were being loaded on every login without anything using them. The options panel is hand-built and never needed them.",
				"Dropdown lists size themselves to their longest entry, so options like \"Lane 3 (off)\" no longer run past the edge of the list they sit in.",
				"Better diagnostics. /cm off arm now takes a length, so /cm off arm 45 traces long enough to cover combat ending, which is when dot learning actually happens, and it reports exactly why a dot was learned or refused. /cm bagscan and /cm itemcd now describe the rule your flavor uses.",
			} },
		},
	},
	{
		version = "1.8.0",
		date = "2026-08-03",
		sections = {
			{ head = "Bug Fixes", items = {
				"Retail: ready boxes no longer pop before the cooldown is actually up. When a cooldown's last second ran out underneath the global cooldown, the game reported it identically to a spell that was already ready, and Cooldown Master read that as the cooldown ending. The ready box fired early and the lane icon vanished before finishing its travel - measured at 0.7 to 0.9 seconds early on a 9.3 second cooldown. Any cooldown whose real length has been learned now holds until it genuinely finishes.",
				"Lane time markers line up with the icons again. The 25% and 75% labels sat about 9 pixels off the icons they were labeling, in opposite directions. Markers measured across the whole lane, while an icon travels across the lane minus its own width. All five markers ship switched on, so every lane showed this out of the box. They now stay aligned at any icon size.",
				"Frame Scale no longer knocks your frames out of place. Rescaling rewrites every lane, box and bar offset so they hold their position on screen, and at smaller scales those numbers could run past what the X and Y Offset sliders were able to represent. The next nudge of one of those sliders then clamped your frame somewhere else entirely. Those sliders now widen as the scale shrinks, so the value always fits.",
				"Turning off a Masque group gives Cooldown Master its icon zoom and border back. Unticking Enabled on one of its groups in Masque left the icons stripped of the skin and of Cooldown Master's own zoom and border, with no way to recover them. Masque re-skins a disabled group with its default skin rather than releasing it, which was being read as still skinned.",
				"Your pet dying no longer pops a ready box for each of its abilities. A dead pet stops reporting its cooldowns all at once, which read as every pet ability coming off cooldown together. They now leave quietly while the pet is down.",
				"Classic: dying no longer pops a ready box for every buff you were tracking. Death strips your buffs in a single pass, and each one fired its own box and sound, filling the display and pushing out anything real. They now clear silently.",
				"Hovering a stacked lane icon no longer drops it underneath its neighbors. Moving the mouse away returned the icon to the bottom of the stack instead of its own layer, where it stayed until its position in the stack happened to change. Needs Stacking and Raise On Mouseover, both off by default.",
				"A frame that hides mid-drag no longer chases your cursor. If a lane, ready box or bar frame hid while you were dragging it, it kept believing the drag was still going and snapped to wherever your cursor had reached by the time it reappeared.",
				"A dragged lane's border is crisp again. Dropping a lane left it sitting between physical pixels, which smears a one-pixel border across two rows until some unrelated setting changed. Lanes, ready boxes and bar frames all re-align the moment you let go now.",
			} },
			{ head = "Improvements", items = {
				"Sharper diagnostics for cooldown timing. /cm anchor arm now takes a length and a spell name, so /cm anchor arm 30 blade of justice traces one spell for 30 seconds instead of your entire tracked set, short enough to read and to paste into a bug report. /cm masque reports a group you have disabled in Masque and no longer claims a failed group registered fine, and /cm petprobe reports whether your pet is alive.",
			} },
		},
	},
	{
		version = "1.7.0",
		date = "2026-07-31",
		sections = {
			{ head = "New Features", items = {
				"Conjured mana gems and healthstones are now tracked. A Mage's Mana Agate through Mana Emerald, and a Warlock's healthstones including the Improved and Master ranks, now appear under Filters > Potions without you adding them by hand. CDM only recognized what Blizzard files as a potion, elixir or flask, and conjured items sit outside all three, so they were invisible to it. They also tend to carry their cooldown on the spell they cast rather than on the item itself, which CDM now reads as well. Thanks to Dr. Hangover for the report. Heads up: if you play a Warlock, your healthstone will start appearing where it did not before - untick Show on its row under Filters > Potions if you would rather it stayed hidden.",
			} },
			{ head = "Bug Fixes", items = {
				"Retail: the Potions list no longer shows potions you are not carrying. CDM was seeding a small built-in set of retail potion IDs on top of scanning your bags. One of them no longer exists in the game and appeared as a nameless \"Item 258318\" row that could never do anything, and two others were alternate versions sharing a name with potions you would actually have, so Light's Potential and Flask of the Magisters each showed up twice. Your bags are the only source now, on every flavor.",
				"Hiding one potion no longer hides another. All combat potions share a single cooldown, and unticking Show on one could leave a potion you had not hidden with no icon, no bar and no ready box at all. Hidden items now step aside instead of claiming the shared cooldown, which is how spells have always behaved.",
				"Using the last of a potion no longer loses its icon. Drinking your final one removes the item from your bags, and the timer used to vanish with it about half a second later, or hand the countdown to a different potion, so a mana potion you drank would finish its run wearing another potion's name. It now runs to the end as itself and pops a ready box when the cooldown is up.",
			} },
			{ head = "Improvements", items = {
				"Two new diagnostics for working out why an item is not showing. /cm bagscan lists every consumable in your bags with what CDM decided about it and why, and /cm itemcd <itemID> reads a single item's cooldown even after you have used your last one.",
			} },
		},
	},
	{
		version = "1.6.0",
		date = "2026-07-28",
		sections = {
			{ head = "New Features", items = {
				"Ignore Threshold now works on the Classic flavors, and on every flavor for potions and trinkets. The slider under Filters has always promised to stop tracking anything whose full cooldown runs longer than the number you set, but on Era, TBC and MoP it never had a length to compare against, so it quietly did nothing at all. It now learns each ability's real cooldown the first time you use it, and remembers that between sessions. Heads up: with the default threshold of 1800 seconds, abilities longer than 30 minutes will now start dropping off your lanes where they used to show - Shaman Reincarnation is the usual example. Tick Show on the spell's row under Filters to keep any of them.",
			} },
			{ head = "Bug Fixes", items = {
				"Ready icons no longer double or triple up for abilities with charges. On retail, spending one charge of something like Blade of Justice looks briefly identical to the ability going on cooldown, and under a fast rotation that could pop a ready box for a cooldown that had not finished - sometimes two or three times over. The false pops are gone, and a ready box now shows one icon per cooldown regardless.",
				"The profile import window opens again on retail. Midnight renamed part of Blizzard's popup dialog, which made the Import window throw an error the instant it appeared, so importing a profile was impossible. Exporting was never affected.",
				"The color picker's opacity slider runs the right way round on retail. It was treating the value as transparency where Midnight reports opacity, so the slider opened at the inverse of your real setting and dragging it to full made things disappear. Cancel now restores the transparency you started with, too.",
				"Bar frames no longer vanish part-way through a cooldown. If the estimated length came in short, a bar could disappear while the lane still showed the same spell running. It now holds until the cooldown genuinely ends, matching the lanes.",
				"Locked ready boxes and bar frames stop swallowing mouse clicks. Both kept taking the mouse after you locked your frames, so clicking where an invisible box sat did nothing in the world behind it. The lanes already handled this correctly.",
				"Importing a profile no longer risks breaking your settings. An import built from an older version could permanently drop any setting that string did not carry, which left blanks behind and could error. An import now starts from a clean set of defaults and layers the imported values over it, so anything the string omits simply keeps its default.",
				"Right-clicking the minimap icon now unlocks bar frames too, and Test Mode brings your ready boxes up straight away instead of leaving them hidden until a sample expired.",
				"The Unlock Frames checkbox no longer ignores your first click after you had locked or unlocked from the minimap button or /cm lock. The Options panel was showing a stale tick.",
				"The Options panel no longer leaks frames while it is closed. Looting, changing spec or switching profiles rebuilt hidden option lists every time, and those frames stack up for the rest of your session. Rebuilds now wait until the panel is actually open.",
			} },
			{ head = "Improvements", items = {
				"Profile exports no longer carry per-character learning. Exported strings were including the cooldown lengths and dot attribution your character had picked up, which is personal runtime data rather than a setting. Exports are smaller now, and importing someone's profile leaves your own learning untouched.",
				"The frame Status Line explains what it cannot do. Per-cooldown tags like [cd.name] have no single cooldown to name on a frame-wide line, so they render blank there. The box now says so - put those on an Icon Label instead.",
			} },
		},
	},
	{
		version = "1.5.1",
		date = "2026-07-22",
		sections = {
			{ head = "Compatibility", items = {
				"Updated for Classic Era 1.15.9.",
			} },
		},
	},
	{
		version = "1.5.0",
		date = "2026-07-22",
		sections = {
			{ head = "New Features", items = {
				"Track a spell's buff alongside its cooldown. On the Classic flavors, a spell that has a cooldown and also gives you a buff - Icy Veins, Arcane Power and the like - can now show a second icon that counts down the buff itself, separate from the cooldown timer. Tick Buff on the spell's row under Filters > Spells, then set where it goes under Filters > Buffs. Off by default, so nothing new appears until you ask for it. Retail surfaces tracked buffs through Blizzard's own list already, so this is Classic-only.",
			} },
			{ head = "Bug Fixes", items = {
				"Cooldown Master shows up in Masque even with an empty timeline. It was only registering its skinnable groups once an icon had been drawn, so opening Masque before any cooldown appeared left CooldownMaster missing from the Skin Settings list. Its three groups - Lane Icons, Ready Icons and Bar Icons - are now registered up front.",
			} },
			{ head = "Compatibility", items = {
				"Updated for Burning Crusade Classic 2.5.6.",
			} },
			{ head = "Thanks", items = {
				"Dr. Hangover - for the idea of tracking a cooldown's buff as its own icon.",
			} },
		},
	},
	{
		version = "1.4.1",
		date = "2026-07-20",
		sections = {
			{ head = "Bug Fixes", items = {
				"The Detect button on a custom cooldown now fills in the buff's real duration instead of always defaulting to 30 seconds. It already had the value from the buff you gained, it just was not using it. On Classic the duration reads straight off the buff, and on retail it fills in whenever the game will let an addon read it.",
			} },
			{ head = "Thanks", items = {
				"Dr. Hangover - for spotting that the custom Detect button was ignoring the buff's duration.",
			} },
		},
	},
	{
		version = "1.4.0",
		date = "2026-07-19",
		sections = {
			{ head = "Bug Fixes", items = {
				"Offensives no longer pick up other players' damage-over-time effects. This is the raid leak from the last update's Known Issues - target a mob other people have already dotted and their Flame Shock or Ignite could land in your Filters > Offensives list. A dot now only enters your list once one of your own casts has claimed it, so someone else's dots stay out even on a shared target. Any that were already collected clear themselves on your next login, or use /cm offreset to wipe them now.",
				"Offensive dots track more cleanly under a busy rotation. The way a dot is matched to the ability that applied it was reworked, so dots learned mid-fight no longer intermittently vanish, freeze at the start of the lane, or double up - which mostly showed on abilities that apply more than one debuff at once.",
			} },
			{ head = "New Features", items = {
				"/cm offlearn - a guided way to teach your dots. Because the game hides a debuff's identity in combat, Offensives are learned out of combat. Type /cm offlearn, cast one dot ability, then stop and let combat end - it reads what that ability applied, learns it, and tells you what it learned. Repeat for each ability, then /cm offlearn stop. Especially handy for an ability that applies more than one debuff at once. Retail only - on the Classic flavors dots are still detected automatically.",
			} },
			{ head = "Improvements", items = {
				"Custom cooldowns are a clean list now. After a few of them the old layout stacked into a long scroll. They now show as a compact list - icon, name, an on/off toggle, Edit and a delete button on each row - and only the one you are editing opens its full editor below. Adding one opens its editor straight away. Filters > Custom.",
				"The Offensives tab now explains how to learn your dots, with the /cm offlearn steps right there on the panel.",
			} },
		},
	},
	{
		version = "1.3.0",
		date = "2026-07-17",
		sections = {
			{ head = "Changed Defaults", items = {
				"A fresh install now starts with all three lanes on, and potions in their own lane. Lane 1 carries your spells, utility, buffs and trinkets. Lane 2 carries potions, flasks and elixirs, so your consumables stop competing with your rotation. Lane 3 is on but deliberately has nothing routed to it - it is a spare, so you can send something to it or just turn it off, whichever suits you. It is meant to make the first five minutes make sense for someone who just installed the addon.",
				"This will reach you even if you have been using the addon a while. Any setting you have actually changed is kept, but anything you never touched picks up the new default - so if you never went near Lane 2 or Lane 3 you will see them switch on, and potions move to Lane 2. Turning a lane back off is one tick under Lanes > that lane > General > Enabled, and potions go back under Filters > Defaults > pick Potions > Default Lane.",
				"This is the last time I change the defaults. I am sorry for any re-setup this costs you. It is only to give new users a sensible starting layout, and it will not happen again.",
			} },
			{ head = "New Features", items = {
				"Masque support. If you use Masque, Cooldown Master now registers three groups you can skin or disable independently in Masque's own options: Lane Icons, Ready Icons and Bar Icons. Nothing changes until you pick a skin for a group. While a group is skinned the skin owns that icon's border and crop, so Cooldown Master's own icon border and zoom step aside for it.",
				"Ready boxes now do text, like lanes and bars. They support an icon label on each ready icon (the ability name by default) and a status line on the box itself, with the same click-to-insert tag picker and full font, size, outline and color control. Both are off by default. Ready > a box > Icons > Icon Label, and Ready > a box > Text > Status Line.",
				"Elixirs are tracked now. Potions and flasks were tracked, elixirs were quietly skipped. They show up alongside them under Filters > Potions.",
			} },
			{ head = "Bug Fixes", items = {
				"Health and resource tags never worked on retail, and no longer pretend to. [player.hp.pct] and [player.power.pct] rendered blank for every retail user since 1.2.0. Retail returns your health and power as protected values addons are not allowed to read, even out of combat, so a percentage cannot be worked out at all. Those tags are now offered on the Classic flavors only, where they work, instead of sitting in the picker doing nothing. [cd.time] has always been Classic-only for the same reason - on retail the icon's own countdown covers it.",
				"A stale status line no longer flashes when a ready box comes back after auto-hiding.",
				"The About tab no longer claims to complement Blizzard's Cooldown Manager on Classic, which does not have one. Same for the addon list description on the three Classic flavors.",
			} },
			{ head = "Improvements", items = {
				"Every row in Filters has tooltips now. Hover a spell or item's name for its real in-game tooltip, and hover Show, Lane, Bar, Ready Box or Flags to find out exactly what each one does - including what Important and Pinned really mean.",
				"/cm tagprobe joins the diagnostic commands, reporting what each text tag resolves to on your client.",
			} },
			{ head = "Known Issues", items = {
				"Offensives can pick up other players' damage-over-time effects in a raid. If you target a boss or a trash pack that other people have already put dots on, those dots can end up in your Filters > Offensives list - Flame Shock or Ignite or Sunfire showing up on a Paladin, for example. It only happens on a target someone else has already dotted, which is why it shows up in raids and never when you are out solo. I have tracked down the cause and a fix is coming very soon in the next update. Until then, /cm offreset clears the whole list, and the per-spell Remove (X) button clears them one at a time. Sorry about this one.",
			} },
			{ head = "Thanks", items = {
				"Rocker57 - for pointing out that the default lanes were wrong, and for all the help along the way making this a better addon. Genuinely appreciated.",
			} },
		},
	},
	{
		version = "1.2.0",
		date = "2026-07-15",
		sections = {
			{ head = "New Features", items = {
				"Icon labels. You can now show text on each cooldown icon in a lane, by default the ability name. Build it from tags like [cd.name] and [cd.type], with a click-to-insert picker so you do not have to remember them, plus full font, size, outline and color. Turn it on under Lanes > a lane > Icons > Icon Label. Off by default.",
				"Status line. A line of live text you can add to any lane or bar frame - the name of the next cooldown coming up, how many are on cooldown, your target's name and more. Same click-to-insert tag picker. Turn it on under a lane's Text tab or a bar's Bar tab. Off by default.",
				"Remove button on Offensives. Each spell in the Offensives category now has a small Remove button. Use it to clear a damage-over-time effect that got picked up from another player on a shared target dummy. If the spell is really yours, it comes back the next time you cast it.",
			} },
			{ head = "Improvements", items = {
				"The Debuffs filter tab is now labeled Buff Bars. It was always a mislabel - that category is Blizzard's bar-style tracked buffs, what the built-in Cooldown Manager shows as bars, not debuffs. Your own damage-over-time effects live in the Offensives category. Your existing settings for the category are kept.",
			} },
		},
	},
	{
		version = "1.1.0",
		date = "2026-07-14",
		sections = {
			{ head = "New Features", items = {
				"Offensives. A new Filters category that tracks your own damage-over-time effects and debuffs on your current target, so you can see when a dot is about to fall off. It is off by default - turn it on under Filters > Offensives. On retail the game hides a target's auras from addons in combat, so Offensives learns each dot from the spell you cast rather than by reading the target. A brand new dot may take a cast or two to start showing, and it follows your current target only.",
				"Pet Spells. A new Filters category that tracks your pet's ability cooldowns, for Hunters, Warlocks, Death Knights and anyone with a pet bar. It is on by default. Your pet's basic attack and its command and stance buttons are left out, so only real cooldowns show.",
				"Scale controls, on the Global tab. Cooldown Frames resizes all of your lanes, bars and ready boxes together while keeping them where they are. Options Window resizes this settings window itself. Both run from half size to double size.",
			} },
			{ head = "Improvements", items = {
				"Each Filters category now has its own Track this category checkbox on its own tab, instead of only being reachable from the Defaults tab.",
				"Disabled lanes now read Lane N (off) in the lane dropdowns, so it is clear why a routed spell is not showing.",
				"The Custom cooldown editor keeps its scroll position while you add or edit entries.",
			} },
			{ head = "Bug Fixes", items = {
				"Custom aura-gained triggers are reliable on retail now. In combat they could fire only every other time, and a buff first gained during a fight could fire late once combat ended. On retail your own buffs are hidden from addons in combat, so an aura-gained custom cannot start mid-combat at all. The editor now says so and points you to the Spell cast trigger, which does work in combat.",
				"Fixed a cooldown that could travel the whole lane with no countdown and no swipe if it was recast the instant it came off cooldown. This was easiest to see with a pet ability the pet recasts on its own, such as Growl.",
				"Fixed a potion or other consumable showing the wrong name when several of them shared a single cooldown.",
			} },
			{ head = "Thanks", items = {
				"Thanks to user_1y22hxslizrfxfxf4w on CurseForge for suggesting the UI scale slider.",
			} },
		},
	},
	{
		version = "1.0.0",
		date = "2026-07-12",
		sections = {
			{ head = "Out of Beta - Please Read", items = {
				"Cooldown Master is officially out of beta. Thank you to everyone who tested, reported bugs, and asked for features along the way. This release earns the 1.0 by rebuilding the default look from scratch, and I owe you an apology up front, because that may change how the addon looks for you.",
				"What happens to your settings: anything you personally changed is kept exactly as it is. Your saved settings are never overwritten. But any setting you never touched follows the default, so it picks up the new value. If you have customized things heavily, you will likely notice nothing. If you have been running the addon as it came, you will see a difference.",
				"The most visible changes, if you never adjusted them: Lane 2 and Lane 3 now start turned off (they used to be on), lanes are thinner (height 10 instead of 17), lane and ready-box icons now have a thin border, backgrounds are a lighter gray and more transparent, borders are thinner and softer, and a Bars 1 frame is now on by default.",
				"Why I did it: the beta defaults grew one piece at a time over about thirty releases, and nobody ever sat down and asked what a brand new user should actually see on their first login. Three lanes stacked up with heavy black borders was a lot to hand someone before they had changed a single setting. The 1.0 defaults are a deliberate pass at a clean, quiet starting point.",
				"How to put it back the way it was: every one of these is a normal option. Lanes tab, pick Lane 2 or Lane 3, and tick Enabled to bring the extra lanes back. Lanes > Appearance sets Height back to 17 and Border Size back to 2. Lanes > Icons unticks Icon Border. Bars tab, pick Bars 1, and untick Enabled to remove the new bar frame. If you would rather start over completely, Profiles > Reset Profile gives you the new defaults from a clean slate.",
			} },
			{ head = "New Features", items = {
				"Bar frames. A whole new way to see your cooldowns, sitting alongside the lanes rather than replacing them: up to 3 frames of depleting status bars, each with an icon, the spell name, and a live countdown, sorted by whichever is coming up next. Style the fill texture and color (or use your class color), choose which side the icon sits on, cap how many bars show at once, and give your Important spells an emphasis border. Route any category or any individual spell to a bar from the Filters tab.",
				"Custom cooldowns. Track anything, including things the game will not tell you about. Give it a name, a duration, and a trigger (either a spell you cast or a buff you gain) and Cooldown Master runs the timer itself. Because entering an aura ID by hand is miserable, there is a Detect button: click it, gain the buff, and it fills in the ID, name, and icon for you. Custom cooldowns flow through the same lanes, bars, and ready boxes as everything else. Find them under Filters > Custom.",
				"Test Mode is now properly configurable. Pick what kind of sample cooldowns to show, how many (1 to 20), the range of durations they span, and whether they loop. Settings apply live as you drag, and the samples obey your real Filters routing, so what you see while setting up is what you get in combat.",
				"Set All. Each Filters category now has Set All buttons next to its Default Lane, Ready Box, and Default Bar, so you can apply a category's routing to every cooldown in it at once instead of one spell at a time.",
				"Three original Cooldown Master textures are now bundled: CDM Gradient, CDM Glass, and CDM Soft Edge. They show up in every texture picker alongside any SharedMedia packs you already have.",
				"Font, size, outline, and color controls for the lane markers (Ready, 25%, 50%, 75%, 100%), the frame name tags, and the countdown number on bars.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed a passive talent showing up as a tracked cooldown. Some talents (for example the Paladin talent Undisputed Ruling) are listed by the game as their own cooldown entry, flagged as hidden, and carry their parent ability's artwork. Blizzard's own Cooldown Manager skips those entries and Cooldown Master was not, so a passive could appear as a bar or lane icon wearing another spell's icon and showing the wrong name and timer. Those hidden entries are now skipped, which also fixes the wrong spell tooltip on hover and the wrong name in the Filters list.",
				"A spell still on cooldown while you changed spec or talents kept its old name and icon until it finished. Cooldowns now refresh immediately.",
				"Fixed color opacity never taking effect on text. Dragging a font's opacity slider changed the color but the text never faded. Two separate problems were behind it, and both are fixed, which also corrects background, border, and highlight opacity at the extremes.",
				"Fixed lanes and frames showing a lighter or darker border than each other depending on where they sat on screen. Frames are now aligned to the pixel grid, so identically configured frames look identical.",
				"Fixed a ready box briefly drawing as two boxes when two cooldowns became ready at the same time (visible only with Auto-hide on).",
				"Changing a cooldown's lane or bar now moves it immediately, instead of waiting until the next time you use it.",
				"The Unlock Frames and Auto-hide options now apply to bar frames, which previously ignored both.",
			} },
			{ head = "Thanks", items = {
				"Thanks to everyone who ran the beta and sent feedback. Special thanks to cliffclive, whose CooldownTimeline2 is the reason this addon exists.",
			} },
		},
	},
	{
		version = "0.21.0",
		date = "2026-07-11",
		sections = {
			{ head = "New Features", items = {
				"Auto-hide now works while your frames are unlocked. Previously it only took effect once you locked your frames. With Auto-hide on, empty lanes and ready boxes now hide out of combat even while unlocked, and each hidden frame shows a small labeled tag you can grab to drag it into place. Lock your frames and the tags disappear, as before.",
			} },
			{ head = "Bug Fixes", items = {
				"Detect Shared Cooldowns no longer hides a different ability. Two unrelated abilities that happened to share a cooldown length and were used together (for example Arcane Power and Icy Veins from one macro) were merged into a single icon, hiding one of them. Abilities now merge only when they are genuinely the same cooldown, so every ability shows.",
				"A repositioning tag hidden in the middle of a drag (for example when a cooldown popped into the box you were moving) could keep chasing the cursor afterward. The drag now finalizes cleanly.",
				"Ready-box repositioning tags now hide in combat, matching the lane tags.",
			} },
			{ head = "Thanks", items = {
				"Thanks to Agaman for knocking this one out for me.",
			} },
		},
	},
	{
		version = "0.20.0",
		date = "2026-07-09",
		sections = {
			{ head = "New Features", items = {
				"Center stacking: a new Center grow direction makes stacked cooldowns straddle the lane line and grow both ways (Up/Down/Center on horizontal lanes, Left/Right/Center on vertical lanes), so a busy lane stays balanced instead of piling in one direction.",
				"Offset stacking style: a new style that fans every stacked icon evenly across the stack Height, alongside Grouped (rows) and Spread (along the lane).",
			} },
			{ head = "Bug Fixes", items = {
				"The What's New popup, the first-run welcome, and automatic profile switching by specialization now run reliably on a fresh login instead of only after a /reload.",
				"Fixed the color picker's opacity being inverted on modern (12.0) clients, so a color's transparency now matches what you set and Cancel restores the correct alpha.",
				"The Filters options no longer rebuild and leak interface frames on every spec, talent, or spellbook change while the options window is closed. The rebuild now happens only while the panel is open.",
				"Fixed the Filters tab sometimes coming up blank after a profile change or options rebuild.",
				"Merely viewing a spell in Filters no longer saves an empty per-spell override into your settings.",
				"Fixed the secondary tracking bar (GCD and Swing) on vertical lanes, which was sized and oriented for a horizontal lane. It now travels correctly along the full length of vertical lanes.",
				"Fixed a post-combat flicker on ready boxes holding a pinned icon. Pinned icons stay shown while unpinned ones clear, and the box no longer relayouts every frame.",
				"The selected Options tab now keeps its yellow highlight when you hover or click it instead of briefly flashing red.",
				"Classic Era and Burning Crusade (Anniversary) no longer set up specialization-change tracking that does not apply on those flavors.",
			} },
			{ head = "Improvements", items = {
				"Grouped stacking now compresses its rows to keep the whole pile within the configured Height, so stacked icons overlap instead of spilling off the lane. Raise Height to reduce the overlap.",
				"Raised the default lane stacking Height to 150 so stacked icons have more room before they overlap.",
				"Overlapping stacked icons now draw in a stable front-to-back order.",
				"Added hover tooltips explaining the Grouped, Offset, and Spread stacking styles, the Center grow direction, and how raising Height reduces overlap.",
				"On Classic and Mists of Pandaria, buff tracking batches rapid aura changes into a single scan instead of scanning on every change, cutting allocation churn and smoothing combat.",
				"Updated the interface versions for the current Classic clients (Classic Era, Burning Crusade/Anniversary, and Mists of Pandaria) so Cooldown Master loads cleanly and is no longer flagged out of date.",
			} },
		},
	},
	{
		version = "0.19.0",
		date = "2026-07-05",
		sections = {
			{ head = "New Features", items = {
				"What's New popup: after an update, Cooldown Master shows a short summary of what changed. Choose how you are notified under Global > After an update: a Popup window, a quiet clickable Chat link in your chat, or Off. Reopen it any time with /cm whatsnew, or tick 'Don't show these again' to turn it off for good.",
				"Per-lane icon borders: each cooldown icon can now have a solid border in a size and color you pick, on both lanes (Lanes > Appearance) and ready boxes (Ready > Icons). Off by default.",
				"Vertical lanes: a new Vertical toggle (Lanes > General) runs a lane top to bottom instead of left to right, swapping its Width and Height so the bar keeps its shape.",
				"Sound preview: a Play button next to Ready Sound and Highlight Sound (Ready tab) lets you hear the sound without waiting for a cooldown to pop.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed icon shake with Spread stacking. In Linear mode, an icon catching up to the one ahead of it would bump and shake several times before passing. Stacked icons now slide smoothly at full frame rate.",
			} },
			{ head = "Improvements", items = {
				"The Ignore Threshold now works. Previously a dead slider, it now hides any spell whose full base cooldown is longer than its category's Ignore Threshold. A per-spell override still wins.",
				"Empty ready boxes now honor Auto-hide instead of always hiding when empty. With Auto-hide off (the default), empty ready boxes stay visible.",
				"Stronger highlight for Important spells: a full-icon glow instead of a thin hollow border, so it stands out at a glance.",
				"Added hover tooltips to every option on the Global tab.",
				"The per-spell Filters list now has an aligned Show / Lane / Ready Box / Flags column header.",
				"Simplified the lane icon-text settings to a single Show Timer toggle under a Countdown Timer header.",
			} },
		},
	},
	{
		version = "0.18.1",
		date = "2026-07-04",
		sections = {
			{ head = "Bug Fixes", items = {
				"Fixed a Lua error that could fire repeatedly in dungeons and instances and quietly interrupt cooldown tracking (a combat-protected value was being read at the wrong moment).",
				"Fixed cooldown icons sometimes appearing at the front of the lane already counting down, instead of traveling from the start. This was most noticeable on charge and builder abilities such as Blade of Justice and Templar Strike during fast rotations. The lane now anchors each cooldown to when it actually started.",
				"Fixed a brief one-frame flash an icon could show at the wrong spot when cooldowns started or reordered.",
				"Newly talented abilities are now picked up without a /reload.",
			} },
			{ head = "Improvements", items = {
				"Smoother lane travel: trimmed redundant per-frame work and spread the periodic background scan across frames, removing a faint recurring stutter as icons move.",
				"Steadier countdown text: the number on each icon now holds to the pixel grid, so it stays crisp while the icon glides.",
				"Learned cooldown durations now self-heal: stale or GCD-length values saved by older versions are cleaned up on load, and learned durations reload correctly when you switch profiles.",
			} },
		},
	},
	{
		version = "0.18.0",
		date = "2026-07-04",
		sections = {
			{ head = "New Features", items = {
				"GCD and Swing tracking on the lanes: each lane can show your global cooldown or main-hand swing timer as a recurring indicator, either a fill across the whole lane (Primary Tracking) or a small bar that slides along it (Secondary Tracking), configurable under Lanes > General with size, color, and direction. Classic flavors only. On retail this is handled by Blizzard's Cooldown Manager.",
				"Max Ready Icons: each ready box now caps how many ready icons show at once (Ready > General), so a burst of cooldowns coming off together no longer floods the box. Newest readies take priority.",
				"The /cm shortcut: every slash command now also works as /cm (for example /cm, /cm lock, /cm test) in addition to /cdmaster.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed the Filters list on Classic showing the same spell multiple times (for example Soul Reaper appearing three times on a Mists Death Knight) and listing off-spec abilities you cannot use (like a Frost ability on a Blood Death Knight). The list now shows only what your current specialization can actually cast.",
			} },
			{ head = "Improvements", items = {
				"Death Gate is now filed under the Utility filter instead of Spells on Classic.",
				"Added hover tooltips to several options: Mode, Primary and Secondary Tracking, ST Height, Stack Style, Highlight Style, and the ready-box Anchor.",
			} },
		},
	},
	{
		version = "0.17.0",
		date = "2026-07-03",
		sections = {
			{ head = "New Features", items = {
				"Mists of Pandaria Classic support: Cooldown Master now runs on the MoP Classic client (5.5.x), using the same spellbook-scan cooldown tracking as the other Classic flavors. The Colors tab covers MoP's full class list, including Death Knight and Monk.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed the Profiles tab showing blank (with a Lua error) on Mists of Pandaria Classic. The per-specialization auto-switch controls now use that client's specialization API. The same fix also covers spec-based profile auto-switching at login.",
			} },
			{ head = "Improvements", items = {
				"Renamed the lane's 'Background' appearance settings to 'Lane' (Lane, Lane Texture, Lane Color, Use Class Color), since they control the visible lane strip.",
				"Removed the non-functional 'Foreground' lane appearance controls, a leftover from an unused bar-style display model.",
			} },
		},
	},
	{
		version = "0.16.8",
		date = "2026-07-03",
		sections = {
			{ head = "Bug Fixes", items = {
				"Classic potions now show properly. On Classic Era and Burning Crusade Classic, tracked potions previously appeared as unnamed 'Item ######' placeholder rows that never resolved. Potions are now discovered from your bags and display their real name and icon. Retail was unaffected.",
				"Fixed editing a class color on the Colors tab being able to alter the built-in default colors shared by other profiles.",
			} },
			{ head = "New Features", items = {
				"Class-color opacity: the class-color pickers on the Colors tab now include an opacity slider, so a class-tinted lane background can be made semi-transparent.",
			} },
			{ head = "Improvements", items = {
				"Ready frames now have a default sound: when a cooldown becomes ready it plays a short click by default instead of being silent. Change it or turn it off under Ready > Sound for each ready box.",
			} },
		},
	},
	{
		version = "0.16.7",
		date = "2026-07-03",
		sections = {
			{ head = "Bug Fixes", items = {
				"Fixed a spell hidden in Filters still popping into a ready frame (or suppressing a visible spell) when Detect Shared Cooldowns was enabled. Hidden spells are now kept out of the ready-frame logic entirely, matching how the lanes already hide them.",
			} },
		},
	},
	{
		version = "0.16.6",
		date = "2026-07-03",
		sections = {
			{ head = "Improvements", items = {
				"Test Mode is now a live preview: clicking Test plays a looping demo where sample cooldowns (drawn from your own tracked spells and buffs) travel the lane and then pop into the ready frame at the finish, so you can watch the full flow and fine-tune your settings. Samples route through your actual lane, ready-box, and filter settings, on both retail and Classic.",
				"Added a Stop Test button next to Test, and closing the options window now ends the test automatically.",
			} },
		},
	},
	{
		version = "0.16.5",
		date = "2026-07-03",
		sections = {
			{ head = "New Features", items = {
				"WoW Classic support: Cooldown Master now runs on Classic flavors that lack retail's Cooldown Viewer. It scans your spellbook and tracks abilities whose cooldown is longer than the global cooldown, reading live cooldown times directly. Class buffs with no cooldown (Paladin Seals and Blessings, and the like) are tracked by remaining duration under the Buffs category, and the tracked set refreshes as you learn spells or swap talents.",
			} },
			{ head = "Improvements", items = {
				"Lane transparency now fades the bar, not the icons: a lane's Box Alpha dims only the bar background, border, name, and markers, while the cooldown icons keep their own Icon Alpha and stay fully visible.",
				"Refreshed default layout for new installs: thinner, wider lanes with tighter borders, slightly smaller icons, and a repositioned first ready box. Existing profiles are untouched.",
				"Lane and ready-box names now float just above the frame instead of centered inside it, so the label never overlaps the bar or its markers.",
			} },
		},
	},
	{
		version = "0.16.4",
		date = "2026-07-03",
		sections = {
			{ head = "Improvements", items = {
				"Cooldown Master is now available on CurseForge.",
				"Added a Credits section to the About tab acknowledging CooldownTimeline2 (CDTL2) by cliffclive, whose addon inspired this one.",
			} },
		},
	},
	{
		version = "0.16.3",
		date = "2026-07-03",
		sections = {
			{ head = "Maintenance", items = {
				"Internal code comment cleanup and tidying. No functional, gameplay, or settings changes.",
			} },
		},
	},
	{
		version = "0.16.2",
		date = "2026-07-02",
		sections = {
			{ head = "Improvements", items = {
				"Auto-hide Frames now hides only each lane's background, border, name, and markers -- your tracked cooldown icons stay visible out of combat and return with the chrome in combat. Use a lane's Override Autohide to keep its chrome pinned.",
				"Added tooltips to the Auto-hide Frames, Override Autohide, and per-category Enabled / Show by Default options so their effect is clear at a glance.",
			} },
			{ head = "Bug Fixes", items = {
				"Locked lanes no longer capture mouse clicks over their area. Clicks now pass through to the game world beneath them.",
			} },
		},
	},
	{
		version = "0.16.1",
		date = "2026-07-02",
		sections = {
			{ head = "Improvements", items = {
				"New addon icon, used on the minimap button, addon list, and data-broker displays.",
			} },
		},
	},
	{
		version = "0.16.0",
		date = "2026-06-30",
		sections = {
			{ head = "New Features", items = {
				"Split lane mode (Lanes > General > Mode): a timeline mode where you set the time curve yourself with up to three control points -- a cooldown with this many seconds left sits at this percent along the lane -- spreading imminent cooldowns near the ready edge and compressing far ones at the back.",
				"Lane icon highlights (Lanes > Icons > Highlight): spells flagged Important can stand out on the lane with a Border, Glow, Flash, or Border + Flash style in a color you pick. Off by default per lane.",
				"Background and border textures (Lanes > Appearance): both are now selectable from any LibSharedMedia texture you have installed, instead of the single built-in fill.",
				"Editable lane labels (Lanes > Text): each of the five labels now has its own text and position, so you can rename and reposition them (Ready / 25% / 50% / 75% / 100% are just the defaults).",
			} },
			{ head = "Improvements", items = {
				"Smoother lane motion: icons glide at sub-pixel precision every frame instead of stepping a whole pixel at a time, so slow cooldowns travel smoothly. Most noticeable on long cooldowns and in Logarithmic mode.",
				"Ready-pop fade-in: icons popping into a ready frame fade in softly instead of appearing instantly.",
				"Logarithmic mode does a little less work per frame (no behavior change).",
			} },
		},
	},
	{
		version = "0.15.0",
		date = "2026-06-24",
		sections = {
			{ head = "Improvements", items = {
				"Detect Shared Spell Cooldowns now also collapses duplicate ready-frame pops: an ability tracked under two spell IDs that share a cooldown pops a single ready icon instead of one per ID, mirroring the lane dedupe. Off by default, gated on the same Global option.",
				"Minor internal code cleanup (comment tidy-up, no behavior change).",
			} },
		},
	},
	{
		version = "0.14.1",
		date = "2026-06-22",
		sections = {
			{ head = "Bug Fixes", items = {
				"Fixed multi-charge spells (such as Roll) not showing on the lane when fully out of charges (a 0.14.0 regression). They now correctly track the recharge once depleted, without flickering on individual charge uses.",
			} },
		},
	},
	{
		version = "0.14.0",
		date = "2026-06-22",
		sections = {
			{ head = "New Features", items = {
				"Icon Zoom (Global tab): a slider to zoom lane and ready-frame icons in. 1 = the default look. Higher crops the icon border further.",
				"Unusable icon tint (Global tab): tint and/or desaturate icons for spells you currently can't cast, in a color you choose (Tint Unusable Icons, Desaturate Unusable Icons, Unusable Tint Color).",
				"Spread stacking (Lanes > Stacking): a new stacking style that pushes overlapping icons apart along the lane instead of into rows.",
				"Detect Shared Spell Cooldowns (Global tab): collapse spells that share a cooldown into a single lane icon instead of showing duplicates.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed certain cooldowns (such as Rising Sun Kick and Strike of the Windlord) tracking at the wrong spot on the lane. The addon now uses the exact learned cooldown length, re-anchors the timer to each cast, and re-learns lengths that changed in a patch.",
				"Fixed multi-charge spells (such as Roll) briefly flashing onto the lane and popping a ready frame on each charge use. They now appear only once you're fully out of charges.",
			} },
		},
	},
	{
		version = "0.13.1",
		date = "2026-06-22",
		sections = {
			{ head = "New Features", items = {
				"Countdown font options (Lanes > Icons > Timer Font): set the font face, size, outline, and color of the timer text on each lane's icons. Size 0 = auto (scales with the icon size).",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed certain cooldowns (such as Supernova and Arcane Orb) sliding to the ready end of the lane and staying there while still on cooldown. The addon now learns each cooldown's true length from how long it actually runs, so the icon tracks the right position. The countdown number and swipe were always correct.",
			} },
		},
	},
	{
		version = "0.13.0",
		date = "2026-06-21",
		sections = {
			{ head = "New Features", items = {
				"Logarithmic lane mode (Lanes > General): a new Mode that lays cooldowns out on a logarithmic seconds axis, so the last several seconds spread across most of the lane and long cooldowns compress toward the far end. Shares the lane's Max Time setting.",
				"Grouped icon stacking (Lanes > Stacking): lane icons that would overlap are packed into rows instead of sitting on top of each other, within the Height you set and in your chosen Grow Direction. Raise On Mouseover brings a stacked icon to the front when you hover it.",
			} },
		},
	},
	{
		version = "0.12.0",
		date = "2026-06-21",
		sections = {
			{ head = "New Features", items = {
				"Per-spec profile auto-switch: map each specialization to a profile on the Profiles tab and the addon switches when you change spec (and on login).",
				"Profile import/export: copy the current profile to a string and paste one back, from the Profiles tab.",
				"Potions and flasks in your bags are auto-discovered, and equipped on-use trinkets (slots 13/14) are tracked under a new Trinkets filter category.",
				"Cooldown Tint slider (Lanes > Appearance > Icons) lightens the cooldown darkening so you can see the spell art, or turns it off at 0.",
			} },
			{ head = "Bug Fixes", items = {
				"Locking the frames no longer hides lanes. It only disables dragging now. Lane visibility follows your Always / In Group / In Instance and Auto-hide settings.",
				"Using a single potion no longer pops several ready frames at once: combat potions share one cooldown, so they show and notify as a single icon.",
			} },
		},
	},
	{
		version = "0.11.0",
		date = "2026-06-21",
		sections = {
			{ head = "New Features", items = {
				"Added a Show Minimap Button checkbox to the Global tab to hide or show the minimap icon.",
				"Hovering a lane icon now shows the spell or item tooltip. Turn it on with the Enable tooltips option on the Global tab (off by default). While frames are unlocked the icons stay click-through, so you can still drag lanes freely.",
			} },
		},
	},
	{
		version = "0.10.2",
		date = "2026-06-21",
		sections = {
			{ head = "Bug Fixes", items = {
				"Fixed every tracked spell popping into the ready frames at once after a loading screen or zone change. The cooldown state the game reports during a loading screen is briefly unreliable, so the addon now waits for it to settle instead of treating every cooldown as ready.",
			} },
			{ head = "Improvements", items = {
				"Switching, copying, or resetting profiles no longer leaks frames: lane and ready boxes are reused instead of destroyed and recreated, and the About tab is no longer rebuilt each time.",
				"Lane icons reposition only when they actually move (not on every frame) and keep a stable order, so they no longer reshuffle as cooldowns come and go.",
				"The in-game changelog now shows the release date for each version.",
			} },
		},
	},
	{
		version = "0.10.1",
		date = "2026-06-21",
		sections = {
			{ head = "Bug Fixes", items = {
				"Fixed a repeating Lua error in combat for multi-charge spells (such as Shimmer). The addon no longer reads the protected in-combat charge count. Multi-charge spells are detected from their maximum charges, so the recharge still shows once fully on cooldown.",
				"Creating a profile now warns on an empty, duplicate, or current name, and clears the box with a confirmation on success.",
				"Hardened active-profile switching so the dropdown can't tear itself down mid-click.",
			} },
			{ head = "Maintenance", items = {
				"Removed charge-count text code paths that can't work under Midnight's in-combat value protection.",
			} },
		},
	},
	{
		version = "0.10.0",
		date = "2026-06-21",
		sections = {
			{ head = "New Features", items = {
				"Ready Frames routing: each Filters category has a Ready Box setting, and any spell can override it, so ready popups can be split across the three boxes (or turned off per spell) instead of all landing in one box.",
				"Highlight for Important spells: flag a spell Important to make its ready popup stand out with a Border, Glow, or Flash in a color you choose, with its own hold time and sound (new Highlight section per box).",
				"Pinned spells: flag a spell Pinned to keep its ready icon up until the box is rebuilt.",
				"More ready grow directions: Down, Up, Left, Right, or centered.",
				"Pop-in flash on ready icons, and built-in ready sounds so you can hear an alert without extra sound media.",
				"Post-Combat Hide: an optional per-box timer that clears the box a set time after combat ends.",
			} },
			{ head = "Bug Fixes", items = {
				"The minimap button's hide state and position now follow profile switches.",
				"Cooldowns first seen in combat re-center once their real length is learned instead of keeping the approximate position.",
				"Charge spells (Shimmer, Fire Blast) again show only when fully on cooldown, not while a charge is still available.",
			} },
			{ head = "Improvements", items = {
				"Ready boxes fade out smoothly when they empty.",
			} },
		},
	},
	{
		version = "0.9.0",
		date = "2026-06-21",
		sections = {
			{ head = "New Features", items = {
				"Ready Frames: when a tracked spell or item comes off cooldown its icon pops into a dedicated on-screen box, holds for a set time, then fades. Three movable boxes, configured on the new Ready tab (General / Appearance / Icons).",
				"Lane visibility (Always / In Group / In Instance) now controls when each lane shows, re-evaluated on combat, group, and zone changes.",
				"Auto-hide out of combat, with a per-lane Override Autohide toggle.",
				"Lane Timeline mode: positions icons by real seconds-until-ready on a shared Max Time axis. The default per-spell mode is unchanged.",
			} },
			{ head = "Bug Fixes", items = {
				"Multi-charge spells (Shimmer, Fire Blast) show their recharge swipe and countdown instead of a blank icon, and appear while a charge is regenerating.",
			} },
			{ head = "Maintenance", items = {
				"Removed dead code: the unused Bar Frames file, undefined frame-discovery calls and their slash subcommands, and stale diagnostic counters.",
			} },
		},
	},
	{
		version = "0.8.1",
		date = "2026-06-21",
		sections = {
			{ head = "Other", items = {
				"Some code cleanup.",
			} },
		},
	},
	{
		version = "0.8.0",
		date = "2026-06-18",
		sections = {
			{ head = "Improvements", items = {
				"Retail interface compatibility updated to WoW 12.0.7, so the addon loads without the out-of-date warning on the current Midnight patch.",
			} },
			{ head = "Maintenance", items = {
				"Corrected the Author field on the Classic Era and TBC Classic builds to match the retail build.",
			} },
		},
	},
	{
		version = "0.7.0",
		date = "2026-06-10",
		sections = {
			{ head = "New Features", items = {
				"Baseline cooldown coverage for all classes and specs, seeded from the game's own base-cooldown data, so icons start in the right place on any class.",
			} },
			{ head = "Bug Fixes", items = {
				"Spells listed in more than one Cooldown Viewer category keep their primary category instead of being reassigned to the wrong sub-tab.",
				"Per-category Filters lists now rebuild when the spell registry does, instead of being a one-time snapshot.",
				"Test mode now works from all three entry points (slash, Global tab button, minimap middle-click).",
				"Learned cooldown durations now persist between sessions instead of re-learning every login.",
				"Changing specialization no longer leaves cooldown positions wrong until a reload.",
				"A party member changing spec no longer wipes your own learned durations.",
			} },
			{ head = "Improvements", items = {
				"Engine allocation pass: the cooldown scan is event-driven with a low-frequency safety sweep, cutting steady-state memory churn in combat.",
				"Lane configuration is applied once at build and on change, not every render frame.",
				"Dragging the Width, Height, X, Y, or Anchor sliders no longer leaks a frame per step.",
			} },
		},
	},
	{
		version = "0.6.0",
		date = "2026-05-30",
		sections = {
			{ head = "New Features", items = {
				"Combat-accurate cooldown display: each lane icon renders Blizzard's native swipe and countdown, fed the cooldown object directly, so timers stay exact in combat.",
				"Real-time lifecycle: icons appear and clear exactly when the real cooldown starts and ends, including proc and talent resets.",
				"Continuous M:SS countdown text (4:59, 4:58, ...) for spells and potions.",
			} },
			{ head = "Improvements", items = {
				"Event-driven engine keyed on cooldown-state changes. Removed unused curve-evaluation code from the live path.",
				"Removed developer chat output on login and reload (still available on demand via /cdmaster api).",
			} },
			{ head = "Known Limitations", items = {
				"Icon position is approximate for haste- or talent-scaled cooldowns. The countdown number is always exact.",
				"Charge-based spells may not show their recharge until fully on cooldown.",
			} },
		},
	},
	{
		version = "0.5.0",
		date = "2026-05-23",
		sections = {
			{ head = "New Features", items = {
				"Potions: item cooldowns polled via C_Container.GetItemCooldown, with a new Filters > Potions sub-tab.",
				"Mage fallback durations for all three specs plus shared utility and defensives.",
				"Filters > Items relabeled Utility to reflect its real contents (Blizzard's Utility-tagged spells, not inventory items).",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed a stray token in Core/Init.lua that prevented the addon from loading.",
				"Backdrop changes (border size, color, padding) now apply immediately instead of needing a reload.",
			} },
			{ head = "Improvements", items = {
				"Engine performance: hoisted pcall closures, multi-value pollers, reused scratch tables, and debounced SPELL_UPDATE_COOLDOWN.",
				"Lane renderer performance: prebuilt time-string lookup tables and cached backdrop tables.",
			} },
		},
	},
	{
		version = "0.4.0",
		date = "2026-05-03",
		sections = {
			{ head = "New Features", items = {
				"Filters > Defaults: per-category Enabled, Show by Default, Ignore Threshold, and Default Lane.",
				"Filters > Spells / Items / Buffs / Debuffs: per-spell visibility checkbox and lane override.",
				"Three-layer visibility model: category enabled, then per-spell override, then category default.",
			} },
			{ head = "Bug Fixes", items = {
				"Multi-lane rendering now gates each entry by its resolved lane, so spells only appear in the lane they are routed to.",
			} },
			{ head = "Migration", items = {
				"Legacy perSpellRouting folded into spellOverrides. The obsolete key is removed (idempotent).",
			} },
		},
	},
	{
		version = "0.3.0",
		date = "Undated",
		sections = {
			{ head = "Removed", items = {
				"Bar Frames and Ready Frames features and their tabs (Blizzard's Cooldown Manager already covers those).",
			} },
			{ head = "Migration", items = {
				"One-time SavedVariables cleanup strips the orphaned bar and ready data (idempotent).",
			} },
		},
	},
	{
		version = "0.2.0",
		date = "2026-05-03",
		sections = {
			{ head = "New Features", items = {
				"Curve-evaluation cooldown engine that routes numeric math through Blizzard's privileged DurationObject, avoiding Midnight secret-value taint.",
				"Persistent learning: each spell's duration is remembered across reload and login once it has been observed.",
			} },
		},
	},
	{
		version = "0.1.0",
		date = "Undated",
		sections = {
			{ head = "Implemented", items = {
				"First playable build: Ace3 addon, themed options panel, LibDataBroker launcher and minimap button, and slash commands. Loads on Midnight, Classic Era, and TBC Classic.",
			} },
		},
	},
}
