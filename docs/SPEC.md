# Stratagem specification

WoW Forever leveling guide. Target client: `D:\WoW\World of Warcraft\_classic_beta_`, interface 16001 (listed first in `Stratagem.toc`). A route is a normal zone quest list. Each reward that is better than what the character has on is named. Gold means that item is the best piece for that slot at the character's current level. The endgame top-10 rank list does not set that badge.

## Player-facing behavior

- Window: left categories, center guide list, right detail. Dark navy panels, violet actions, gold labels. Categories: All guides, Leveling, Professions, Reputation, Exploration, Legacy, Collectibles, Dungeons, Favorites, Options.
- Guides are grouped by bracket and zone (Horde and Alliance, 1–30 and 30–40, plus the other categories).
- Detail shows the zone, level range, faction, step count, progress, Continue, Open in tab, and Open in new tab. Each guide row has an Open button. The first visible guide is selected so Continue is available without an extra click. Continue opens the guide and sets the waypoint. Open in tab replaces the current guide tab. Open in new tab adds one, up to four.
- Until a guide has been started, login opens the window. The tracker shows Choose a guide instead of step buttons. Prev, Next, Done, and Point open that window when nothing is selected. Prev moves to the previous visible step and clears its done mark so the tracker stays there. Right-click the tracker or the HUD arrow opens the guide list.
- Each quest is accept, complete, then turn in. Travel and "level toward" notes are optional and do not count. Progress is per character.
- Selecting a guide reads this character's completed quests and quest log. Accept is marked done when that quest is already in the log or already turned in. Complete is marked done when the objectives are done. Turn-in is marked done only after the quest is turned in. A failed quest is left open. Travel and notes before the first unfinished quest are marked done once any quest on that route is already done. A quest the character never accepted stays on the route. Chat says how many steps were skipped. Prev still stays on the step it returns to until that guide is selected again. With auto-advance on, login fills every guide's progress from the quest log, and the active guide's tracker moves to the first open step.
- Spec is chosen in the sidebar or with `/sg spec <key>`. Keys match NaowhForever_BiS (`arms-warrior`, `feral-dps-druid`, `feral-tank-druid`, …). Auto-detect uses the classic talent tab. Feral tank shares tab 2 with feral DPS and stays a manual choice.
- Wrong class, race, or faction is never shown. "Hide rewards meant for other specs" hides quests the endgame list ranked for a different spec. A journal quest that the top-10 ranking slice names for nobody stays visible. Starting-zone steps stay visible either way.
- On a leveling route, a quest that ranks for the player's class and is missing from that zone's written steps is inserted at its level. The accept, complete, and turn-in steps are one chain. Switching spec changes which of those steps are hidden. It does not rebuild the step list, and neither does equipping gear or gaining a level. Dungeon quests are inserted only into a segment named for that dungeon.
- Gear advice is separate from that list. For every reward the character can equip, a step says to take it when it is better than the worn piece. An empty slot counts as item level 0. A choice quest names the one piece to pick and says what to skip. Gold and the label Level BiS mean that item is the best armor tier, and the highest item level of that tier, among rewards this character can obtain from quests at or below their level. Green and the label Upgrade mean it is still worth taking, and a stronger piece for that slot is already available. Mail is not hunter or shaman gear before level 40. Plate is not warrior or paladin gear before level 40. A quest the character cannot accept, because of class, race, or faction, does not count. The endgame rank is not shown.
- Horde 1–30 includes Camp Narache & Mulgore (tauren) and Valley of Trials & Durotar (orc and troll). Those steps are the way out of the start zone, and the spec filter does not hide them. Quest ids come from the Forever Codex hub lists for those zones. They are not rows in `Data\Quests.lua`. Their reward names come from QuestieDB when that addon is enabled. A tauren hunter on The Hunt Begins is told to choose the leather waist while that slot is empty and mail is unusable, and to skip the mail hands. Shaman Call of Fire (1527) stays on the Durotar guide. The Broodmother (96261) stays on the 30–40 guide. Mulgore pins use classic map 1412. Forever redrew that zone, so a pin can sit off the camp. Durotar still uses its classic map.
- TomTom gets a waypoint when the step has a map id. The HUD arrow still shows. It points at the tracker's current step, names that step, and prints the distance in yards. Prev, Next, Done, and a click on a step move it. Left-click drag moves the arrow, and the spot is remembered. Right-click still opens the guide list. Distance uses HereBeDragons or `C_Map.GetWorldPosFromMapPos` when one of those is present. On the same map, without either, it estimates 42 yards per map percent. `/sg arrowflip` reverses the arrow. A step with no coordinates does not raise the arrow. Steps that share one camp pin keep the same direction until the route leaves that pin.
- Slash: `/stratagem` and `/sg` with show, hide, tracker, next, prev, done, waypoint, spec, status, reset, reset all, arrowflip. Keybind: Toggle Stratagem.
- Saved variables: `StratagemDB` (account), `StratagemCharDB` (character).

## Data

- Live source, when loaded: `_G.NaowhForever` or `_G.NaowwahForever`, `Journal.BiSQuestData` plus `BiSData` spec rankings. Dungeon tags are copied from the snapshot onto live rows by quest id.
- Bundled snapshot: `Data\Quests.lua` and `Data\ItemSpecs.lua`, generated by `Tools\build_catalog.ps1` from the local Naowh journal and BiS list. 131 quests, about level 6 through 34. Higher brackets only contain quests that exist in that range. No quest id is invented.
- Routes live in `Guides.lua`. Dynamic dungeon, zone, class, and choice guides are built at login from the catalog.
- A segment may also carry `plain` quests. Engine marks those steps `path`. They are filtered by class, `notClass`, and race, then shown even when the spec filter is on. The accept text calls them starting-zone quests. `Gear.lua` appends the reward sentence once QuestieDB has been scanned. Without QuestieDB those steps cannot name a reward. Catalog quests still can, from the reward ids already on the quest row.

## Files the client loads

`Stratagem.toc`, `Bindings.xml`, `Core.lua`, `Specs.lua`, `Data\Quests.lua`, `Data\ItemSpecs.lua`, `BiS.lua`, `Gear.lua`, `Guides.lua`, `Engine.lua`, `Nav.lua`, `UI\Theme.lua`, `UI\Widgets.lua`, `UI\Minimap.lua`, `UI\Tracker.lua`, `UI\Window.lua`, `Media\`.

QuestieDB is an optional dependency. Stratagem reads `_G.ItemDB` and `_G.QuestDB` from it. It does not copy that database into this repo.

## Current limits

The 30–40 routes are thin because the snapshot ends near level 34. Steps with coordinates in the text but no map id do not drop a TomTom pin. This build has not been loaded in the client yet.

## How to test this version

On the Forever character screen, enable Stratagem. In game:

1. `/sg` opens the window. Esc, the minimap button, and `/sg hide` close it.
2. The footer spec matches the character. Pick another spec for that class, `/reload`, and confirm it persisted. `/sg spec` prints the key.
3. Horde or Alliance 1–30 lists zone guides for your faction. A class-only guide you cannot do is absent. On a tauren, Camp Narache & Mulgore is in the list and Valley of Trials is absent unless you are a shaman (then only Call of Fire). On an orc or troll, Valley of Trials & Durotar is in the list and Mulgore is absent. Undead still get Tirisfal, not those two.
4. Continue on a zone guide shows accept / complete / turn-in steps, a progress bar, and reward names once the client knows the items. On a tauren hunter who still has an empty waist, The Hunt Begins should say to choose the leather waist, mark it Level BiS in gold, and say to skip mail. Equip a better waist, or level past a better one, and the gold mark should drop. A reward that is only an endgame rank, and is worse than what is already available at this level, should not get a gold bar.
5. Accepting a listed quest marks the accept step done when auto-advance is on.
6. Continue raises the HUD arrow. It points along the step, names that step, and shows a yard distance. Next and Prev move the arrow to the new step. Left-click drag moves the arrow, and `/reload` keeps that spot. `/sg arrowflip` reverses it. With TomTom on, a pin is dropped as well and the HUD arrow stays.
7. `/sg status` names the live journal or the bundled snapshot.

## Repository

Each completed prompt is one commit, then a push to `origin` `main` on `https://github.com/hydrolive/stratagem.git`. No force-push. The Forever AddOns copy is a separate step and is not the git push.

## Last change

The HUD arrow follows the step the tracker is on, and it can be dragged. Left-click drag moves it, and the position is saved. Next, Prev, Done, and a click on a step retarget it, including the name under the arrow. A hidden arrow keeps checking, so the next step that has coordinates raises it again.

`/reload`, Continue on a route, then press Next. The name under the arrow should change with the tracker, and the direction should change when the new step has a different pin. Drag the arrow with the left button. `/reload` should leave it where you dropped it. Right-click still opens the guide list.
