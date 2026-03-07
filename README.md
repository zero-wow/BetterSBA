<p align="center">
  <img src="https://img.shields.io/badge/WoW-Midnight_12.x-blue?style=flat-square&logo=battle.net&logoColor=white" />
  <img src="https://img.shields.io/badge/version-v0003-66B8D9?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-444?style=flat-square" />
</p>

<h1 align="center">
  <code style="background:none;border:none;">Better</code><strong>SBA</strong>
</h1>

<p align="center">
  <em>Enhanced Single-Button Assistant for World of Warcraft</em>
</p>

<p align="center">
  <code>/targetenemy [noharm][dead]</code> · <code>/petattack</code> · <code>/stopmacro [channeling]</code> · <code>/cast SBA</code>
</p>

---

## What is this?

BetterSBA wraps the **Single-Button Assistant** (Assisted Combat) into a `SecureActionButton` with `/targetenemy`, `/petattack`, and channel protection baked into one keypress.

Press your keybind → auto-target nearest enemy → send pet → protect channels → cast. No more tab-targeting before every press.

It also gives you a **rotation queue display** showing your full SBA spell pool with cooldowns, importance borders, and range coloring — everything the default SBA button doesn't show you.

---

## Features

<table>
<tr>
<td width="50%" valign="top">

### 🎯 Keybind Interception
Automatically hooks your existing SBA action bar keybind. The macro fires when you press your normal hotkey — not just when clicking the BetterSBA button. Works with default bars, Bartender4, ElvUI, and Dominos.

### 🔲 Rotation Queue
Shows your SBA rotation pool as icons beside the main button. 8 anchor positions, per-icon cooldowns, and importance-colored borders based on spell cooldown tiers.

### ⚔️ Cast Animations
6 animation types: **Drift**, **Pulse**, **Spin**, **Zoom**, **Slam**. Two styles — **Keep** (button stays, clone animates away) or **Recreate** (old icon animates out, new icon fades in).

</td>
<td width="50%" valign="top">

### 🎨 Importance Borders
Spells auto-classified by base cooldown duration:
| Tier | Cooldown | Default Color |
|------|----------|---------------|
| Filler | < 10s | 🟢 Green |
| Short CD | 10–30s | 🔵 Blue |
| Long CD | 30–120s | 🟣 Purple |
| Major CD | > 120s | 🟠 Orange |

All colors fully configurable.

### 📡 Range Coloring
Icon desaturates red when your target is out of range. Instant visual feedback.

### 🖥️ Config Panel
Full custom settings UI — `/bs` to open. Toggles, sliders, dropdowns, color pickers. Dark minimal theme.

</td>
</tr>
</table>

---

## Install

1. Download the latest release from [Releases](../../releases)
2. Extract `BetterSBA/` into `Interface/AddOns/`
3. `/reload` in-game
4. Type `/bs` to configure

**Requires:** WoW Midnight (12.x) with Assisted Combat / SBA enabled.

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/bs` | Open config panel |
| `/bs lock` | Lock button position |
| `/bs unlock` | Unlock button position |
| `/bs toggle` | Enable / disable |
| `/bs reset` | Reset button position |
| `/bs macro` | Print current macrotext |
| `/bs debug` | Toggle debug output |

Also responds to `/bsba` and `/bettersba`.

---

## How It Works

```
┌─────────────────────────────────────────┐
│  Your Keybind ("2")                     │
│    ↓                                    │
│  SetOverrideBindingClick                │
│    ↓                                    │
│  BetterSBA SecureActionButton           │
│    ↓                                    │
│  macrotext:                             │
│    /targetenemy [noharm][dead]          │
│    /petattack                           │
│    /stopmacro [channeling]              │
│    /cast Single-Button Assistant        │
│                                         │
│  Display Layer (non-secure):            │
│    Icon ← C_AssistedCombat API          │
│    Cooldown ← C_Spell.GetSpellCooldown  │
│    Border ← base CD classification      │
│    Range ← C_Spell.IsSpellInRange       │
└─────────────────────────────────────────┘
```

The secure button is a **sibling** of the display button (both parented to `UIParent`), not a child. This avoids protected frame taint — the display layer can freely update textures, cooldowns, and visibility without triggering `Show()`/`Hide()` lockdown errors in combat.

---

## Optional Dependencies

| Addon | Integration |
|-------|-------------|
| **Masque** | 3 skinning groups: Main Button, Rotation, Animated Button |
| **LibSharedMedia** | Full font library access |
| **LibDBIcon** / **LibDataBroker** | Minimap button |
| **Bartender4** / **ElvUI** / **Dominos** | Keybind scanning + interception |

---

## API Surface

BetterSBA reads from these Blizzard APIs:

```lua
C_AssistedCombat.GetNextCastSpell(checkVisible)  -- primary recommendation
C_AssistedCombat.GetActionSpell()                 -- fallback (12.0+)
C_AssistedCombat.GetRotationSpells()              -- rotation pool
C_AssistedCombat.IsAvailable()                    -- availability check
C_Spell.GetSpellCooldown(spellID)                 -- cooldown info
C_Spell.IsSpellInRange(spellID, unit)             -- range check
C_Spell.GetSpellBaseCooldown(spellID)             -- importance classification
C_ActionBar.FindAssistedCombatActionButtons()     -- SBA slot detection
```

EventRegistry callbacks for real-time updates:
- `AssistedCombatManager.OnAssistedHighlightSpellChange`
- `AssistedCombatManager.RotationSpellsUpdated`
- `AssistedCombatManager.OnSetActionSpell`

---

<p align="center">
  <sub>built for midnight · no ace3 · no libstub · fully self-contained</sub>
</p>
