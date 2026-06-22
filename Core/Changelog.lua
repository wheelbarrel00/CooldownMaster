local ADDON_NAME, ns = ...

ns.Changelog = {
	{
		version = "0.10.1",
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
		sections = {
			{ head = "Other", items = {
				"Some code cleanup.",
			} },
		},
	},
	{
		version = "0.8.0",
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
		sections = {
			{ head = "New Features", items = {
				"Curve-evaluation cooldown engine that routes numeric math through Blizzard's privileged DurationObject, avoiding Midnight secret-value taint.",
				"Persistent learning: each spell's duration is remembered across reload and login once it has been observed.",
			} },
		},
	},
	{
		version = "0.1.0",
		sections = {
			{ head = "Implemented", items = {
				"First playable build: Ace3 addon, themed options panel, LibDataBroker launcher and minimap button, and slash commands. Loads on Midnight, Classic Era, and TBC Classic.",
			} },
		},
	},
}
