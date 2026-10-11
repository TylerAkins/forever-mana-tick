# Development

## Source analysis

The supplied ManaTick.zip contains one Lua file, one TOC, a README, and an MIT license. Apple archive metadata is excluded from the port.

The original registers spell success and power updates, draws two sparks over PlayerFrameManaBar, and uses timer callbacks to fade mana-change text. It assumes spell event argument two is a spell ID, divides the regeneration return by five, starts a countdown at time zero, compares explicit mana with the active resource maximum, and allows older timers to fade newer text.

The port initializes at login, resets on world entry and resource-capacity changes, filters events to the active mana or energy resource, and uses one display clock for fading. Duplicate frequent/update events with unchanged resource values do nothing. Resource changes reset the display baseline. Bursts of readable gains can synchronize the two-second sweep; continuous gains do not restart it every frame.

## Client evidence

Blizzard's `wow_classic_beta` versions feed reported 1.60.1.70338 on 2026-10-10. Interface 16001 is derived from its major, minor, and patch components.

The [Gethe Forever source for build 1.60.1.70338](https://github.com/Gethe/wow-ui-source/tree/943764493e6b16d63ded3ab304150d1f05e58b57) declares the mana bar in `Blizzard_UnitFrame/Mainline/PlayerFrame.xml` as `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar`. The addon resolves this path first and retains the original global as a fallback.

The initial v0.1.0 investigation used the Classic beta branch, whose global PlayerFrameManaBar did not match the Forever player frame. That mismatch prevented display initialization. A fixture with the Forever frame hierarchy reproduced the failure before the v0.1.1 fix and passes afterward. Runtime coverage also checks the legacy fallback and initialization after delayed frame availability.

The mirror commit is API evidence, not proof that this exact client build has been tested. Runtime tests use a mocked client boundary and do not prove combat safety or visual placement.

The Forever build's UnitDocumentation.lua marks UnitPower and UnitPowerMax as conditionally restricted. Blizzard_SharedXML/Dump.lua uses issecretvalue to identify secret values. The addon checks current and maximum power before calculations or comparisons and reestablishes the numeric baseline after restrictions. Restricted values never enter resource arithmetic or text formatting. Regression fixtures reproduce the reported subtraction/comparison failures; they do not reproduce WoW's full taint engine.

EnergyWatch Forever 1.0.7's Combat/ManaFiveSecond.lua provided a reference for readable spell-cost countdowns and native curve-driven opacity. This port uses C_Spell.GetSpellPowerCost with the third spell-event payload argument, guards conditional aura costs, and estimates periodic mana channels. UnitPowerPercent evaluates a step curve on the resource fraction and passes its result directly to Texture:SetAlpha. The Forever build's SpellDocumentation.lua, CurveUtilDocumentation.lua, LuaCurveObjectAPIDocumentation.lua, and SimpleRegionAPIDocumentation.lua verify these contracts, including SetAlpha accepting secret arguments while execution is tainted. No EnergyWatch runtime dependency is required.

## In-game verification before release

Install the built ZIP in the Forever beta client and record the build from GetBuildInfo.

1. Log in and reload on a mana user. Confirm no startup five-second countdown and no Lua errors.
2. Spend mana. Confirm a right-to-left countdown and purple loss text.
3. Let regeneration resume. Confirm the left-to-right estimate, blue gains, and text fading after the latest change.
4. Reach full mana. Confirm the regeneration spark hides.
5. On a druid, enter cat form. Confirm an energy sweep with no five-second countdown. Enter bear form and confirm all indicators hide. Return to caster form and confirm no artificial resource-change text. Repeat energy checks on a rogue.
6. Zone, die, resurrect, and change maximum mana. Confirm the baseline resets without artificial gain/loss text.
7. Repeat casting in combat, use a potion, and test with other installed addons. Record errors and the expected potion-induced timing reset.
8. Verify the default bar remains readable at the intended UI scale.
9. With restricted resource values, cast a mana-cost spell and verify the estimated countdown, followed by the sweep. Verify the native curve hides the regeneration spark at full resource. Check a periodic mana channel and a free spell. Numeric gain/loss text should remain absent while power is restricted.
