# Stratagem

A free gear guide for the WoW Forever client (`World of Warcraft\_classic_beta_`, interface 16001). Gear lists quest rewards, dungeon drops, crafts, and world drops that beat what you have on, within 3 levels. It does not choose a leveling path. Level BiS is the best piece for that slot at your level. Upgrade is still worth taking.

The window is a dark navy browser: categories on the left, the gear list or a guide list in the middle, the selected step on the right. Gear and Level 60 BiS open their steps immediately. The other categories are lists. Several of those guides can be open in tabs.

## Install

1. Copy this folder to `D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns\Stratagem`. The folder name must be `Stratagem`.
2. Enable **Stratagem** at the character screen. The addon list icon is the compass medallion.
3. Optional, and recommended when you have them:
   - **NaowhForever**, **NaowhForever_BiS**, and **NaowhForever_DungeonJournal** (a `NaowwahForever_BiS` folder is recognized too). While those are enabled, Stratagem reads their live quest list and spec rankings.
   - **QuestieDB**. Quest rewards that are not in the bundled catalog, such as the leather waist on The Hunt Begins, are named from QuestieDB. Without it, those quests are left off the Gear list. Catalog quests still name their rewards.
   - **TomTom**, for a minimap and world arrow. Without it, Stratagem shows coordinates and its own on-screen arrow.

`/reload` after enabling. Open the window with `/sg` or the minimap button.

## Testing on WoW Forever

Log into the `_classic_beta_` client with Stratagem enabled.

1. `/reload`. Gear is already open. There is no All guides button and no zone route. Each line is an optional upgrade within 3 levels, grouped by where it comes from. When nothing qualifies, the first line says nothing in the next 3 levels beats what you have on. Esc, the minimap button, and `/sg hide` close the window. The window pops on its own only the first time this character has no saved guide.
2. The sidebar spec should match your class. Open it and pick a spec, reload, and confirm the choice stuck. `/sg spec` prints the key.
3. A line names a quest, a dungeon drop, a craft, or a world drop. Equip something better in that slot and the line leaves. Turn the quest in and its line leaves. Accepting the quest does not. If the item was only in your bags, getting rid of it brings the line back.
4. With the dungeon journal loaded, a dungeon line names the item, the boss, and a percent, and the detail pane shows the item. Trash has no percent. Without the journal, those lines are absent.
5. A craft names the profession only when the profession spell or the source text does. A world drop does not say to buy it unless the source says auction.
6. On an empty slot the line can say Level BiS in gold. When a stronger piece for that slot is already available, it says Upgrade in green. The detail pane and the tracker show the item icon. Mouse over the icon.
7. The HUD arrow should show the step name, a direction, and a yard distance. Walk the way it points and the yards should go down. Next and Prev should retarget it. Left-click drag should move it, and a reload should keep that spot. `/sg arrowflip` mirrors it. Right-click the tracker or the arrow opens Gear. With TomTom enabled, a pin is dropped as well, and the HUD arrow stays.
8. Level 60 BiS, just above Options, lists a step per slot. With Naowh loaded it names the rank-1 item and where it comes from. A drop, an auction piece, or a quest reward shows the item icon. The optional enchant line names the enchant for that rank 1 piece, or says the list has none. The detail line shows your gear score against the score of those pieces. Attunements lists Onyxia for your faction and Molten Core. Open one and walk the steps.
9. `/sg status` should say whether the live Naowh journal loaded or the bundled snapshot (131 quests, about level 6–34) is in use.

## How Gear works

Pick your spec at the bottom of the sidebar, or leave **Match my talent tab** on. Feral tank and feral DPS share a talent tab, so the addon keeps feral DPS until you choose the tank spec yourself.

Gear does not choose a zone. Each line is one optional pickup: a quest reward, a dungeon drop, a crafted piece, or a world drop. It shows only when that item is better than what you have on, and the pickup is within 3 levels. An empty slot counts. The same item level is not an upgrade. If you already wear something better, or the item is already in your bags, the line is marked done and left off. Take the piece off, or get rid of the bag item, and the line comes back. Turn the quest in and the line stays done. Accepting the quest does not finish it. A piece more than 3 levels ahead stays hidden, and it is not marked done. Clicking Done stays done.

The lines are grouped by zone, dungeon, profession, World drops, or Auction house. A quest line names the quest and where to pick it up. A dungeon line names the item, the boss, and the journal percent. Trash has no percent. A craft line names the profession when the spell or the source text does, and it names the skill, trainer, vendor, or drop mob only when the recipe does. Buy it on the auction house only when the source text says auction. A world drop says the list does not call it an auction listing.

**Level BiS** (gold) means that item is the best piece for the slot you can wear at your level. **Upgrade** (green) means it is still an improvement, and a stronger piece for that slot is already available. Mail is not a hunter or shaman upgrade before level 40. Plate is not a warrior or paladin upgrade before level 40. The endgame rank list is not printed on the step.

The Dungeons category is still a list of dungeon quests. Those guides finish the lead-in, accept every dungeon quest, then one Run step, then each turn-in. Gear does not use that shape. Its dungeon lines are the drops.

Wrong class, race, or faction is hidden. **Hide rewards meant for other specs** still applies to the other categories. On Gear, a line shows when the item is an upgrade this class can wear. Changing spec can change which choice a quest names. Equipping gear hides or completes Gear lines. The step list itself is rebuilt when reward data arrives, not on every equip. Level 60 BiS rewrites its item names when you change spec. The number of slots stays the same.

Right-click a guide in a list to favorite it. Right-click the tracker, or the HUD arrow, to open Gear. In Professions, Attunements, and the other lists, double-click, **Continue**, or **Open in new tab** opens a tab (four at a time; the oldest closes). **Open in tab** replaces the guide tab you already have open. **Continue** also sets the waypoint.

## Level 60 BiS and attunements

**Level 60 BiS** is above Options. It opens one step per slot for your spec: head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, both fingers, both trinkets, weapon, off hand, and ranged. The step says where to get the rank-1 item. A quest names the quest and the place to start it. A drop names the boss and the percent when the journal has one. Buy it on the auction house only when the list itself says auction. A world drop is not treated as a listing. A drop, an auction piece, or a quest reward shows the item icon. The following step is an optional enchant for the rank 1 piece, and it names that enchant. A slot the list cannot enchant says so. It does not depend on what you are wearing. The top of the list, and the detail pane, show your gear score now and the score after these pieces. Some items still loading can make the ideal number climb. Without NaowhForever_BiS, every line says the list loads with that addon.

**Attunements** is the next category. Pick Onyxia Attunement (Alliance or Horde, matching your faction) or Molten Core Attunement. The steps are the chain the Dungeon Journal lists for that quest, in order. A branch the journal marks as a choice is one step that names the options. Quests the journal does not list are not filled in from memory. Without the journal, the guide tells you to enable it and reload.

**Prev** moves to the previous visible step and clears that step's done mark. The quest log will not immediately check it off again. **Next** marks the current step done and moves forward.

## Navigation

The HUD arrow points at the step the tracker is on and shows that step's name and the distance in yards. The direction and the distance are the same vector, so walking toward the arrow brings the number down. Next, Prev, Done, and a click on a step move it. Left-click and drag to place it somewhere else. That spot is remembered. Right-click opens Gear. `/sg arrowflip` mirrors it (left becomes right) if the texture feels backwards. TomTom can still drop a pin at the same time. The arrow stays up either way. A step with no map coordinates does not raise it. A dungeon Run step points at the entrance from the dungeon journal. Several quests in one camp share a pin, so the direction stays put until the route leaves that pin. The name under the arrow still changes.

With TomTom enabled, the current step drops a waypoint when the quest has a map id. Coordinates in the journal are 0–100 and are converted for TomTom. The quest is also super-tracked in the quest log when that option is on.

Some turn-ins name a place in the text but have no map id (Grimand's Armor is one). Those steps show the written coordinates and do not drop a pin. The map id is not guessed.

Distance and direction use HereBeDragons when TomTom brought it: one world vector from you to the pin. Otherwise the client's world position is used with the same angle. On the same map, if neither is available, the number is an estimate (42 yards per map percent) and the arrow still uses that same angle, with north opposite the map's downward y. From another zone the arrow still shows the distance when a world position exists.

## Slash commands

| Command | What it does |
| --- | --- |
| `/sg` or `/stratagem` | Open or close the window |
| `/sg show` / `/sg hide` | Show or hide it |
| `/sg tracker` | Show or hide the step tracker |
| `/sg next` / `/sg prev` | Move one visible step. Prev stays on the step it returns to. |
| `/sg done` | Mark the current step done |
| `/sg waypoint` | Point at the current step |
| `/sg spec` | Print the spec key |
| `/sg spec beast-mastery-hunter` | Set a spec. Keys match Naowh (`arms-warrior`, `feral-tank-druid`, `combat-rogue`, …) |
| `/sg status` | Spec, and whether live BiS data loaded |
| `/sg reset` | Clear the current guide |
| `/sg reset all` | Clear every guide on this character |
| `/sg arrowflip` | Mirror the on-screen arrow |

A keybind, **Toggle Stratagem**, is under the Stratagem header in the game's keybind menu.

## Guides that ship with this version

Gear is one Horde list and one Alliance list. The steps are grouped by zone, dungeon, profession, World drops, or Auction house. Professions, reputation, dungeons, exploration, class quests, and choice-reward lists stay separate categories. Dungeon, zone, class, and choice lists are built from the catalog when you log in, so they follow whatever Naowh Forever has loaded.

The bundled snapshot has **131** catalog quests, about **level 6 through 34**. Quest rewards outside that snapshot are named when QuestieDB is enabled. The addon does not invent the rest. With NaowhForever loaded, dungeon drops, crafts, and world drops come from that addon's lists. Journal quest ids, bosses, and drop chances were not invented. A quest with no name is left off.

Starter-zone quest rewards are included when QuestieDB or the catalog names them and the item is an upgrade. They are not a path the addon makes you walk.

Level 60 BiS, enchant advice, gear score, dungeon drop rates, and the Onyxia and Molten Core chains are read from NaowhForever_BiS and NaowhForever_DungeonJournal while those addons are enabled. They are not stored in this download. If one of them is off, the matching steps say what to enable. The Barrens Oases is read from NaowhForever_Discovery when that addon is enabled. The dungeon journal's Wailing Caverns list does not name it. Without Discovery, that one step is absent and the chain still starts at The Forgotten Pools.

## Updating the BiS snapshot

WoW cannot read arbitrary files from disk. At login Stratagem uses `_G.NaowhForever` (or `_G.NaowwahForever`) when that addon is loaded: `Journal.BiSQuestData` for quests and `BiSData` for spec rankings. Dungeon tags live on the bundled copy and are copied onto live rows by quest id. If the globals are missing, the files in `Data\` are used.

Regenerate those files from your local install (do not hand-edit them):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\build_catalog.ps1
```

The script reads `NaowhForever_DungeonJournal\Data\BiSQuests.lua` and `NaowhForever_BiS\Data\BiS.lua` under `D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns`. Edit the paths at the top of the script if your client lives somewhere else. Then reload the game.

## Saved variables

- `StratagemDB` (account): window position and scale, tracker position, minimap angle, options, favorites, recent guides, open tabs.
- `StratagemCharDB` (character): class, spec, auto-detect, active guide, per-step progress.

## Icons

Category icons, the arrow, and the main icon are 32-bit TGA files in `Media\`. Rebuild them from the Imagine sources with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\export_icons.ps1
```

`-MainOnly` rewrites just `Media\Icon.tga`. The prompts used to generate the art:

Main icon:

> A square video-game addon icon, centered, of a golden eight-pointed compass rose fused with a star, a slim sword and a small kite shield crossed behind it. The symbol sits on a dark navy circular medallion with a thin violet inner ring and warm gold rim. Polished World of Warcraft interface art, crisp metallic edges, deep black-navy field filling the square, soft violet glow in the metal. Even studio lighting, no text, no letters, no watermark, generous padding so the medallion reads clearly at a tiny size.

The shield on the shipped icon is a plain gold kite with a violet four-point star, so it does not favor a faction.

Category sheet:

> A game UI icon sheet on a flat pure magenta background, two rows of five equal square icons with wide even gaps and nothing touching. Every icon is the same dark navy rounded medallion with a thin gold rim and a single gold-and-violet metallic symbol. Top row: four small window panes, a sword rising along an upward chevron, a blacksmith anvil, a hanging banner, a compass rose. Bottom row: an hourglass, a cut gemstone, a stone dungeon archway, a five-point star, a cogwheel.

Arrow:

> A single game UI arrow icon centered on a flat pure magenta background. A bold upward chevron made of polished gold metal with a violet edge highlight. Dark World of Warcraft interface art, crisp edges, no text, no letters, no extra shapes.

## Layout

```
Stratagem.toc          load list and saved variables
Bindings.xml           toggle keybind
Core.lua               saved variables, events, slash commands
Specs.lua              class and spec catalog, talent detection
BiS.lua                live Naowh data, or the bundled snapshot
Gear.lua               the Gear list: quest, dungeon, craft, and world-drop upgrades
Engine.lua             steps, filters, progress
Guides.lua             zone sources, professions, and dynamic guide defs
Route.lua              Level 60 BiS, attunements, and zone sources Gear does not open
Nav.lua                TomTom, super-track, on-screen arrow
Data\Quests.lua        generated quest snapshot
Data\ItemSpecs.lua     generated spec rankings
UI\                    theme, widgets, window, tracker, minimap
Media\                 icons
Tools\                 catalog and icon exporters
```
