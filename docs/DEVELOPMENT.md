# Development

## Source analysis

The supplied ManaTick.zip contains one Lua file, one TOC, a README, and an MIT license. Apple archive metadata is excluded from the port.

The original registers spell success and power updates, draws two sparks over PlayerFrameManaBar, and uses timer callbacks to fade mana-change text. It assumes spell event argument two is a spell ID, divides the regeneration return by five, starts a countdown at time zero, compares explicit mana with the active resource maximum, and allows older timers to fade newer text.

The port uses observed player mana changes rather than spell costs or an inferred regeneration amount. It initializes at login, resets on world entry and resource-capacity changes, filters MANA events, explicitly requests mana maxima, and uses one display clock for fading. Duplicate frequent/update events with unchanged mana do nothing. Resource changes reset the display baseline.

## Client evidence

Blizzard's `wow_classic_beta` versions feed reported 1.60.1.70338 on 2026-10-10. Interface 16001 is derived from its major, minor, and patch components.

The [Gethe Classic beta source](https://github.com/Gethe/wow-ui-source/tree/4d9399a664eb65f2c8d5e96d7a6bf5e234414239) declares PlayerFrameManaBar in `Blizzard_UnitFrame/Classic/PlayerFrame.xml`. Its Classic UnitFrame.lua uses UnitPower, UnitPowerMax, and UnitPowerType. Generated UnitDocumentation.lua declares player-token and power-type payloads for UNIT_POWER_UPDATE and UNIT_POWER_FREQUENT.

The mirror commit is API evidence, not proof that this exact client build has been tested. Runtime tests use a mocked client boundary and do not prove combat safety or visual placement.

## In-game verification before release

Install the built ZIP in the Forever beta client and record the build from GetBuildInfo.

1. Log in and reload on a mana user. Confirm no startup five-second countdown and no Lua errors.
2. Spend mana. Confirm a right-to-left countdown and purple loss text.
3. Let regeneration resume. Confirm the left-to-right estimate, blue gains, and text fading after the latest change.
4. Reach full mana. Confirm the regeneration spark hides.
5. On a druid, enter and leave bear/cat form. Confirm no mana sparks over rage/energy and no artificial mana loss on return.
6. Zone, die, resurrect, and change maximum mana. Confirm the baseline resets without artificial gain/loss text.
7. Repeat casting in combat, use a potion, and test with other installed addons. Record errors and the expected potion-induced timing reset.
8. Verify the default bar remains readable at the intended UI scale.
