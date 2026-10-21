# Stratagem agent rules

Stratagem is a WoW Forever addon. The client is `D:\WoW\World of Warcraft\_forever_`. NaowhForever_BiS on that client uses interface **16001**. That number stays first in `Stratagem.toc`. The other interface numbers are only the ones TomTom already lists, so a Forever build that advertises one of them still loads. Do not aim this addon at retail or at a different classic client.

## After every prompt

When a prompt changes the addon, its data, or these instructions, finish in this order:

1. Update `docs/SPEC.md` so it matches the code. Include what changed and the in-game steps that prove it.
2. Update `README.md` when install, commands, or player-facing behavior changed.
3. Update the workspace memory topic `topics/stratagem.md` under the Stratagem workspace scope. Do not edit `MEMORY.md`. Record stable facts only: client path, deploy path, data source, and catalog limits.
4. Commit the repository. One commit for the completed prompt.
5. Push that commit to `origin` `main` (`https://github.com/hydrolive/stratagem.git`). Do not force-push.
6. Copy the addon to `D:\WoW\World of Warcraft\_forever_\Interface\AddOns\Stratagem`. Exclude `.git`.
7. Tell the user what changed and how to test it on WoW Forever.

Skip the copy only when the prompt did not change anything the client loads or the docs that describe it. Still update the spec and memory if the contract changed.

## Client and code

- Lua 5.1. No `continue`, `goto`, or `//`. A call that returns several values has to be the last argument.
- Assign `StratagemDB` and `StratagemCharDB` on `ADDON_LOADED`, never at file scope.
- Prefer native frames. Add Ace3 only if the user asks.
- Do not invent quest ids. Do not hand-edit `Data\Quests.lua` or `Data\ItemSpecs.lua`. Regenerate them with `Tools\build_catalog.ps1`.
- At login, read `_G.NaowhForever` or `_G.NaowwahForever` when those addons are loaded. Otherwise use the bundled snapshot.
- Quest coordinates in the journal are 0–100. TomTom wants 0–1. Do not invent a map id when the journal has none.
- Icons in `Media\` are 32-bit uncompressed TGA, bottom-left origin, alpha in header byte 17.

## Deploy

```powershell
robocopy E:\Github\stratagem "D:\WoW\World of Warcraft\_forever_\Interface\AddOns\Stratagem" /E /XD .git
```

Robocopy codes 0 through 7 mean the copy worked.
