-- Locales/enUS.lua
-- Default locale + source-of-truth phrase list for Cooldown Master.
--
-- ns.L["English string"] returns the localized text for the player's client
-- (per GetLocale()), or the English string itself when no translation exists
-- (the metatable __index below). So EVERY wrapped string is safe to use even
-- with zero translations loaded. Untranslated text simply renders in English.
--
-- Translations are bundled directly in the other Locales/*.lua files as
-- L["key"] = "value" lines, NOT fetched through an @localization@ packager
-- token. That token fails the CurseForge build with errorCode 1002 on a project
-- without localization enabled, so it must never be added here.
--
-- Pattern: the English string IS the key (no semantic IDs). Keep keys in sync
-- with the code. If you reword an English string, update it here too or the
-- existing translation orphans (and the new text falls back to English).
--
-- The /cm diagnostic output and Core/Changelog.lua are deliberately NOT wrapped.
-- Diagnostics are a developer tool that has to read the same in every bug report,
-- and changelog entries churn every release.
--
-- GENERATED FILE: the phrase list is a pure function of the L[...] usages in the
-- code. Do not hand-edit. It is rebuilt by scan.py in the EverythingLocales repo,
-- which also regenerates the translation files from the shared store.


local _, ns = ...

ns.L = setmetatable({}, { __index = function(_, k) return k end })
local L = ns.L

-- UI/Settings.lua
L["Join our Discord"] = true
L["Click to copy the invite link."] = true
L["Plays the currently selected sound."] = true
L["Clear"] = true
L["Press Ctrl+C to copy, then Escape to close."] = true
L["Close"] = true
L["None"] = true
L["Outline"] = true
L["Thick Outline"] = true
L["Top Left"] = true
L["Top"] = true
L["Top Right"] = true
L["Left"] = true
L["Center"] = true
L["Right"] = true
L["Bottom Left"] = true
L["Bottom"] = true
L["Bottom Right"] = true
L["Down"] = true
L["Up"] = true
L["Center (vertical)"] = true
L["Center (horizontal)"] = true
L["Border"] = true
L["Flash"] = true
L["Above icon"] = true
L["On icon"] = true
L["Below icon"] = true
L["Above frame"] = true
L["Below frame"] = true
L["Font"] = true
L["Font Size"] = true
L["Font Outline"] = true
L["Font Color"] = true
L["Status Line"] = true
L["Show Status Line"] = true
L["Draw one line of text on this frame, built from the tags in the box below. Off by default. Use it for a live readout - the next cooldown coming up, how many are on cooldown, or your target's name."] = true
L["Text"] = true
L["Position"] = true
L["Click a tag to add it:"] = true
L["Inserts %s"] = true
L["Unlock Frames"] = true
L["Unlock every lane and ready box so you can drag them into place. Backgrounds show while unlocked; lock again to hide the chrome and let clicks pass through."] = true
L["Test"] = true
L["Stop Test"] = true

-- UI/SettingsGlobal.lua
L["Enabled"] = true
L["Always"] = true
L["Show your lanes at all times, no matter where you are. When on, the In Group and In Instance conditions do not matter."] = true
L["In Group"] = true
L["Show your lanes only while you are in a party or raid. Any ticked visibility box can show them, so this stacks with In Instance."] = true
L["In Instance"] = true
L["Show your lanes only while you are inside a dungeon, raid, or other instance. Any ticked visibility box can show them."] = true
L["General"] = true
L["Auto-hide Frames"] = true
L["Out of combat, hides each lane's background, border, name, and markers, but your tracked cooldown icons stay visible. The chrome returns in combat. Tick a lane's Override Autohide (Lanes > General) to keep its chrome always shown."] = true
L["Enable tooltips"] = true
L["Show the spell or item tooltip when you hover a cooldown icon on a lane. Icons take the mouse only while frames are locked, so this never blocks dragging."] = true
L["Detect Shared Spell Cooldowns"] = true
L["When one ability is tracked under two spell IDs that share a cooldown (a base spell and its talent override, or the same spell in two categories), show one icon and one ready pop instead of duplicates."] = true
L["Tint Unusable Icons"] = true
L["While a spell or item cannot be used right now (not enough resources, wrong stance, out of range), tint its icon with the Unusable Tint Color below."] = true
L["Unusable Tint Color"] = true
L["Desaturate Unusable Icons"] = true
L["While a spell or item cannot be used right now, draw its icon in greyscale. Can be combined with Tint Unusable Icons."] = true
L["Icon Zoom"] = true
L["Show Minimap Button"] = true
L["Test Mode"] = true
L["Type"] = true
L["Which kind of sample cooldowns to create. Mixed uses a spread of your spells, buffs and utility. Each type is routed with that category's Lane, Bar and Ready Box settings, so this previews your own Filters routing."] = true
L["Number of Cooldowns"] = true
L["How many sample cooldowns to create, from 1 to 20. A ready box only holds as many icons as its Max Ready Icons setting, so extras push the oldest pop out."] = true
L["First Cooldown Duration"] = true
L["Length of the first sample cooldown, in seconds. The rest are spread evenly between this and the Last Cooldown Duration."] = true
L["Last Cooldown Duration"] = true
L["Length of the last sample cooldown, in seconds. A lane only draws cooldowns up to its Max Time unless you turn off Hide Long Timers, so a value above that will not appear on the lane."] = true
L["Loop"] = true
L["Keep restarting the sample cooldowns after they pop into the ready box. Turn this off to watch them run once and clear."] = true
L["Scale"] = true
L["Cooldown Frames"] = true
L["Resize the cooldown display - your lanes, bars and ready boxes - together. 1.00 is the normal size, below shrinks them, above enlarges them. They keep their on-screen position as they scale."] = true
L["Options Window"] = true
L["Resize this Cooldown Master settings window itself. 1.00 is the normal size. Applies when you let go of the slider or press Enter."] = true
L["Updates"] = true
L["After an update"] = true
L["Popup window"] = true
L["Chat link"] = true
L["Off"] = true
L["How Cooldown Master tells you about a version that brings new features: a Popup window, a quiet clickable Chat link in your chat, or Off. Releases with only fixes stay quiet, and the next feature release shows them too. Reopen the notes any time with /cm whatsnew."] = true
L["Show What's New"] = true
L["Global"] = true

-- UI/SettingsLanes.lua
L["Linear"] = true
L["Timeline (seconds)"] = true
L["Logarithmic (seconds)"] = true
L["Split (seconds)"] = true
L["Swing"] = true
L["Frame Name"] = true
L["Reversed"] = true
L["Vertical"] = true
L["Run this lane top-to-bottom instead of left-to-right. Toggling it swaps the lane's Width and Height (under Appearance) so the bar keeps its shape, just rotated."] = true
L["Mode"] = true
L["How a cooldown's time left places it on the lane. Linear: each icon crosses the whole lane over its own cooldown, with no shared clock. Timeline: one shared clock, seconds spread evenly up to Max Time. Logarithmic: the same clock with the last seconds spread wide and long timers squeezed together. Split: the same clock bent through your own points below."] = true
L["Max Time (seconds)"] = true
L["The far end of the lane's clock, in seconds, on Timeline, Logarithmic and Split. On Linear each icon crosses the lane over its own cooldown, so there it only sets which cooldowns Hide Long Timers keeps off the lane."] = true
L["Hide Long Timers"] = true
L["Keeps a cooldown off this lane until it has Max Time or less left. Turned off, a longer cooldown waits at the far end on Timeline, Logarithmic and Split, and travels as usual on Linear."] = true
L["Split Points (Split mode)"] = true
L["Split Points"] = true
L["Point %d Time (sec)"] = true
L["Point %d Position (%%)"] = true
L["Auto-hide"] = true
L["Override Autohide"] = true
L["Keeps this lane's background, border, and markers visible even when Auto-hide Frames is on."] = true
L["Keep Shown While Running"] = true
L["With Auto-hide Frames on, keeps this lane's background, border, and markers visible out of combat for as long as a cooldown is still traveling on it, then hides them again once the lane empties. Override Autohide wins over this, and this option is ignored while Unlock Frames is on."] = true
L["Secondary Tracking"] = true
L["Primary Tracking"] = true
L["Fills the whole lane like a progress bar for a recurring timer. GCD follows your global cooldown; Swing follows your main-hand swing timer; None turns it off. Uses the ST color and texture below."] = true
L["Reverse Primary"] = true
L["A second tracking bar, separate from Primary Tracking. GCD or Swing; None turns it off. Its size and color are the ST (Secondary Tracking) options below."] = true
L["Reverse Secondary"] = true
L["ST Width"] = true
L["ST Height"] = true
L["ST stands for Secondary Tracking. Sets the height, in pixels, of the Secondary Tracking bar set above."] = true
L["ST Texture"] = true
L["The texture that fills the Secondary Tracking bar. Any statusbar texture from LibSharedMedia is selectable."] = true
L["ST Color"] = true
L["Width"] = true
L["Height"] = true
L["X Offset"] = true
L["Y Offset"] = true
L["Anchor"] = true
L["Lane"] = true
L["Lane Texture"] = true
L["Use Class Color (Lane)"] = true
L["Lane Color"] = true
L["Lane Alpha"] = true
L["Show Border"] = true
L["Border Texture"] = true
L["The texture drawn around this lane. A soft texture like CDM Soft Edge needs room to fade, so raise Border Size to about 6 or it squashes into a smear."] = true
L["Border Color"] = true
L["Border Padding"] = true
L["Border Size"] = true
L["Size"] = true
L["Transparency"] = true
L["Icon Offset"] = true
L["Cooldown Tint (0 = off)"] = true
L["Pulse"] = true
L["Makes an icon breathe in and out as it travels, so a lane you care about is easier to catch out of the corner of your eye. Masque skins draw their own icon, so the pulse stands down while one is active."] = true
L["Pulse Within (sec)"] = true
L["Start pulsing only once a cooldown is this close to ready. Set it to 0 to pulse the whole way along the lane."] = true
L["Pulse Strength"] = true
L["How many pixels the icon grows at the peak of each pulse."] = true
L["Icon Border"] = true
L["Show Icon Border"] = true
L["Draw a clean solid border around every cooldown icon in this lane. Set per lane, so you can border one lane and leave another plain. On by default."] = true
L["Highlight (Important spells)"] = true
L["Highlight Style"] = true
L["Visual emphasis drawn on icons flagged Important (per spell, in Filters). Border draws a still outline, Flash makes it pulse, and None turns it off."] = true
L["Highlight Color"] = true
L["Countdown Timer"] = true
L["Show Timer"] = true
L["Show the remaining-time number on each cooldown icon in this lane (for example 1:16, then 45, 44...). Style it with the Timer Font options below."] = true
L["Timer Font"] = true
L["Font Size (0 = auto)"] = true
L["Icon Label"] = true
L["Show Label"] = true
L["Draw a line of text on each cooldown icon in this lane, built from the tags in Label Text below. Off by default - lanes otherwise show only the timer number, so this is how you put the ability name on the icon."] = true
L["Label Text"] = true
L["Label Position"] = true
L["Where the label sits on the icon. On icon overlaps the timer number."] = true
L["Label Font"] = true
L["Label Size"] = true
L["Label Outline"] = true
L["Label Color"] = true
L["Grouped"] = true
L["Spread"] = true
L["Offset"] = true
L["Raise On Mouseover"] = true
L["Brings the icon under your mouse to the front of a pile of overlapping icons. Icons take the mouse only while Enable tooltips (Global) is on and frames are locked."] = true
L["Behavior"] = true
L["Stack Style"] = true
L["How cooldowns that pile on the same spot are arranged. Grouped packs them into rows and overlaps them to stay within Height; Offset fans every icon evenly across Height; Spread pushes them apart along the lane so each stays visible."] = true
L["Grow Direction"] = true
L["Which way a Grouped or Offset stack grows from the lane line. Center straddles the line and grows both ways."] = true
L["How much room across the lane the stack may use. When the icons do not all fit, they overlap to stay within it, so raise Height to reduce overlap."] = true
L["Above lane"] = true
L["On lane"] = true
L["Below lane"] = true
L["Percent of lane"] = true
L["Percent of lane (auto label)"] = true
L["Time (seconds)"] = true
L["Time (auto label)"] = true
L["Anchor By"] = true
L["Percent holds the label at a fixed spot on the bar. Time holds it at a number of seconds and moves the label to match. The auto label choices write the text for you from the lane's current Mode and Max Time, so the label stays true after you change either one - seconds on Timeline, Logarithmic and Split, and a percent on Linear, which has no shared clock to read."] = true
L["What the label reads. The auto label choices ignore this and write the text themselves."] = true
L["Label %d enabled"] = true
L["Position (percent)"] = true
L["Where the label sits, as a percent along the lane. Moving this also updates Position (seconds) to match."] = true
L["Position (seconds)"] = true
L["Where the label sits, as seconds left on a cooldown. Moving this also updates Position (percent) to match. Linear has no seconds axis, so this does nothing there."] = true
L["Default Text"] = true
L["Label Placement"] = true
L["Where the labels sit relative to the lane bar. Move them off the bar when tall icons cover them. On a vertical lane, Above places them to the right of it and Below to the left."] = true
L["Nudges every label sideways from its placement."] = true
L["Nudges every label up or down from its placement."] = true
L["Marker Font"] = true
L["Font for the position markers along this lane (Ready, 25, 50, 75, 100 percent)."] = true
L["Name Tag Font"] = true
L["Font for this lane's name tag (shown above the bar while frames are unlocked)."] = true
L["Lanes"] = true
L["Lane %d"] = true
L["Appearance"] = true
L["Icons"] = true
L["Stacking"] = true

-- UI/SettingsReady.lua
L["Display Duration (sec)"] = true
L["How long an ordinary icon stays in this box before it fades. An Important one stays for its Highlight Duration instead, and a Pinned one never fades."] = true
L["Post-Combat Hide (sec, 0 = off)"] = true
L["Clears this box this many seconds after combat ends or after the latest pop, whichever comes later, so icons left over from a fight do not sit out their full Display Duration. Pops out of combat count too, so a value shorter than Display Duration cuts those short. Pinned icons stay. 0 turns it off."] = true
L["Max Ready Icons"] = true
L["How many icons this box holds at once. When it is full, the icon closest to fading makes room for the new one. A Pinned icon is never the one pushed out, so a box full of Pinned icons drops new pops."] = true
L["Ready Sound"] = true
L["Screen point the box is pinned to, then nudged by the X and Y offsets above. Also the point the ready icons grow out from."] = true
L["Box Alpha"] = true
L["Fades the whole box, its background, border and icons together. Transparency under Icons fades only the icons."] = true
L["Background"] = true
L["Texture"] = true
L["Background Color"] = true
L["Spacing"] = true
L["Draw a clean solid border around each ready icon in this box. Set per box. On by default."] = true
L["Draw a line of text on each ready icon in this box, built from the tags in Label Text below. Off by default - a ready icon is otherwise just art, so this is how you name what came up."] = true
L["Where the label sits on the icon. On icon draws it over the art."] = true
L["Font for this box's name tag (shown above the box while frames are unlocked)."] = true
L["Applies to spells flagged Important under Filters. Important spells use the hold and sound below instead of the normal ones."] = true
L["Highlight Duration (sec)"] = true
L["Highlight Sound"] = true
L["Ready"] = true
L["Box %d"] = true
L["Highlight"] = true

-- UI/SettingsBars.lua
L["Longest first"] = true
L["Shortest first"] = true
L["Direction the bars stack as more cooldowns become active."] = true
L["Sort Order"] = true
L["Longest first puts the cooldown with the most time left at the start of the grow direction."] = true
L["Max Bars"] = true
L["Cap on how many bars this frame shows at once."] = true
L["Show Extremely Long Cooldowns"] = true
L["Lets this frame show cooldowns up to 60 minutes long, ignoring the Ignore Threshold that keeps them off your lanes. Anything shorter than 60 minutes is covered too, not only the very longest. It applies to this bar frame alone, so your lanes and ready boxes are unaffected, and a cooldown you hid by hand on its Filters row stays hidden. Tick it on the frame your cooldowns actually go to, which is set by Default Bar under Filters, and make sure that frame is enabled under Bars. Bear in mind an hour-long bar keeps its place in the list for the whole hour, so raise Max Bars or give it a frame of its own."] = true
L["Hand Off Below (sec)"] = true
L["This frame lets go of a cooldown once it has this many seconds left, so a lane can take it the rest of the way. 0 keeps every cooldown on the bar until it is ready.\n\nThis only decides when the BAR lets go. When the lane picks it up is decided by that lane's own Max Time and Hide Long Timers, so set this to the lane's Max Time and make sure Hide Long Timers is on for it. Without that the lane draws the cooldown the whole time instead of waiting its turn, parked at the far end on Timeline, Logarithmic and Split, and crossing the lane slowly on Linear.\n\nA value above the lane's Max Time leaves a stretch where neither one draws it. It applies to everything routed to this frame, not only to long cooldowns."] = true
L["Screen point the frame is pinned to, then nudged by the X and Y offsets above."] = true
L["Frame Alpha"] = true
L["Fades the whole frame, its background, border and bars together."] = true
L["Frame Padding"] = true
L["Bar Width"] = true
L["Bar Height"] = true
L["Gap, in pixels, between stacked bars."] = true
L["Foreground"] = true
L["Use Class Color"] = true
L["Fill the bar with your class color instead of the color below."] = true
L["Color"] = true
L["Bar Background"] = true
L["Icon"] = true
L["Show Icon"] = true
L["Icon Position"] = true
L["Emphasis drawn on the bar of a spell flagged Important (per spell, under Filters)."] = true
L["Name"] = true
L["Show Name"] = true
L["Name Color"] = true
L["Time"] = true
L["Show Time"] = true
L["Show the countdown number, drawn by the game's own cooldown widget so it stays correct in combat."] = true
L["Time Font"] = true
L["Font for the countdown number, drawn by the game's cooldown widget."] = true
L["Time Size"] = true
L["Time Outline"] = true
L["Time Color"] = true
L["Name Tag"] = true
L["Font for this frame's name tag (shown above the frame while frames are unlocked)."] = true
L["Bars"] = true
L["Bars %d"] = true
L["Bar"] = true

-- UI/SettingsFilters.lua
L["Lane %d (off)"] = true
L["Default"] = true
L["Normal"] = true
L["Important"] = true
L["Pinned"] = true
L["Imp + Pin"] = true
L["No harmful effects discovered yet.\nThe effects you put on a target are listed here as you apply them."] = true
L["This category is switched off, so none of its cooldowns show on a lane or a bar, or pop a ready box.\nTick Track this category above to switch it on."] = true
L["No spells discovered yet for this category.\nLog in or /reload to populate the list."] = true
L["Spell %d"] = true
L["Find a cooldown"] = true
L["Show"] = true
L["Track this cooldown and draw it. Untick to hide it from every lane, bar and ready box. Until you touch it here, it follows this category's Show By Default setting."] = true
L["Which lane this cooldown travels in. Default follows this category's Default Lane, set above."] = true
L["Which bar frame this cooldown shows on. Default follows this category's Default Bar. Off keeps it off the bars without hiding it from your lanes or ready boxes."] = true
L["Ready Box"] = true
L["Which ready box this pops into the moment the cooldown comes up. Default follows this category's Ready Box. Off means it never pops."] = true
L["Flags"] = true
L["How this one behaves once it pops into a ready box.\n\nNormal - fades after the box's Display Duration.\n\nImportant - highlights the icon and holds it for the box's Highlight Duration instead, and plays the box's Highlight Sound (set to None until you pick one).\n\nPinned - the icon never fades. It stays until you reload, switch profile or start or stop Test Mode, and a box full of pinned icons has no room for new pops.\n\nImp + Pin - both."] = true
L["Remove"] = true
L["Remove this from Offensives. Use it to clear a debuff that leaked in from another player on a shared target. If the spell is actually yours, it relearns the next time you cast it."] = true
L["Buff"] = true
L["Also track this spell's buff. Adds a second icon that counts down how long the buff lasts, separate from the cooldown. Off by default - leave it off for spells that do not give you a buff."] = true
L["Nothing in this list matches."] = true
L["Set All"] = true
L["Set every cooldown in %s to follow the category default for %s? Any per-spell choice for that setting is cleared."] = true
L["Defaults"] = true
L["Track this category"] = true
L["Untick to stop tracking this whole category. None of its cooldowns show on a lane or a bar, or pop a ready frame."] = true
L["Show by Default"] = true
L["On: spells in this category show unless you hide one individually. Off: spells stay hidden until you enable each one."] = true
L["Ignore Threshold (sec)"] = true
L["Stop tracking any cooldown in this category whose full length is longer than this many seconds. Use it to hide very long cooldowns (like 30+ minute abilities) so they never show on a lane or pop ready. A spell you explicitly enable in the list below still shows. Unlike a lane's Max Time, this filters by the ability's total cooldown, not how much of the timeline is drawn."] = true
L["Default Lane"] = true
L["Which lane this category's cooldowns travel along. The chosen lane must also be enabled under Lanes - one marked (off) draws nothing."] = true
L["Which ready box this category's cooldowns pop into the moment they come up. Off means they never pop."] = true
L["Default Bar"] = true
L["Which bar frame this category's cooldowns appear in. The chosen Bars frame must also be enabled under Bars. Off shows no bar."] = true
L["Makes every cooldown in this category follow the Default Lane above. Any per-spell Lane you picked in the category's list is cleared. Show, Bar, Ready Box, Important and Pinned choices are left alone."] = true
L["Makes every cooldown in this category follow the Ready Box above. Any per-spell Ready Box you picked in the category's list is cleared. Show, Lane, Bar, Important and Pinned choices are left alone."] = true
L["Makes every cooldown in this category follow the Default Bar above. Any per-spell Bar you picked in the category's list is cleared. Show, Lane, Ready Box, Important and Pinned choices are left alone."] = true
L["Harmful effects you put on a target are detected automatically as you apply them - nothing to set up."] = true
L["A target's debuff cannot be identified in combat, so Cooldown Master learns which of your abilities applies which effect out of combat, from what lands just after you cast.\n\nSince 12.1 the game withholds that too, so an effect it has not already learned cannot be picked up at all. /cm offlearn tells you when your client is withholding it rather than leaving you guessing, and where the game still allows learning, it walks you through one ability at a time - type /cm offlearn, cast the ability, let combat end, then /cm offlearn stop. Anything already learned keeps tracking normally."] = true
L["Learning your offensives"] = true
L["Offensives is turned off"] = true
L["This category tracks the harmful effects you put on your target - damage-over-time effects, and debuffs like stuns - so each one travels a lane and pops a ready box when it drops. Nothing in this category is tracked while it is switched off - tick Track this category above to switch it on.\n\n"] = true
L["Spell cast"] = true
L["Aura gained"] = true
L["New Custom"] = true
L["Custom"] = true
L["Delete this custom cooldown?"] = true
L["Custom cooldowns run a local timer you define - a fixed duration plus a trigger. They never read a live cooldown, so they behave the same in combat."] = true
L["No custom cooldowns yet. Add one below."] = true
L["Add Custom Cooldown"] = true
L["Create a new custom cooldown - its editor opens below so you can set its trigger and duration."] = true
L["Select a custom cooldown above to edit it."] = true
L["Delete"] = true
L["Remove this custom cooldown."] = true
L["Edit"] = true
L["Toggle this custom cooldown on or off without opening it."] = true
L["Shown on the cooldown's icon tooltip and bar. Left blank, it follows the trigger spell's name."] = true
L["Trigger"] = true
L["Spell cast starts the timer when you cast the entered spell. On-use trinkets, potions and flasks all count - enter the spell the item casts. This is the reliable choice.\n\nAura gained starts it when you gain the entered buff. On retail, the game hides your buffs from addons while you are in combat, so a buff gained mid-fight cannot be seen and the timer will not start. Prefer Spell cast for anything you cast or use."] = true
L["Trigger ID"] = true
L["The buff's spell ID (often different from the ability that grants it). Not sure of the ID? Use the Detect button."] = true
L["The spell ID you cast that fires this cooldown. For an on-use item, enter the spell the item casts."] = true
L["Detect"] = true
L["Click, then gain the buff in-game within 15 seconds - CDM fills in its ID, name, icon and duration."] = true
L["Duration (sec)"] = true
L["How long the timer runs after the trigger fires. Click the number to type an exact value."] = true
L["Editing"] = true
L["Gain a buff..."] = true
L["Route by Cooldown Length"] = true
L["Sort cooldowns into lanes by length"] = true
L["Sends a cooldown to a lane based on how long it is rather than what kind it is, so short cooldowns can run a fast lane and long ones a slow lane. A lane you picked for an individual spell still wins over this. A cooldown Cooldown Master has not timed yet goes by the length the game lists for it, and falls back to its category's Default Lane only when neither is known."] = true
L["Short Up To (sec)"] = true
L["A cooldown this long or shorter counts as short."] = true
L["Short Lane"] = true
L["Medium Up To (sec)"] = true
L["A cooldown longer than Short Up To but no longer than this counts as medium. Anything above it is long."] = true
L["Medium Lane"] = true
L["Long Lane"] = true
L["Category Defaults"] = true
L["Filters"] = true

-- UI/SettingsColors.lua
L["Colors"] = true
L["Class Colors"] = true
L["Use Class Color on a lane or a bar frame fills it with your class's color from this list. Only your character's class is drawn. The others apply when an alt shares this profile."] = true

-- UI/SettingsProfiles.lua
L["serialization libraries unavailable"] = true
L["empty string"] = true
L["not a valid import string"] = true
L["could not decompress"] = true
L["could not read profile data"] = true
L["not a Cooldown Master profile string"] = true
L["Enter a profile name first."] = true
L["Already on profile: %s"] = true
L["Profile already exists: %s (switch to it in the list, or pick a new name)."] = true
L["Create"] = true
L["Created and switched to profile: %s"] = true
L["Copy every setting from \"%s\" into your current profile, \"%s\"? Your current settings are replaced."] = true
L["Delete profile \"%s\"? This cannot be undone."] = true
L["Reset profile \"%s\" to default settings?"] = true
L["Export failed."] = true
L["Paste an exported string to overwrite the current profile \"%s\"."] = true
L["Import"] = true
L["Import failed: %s"] = true
L["invalid string"] = true
L["Imported into profile \"%s\"."] = true
L["Copy"] = true
L["Switch"] = true
L["(no auto-switch)"] = true
L["Auto-switch by Specialization"] = true
L["Switch profile automatically when you change spec."] = true
L["Profiles"] = true
L["New Profile"] = true
L["Name for the new (empty) profile:"] = true
L["Duplicate Current"] = true
L["Name for the copy of the current profile:"] = true
L["Export"] = true
L["Reset current profile to defaults"] = true

-- UI/SettingsAbout.lua
L["Open or close the options window (or /cdmaster)"] = true
L["Lock the lane frames"] = true
L["Unlock the lane frames for moving"] = true
L["Toggle sample cooldowns (set them up in Global > Test Mode)"] = true
L["Reset the current profile to defaults"] = true
L["Print the version and game flavor"] = true
L["Reopen the What's New window"] = true
L["Thanks to %s, who translated my other addons into French."] = true
L["Thanks to %s, who translated my other addons into Russian."] = true
L["Thanks to %s, who translated my other addons into Korean."] = true
L["Thanks to %s, who translated my other addons into Simplified Chinese."] = true
L["Thanks to %s, who translated my other addons into Traditional Chinese."] = true
L["Thanks to %s, who translated my other addons into German."] = true
L["by %s"] = true
L["A timeline-style lane cooldown tracker that complements Blizzard's built-in Cooldown Manager."] = true
L["A timeline-style lane cooldown tracker for your spells, items, and buffs."] = true
L["GitHub"] = true
L["Report a Bug"] = true
L["Commands"] = true
L["Tip: left-click the minimap button to open Options, right-click to lock or unlock frames."] = true
L["More Add-ons by Wheelbarrel00"] = true
L["CurseForge"] = true
L["Cooldown Master shares part of its text with my other addons, and those phrases are the work of the translators below. The rest was written in-house in their style and with their permission, so anything wrong in it is my mistake and not theirs. Corrections are very welcome."] = true
L["Changelog"] = true
L["Older versions are on GitHub"] = true
L["About"] = true
L["Tutorials"] = true
L["Video tutorials are coming soon."] = true
L["Credits"] = true
L["Cooldown Master carries forward the idea behind |cffEBB706%1$s|r by |cffEBB706%2$s|r - the timeline-cooldown addon that inspired this one. After Midnight changed how cooldowns work, I rebuilt the concept from the ground up for 12.0 with his blessing. Full credit for the original timeline-cooldown idea goes to him. Thank you, cliffclive."] = true
L["Translations"] = true
L["Thanks"] = true
L["Built with feedback, reports, and ideas from the community. Thank you!"] = true

-- UI/WhatsNew.lua
L["Missed an update?"] = true
L["Every release's full notes live inside the addon - type %1$s, open the %2$s page, and read the Changelog there."] = true
L["Prefer quiet updates?"] = true
L["Switch these notices to a clickable chat link, or turn them off, under %1$s > %2$s > %3$s, or tick \"Don't show these again\" below."] = true
L["Thanks for using %s!"] = true
L["Found a bug or have an idea? Use the Discord button at the top of this window."] = true
L["What's New"] = true
L["Don't show these again"] = true
L["Stops What's New notices entirely. You can turn them back on under /cm > Global > After an update."] = true
L["Got it"] = true
L["Open Options"] = true
L["[See what's new]"] = true
L["%1$s updated to %2$s - %3$s"] = true

-- UI/Lanes.lua
L["%ds"] = true
L["%dm"] = true
L["Cooldown"] = true
L["Custom cooldown"] = true

-- UI/ReadyFrames.lua
L["Ready %d"] = true

-- UI/Bars.lua
L["Bar %d"] = true

-- Core/Constants.lua
L["Mixed"] = true
L["Spells"] = true
L["Utility"] = true
L["Buffs"] = true
L["Buff Bars"] = true
L["Potions"] = true
L["Trinkets"] = true
L["Pet Spells"] = true
L["Offensives"] = true

-- Core/DataBroker.lua
L["Frames unlocked."] = true
L["Frames locked."] = true
L["Version %s"] = true
L["%s to open options."] = true
L["Left-click"] = true
L["%s to lock/unlock."] = true
L["Right-click"] = true
L["%s to toggle test."] = true
L["Middle-click"] = true

-- Core/Init.lua
L["Welcome! Type /cdmaster to open the options panel."] = true
L["Frames %s."] = true
L["locked"] = true
L["unlocked"] = true
L["Settings reset to defaults."] = true
L["Version %1$s on %2$s"] = true
L["Test mode: %s"] = true
L["on"] = true
L["off"] = true

-- Core/Tags.lua
L["Spell"] = true
L["Buff Bar"] = true
L["Potion"] = true
L["Trinket"] = true
L["Pet"] = true
L["Offensive"] = true
L["Type text and these tags fill in live."] = true
L["Per cooldown (icon labels only):"] = true
L["[cd.name] - spell or item name"] = true
L["[cd.type] - category (Spell, Buff, Potion...)"] = true
L["[cd.time] - remaining time"] = true
L["Global (status line, or icons):"] = true
L["[cd.next] - name of the next cooldown up"] = true
L["[cd.count] - how many are on cooldown"] = true
L["[target.name] / [target.class] - blank if hidden"] = true
L["This line belongs to the frame, not to one cooldown, so per-cooldown tags like [cd.name] and [cd.type] stay blank here. Put those on an Icon Label instead."] = true
L["Time Left"] = true
L["Next CD"] = true
L["CD Count"] = true
L["My Class"] = true
L["My Name"] = true
L["Target"] = true
L["Target Class"] = true
L["My HP Percent"] = true
L["My Power Percent"] = true

-- Convert the `true` sentinels to their key (the self-keyed English default).
for k, v in pairs(L) do if v == true then L[k] = k end end
