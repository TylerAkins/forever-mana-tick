# Forever Mana Tick

Mana timing indicators for the default player mana bar in **WoW Forever**.

## Features

- A spark moves from right to left for five seconds after observed mana spending.
- A second spark moves from left to right over an estimated two-second regeneration cycle.
- Mana gains appear in blue and losses in purple, then fade.
- Indicators hide while a non-mana resource is active. No configuration, saved variables, or dependencies are required.

## Installation

Download a versioned ZIP from [GitHub Releases](https://github.com/TylerAkins/forever-mana-tick/releases). Extract the `ForeverManaTick` folder into the Forever client's `Interface/AddOns` directory, then enable **Forever Mana Tick** at character selection.

The installed layout must be `Interface/AddOns/ForeverManaTick/ForeverManaTick.toc`. Remove or disable ManaTickTrackerPlus to avoid duplicate indicators.

## Compatibility and limitations

This port targets WoW Forever beta build **1.60.1.70338**, Interface **16001**. Client source and mocked runtime checks have been inspected; in-game verification is pending. Retail, Era, and other Classic clients are outside the supported scope.

The addon follows Blizzard's default player mana bar. Replacement unit frames that hide that bar will also hide the indicators.

Tick timing is an estimate based on observed mana gains. Potions, refunds, and other gains can reset the cycle. Observed mana losses start the five-second countdown; events do not identify whether every loss suppresses regeneration. At full mana the tick spark hides. The display does not predict a guaranteed amount of mana or change regeneration.

## Development

Run `luajit tests/runtime.lua` and `python3 -m unittest discover -s tests`. Lua 5.1 can also run the runtime tests. Build an installable ZIP with `bash tools/package.sh`.

See [development notes](docs/DEVELOPMENT.md) for source analysis and the in-game checklist, and [release setup](docs/RELEASING.md) for GitHub and CurseForge setup.

The interface workflow runs Wednesdays at 12:00 UTC and can be dispatched manually. It prepares a patch-version pull request when Blizzard's Forever interface changes. Review and test compatibility before merging. Publication is disabled initially. After approval and activation, reviewed interface merges trigger patch releases; manual releases use versioned tags.

## Credits and license

The installed addon is derived from ManaTickTrackerPlus by Dustin Checketts and distributed under the preserved [MIT license](LICENSE). Development tooling adapted from forever-quest-markers is GPL-3.0-or-later. See [ATTRIBUTION.md](ATTRIBUTION.md).
