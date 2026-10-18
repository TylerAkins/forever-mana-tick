# Forever Mana Tick

Mana and energy timing indicators for the default player power bar in **WoW Forever**.

## Features

- A spark moves from right to left for five seconds after a readable mana-cost cast or observed mana spending. Known periodic mana channels hold the countdown until the channel stops.
- A second spark moves from left to right over an estimated two-second mana or energy regeneration cycle.
- The spark size matches the default power bar and can be adjusted in the addon options.
- Readable mana gains appear in blue, energy gains in yellow, and losses in purple, then fade.
- The display switches between mana and energy, including druid cat form. Other resources hide the indicators. The selected spark size is saved account-wide. No external dependencies are required.

## Installation

Download a versioned ZIP from [GitHub Releases](https://github.com/TylerAkins/forever-mana-tick/releases). Extract the `ForeverManaTick` folder into the Forever client's `Interface/AddOns` directory, then enable **Forever Mana Tick** at character selection.

The installed layout must be `Interface/AddOns/ForeverManaTick/ForeverManaTick.toc`. Remove or disable ManaTickTrackerPlus to avoid duplicate indicators.

## Compatibility and limitations

This port targets WoW Forever beta build **1.60.1.70338**, Interface **16001**. Client source and mocked runtime checks have been inspected; in-game verification is pending. Retail, Era, and other Classic clients are outside the supported scope.

The addon follows Blizzard's default player mana bar. Replacement unit frames that hide that bar will also hide the indicators.

Adjust the spark size under **Esc > Options > AddOns > Forever Mana Tick**. The default slider value is 100%, which uses the spark size previously shown at 150%.

When power values are restricted, successful casts with readable mana costs can still start an estimated five-second countdown. A native mana/energy percentage curve controls the regeneration spark's opacity at full resource; its result goes directly to the display. The sweep uses a public clock and does not measure restricted regeneration ticks. Gain/loss text pauses until values become accessible, then starts from a fresh baseline.

Tick timing is an estimate that can synchronize to readable resource gains. Potions, refunds, and other gains can reset the cycle. Observed mana losses start the five-second countdown; events do not identify whether every loss suppresses regeneration. A spell-cost countdown can also differ from actual spending after discounts or refunds. If spell information is restricted too, that cast cannot start the countdown. At full mana or energy the regeneration spark disappears. The display does not predict a guaranteed amount of regeneration or change regeneration.

## Development

Run `luajit tests/runtime.lua` and `python3 -m unittest discover -s tests`. Lua 5.1 can also run the runtime tests. Build an installable ZIP with `bash tools/package.sh`. Build a clean local addon directory with `python3 tools/compile_addon.py`; add `--install` to copy it into the Forever beta client's AddOns folder. Use `--addons-dir /path/to/Interface/AddOns` to select a different client installation.

See [development notes](docs/DEVELOPMENT.md) for source analysis and the in-game checklist, and [release setup](docs/RELEASING.md) for GitHub and CurseForge setup.

The interface workflow runs Wednesdays at 12:00 UTC and can be dispatched manually. It prepares a patch-version pull request when Blizzard's Forever interface changes. Review and test compatibility before merging. Publication is disabled initially. After approval and activation, reviewed interface merges trigger patch releases; manual releases use versioned tags.

## Credits and license

The installed addon is derived from ManaTickTrackerPlus by Dustin Checketts and distributed under the preserved [MIT license](LICENSE). Development tooling adapted from forever-quest-markers is GPL-3.0-or-later. See [ATTRIBUTION.md](ATTRIBUTION.md).
