local ADDON_NAME, ns = ...

ns.Changelog = {
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
				"The most visible changes, if you never adjusted them: Lane 2 and Lane 3 now start turned off (they used to be on), lanes are thinner (height 10 instead of 17), lane and ready-box icons now have a thin border, backgrounds are a lighter grey and more transparent, borders are thinner and softer, and a Bars 1 frame is now on by default.",
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
				"The Filters options no longer rebuild and leak interface frames on every spec, talent, or spellbook change while the options window is closed; the rebuild now happens only while the panel is open.",
				"Fixed the Filters tab sometimes coming up blank after a profile change or options rebuild.",
				"Merely viewing a spell in Filters no longer saves an empty per-spell override into your settings.",
				"Fixed the secondary tracking bar (GCD and Swing) on vertical lanes, which was sized and oriented for a horizontal lane; it now travels correctly along the full length of vertical lanes.",
				"Fixed a post-combat flicker on ready boxes holding a pinned icon; pinned icons stay shown while unpinned ones clear, and the box no longer relayouts every frame.",
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
				"Fixed cooldown icons sometimes appearing at the front of the lane already counting down, instead of traveling from the start. This was most noticeable on charge and builder abilities such as Blade of Justice and Templar Strike during fast rotations; the lane now anchors each cooldown to when it actually started.",
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
				"GCD and Swing tracking on the lanes: each lane can show your global cooldown or main-hand swing timer as a recurring indicator, either a fill across the whole lane (Primary Tracking) or a small bar that slides along it (Secondary Tracking), configurable under Lanes > General with size, color, and direction. Classic flavors only; on retail this is handled by Blizzard's Cooldown Manager.",
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
				"Fixed the Profiles tab showing blank (with a Lua error) on Mists of Pandaria Classic. The per-specialization auto-switch controls now use that client's specialization API; the same fix also covers spec-based profile auto-switching at login.",
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
				"Locked lanes no longer capture mouse clicks over their area; clicks now pass through to the game world beneath them.",
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
				"Minor internal code cleanup (comment tidy-up; no behavior change).",
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
				"Icon Zoom (Global tab): a slider to zoom lane and ready-frame icons in. 1 = the default look; higher crops the icon border further.",
				"Unusable icon tint (Global tab): tint and/or desaturate icons for spells you currently can't cast, in a color you choose (Tint Unusable Icons, Desaturate Unusable Icons, Unusable Tint Color).",
				"Spread stacking (Lanes > Stacking): a new stacking style that pushes overlapping icons apart along the lane instead of into rows.",
				"Detect Shared Spell Cooldowns (Global tab): collapse spells that share a cooldown into a single lane icon instead of showing duplicates.",
			} },
			{ head = "Bug Fixes", items = {
				"Fixed certain cooldowns (such as Rising Sun Kick and Strike of the Windlord) tracking at the wrong spot on the lane. The addon now uses the exact learned cooldown length, re-anchors the timer to each cast, and re-learns lengths that changed in a patch.",
				"Fixed multi-charge spells (such as Roll) briefly flashing onto the lane and popping a ready frame on each charge use; they now appear only once you're fully out of charges.",
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
				"Locking the frames no longer hides lanes; it only disables dragging now. Lane visibility follows your Always / In Group / In Instance and Auto-hide settings.",
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
				"Hovering a lane icon now shows the spell or item tooltip. Turn it on with the Enable tooltips option on the Global tab (off by default); while frames are unlocked the icons stay click-through, so you can still drag lanes freely.",
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
				"Fixed a repeating Lua error in combat for multi-charge spells (such as Shimmer). The addon no longer reads the protected in-combat charge count; multi-charge spells are detected from their maximum charges, so the recharge still shows once fully on cooldown.",
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
				"Event-driven engine keyed on cooldown-state changes; removed unused curve-evaluation code from the live path.",
				"Removed developer chat output on login and reload (still available on demand via /cdmaster api).",
			} },
			{ head = "Known Limitations", items = {
				"Icon position is approximate for haste- or talent-scaled cooldowns; the countdown number is always exact.",
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
				"Legacy perSpellRouting folded into spellOverrides; the obsolete key is removed (idempotent).",
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
