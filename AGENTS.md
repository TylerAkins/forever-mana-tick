# Repository guidance

Forever Mana Tick is a small World of Warcraft Forever addon. Keep runtime code compatible with WoW's Lua 5.1 environment and the supported Forever interface version declared in `ForeverManaTick.toc`. The installed addon has no external runtime dependencies.

## Runtime behavior

- Follow the default player power bar in the Forever player-frame hierarchy. Preserve the legacy `PlayerFrameManaBar` fallback and its runtime fixture.
- Track only the player's active mana or energy resource. Druid energy applies in cat form; other forms and resources hide the indicators.
- Treat `UnitPower` and `UnitPowerMax` results as potentially restricted. Check them before arithmetic, comparison, or text formatting, and reset the numeric baseline when they become readable again.
- Keep the mana five-second-rule countdown separate from the two-second regeneration estimate. Energy gains can synchronize the estimate when they look like a 20- or 40-energy tick or reach the cap.
- Keep spark sizing relative to the default bar. Add persistent options to the TOC's declared saved-variable table and cover defaults, saved values, and live updates in the runtime fixture.

## Verification

From the repository root, run:

```sh
luac5.1 -p ForeverManaTick.lua
lua5.1 tests/runtime.lua
python3 -m unittest discover -s tests
```

The runtime fixture models the client API and restricted-value behavior. It does not establish in-game visual placement or WoW's full taint behavior. Follow the checklist in `docs/DEVELOPMENT.md` for client verification. Build and inspect a release archive with `bash tools/package.sh` when packaging changes are in scope.

If Lua 5.1 is unavailable, `luajit tests/runtime.lua` runs the runtime fixture and `luajit -b ForeverManaTick.lua /tmp/ForeverManaTick.luac` checks Lua syntax without editing the repository.

## Releases and attribution

Keep the original MIT attribution and license intact. Treat interface metadata as compatibility evidence, not proof of a live client check. Follow `docs/RELEASING.md` for versioning and release preparation. Do not publish, push, or change release automation without explicit authorization.
