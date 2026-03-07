# BetterSBA - Enhanced Single-Button Assistant

## Project Overview
BetterSBA is a World of Warcraft addon that enhances the Single-Button Assistant (SBA/Assisted Combat) system. It provides a SecureActionButton that wraps `/targetenemy [noharm][dead]`, `/petattack`, and `/cast Single-Button Assistant` into one button press, while displaying the recommended spell icon and an ability queue.

## Architecture

### Core Concept
- **SecureActionButtonTemplate** with dynamic `macrotext` for the casting action
- **Plain frame display layer** for icon updates (textures are NOT protected operations)
- **C_AssistedCombat API** for spell recommendations (three-tier fallback)
- **EventRegistry callbacks** for real-time updates from AssistedCombatManager

### File Structure
```
BetterSBA/
  BetterSBA.toc          -- Manifest (interfaces 110207, 120001)
  Bindings.xml           -- Keybinding registration for WoW keybind UI
  Core/
    Constants.lua         -- Namespace, API cache, defaults, theme colors
    Database.lua          -- SavedVariables init (BetterSBA_DB)
    Functions.lua         -- Spell collection, macro builder, keybind scanning
  GUI/
    Framework.lua         -- UI primitives: panels, toggles, sliders, cycle buttons
    MainButton.lua        -- SecureActionButton + icon/cooldown/keybind display
    QueueDisplay.lua      -- Secondary rotation spell queue display
    Config.lua            -- Custom settings panel (/bs command)
  BetterSBA.lua           -- Main entry point, events, slash commands
  CLAUDE.md               -- This file
  TODO.md                 -- Work tracking
```

### Load Order (critical)
Constants → Database → Functions → Framework → MainButton → QueueDisplay → Config → BetterSBA

### Key API Surface
- `C_AssistedCombat.GetNextCastSpell([checkVisible])` — primary spell recommendation
- `C_AssistedCombat.GetRotationSpells()` — rotation spell pool (array of IDs)
- `C_AssistedCombat.GetActionSpell()` — fallback for 12.0+
- `C_AssistedCombat.IsAvailable()` — availability check
- SBA Spell ID: `1229376`
- EventRegistry: `AssistedCombatManager.OnAssistedHighlightSpellChange`, `.RotationSpellsUpdated`, `.OnSetActionSpell`

### Macrotext Construction
Built dynamically from settings (rebuilt out of combat only):
```
/targetenemy [noharm][dead]    -- if enableTargeting
/petattack                     -- if enablePetAttack
/stopmacro [channeling]        -- if enableChannelProtection
/cast Single-Button Assistant  -- always (localized via C_Spell.GetSpellName)
```

### SecureActionButton Constraints
- Cannot change attributes (`type`, `macrotext`) during `InCombatLockdown()`
- Pending changes queued via `NS._pendingMacroRebuild`, applied on `PLAYER_REGEN_ENABLED`
- Icon/texture/cooldown updates are NOT protected — can update freely anytime
- Drag-to-move uses `RegisterForDrag("LeftButton")` — WoW separates click vs drag

## User Preferences
- **Minimalist aesthetic**: dark backgrounds, square 1px borders, clean spacing
- **No library deps**: no Ace3, no LibStub, fully self-contained
- **Theme colors**: dark with cyan/blue accent (`{ 0.40, 0.72, 0.85 }`)
- **Config panel**: custom popup frame (NOT WoW Settings API), square toggles, clean sliders

## Conventions
- **Version format**: `R1.YYMM.HHNN` (e.g., `R1.2603.0100`)
- **Namespace**: `local ADDON_NAME, NS = ...` pattern, globals via `_G.BetterSBA = NS`
- **Git**: local repo, author `Zero <noreply@zero-wow.github.com>`
- **Commits**: imperative summary + bullet-point body
- **Slash commands**: `/bsba`, `/bettersba`, `/bs` (subcommands: lock, unlock, toggle, reset)
- **SavedVariables**: `BetterSBA_DB` (flat table, not nested global/char)

## Keybind Support
- `Bindings.xml` registers `CLICK BetterSBA_MainButton:LeftButton` in WoW keybind UI
- Keybind scanning supports: default Blizzard bars, Bartender4, ElvUI, Dominos
- Keybind text displayed on the main button icon

## Queue Display
- Shows `GetRotationSpells()` as small icons beside the main button
- Current `GetNextCastSpell()` highlighted with accent border
- Position configurable: RIGHT, LEFT, TOP, BOTTOM
- Note: this is the rotation POOL, not a sequential cast queue (API limitation)

## Important Notes
- `GetRotationSpells()` returns the set of rotation spells, NOT a priority queue
- Never use `/castsequence` with SBA — breaks reset timer permanently
- SBA has a 25% GCD penalty on abilities used through it
- The addon is display + casting — it does NOT replace action bar buttons
- If BetterButtonAssistant is also installed, both will work independently (no conflict)

## Testing Checklist
- [ ] Button appears and shows correct spell icon
- [ ] Clicking button casts with targeting/petattack prefix
- [ ] Keybinding works via WoW keybind UI
- [ ] Queue display shows rotation spells
- [ ] Config panel opens/closes with /bs
- [ ] Settings persist across /reload
- [ ] Position saves and restores
- [ ] Lock/unlock works
- [ ] Combat alpha transitions work
- [ ] Range coloring (red when out of range)
- [ ] No taint errors in combat
