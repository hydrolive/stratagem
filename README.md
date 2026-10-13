# Stratagem

A free leveling-guide addon for the WoW Forever client (`World of Warcraft\_classic_beta_`, interface 16001). The route is the zone quest list, in order. When a quest rewards a best-in-slot piece for your spec and the route did not already include it, that chain is added. It is not a speedrun.

The window is a dark navy browser: categories on the left, guides in the middle, the selected route on the right. Several guides can be open in tabs.

## Install

1. Copy this folder to `D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns\Stratagem`. The folder name must be `Stratagem`.
2. Enable **Stratagem** at the character screen. The addon list icon is the compass medallion.
3. Optional, and recommended when you have them:
   - **NaowhForever**, **NaowhForever_BiS**, and **NaowhForever_DungeonJournal** (a `NaowwahForever_BiS` folder is recognized too). While those are enabled, Stratagem reads their live quest list and spec rankings.
   - **TomTom**, for a minimap and world arrow. Without it, Stratagem shows coordinates and its own on-screen arrow.

`/reload` after enabling. Open the window with `/sg` or the minimap button.

## Testing on WoW Forever

Log into the `_classic_beta_` client with Stratagem enabled.

1. `/reload`. Until you start a route, the window opens on its own. Each guide has an Open button, and the first one is already selected so Continue is on the right. The tracker button is Choose a guide. Esc, the minimap button, and `/sg hide` close the window.
2. The sidebar spec should match your class. Open it and pick a spec, reload, and confirm the choice stuck. `/sg spec` prints the key.
3. Set faction to your side. Horde 1–30 and Alliance 1–30 should list zone guides. Tauren get Camp Narache & Mulgore. Orcs and trolls get Valley of Trials & Durotar. A guide for another race stays hidden. Shamans also get Call of Fire on the Durotar guide.
4. Select The Barrens or an Alliance zone, press Continue, and confirm the step list, progress bar, and reward rows. Accept the quest in game and confirm the accept step marks itself done.
5. Continue should raise the HUD arrow with a direction and a yard distance. `/sg arrowflip` reverses it. With TomTom enabled, Continue also drops a pin, and the HUD arrow stays.
6. `/sg status` should say whether the live Naowh journal loaded or the bundled snapshot (131 quests, about level 6–34) is in use.

## How a route works

Pick your spec at the bottom of the sidebar, or leave **Match my talent tab** on. Feral tank and feral DPS share a talent tab, so the addon keeps feral DPS until you choose the tank spec yourself.

Each quest on a route is three steps: accept, complete, turn in. Travel and "level toward" notes are optional and do not count toward the bar. Progress is saved per character. The quest log can mark steps done on its own (Options, on by default).

**Only quests that are BiS for my spec** hides rewards that are ranked for a different spec. A quest still shows when the catalog lists it as BiS but the top-10 ranking slice does not name your spec. Quests for another class, race, or faction are always hidden. A guide with nothing left for you disappears from the list.

A chain that upgrades your spec is marked on every step. **Route BiS** (gold bar) means the quest was already in the guide. **Added BiS** (violet bar) means it was inserted because the written route did not have it. The tracker and the detail panel use the same labels. Changing spec moves the badges. It does not rebuild the step order.

Camp Narache and the Valley of Trials are the exception. Those steps are how a new character leaves the start zone. Each one is marked Starting zone, and the accept text says the reward is not best in slot. The spec filter does not remove them. Mulgore's map was redrawn, so those pins can sit off the camp. Durotar's map was not. The only best-in-slot quest in early Durotar is the shaman Call of Fire. Mulgore's only catalogued BiS quest, The Broodmother, stays on the 30–40 guide.

Right-click a guide to favorite it. Double-click, **Continue**, or **Open in new tab** opens a tab (four at a time; the oldest closes). **Open in tab** replaces the guide tab you already have open. **Continue** also sets the waypoint.

## Navigation

The HUD arrow sits above your character. It points at the current step and shows the distance in yards. `/sg arrowflip` reverses it if it points the wrong way. TomTom can still drop a pin at the same time. The arrow stays up either way. A step with no map coordinates does not raise it.

With TomTom enabled, the current step drops a waypoint when the quest has a map id. Coordinates in the journal are 0–100 and are converted for TomTom. The quest is also super-tracked in the quest log when that option is on.

Some turn-ins name a place in the text but have no map id (Grimand's Armor is one). Those steps show the written coordinates and do not drop a pin. The map id is not guessed.

Distance uses HereBeDragons when TomTom brought it, otherwise the client's world-position API. On the same map, if neither is available, the number is an estimate (42 yards per map percent). From another zone the arrow still shows the distance when a world position exists, and it waits to turn until it can.

## Slash commands

| Command | What it does |
| --- | --- |
| `/sg` or `/stratagem` | Open or close the window |
| `/sg show` / `/sg hide` | Show or hide it |
| `/sg tracker` | Show or hide the step tracker |
| `/sg next` / `/sg prev` | Move one visible step |
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

Leveling guides are zone segments for Horde and Alliance, grouped as 1–30 and 30–40. Professions, reputation, dungeons, exploration, class quests, and choice-reward lists are separate categories. Dungeon, zone, class, and choice guides are built from the catalog when you log in, so they follow whatever Naowh Forever has loaded.

The bundled snapshot has **131** BiS quests, about **level 6 through 34**. That is the whole journal extract this copy was built from. The 30–40 brackets only contain the quests that exist in that range, and there is no BiS route past the mid 30s until the catalog grows. Journal quest ids were not invented.

The Mulgore and Durotar starter routes use quest ids the Forever Codex lists for those hubs. They are not in the BiS snapshot, and they are not claimed as best in slot.

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
Engine.lua             steps, filters, progress
Guides.lua             hand-written routes and dynamic guide defs
Nav.lua                TomTom, super-track, on-screen arrow
Data\Quests.lua        generated quest snapshot
Data\ItemSpecs.lua     generated spec rankings
UI\                    theme, widgets, window, tracker, minimap
Media\                 icons
Tools\                 catalog and icon exporters
```
