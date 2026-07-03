local ADDON_NAME, ns = ...

ns.Changelog = {
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
