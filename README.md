# Cooldown Master

[![Support on Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=flat-square&logo=ko-fi)](https://ko-fi.com/wheelbarrel00) [![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal)](https://www.paypal.biz/wheelbarrel00) [![Join our Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/vm8K2WfQUE) [![Version](https://img.shields.io/github/v/release/wheelbarrel00/CooldownMaster?color=6D0501&label=Version&style=flat-square)](https://github.com/wheelbarrel00/CooldownMaster/releases) ![Languages](https://img.shields.io/badge/Languages-EN_FR_DE_RU_KO_ZHCN_ZHTW-6D0501?style=flat-square) ![WoW Midnight](https://img.shields.io/badge/WoW-Midnight12.1-8B0000?style=flat-square) ![WoW Classic Era](https://img.shields.io/badge/WoW-ClassicEra1.15-8B0000?style=flat-square) ![WoW TBC](https://img.shields.io/badge/WoW-BurningCrusade2.5-8B0000?style=flat-square) ![WoW MoP](https://img.shields.io/badge/WoW-MoP5.5-8B0000?style=flat-square) ![Interface](https://img.shields.io/badge/Interface-120100-333333?style=flat-square) [![License](https://img.shields.io/github/license/wheelbarrel00/CooldownMaster?style=flat-square&color=333333)](https://github.com/wheelbarrel00/CooldownMaster/blob/main/LICENSE)

**A timeline-style cooldown tracker for World of Warcraft. Your spells, items, potions, and trinkets glide along lanes toward a ready edge, with depleting bars and pop-up alerts the moment they come up. The visual companion to Blizzard's built-in Cooldown Manager. Install it and it just works. Your cooldowns show up automatically, in your own language, with deep customization there if you want it.**

Runs on **Midnight (retail 12.1)**, **Classic Era**, **Burning Crusade Classic**, and **Mists of Pandaria Classic** from one code base, ships in **seven languages**, and registers a LibDataBroker launcher plus minimap button so panel addons like Titan Panel, Bazooka, Arcana, and other LibDataBroker displays pick it up automatically.

---

## Contents

**Using it**

1. [What it does](#what-it-does)
2. [How it works, and why Retail settles in after a few casts](#how-it-works-and-why-retail-settles-in-after-a-few-casts)
3. [Quick start](#quick-start)
4. [Lanes](#lanes)
5. [Bars](#bars)
6. [Ready boxes](#ready-boxes)
7. [What gets tracked](#what-gets-tracked)
8. [Filters and routing](#filters-and-routing)
9. [Highlights and flags](#highlights-and-flags)
10. [Custom cooldowns](#custom-cooldowns)
11. [Text tags](#text-tags)
12. [Test mode](#test-mode)
13. [Appearance and media](#appearance-and-media)
14. [Masque](#masque)
15. [Profiles](#profiles)
16. [Panel addons and the minimap button](#panel-addons-and-the-minimap-button)
17. [Slash commands](#slash-commands)
18. [Flavor differences](#flavor-differences)
19. [Languages](#languages)

**For developers**

20. [Midnight and the secret-value API](#midnight-and-the-secret-value-api)
21. [The localization pipeline](#the-localization-pipeline)
22. [Building and running locally](#building-and-running-locally)

**Project**

23. [What is next](#what-is-next)
24. [Credits](#credits)
25. [License](#license)

---

## What it does

Cooldown Master shows you when your abilities come back, in three different styles, and you can use any mix of them at once.

**Lanes** are the signature view. Every ability gets an icon that travels along a lane toward a "ready" edge, at a speed set by its own cooldown. Long cooldowns sit at the far end, imminent ones crowd the ready edge, and the whole rotation fans out by urgency so you read it at a glance.

**Bars** are the classic view. A tidy list of depleting status bars, each with an icon, the spell name, and a live countdown, sorted by whichever is coming up next.

**Ready boxes** are alerts. An icon pops the instant a cooldown finishes, holds for a few seconds, then fades.

Out of the box you get one of each, all showing the same cooldowns, so you can see the three styles side by side and keep whichever suits you. Every cooldown can be sent to any combination of the three, either by category or one spell at a time.

Cooldown Master complements Blizzard's built-in Cooldown Manager rather than replacing it. It reads the same category sets, so your tracked abilities appear automatically with nothing to set up, and adds the timeline, the bars, and the ready alerts that the built-in one does not have.

It only ever displays information. It never casts, queues, or automates anything.

---

## How it works, and why Retail settles in after a few casts

To place an icon on a timeline, Cooldown Master has to know how long that cooldown really is, including your talents and your haste.

**On Classic** that number is readable at any time, so there is nothing to learn and nothing to wait for.

**On Retail (Midnight)** Blizzard hides cooldown numbers from addons during combat, so Cooldown Master learns them instead. Out of combat it reads your true cooldown lengths directly and saves them to your character, so a spell is only ever learned once. During combat, where the number is hidden, it times each cooldown from start to finish to fill in anything it has not seen yet.

**What that means for you.** On a fresh install, a new character, or right after a spec change, give it a minute. For the first few casts some icons may sit slightly off on the lane while it works out their real timing. It sharpens with every cooldown you use, and once a spell is learned it stays learned across sessions.

**The countdown number and the swipe on every icon are always exact.** Those come straight from Blizzard's own cooldown widgets. It is only the icon's *position along the lane* that settles in as it learns.

If a spell or buff is missing, or has landed in the wrong category, please say so on the [Discord](https://discord.gg/vm8K2WfQUE) or open a [GitHub issue](https://github.com/wheelbarrel00/CooldownMaster/issues) and it will get sorted.

The technical detail behind all this is in [Midnight and the secret-value API](#midnight-and-the-secret-value-api).

---

## Quick start

1. Install and log in. Your cooldowns should already be moving along Lane 1.
2. Type **`/cm`**, or click the minimap button, to open the options.
3. Type **`/cm unlock`** to unlock the frames, drag them where you want them, then **`/cm lock`**.
4. Type **`/cm test`** to fill the frames with sample cooldowns while you set things up, and again to turn it off.

That is enough to use it. Everything below is optional.

---

## Lanes

**Options > Lanes.** You get three lanes, all on by default, with Lane 3 left empty as a spare for you to fill or switch off. Each lane is configured independently through the sub-tabs on the left: General, Appearance, Icons, Stacking, and Text.

### General

**Frame Name** is the label shown on the drag handle when frames are unlocked. It is purely for your own reference.

**Enabled** turns the lane on or off. A lane that is off draws nothing, and it shows as "Lane N (off)" everywhere you can route a cooldown to it.

**Reversed** flips the direction of travel, so icons move the other way along the lane.

**Vertical** runs the lane top to bottom instead of left to right. Toggling it swaps the lane's Width and Height so the bar keeps its shape, just rotated.

#### Mode and Max Time

**Mode** decides how a cooldown's time remaining maps to its spot on the lane. This is the single most important setting on a lane.

| Mode | What it does | Best for |
| --- | --- | --- |
| **Linear** | Each icon spans its own cooldown. A 30 second spell and a 5 minute spell both start at the far end and arrive together. | Seeing progress as a percentage, regardless of length |
| **Timeline (seconds)** | One shared seconds axis. Position is time remaining divided by Max Time, evenly. | A true, honest timeline |
| **Logarithmic (seconds)** | Same shared axis, but the last few seconds spread out wide and long cooldowns compress toward the far end. | Rotations where the final seconds matter most |
| **Split (seconds)** | You shape the curve yourself with up to three control points. | Full control, see below |

**Max Time (seconds)** is the longest cooldown the lane will display, from 10 up to 360. Anything longer than this sits parked at the far end until it comes within range. This has no effect in Linear mode, which has no shared clock.

#### Split mode, explained

Split mode lets you decide exactly how much lane space each stretch of time gets.

Set **Split Points** to how many control points you want (1 to 3). Each point has two sliders:

- **Point N Time (sec)** is a number of seconds remaining.
- **Point N Position (%)** is where along the lane that moment should sit.

Cooldown Master draws a straight line from the ready end (0 seconds, 0%) through each of your points, and on to the far end (Max Time, 100%).

**A worked example.** Set Max Time to 360, Split Points to 1, Point 1 Time to 30, and Point 1 Position to 70.

You have just said: *the last 30 seconds should take up 70% of the lane, and everything from 30 seconds out to 6 minutes gets squeezed into the remaining 30%.*

The result is a lane that gives you a huge amount of room to read your imminent cooldowns, while still showing you that your long ones exist. A cooldown with 15 seconds left sits at 35%. One with 30 seconds left sits at 70%. One with 6 minutes left sits at 100%.

**Two rules the curve enforces.** A point set at or beyond Max Time is ignored, because it would strand the end of the lane as unreachable. A point that does not advance both time and position past the point before it is also ignored, because it would fold the curve back on itself. In both cases the lane just falls back to a straight line through whatever points remain valid.

#### Secondary tracking (Classic only)

**Primary Tracking** fills the whole lane like a progress bar for a recurring timer. **Secondary Tracking** adds a second, thinner bar that slides along it. Both can be set to **GCD** (your global cooldown), **Swing** (your main hand swing timer), or **None**.

Primary uses the lane's own fill. Secondary uses the **ST Width**, **ST Height**, **ST Texture**, and **ST Color** settings below it. **Reverse Primary** and **Reverse Secondary** flip each one's direction independently.

These are Classic only. On Retail, Blizzard's own Cooldown Manager already covers this ground.

#### Other General options

**Hide Long Timers** hides any cooldown longer than the lane's Max Time instead of parking it at the far end.

**Override Autohide** keeps this lane's background, border, and markers visible even when Auto-hide Frames is switched on globally.

### Appearance

**Width**, **Height**, **X Offset**, **Y Offset**, and **Anchor** position and size the lane. Anchor is the screen point the lane is measured from, and the offsets move it from there.

**Lane Texture** and **Lane Color** style the bar itself, and each texture in the list shows a preview swatch so you can see what you are picking. **Use Class Color (Lane)** overrides the color with your class color.

**Show Border**, **Border Texture**, **Border Color**, **Border Padding**, and **Border Size** control the frame around the lane. Border textures also preview in the list. A soft border like CDM Soft Edge needs room to fade, so raise Border Size to around 6 or it squashes into a smear.

**Lane Alpha** sets the opacity of the lane background.

### Icons

**Size**, **Transparency**, and **Icon Offset** control the icons themselves. Icon Offset nudges them across the lane, perpendicular to their direction of travel.

**Pulse** makes an icon breathe in and out as it travels, so a lane you care about is easier to catch out of the corner of your eye.

- **Pulse Within (sec)** starts the pulsing only once a cooldown is that close to ready. Set it to 0 to pulse the whole way along the lane.
- **Pulse Strength** is how many pixels the icon grows at the peak of each pulse.

Masque skins draw their own icon, so the pulse steps aside while a skin is active.

**Cooldown Tint (0 = off)** darkens the cooldown swipe over the icon.

**Icon Border** draws a solid ring around each icon, with its own size and color.

**Countdown Timer** draws the time left on the icon. **Icon Label** adds a line of tag-built text with its own font, size, outline, and color. See [Text tags](#text-tags).

**Label Position** anchors the icon's name label above, on, or below the icon, with its own font, size, outline, and color.

### Stacking

When cooldowns bunch up near the ready edge they can cover each other. Stacking keeps them readable.

| Style | What it does |
| --- | --- |
| **Grouped** | Overlapping icons stack into rows |
| **Spread** | Icons are nudged apart along the lane |
| **Offset** | Icons fan out with an even step |

**Grow Direction** sets which way the stack builds (Up, Down, or Center on a horizontal lane, Left, Right, or Center on a vertical one). **Height** caps how far it can grow. **Raise On Mouseover** brings a hovered icon to the front.

### Text

This tab controls the labels printed along the lane itself, plus the lane's status line.

#### Lane markers and auto labels

A lane can show up to five position markers, the little labels that tell you where you are on the timeline. By default they read Ready, 25%, 50%, 75%, and 100%.

Each marker has an **Anchor By** setting, and this is the part worth understanding, because it decides two separate things at once: **what pins the marker in place**, and **who writes its text**.

| Anchor By | Pinned to | Text written by |
| --- | --- | --- |
| **Percent of lane** | A spot on the lane | You |
| **Percent of lane (auto label)** | A spot on the lane | Cooldown Master |
| **Time (seconds)** | A number of seconds | You |
| **Time (auto label)** | A number of seconds | Cooldown Master |

**Position (percent)** and **Position (seconds)** are two views of the same spot. Move either one and the other updates to match, so you can place a marker whichever way you think about it.

**Why the auto label options exist.** Say you hand-type a marker that reads "30s" and place it at 70% of the lane. Later you change Mode from Timeline to Logarithmic, or raise Max Time from 180 to 360. That spot on the lane is no longer 30 seconds, but your label still says "30s", and now it is lying to you.

An auto label solves itself every time the lane changes. Set it to **Percent of lane (auto label)** and it stays at 70% and rewrites its own text to whatever time actually falls there. Set it to **Time (auto label)** and it stays pinned to 30 seconds and moves itself to wherever that lands.

**On Linear, auto labels show a percentage instead of a time.** Linear has no shared clock, because every icon spans its own cooldown, so no single number of seconds is true at a given spot. A percentage is true for every icon, so that is what it shows.

#### Label placement

**Label Placement** puts the whole set of markers above the lane bar, on it, or below it. Move them off the bar when tall icons cover them.

On a vertical lane the cross axis rotates with everything else, so **Above** places them to the right of the lane and **Below** places them to the left.

**X Offset** and **Y Offset** nudge every label from wherever the placement put it.

**Marker Font**, size, outline, and color style all five together.

#### Status line

**Show Status Line**, in the Status Line section, adds a live readout to the lane, for things like the next cooldown coming up or how many are currently down. It is off by default. See [Text tags](#text-tags).

---

## Bars

**Options > Bars.** Three bar frames, off by default except the first. Each one is a list of depleting status bars, sorted by whichever cooldown is coming up next.

**Enabled**, **Frame Name**, **Anchor**, **X Offset**, **Y Offset**, and **Transparency** work the same as on a lane.

**Texture** and **Color** style the fill, with preview swatches in the texture list, and there is a **Use Class Color** option. The **Bar Background** section has its own **Texture** and color, sitting behind the fill.

**Bar Width**, **Bar Height**, and **Padding** size the bars and the gap between them. **Max Bars** caps how many show at once.

**Grow Direction** builds the list upward or downward. **Sort Order** picks whether the soonest or the furthest out sits first.

**Icon Position** puts the icon on the left or right of each bar. **Font**, **Time Font**, and their sizes, outlines, and colors style the spell name and the countdown independently.

---

## Ready boxes

**Options > Ready.** Three notification boxes, the first on by default. A ready box pops an icon the instant a cooldown finishes, holds it, then fades it out.

**Display Duration (sec)** is how long an ordinary icon stays up. **Highlight Duration (sec)**, over on the Highlight sub-tab, is the same thing for an Important icon.

**Max Ready Icons** caps how many can sit in the box at once. When it is full, the oldest is pushed out.

**Post-Combat Hide (sec, 0 = off)** keeps icons up for a few extra seconds after combat ends, so you can see what came up right at the end.

**Ready Sound** plays when an icon pops. A few sounds are bundled, and any LibSharedMedia sound you have shows up in the list too.

**Icon Size**, **Transparency**, **Icon Offset**, and the border and label options match the lane Icons tab.

Icons flagged **Pinned** stay in the box until you clear them, so a cooldown you must not miss will wait for you.

---

## What gets tracked

Cooldown Master sorts everything it tracks into nine categories. Each one is a sub-tab under **Options > Filters**.

| Category | What is in it |
| --- | --- |
| **Spells** | Your main ability cooldowns |
| **Utility** | Utility and movement abilities |
| **Buffs** | Buffs you have on you |
| **Buff Bars** | Buff-style entries from Blizzard's own category set (Retail) |
| **Potions** | Potions, flasks, and elixirs found in your bags |
| **Trinkets** | Equipped on-use trinkets |
| **Offensives** | Harmful effects you have put on your target |
| **Pet Spells** | Your pet's cooldowns |
| **Custom** | Anything you define yourself |

**Potions and consumables** are discovered from your bags automatically. Conjured mana gems and healthstones are recognized by ID, and your equipped on-use trinkets are picked up without any setup. Classic Era reports every consumable under one category with nothing to tell a potion from a sandwich, so there it lists them all. Food and drink carry no cooldown and never draw anything, and can be hidden from the list.

**Pet Spells** reads your pet's spellbook, so Spell Lock, Axe Toss, Gnaw, Freeze and the rest travel the lanes like anything else. Your pet's basic attack and its command and stance buttons are left out, so only real cooldowns show. It is on by default for anyone with a pet bar.

**Shared-cooldown dedupe** collapses abilities tracked under multiple spell IDs to a single lane icon and a single ready pop.

### A cooldown's buff, on Classic

Some abilities have a cooldown *and* give you a buff, and you want to watch both. Icy Veins and Arcane Power are the obvious cases.

Tick **Buff** on that spell's row under **Filters > Spells** and the buff appears as its own second icon, counting down the buff itself rather than the cooldown. It is off by default, so nothing new appears until you ask for it.

On Retail, Blizzard's own category sets already surface tracked buffs, so this is not needed there.

### Offensives

**Offensives** watches the harmful effects you put on your target. Damage over time effects and debuffs like stuns are both included. They are timed by how long the effect lasts rather than by a cooldown, so an effect travels the lane and pops a ready box the moment it wants recasting.

It follows your current target, so swapping targets clears the lane. Each spell gets a **Remove (X)** button for clearing anything picked up off a shared target dummy.

Offensives is **off by default**. Turn it on under **Filters > Offensives**.

It works on every flavor, but the two sides identify an effect differently.

**On Classic**, effects are detected automatically as you apply them. An effect that leaves nothing readable on your target, and a Paladin's Consecration is the clearest case, has its length learned by observation instead, from when the combat log says it ended. That estimate only ever revises upward, so on a fresh install its ready box fires early for the first several casts and settles once the effect has run its full course uninterrupted. Measured on TBC: 3s, then 5s, then 8s and stable. That is the learning working, not a fault.

**On Retail**, a target's debuff cannot be identified during combat at all, so Cooldown Master learns which of your abilities applies which effect out of combat, from what lands just after you cast. Since 12.1 the game withholds that too, so an effect it has not already learned cannot be picked up. Run **`/cm offlearn`** and it will tell you plainly whether your client is withholding it, and where learning is still allowed it walks you through one ability at a time. Anything already learned keeps tracking normally.

A dot is only ever learned once its source can be positively confirmed as you, so a groupmate's dots on a shared target stay off your lanes.

---

## Filters and routing

**Options > Filters.** This is where you decide what shows up and where it goes.

### Category defaults

Pick a category from **Filters > Defaults** and set how everything in it behaves:

- **Enabled** turns the whole category on or off.
- **Show by default** decides whether new cooldowns in it appear without you enabling them one by one.
- **Ignore Threshold (sec)** hides anything whose full cooldown is longer than this. Use it to keep half hour abilities off your lanes. This filters on the ability's total cooldown, which is different from a lane's Max Time, which only controls how much of the timeline is drawn.
- **Default Lane**, **Default Bar**, and **Ready Box** decide where the category's cooldowns are sent. Any of them can be set to off.

### Per-spell overrides

Every category's sub-tab lists the individual spells it has found. Each row gives you:

- **Show** to hide that one spell without touching the rest.
- **Lane**, **Bar**, and **Ready Box** to send that one spell somewhere different. "Default" means it follows the category.
- **Flags** to mark it Normal, Important, or Pinned.

**Set All** buttons next to the category defaults push that setting onto every spell in the category at once, clearing any per-spell choices for that one setting and leaving the others alone.

### Route by Cooldown Length

Sitting at the top of **Filters > Defaults**, this sends a cooldown to a lane based on **how long it is** rather than what kind of ability it is.

Tick **Sort cooldowns into lanes by length** and set your bands:

- **Short Up To (sec)** and **Short Lane**
- **Medium Up To (sec)** and **Medium Lane**
- **Long Lane** takes everything above the medium threshold

The classic use is a fast lane and a slow lane. Send everything under a minute to Lane 1 with a short Max Time so it reads like a rotation helper, and everything longer to Lane 2 with a long Max Time so your big cooldowns have their own space.

**How it interacts with everything else.** A lane you picked for an individual spell still wins over this. Anything whose length Cooldown Master has not learned yet falls back to the category defaults underneath. It is off by default, so nothing moves until you turn it on.

---

## Highlights and flags

Mark a spell **Important** in its Flags column and it stands out everywhere it appears: on the lane, on the bars, and in the ready box.

The highlight style and color are set per frame, under **Lanes > a lane > Icons**, **Ready > a box > Highlight**, and **Bars > a bar > Style**:

| Style | What it looks like |
| --- | --- |
| **None** | No highlight |
| **Border** | A colored ring |
| **Glow** | A soft colored glow |
| **Flash** | Pulses in and out |
| **Border + Flash** | Both together |

**Pinned** is stronger. A pinned icon stays in its ready box until you clear it, instead of fading on a timer.

---

## Custom cooldowns

**Options > Filters > Custom.** Some things the cooldown API simply will not report. Custom cooldowns let you build your own timer for them.

1. Click **Add**.
2. Give it a **Name** and a **Duration (sec)**.
3. Choose a **Trigger**: either a **Spell** you cast, or an **Aura** you gain.
4. Enter the **Trigger ID**.

Typing an aura ID by hand is miserable, so there is a **Detect** button. Click it, then gain the buff you want to track, and it fills in the ID, the name, the icon, and the duration for you.

Custom cooldowns run on a purely local timer, so they work for anything the cooldown API does not expose. They flow through the same lanes, bars, and ready boxes as everything else, with the same routing and highlight options.

---

## Text tags

Two places take text: the **label on each icon**, and the **status line** on a lane or bar frame. Both are off by default and both get full font, size, outline, and color control.

Text is built from tags in square brackets, mixed with any plain text you like.

**Icon tags** describe the cooldown the icon belongs to, things like its name and type: `[cd.name]`, `[cd.type]`, and `[cd.time]` on Classic.

**Status tags** describe your overall state: `[cd.next]`, `[cd.count]`, `[player.class]`, `[player.name]`, `[target.name]`, `[target.class]`, plus `[player.hp.pct]` and `[player.power.pct]` on Classic.

Nobody wants to memorize tag syntax, so there is a **click-to-insert picker** next to every text field. It only ever offers the tags that are valid in that spot, and only the ones your game version can actually draw. Templates built from static tags alone resolve once instead of every frame.

Health and resource tags are Classic only, because Midnight protects those values from addons even out of combat. `[cd.time]` is Classic only for the same reason. On Retail the icon's native countdown draws it instead.

---

## Test mode

**Options > Global > Test Mode**, or **`/cm test`**, or middle-click the minimap button.

Test mode fills your frames with sample cooldowns so you can position and style everything without waiting for a real fight.

- **Type** picks what kind of cooldowns to fake.
- **Number of Cooldowns** is how many, from 1 to 20.
- **First Cooldown Duration** and **Last Cooldown Duration** set the range of lengths they span.
- **Loop** restarts them when they finish.

Settings apply live as you drag the sliders, and the samples obey your real filter routing, so what you see while setting up is what you will get in combat.

---

## Appearance and media

One in-game options window controls the whole look.

**Fonts** are picked from a list that **previews each font in the font itself**, so you can see what you are choosing before you commit.

**Textures and borders** preview too. Statusbar textures show a filled swatch of the actual texture, and borders show a small square with that border drawn around it.

**LibSharedMedia** is fully supported, so any font, texture, border, or sound pack you already have appears in the pickers automatically. A few original Cooldown Master textures are bundled as well (Gradient, Glass, Soft Edge).

**Two scale sliders** under Options > Global: one resizes every cooldown frame together while keeping each anchored where you put it, and the other resizes the options window itself from half size up to double.

**Auto-hide Frames** hides your frames out of combat. Visibility rules let you show frames **Always**, **In a group**, or **In an instance**. Any single lane can opt out with **Override Autohide**.

**Class colors** are a per-class table, flavor-aware (13 classes on retail, 11 on MoP, 9 on Era and TBC), feeding the lane fill and bar fill "use class color" toggles.

**Icon zoom**, an **unusable icon tint or desaturate**, and a **cooldown swipe tint** are all under Global as well.

A **What's New popup** gives you a short digest after an update, with a quiet chat-link mode or off entirely.

Or change nothing. The defaults stand on their own.

---

## Masque

If you skin your icons, Cooldown Master registers **three separate groups** in Masque's own options:

- **Lane Icons**
- **Ready Icons**
- **Bar Icons**

Skin or disable each independently. It is opt-in per group, so nothing changes until you pick a skin.

While a group is skinned, that skin owns the icon's border and crop, so Cooldown Master's own icon border, zoom, and pulse step aside for it. Turn the group off again and they come straight back.

Run **`/cm masque`** if you want to check what it has detected.

---

## Profiles

**Options > Profiles.** Standard AceDB profile management, plus two extras.

**Auto-switch by Specialization** maps a profile to each spec and switches for you when you change spec.

**Import and Export** turn any profile into a copy-paste string, so you can share a setup or carry it to another character.

---

## Panel addons and the minimap button

Cooldown Master provides a LibDataBroker-1.1 launcher and a LibDBIcon-1.0 minimap button. Titan Panel, Bazooka, Arcana, and other LibDataBroker displays pick it up automatically. Just enable "Cooldown Master" in your panel addon's plugin list.

| Click | What happens |
| --- | --- |
| **Left** | Open the options panel |
| **Right** | Lock or unlock frames |
| **Middle** | Toggle test mode |

The minimap button can be hidden under Options > Global if you would rather not have it.

---

## Slash commands

| Command | What it does |
| --- | --- |
| **`/cm`** | Open or close the options panel |
| **`/cm lock`** | Lock all frames |
| **`/cm unlock`** | Unlock all frames for repositioning |
| **`/cm test`** | Toggle test mode |
| **`/cm offlearn`** | Guided setup for Offensives on Retail |
| **`/cm whatsnew`** | Show the What's New popup |
| **`/cm reset`** | Reset the current profile to defaults |
| **`/cm version`** | Print the version and game flavor |

**`/cdmaster`** and **`/cooldownmaster`** work as long forms, with every subcommand above.

There is a set of diagnostic subcommands too, for troubleshooting or filing a good bug report: `debug`, `api`, `spells`, `haste`, `tracking`, `cdv`, `seedtest`, `curvetest`, `items`, `bagscan`, `itemcd <id>`, `buffs`, `petprobe`, `tagprobe`, `masque`, and the offensives probes (`off`, `offprobe`, `offlearn`, `offreset`, `auraprobe`, `auraapi`).

**`/cm anchor arm 30 <spell>`** traces one spell's live cooldown state for 30 seconds, which is the quickest way to show what the engine is actually seeing when reporting a timing bug. **`/cm off arm [seconds]`** does the same for the offensives binder, showing why each dot was learned or refused.

---

## Flavor differences

Cooldown Master runs on Midnight (12.1), Classic Era, Burning Crusade Classic, and Mists of Pandaria Classic from one install. A few things differ between them, and all of them come down to what the game will tell an addon.

| Feature | Retail (Midnight) | Classic |
| --- | --- | --- |
| Cooldown lengths | Learned, see above | Read directly |
| GCD and swing indicators | Not available | Available |
| Health and resource tags | Not available | Available |
| A cooldown's buff as a second icon | Handled by Blizzard's category sets | Tick **Buff** on the spell's row |
| Offensives | Learned out of combat, `/cm offlearn` | Detected automatically |

---

## Languages

Cooldown Master speaks **English, French, German, Russian, Korean, Simplified Chinese, and Traditional Chinese**, and all seven are complete, end to end. Every options label, tooltip, ready box, and the What's New popup reads in your client's language.

Translations are bundled in `Locales/`, selected from `GetLocale()`, and fall back to English per phrase, so a language renders as itself where it has a translation and as English where it does not. There is nothing extra to install, and switching client language switches the addon with it.

**Spotted a translation that reads wrong, or want your language added?** Say so on the [Discord](https://discord.gg/vm8K2WfQUE) or open a [GitHub issue](https://github.com/wheelbarrel00/CooldownMaster/issues). You do not need a GitHub account or any tooling to help. A plain list of phrases is perfectly welcome, and corrections to the languages already here are just as valuable as a new one.

Translator credits are in [Credits](#credits).

---

## Midnight and the secret-value API

The interesting part for other addon authors. Under Midnight, every cooldown *number* is a **secret value** in combat: `C_Spell.GetSpellCooldown`'s start/duration, the `DurationObject`'s `GetRemainingDuration`/`GetTotalDuration`, and even curve evaluation all return taint-protected secrets that error the moment you read or compare them in Lua (`issecretvalue()` is the detector). The only combat-readable signals are `C_Spell.GetSpellCooldown(id).isActive` / `.isOnGCD` (plain booleans) and `maxCharges`.

Cooldown Master works around this with a hybrid approach:

- **Exact swipe + countdown text** come from feeding the opaque `DurationObject` straight into a native `Cooldown` widget via `Cooldown:SetCooldownFromDurationObject`. Blizzard's widget consumes the secret internally, so the timer is exact even though the addon can never read the number.
- **Icon position** on the lane is self-extrapolated from each spell's true duration, learned out of combat (where numbers read normally) and persisted across sessions via SavedVariables, plus an in-combat wall-clock observation layer for anything not yet learned.
- **Spell discovery** uses the `C_CooldownViewer` category sets, and on/off is driven entirely off the readable `isActive`/`isOnGCD` booleans.

(Earlier versions of this README described a curve-evaluation engine that "sidesteps the taint." That turned out to be a dead end. Step, linear and identity curves all came back secret.)

### Auras are stricter than cooldowns, and 12.1 tightened them again

A cooldown at least keeps two readable booleans. An aura on your target keeps almost nothing: in combat its `spellId`, `name`, `icon`, `duration` and `sourceUnit` are all secret, and every "ask by spell" API (`GetUnitAuraBySpellID`, `GetAuraDataBySpellName`) returns `nil` outright rather than a secret. So **you cannot identify a debuff on your target in combat by any path**. That is why Offensives is cast-driven: the spell ID from `UNIT_SPELLCAST_SUCCEEDED` stays plain, so identity comes from what you cast rather than from what you read.

As of **12.1** the `UNIT_AURA` payload itself arrives secret. `isFullUpdate` is a secret boolean and `addedAuras` a secret table. Two practical notes for anyone hitting this:

- **A boolean test on a secret *boolean* throws** (`if updateInfo.isFullUpdate then` is enough to error), because the single bit is the whole payload. A boolean test on a secret *table* or *number* does not throw, since truthiness of a non-boolean leaks nothing. Check the value type before assuming which you have.
- **`tostring` does not throw on a secret.** It hands back a secret *string*, and `string.format` is what dies. Wrapping a read in `tostring` or a `pcall` around the producer protects nothing. Test the returned value with `issecretvalue()`.

Instance-id collections go the same way. `removedAuraInstanceIDs` measures as a secret table, and `C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL|PLAYER")` is dropped for the same reason. With no plain reconcile source left, the cast-driven path stands alone and a wall-clock expiry sweep does the job the reconcile loop used to.

---

## The localization pipeline

**`Locales/*.lua` are generated. Never hand-edit one.** They are built from the [EverythingLocales](https://github.com/wheelbarrel00/EverythingLocales) shared store, which Cooldown Master joined alongside Everything Quests and EQ Objective Tracker. That store keys a translation on its **English phrase** rather than on any addon, so a phrase CDM shares with the other two arrives already translated. 45 did on the day CDM joined, before anyone typed anything. Editing a generated file here is overwritten on the next build, and that repo's drift check exists to catch exactly that.

`Locales/enUS.lua` is the manifest and creates `ns.L`. It must load after `embeds.xml` and before `Core\Constants.lua` in all four `.toc` files. `ns.L` carries an `__index` that returns the key, so a missing phrase degrades to English rather than erroring.

Run `python docs/_verify_locale.py` (exit 0) alongside `luacheck .` after any user-facing string change. It checks code keys against the manifest and every translation for orphans and `string.format` mismatches, without needing the store repo checked out.

> **Displayed does not mean translatable.** A string that is also persisted to SavedVariables or used as a lookup key must stay bare English. AceDB `rawset`s scalar defaults straight into the saved profile, so a translated default is written to disk and outlives a client language change. Dropdowns take `{ value = <bare>, text = L["..."] }`, and anything Blizzard already localizes should use the Blizzard global instead.

---

## Building and running locally

Clone it straight into your AddOns folder and `/reload`. Every embedded library is committed to the repo, so a fresh clone runs as-is:

```bash
git clone https://github.com/wheelbarrel00/CooldownMaster.git
```

Drop the `CooldownMaster/` folder into `World of Warcraft/_retail_/Interface/AddOns/` (or the `_classic_era_`, `_anniversary_`, or `_classic_` equivalent). The same folder serves every flavor, and the right `.toc` loads itself.

At release time the [BigWigs packager](https://github.com/BigWigsMods/packager) re-fetches each library fresh from its upstream via the `externals` block in `.pkgmeta`, so the committed copies are a convenience for local development, not the source of truth for what ships.

The options panel is hand-built rather than driven by an AceConfig options table, so AceGUI, AceConfig and AceDBOptions are deliberately **not** embedded. Do not add them.

---

## What is next

- **More tags** for the label and status line system.
- **More languages.** All seven here are complete, and any new language is welcome. Corrections to the ones already in are just as valuable.
- **More tracking indicator types** on Classic. The per-lane secondary tracking covers the GCD and your main hand swing timer today.
- **Conditional autohide**, to hide frames on resource level or stealth state, alongside the existing out of combat and group rules.

---

## Credits

Cooldown Master carries forward the idea behind **CooldownTimeline2 (CDTL2)** by **cliffclive**, the timeline cooldown addon that inspired this one. When Midnight changed how cooldowns work and CDTL2 could no longer run under the new restrictions, I rebuilt the concept from the ground up for 12.0 and reached out to cliffclive before publishing anything. He kindly gave his blessing to carry the idea forward. Full credit for the original timeline cooldown concept goes to him. Thank you, cliffclive.

**Translations** are shared across my addons, so a phrase translated once helps all of them.

| Language | Translator |
| --- | --- |
| French | **Zox** |
| German | **Stonetwist** |
| Russian | **Malevi4** |
| Korean | **labrie75** |
| Simplified Chinese | **Keriaovo** |
| Traditional Chinese | **BNS333** |

**Credit where it is actually due.** These six translated *my other addons*. Cooldown Master shares a portion of its text with those and inherited their work through the shared translation store. Everything beyond that was written in house, in each translator's established style and with their permission, so any mistake in it is mine and not theirs. The same note is on the addon's About tab, and corrections are very welcome.

Thank you all. This addon reaches a lot more people because of you.

---

## Found a bug or have an idea?

Report it on the [GitHub Issues page](https://github.com/wheelbarrel00/CooldownMaster/issues). Include the error text if you can grab it, since BugSack and BugGrabber make that easy, and what you were doing when it happened.

If you like this one, check out my other addons: [Everything Quests](https://www.curseforge.com/wow/addons/everythingquests), [Everything Delves](https://www.curseforge.com/wow/addons/everything-delves), and [Loot Pro](https://www.curseforge.com/wow/addons/loot-pro). **[Join the Discord](https://discord.gg/vm8K2WfQUE)** for questions or update news.

---

## License

Released under the MIT License. See [`LICENSE`](LICENSE).
