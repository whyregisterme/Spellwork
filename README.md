# Spellwork

Train the five schools of magic. **Alpha.**

Two lesser powers:

- **Soul Study** spends a soul to raise a school one level, the way a trainer would.
- **Practice Ward** conjures a practice dummy. School spells you cast near it teach half again as much.

## Requirements

- SKSE
- Optional: **Magelight UI 1.3.0 or newer** (SeverActions installs it too). With it, the choice is one
  page; without it, two message boxes.
- Optional: **SkyrimNet 0.25 or newer**. With it, the people around you notice. See [SkyrimNet](#skyrimnet).
- Recommended: **YASTM** (Yet Another Soul Trap Manager) by Seally25. See [Souls](#souls).

SkyrimNet isn't required, and there's no DLL. The plugin is ESL-flagged and uses header version 1.70, so it loads on SE 1.5.97
as well as AE.

## Install

Download `Spellwork-<version>.zip` from [Releases](../../releases) and install it with your mod manager
(Vortex or MO2). Enable `Spellwork.esp`. Both powers are added the next time you load a save.

## Soul Study

1. Cast **Soul Study** (Powers). Not in combat.
2. Pick a school, then a soul to spend.
3. The screen fades, two hours pass, and the school rises one level.

| Soul | Teaches a school up to |
|---|---|
| Petty | 25 |
| Lesser | 40 |
| Common | 50 |
| Greater | 75 |
| Grand (black gems too) | 90 |

- **Your progress is kept**, as with a trainer: a study made at 90% of the way to the next level leaves
  you 90% of the way to the one after.
- **Five studies per character level**, as vanilla allows five trainings. Spellwork keeps its own count,
  separate from trainers'.
- **Past 90, only practice teaches**, as with a master trainer.
- **The cheapest gem goes first.** If a petty soul sits in a petty gem and another in a grand gem, the
  petty gem is spent and the grand one is kept.
- **Azura's Star and the Black Star** give up their soul and come back empty, as when you enchant with
  them. Any other reusable gem is left alone and doesn't count.

## Practice Ward

1. Cast **Practice Ward** (Powers). Not in combat. A practice dummy shimmers into being in front of you
   and stands for three minutes.
2. Cast spells of any school within about 20 metres of it: armour spells, summons, heals, fire at the
   dummy, anything that costs magicka.
3. Each one teaches its school what it always does, and **half again** on top. A spell you hold (a ward,
   Flames, Healing Hands) earns that for every second you hold it.

- **The bonus fades as you tire.** By the time you've spent about 1,000 magicka at the ward it's down to
  a quarter, and it keeps shrinking. An hour's rest clears about 250 magicka of tiredness. Conjuring a
  fresh ward doesn't reset it, because the tiredness is yours, not the ward's.
- Casts made in combat don't count. Scrolls, staffs, powers and shouts don't either.
- Activate the dummy to dismiss it. Cast the power again to move it.

## Souls

Spellwork reads the soul a gem holds from the gem itself. That is how gems you buy or find filled carry
their souls, and how YASTM stores **every** soul it traps, partial fills included (a grand gem holding a
lesser soul counts as a lesser soul).

Without YASTM, vanilla soul trap stores a gem filled *below* its capacity in a way scripts can't read,
so those gems don't count. Gems filled to capacity still do.

## SkyrimNet

Spellwork ships a SkyrimNet layer, `whyregister.spellwork`, that narrates these moments. Everyone nearby
perceives and remembers them, and may remark on them:

- **A finished Soul Study**: you rise from two hours of study with a firmer grasp of the school.
- **A conjured practice ward**: at most once every five minutes, so moving or renewing the ward doesn't
  repeat it.
- **The ward going away**: it fades when its time runs out, or dissolves when you dismiss it. Only when
  you're near it; moving it with the power says nothing.

The layer is only triggers listening for Spellwork's mod events. It has no scripts or plugin of its
own, and without SkyrimNet nothing reads it. Turn it off in SkyrimNet's dashboard like any other layer.

### Mod events

Any mod can listen for these (`RegisterForModEvent`):

| Event | strArg | numArg | When |
|---|---|---|---|
| `Spellwork_Studied` | the school, e.g. `Illusion` | its new level | After a Soul Study that raised it |
| `Spellwork_WardConjured` | | | When the practice dummy appears |
| `Spellwork_WardGone` | `expired` or `dismissed` | casts counted at that ward, plus seconds of held spells | When it goes, if you're within its reach. Not sent when it is moved |

## Console levers

- Prefer the message boxes: `set SW_UseMagelight to 0`. Set it back to `1` and load a save to bring the
  page back.
- Stuck (black screen, no controls): load a save, or `stopquest SW_Quest`, then `startquest SW_Quest`.

## Files

| File | What it is |
|---|---|
| `Spellwork.esp` | The quest, both powers and their effects, the dummy, the two message boxes, `SW_UseMagelight` |
| `Scripts/SW_Main.pex` | Soul Study itself |
| `Scripts/SW_UI.pex` | Every Magelight call, kept apart so the rest never names Magelight |
| `Scripts/SW_SoulStudyEffect.pex` | The Soul Study power: opens the choice |
| `Scripts/SW_Ward.pex` | Practice Ward itself |
| `Scripts/SW_PracticeWardEffect.pex` | The Practice Ward power: conjures the dummy |
| `Scripts/SW_WardDummy.pex` | The dummy: activate to dismiss |
| `Scripts/SW_PlayerAlias.pex` | Passes the load event and your spell casts on |
| `Magelight/Spellwork/` | The page |
| `SKSE/Plugins/SkyrimNet/external/whyregister.spellwork/` | The SkyrimNet layer |
| `Source/Scripts/` | The sources |

## Building

`bash build.sh` compiles the scripts with Caprica, builds the plugin from `spriggit/` with Spriggit,
round-trips it to catch fields Spriggit drops, and zips `dist/Spellwork-<version>.zip`. `imports/`
holds the Magelight header it compiles against, which it never ships.

## Credits

By whyregister. Magelight UI by Severause (MIT). YASTM (Yet Another Soul Trap Manager) by Seally25.

MIT licensed.
