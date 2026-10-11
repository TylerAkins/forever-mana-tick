# Attribution

Forever Mana Tick is derived from ManaTickTrackerPlus by Dustin Checketts, provided in ManaTick.zip. The original MIT license and copyright notice are preserved in LICENSE.

The Forever port replaces the Era spell-cost handler with a guarded C_Spell lookup, uses one display clock instead of timer callbacks, and follows the Forever player-frame hierarchy. It tracks mana and energy, with estimates based on readable gains or a public clock when power is restricted. EnergyWatch Forever 1.0.7 by Sanscrit served as a reference for spell-cost countdowns and native curve-driven opacity.

The interface updater, release validation helpers, and updater tests are adapted from Tyler Akins' forever-quest-markers repository under GPL-3.0-or-later. Their license is in tools/LICENSE. Development tools are excluded from the installed addon package.
