# Changelog

## 0.1.1 - 2026-10-10

- Fix missing mana indicators on the Forever client's default player frame.
- Keep an estimated mana countdown and regeneration sweep available when power values are restricted, using readable spell costs and native display APIs.
- Add energy tick estimates and energy-change text for rogues and cat form.

Targets the WoW Forever beta client. Gain/loss text requires readable power values. Tick timing and spell-based mana countdowns are estimates. In-game verification is pending.

## 0.1.0 - 2026-10-10

- Add a five-second-rule countdown spark to the default player mana bar.
- Show an estimated two-second mana tick spark and fading mana gains and losses.
- Hide mana indicators while another resource is active, including druid forms.

Targets the WoW Forever beta client. Tick timing is an estimate; potions and other mana gains can reset it. In-game verification is pending.
