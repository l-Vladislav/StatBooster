# StatBoosterUI — Addon Installation & Usage

## Installation

1. Copy the `StatBoosterUI` folder to your WoW addons directory:
   ```
   World of Warcraft/Interface/AddOns/StatBoosterUI/
   ```
2. Also install `StatBoostTooltip` (same `ClientAddon` directory) for enchant tooltip coloring.
3. Restart WoW or type `/reload` in chat.

## Usage

### Opening the UI
- Click the **minimap button** (enchant crystal icon)
- Or type `/sb` or `/statboost` in chat
- Drag the minimap button around the minimap edge to reposition

### Placing an Item
- **Alt+Click** any item in your bags or on your character sheet
- Or **drag-and-drop** an item onto the item slot
- Click the item slot to **clear** it

### Scroll Selection

**If the item has NO StatBoost enchant:**
- Four scroll options appear (one per pool):
  - **Battle** (Blacksmithing) — Str, Agi, AP, Crit, Haste, ArPen
  - **Warding** (Leatherworking) — Sta, Armor, Defense, Block, Health
  - **Arcana** (Enchanting) — Int, Spirit, Spell Power, Mana
  - **Fortune** (Inscription) — Procs, utility, hybrid effects
- Each shows the **correct tier** for the item's iLvl
- **Green count** = you have this scroll in bags; **grey x0** = not in bags
- Click a scroll to preview matching enchants below

**If the item already HAS a StatBoost enchant:**
- Only the **Recalibrator** option appears
- Shows the current enchant's pool name
- Rerolls within the same pool and tier

### Applying
1. Click a scroll option to select it
2. Review the possible enchants list
3. Click **Apply** (enabled only if the scroll is in your bags)
4. Click the target item when prompted

### Enchant Preview
The enchant list shows all possible outcomes for the selected scroll + item combo, filtered by:
- Item level range (tier)
- Equipment slot (mask)
- Item type (weapon/armor/shield)

## Files

| File | Purpose |
|------|---------|
| `StatBoosterUI.lua` | Main UI frame, scroll selection, apply logic |
| `EnchantDB.lua` | Enchant database — maps pools, iLvl ranges, slot masks |
| `StatBoosterUI.toc` | Addon manifest |

## Updating EnchantDB

When enchants are added/changed in the server DB:
1. Update the pool doc files (`.claude/statBoosterItems/fortune_pool/fortune_pool_T*.md`)
2. Update SQL (`data/sql/updates/pending_db_world/statbooster_use_spells.sql`)
3. Update `EnchantDB.lua` pool=4 entries to match SQL masks and iLvl ranges
4. For pools 1-3, entries come from `statbooster_enchant_template` — regenerate if base stats change
