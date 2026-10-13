# Stratagem

A free leveling-guide addon for the WoW Forever client (`World of Warcraft\_classic_beta_`, interface 16001). Leveling is one route. It follows your level, leaves a zone when another zone's quest is the better piece, and comes back later for the quests you skipped past. Along the way it names every reward worth equipping, and it marks gold only when that item is the best piece for the slot at your current level. The ride between zones is not treated as a cost. The aim is a character who is geared for the next dungeon, not only a character who leveled quickly.

The window is a dark navy browser: categories on the left, the route or a guide list in the middle, the selected step on the right. Leveling and Level 60 BiS open their steps immediately. The other categories are lists. Several of those guides can be open in tabs.

## Install

1. Copy this folder to `D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns\Stratagem`. The folder name must be `Stratagem`.
2. Enable **Stratagem** at the character screen. The addon list icon is the compass medallion.
3. Optional, and recommended when you have them:
   - **NaowhForever**, **NaowhForever_BiS**, and **NaowhForever_DungeonJournal** (a `NaowwahForever_BiS` folder is recognized too). While those are enabled, Stratagem reads their live quest list and spec rankings.
   - **QuestieDB**. Starting-zone quests are not in the bundled catalog, so their reward names (such as the leather waist on The Hunt Begins) come from QuestieDB. Without it, those steps still show, and they cannot name the item. Catalog quests still can.
   - **TomTom**, for a minimap and world arrow. Without it, Stratagem shows coordinates and its own on-screen arrow.

`/reload` after enabling. Open the window with `/sg` or the minimap button.

## Testing on WoW Forever

Log into the `_classic_beta_` client with Stratagem enabled.

1. `/reload`. Leveling is already open and shows every step, grouped by zone. There is no All guides button and no zone picker. The first group is Camp Narache & Mulgore for a tauren, or Valley of Trials & Durotar for an orc or troll. Esc, the minimap button, and `/sg hide` close the window. The window pops on its own only the first time this character has no saved guide.
2. The sidebar spec should match your class. Open it and pick a spec, reload, and confirm the choice stuck. `/sg spec` prints the key.
3. Scroll the route. A zone such as The Barrens can appear, then Silverpine Forest or a dungeon, then The Barrens again. Each step shows the level. The Barrens includes the journal chain that leads into Wailing Caverns, not only Centaur Bracers. A line marked (Optional) is a dungeon farm, a gear quest that was not on the written route, or the skyborne island for a mainland race. With the dungeon journal loaded, a farm names the item, the boss, and the drop percent, and the detail pane shows the item. Mark it done to skip it.
4. On a character who already finished quests, the tracker should sit near your level. Those earlier quests stay on the list unless the quest log completed them. Accept a listed quest in game and confirm the accept step marks itself done.
5. The HUD arrow should show the step name, a direction, and a yard distance. Next and Prev should retarget it. Left-click drag should move it, and a reload should keep that spot. `/sg arrowflip` reverses it. Right-click the tracker or the arrow opens the leveling steps. With TomTom enabled, a pin is dropped as well, and the HUD arrow stays.
6. Level 60 BiS, just above Options, lists a step per slot. With Naowh loaded it names the rank-1 item, where it comes from, an optional enchant, and your gear score against the score of those pieces. Attunements lists Onyxia for your faction and Molten Core. Open one and walk the steps.
7. `/sg status` should say whether the live Naowh journal loaded or the bundled snapshot (131 quests, about level 6–34) is in use.

## How a route works

Pick your spec at the bottom of the sidebar, or leave **Match my talent tab** on. Feral tank and feral DPS share a talent tab, so the addon keeps feral DPS until you choose the tank spec yourself.

Each quest on the route is three steps: accept, complete, turn in. Travel notes are optional and do not count toward the bar. Progress is saved per character. The quest log can mark quest steps done on its own (Options, on by default). It does not mark a dungeon farm done.

The route is built from the starter path and from the catalog quests that used to live on the zone guides. Each of those quests also brings the earlier quests in its Dungeon Journal chain, and a dungeon brings the quests the journal lists for that dungeon. At each level it picks the quest with the better piece for your class, and it does not charge you for the flight. It stays in that zone for the quests within three levels, then it will send you back when a later quest there is next. That is why The Barrens, Silverpine Forest, and Hillsbrad Foothills can each show up more than once. The bundled list still ends in the mid 30s. It is not every side quest in those zones. A Barrens quest that does not lead to a catalog quest or a Wailing Caverns journal quest is not on the route.

A quest written into that route is required, including the chain that leads to it. A gear quest added because it ranks for your class, and was not already written there, is marked (Optional). A dungeon farm is marked (Optional). The first visit lists one piece your class can equip in each slot, the boss it drops from, and the percent from the dungeon journal. The detail pane shows the item. Trash has no percent. If the journal is not enabled, the step says so instead of guessing. Mark it done to skip it.

Zephras Isle is the skyborne starting island. A tauren, orc, troll, or undead is not required to go there. If your race has a quest on the island, it is one optional group after the starter, and the travel step names the zeppelin: from Mulgore for Horde, from Dalaran for Alliance. The arrow stays on the mainland. Skyborne characters start on the island. In Bloodhoof, Supervisor Fizsprocket comes after The Venture Co., and Journey into Thunder Bluff comes after that.

On login the tracker sits on the first unfinished step within two levels of you. Quests you never accepted stay on the list, even if you are past their level. Travel before the first quest you have not finished is skipped once any quest on the route is already done. Chat says how many steps were skipped when you open a guide from a list. Prev still stays put until you select that guide again.

**Hide rewards meant for other specs** hides quests the endgame list ranked for a different spec. A quest still shows when that list does not name a spec at all. Quests for another class, race, or faction are always hidden. Changing spec hides and shows those steps. It does not rebuild the leveling step order. Equipping gear does not either. Level 60 BiS does rewrite its item names when you change spec. The number of slots stays the same.

On a quest, every reward that is better than what you have on is named. An empty slot counts. A choice tells you which one to take and what to skip. **Level BiS** (gold) means that item is the best piece for the slot you can wear at your level. **Upgrade** (green) means it is still an improvement, and a stronger piece for that slot is already available. Mail is not a hunter or shaman upgrade before level 40. Plate is not a warrior or paladin upgrade before level 40. The endgame rank list is not printed on the step.

Camp Narache and the Valley of Trials are how a new character leaves the start zone. The spec filter does not remove them. With QuestieDB enabled, a tauren hunter on The Hunt Begins is told to choose the leather waist while that slot is empty, and to skip the mail hands. Once a better waist is equipped, or one is available from a quest you can do by your current level, the gold mark drops. Mulgore's map was redrawn, so those pins can sit off the camp. Durotar's map was not. A tauren shaman still gets Call of Fire. An orc or troll takes it inside the Durotar starter.

Right-click a guide in a list to favorite it. Right-click the tracker, or the HUD arrow, to open the leveling steps. In Professions, Attunements, and the other lists, double-click, **Continue**, or **Open in new tab** opens a tab (four at a time; the oldest closes). **Open in tab** replaces the guide tab you already have open. **Continue** also sets the waypoint.

## Level 60 BiS and attunements

**Level 60 BiS** is above Options. It opens one step per slot for your spec: head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, both fingers, both trinkets, weapon, off hand, and ranged. The step says where to get the rank-1 item. A quest names the quest and the place to start it. A drop names the boss and the percent when the journal has one. Buy it on the auction house only when the list itself says auction. A world drop is not treated as a listing. The following step is an optional enchant for the item you have equipped. The top of the list, and the detail pane, show your gear score now and the score after these pieces. Some items still loading can make the ideal number climb. Without NaowhForever_BiS, every line says the list loads with that addon.

**Attunements** is the next category. Pick Onyxia Attunement (Alliance or Horde, matching your faction) or Molten Core Attunement. The steps are the chain the Dungeon Journal lists for that quest, in order. A branch the journal marks as a choice is one step that names the options. Quests the journal does not list are not filled in from memory. Without the journal, the guide tells you to enable it and reload.

**Prev** moves to the previous visible step and clears that step's done mark. The quest log will not immediately check it off again. **Next** marks the current step done and moves forward.

## Navigation

The HUD arrow points at the step the tracker is on and shows that step's name and the distance in yards. Next, Prev, Done, and a click on a step move it. Left-click and drag to place it somewhere else. That spot is remembered. Right-click opens the leveling route. `/sg arrowflip` reverses it if it points the wrong way. TomTom can still drop a pin at the same time. The arrow stays up either way. A step with no map coordinates does not raise it. Several quests in one camp share a pin, so the direction stays put until the route leaves that pin. The name under the arrow still changes.

With TomTom enabled, the current step drops a waypoint when the quest has a map id. Coordinates in the journal are 0–100 and are converted for TomTom. The quest is also super-tracked in the quest log when that option is on.

Some turn-ins name a place in the text but have no map id (Grimand's Armor is one). Those steps show the written coordinates and do not drop a pin. The map id is not guessed.

Distance uses HereBeDragons when TomTom brought it, otherwise the client's world-position API. On the same map, if neither is available, the number is an estimate (42 yards per map percent). From another zone the arrow still shows the distance when a world position exists, and it waits to turn until it can.

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
| `/sg arrowflip` | Reverse the on-screen arrow |

A keybind, **Toggle Stratagem**, is under the Stratagem header in the game's keybind menu.

## Guides that ship with this version

Leveling is one Horde route and one Alliance route. The steps are grouped by the zone or dungeon you are sent to, and that name repeats when you are sent back. Professions, reputation, dungeons, exploration, class quests, and choice-reward lists stay separate categories. Dungeon, zone, class, and choice lists are built from the catalog when you log in, so they follow whatever Naowh Forever has loaded.

The bundled snapshot has **131** catalog quests, about **level 6 through 34**. That is the whole journal extract this copy was built from. The woven route cannot invent the rest of the Barrens, Silverpine, Hillsbrad, or the path from 35 to 60. With NaowhForever loaded, the live quest list replaces that snapshot, and the route still only includes quests that list contains. Journal quest ids, bosses, and drop chances were not invented. Level BiS on the starting-zone quests still works, because those reward names come from QuestieDB rather than from the snapshot.

The Mulgore and Durotar starter steps use quest ids the Forever Codex lists for those hubs. They are not in the BiS snapshot, and they are not claimed as best in slot.

Level 60 BiS, enchant advice, gear score, dungeon drop rates, and the Onyxia and Molten Core chains are read from NaowhForever_BiS and NaowhForever_DungeonJournal while those addons are enabled. They are not stored in this download. If one of them is off, the matching steps say what to enable.

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
Gear.lua               level BiS and upgrade lines on quest steps
Engine.lua             steps, filters, progress
Guides.lua             zone sources, professions, and dynamic guide defs
Route.lua              the one leveling route, Level 60 BiS, attunements
Nav.lua                TomTom, super-track, on-screen arrow
Data\Quests.lua        generated quest snapshot
Data\ItemSpecs.lua     generated spec rankings
UI\                    theme, widgets, window, tracker, minimap
Media\                 icons
Tools\                 catalog and icon exporters
```
