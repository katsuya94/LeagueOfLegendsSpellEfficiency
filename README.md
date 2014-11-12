# League of Legends - Spell Efficiency

Given a champion ability power, base attack damage, bonus attack damage, and cooldown reduction, rank spells based various metrics

In general, these methods attempt to score spells on effectiveness in the absolute most ideal state (hitting the maximum number of targets, hitting with all of the spell, etc.)

run.rb provides a script for generating an HTML document ordering the spells by calculated efficiency

Usage: run.rb \[-d\] (--dps|--mana) base_ad bonus_ad ap cdr outfile

## Metrics

### Damage Per Second

Without regards to resources (mana, etc.) if the champion were to cast this spell on as many enemy champions as possible (5), using it as soon as it comes off cooldown (ignoring casting time except in the case that a duration is given in which case a cycle is duration + cooldown), how fast could he/she/it do damage with the spell alone.

### Damage Per Mana

Applicable only to spells that consume mana. With one use of the spell, how much damage can be dealt per unit of mana.

## Options

### Duel

Disable casting on multiple targets
