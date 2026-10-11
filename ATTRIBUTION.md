# Attribution

Forever Mana Tick is derived from ManaTickTrackerPlus by Dustin Checketts, provided in ManaTick.zip. The original MIT license and copyright notice are preserved in LICENSE.

The Forever port removes the spell-cost handler and timer callbacks, initializes after login, filters player mana events, and handles resource changes. Its tick spark estimates the cycle from observed mana gains.

The interface updater, release validation helpers, and updater tests are adapted from Tyler Akins' forever-quest-markers repository under GPL-3.0-or-later. Their license is in tools/LICENSE. Development tools are excluded from the installed addon package.
