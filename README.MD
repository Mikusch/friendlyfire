# [TF2] Fixed Friendly Fire

This plugin attempts to fix the incredibly broken friendly fire in Team Fortress 2.

**Note:** This plugin does nothing if `mp_friendlyfire` is not enabled.

## Requirements

* SourceMod 1.11+
* [nosoop/SM-TFUtils](https://github.com/nosoop/SM-TFUtils)
* [Mikusch/PluginStateManager](https://github.com/Mikusch/PluginStateManager) (compile only)

## What does this fix?

This fixes pretty much all interactions with weapons against your own team or entities created by your team's weapons.

The full changelog is far too big to include, but some notable changes include:

* **General**
    * Fixed jar-based projectiles not affecting teammates
    * Fixed projectiles not colliding with teammates under certain conditions
    * Fixed not being able to destroy your team's stickybombs with regular weapons
* **Scout**
    * Shortstop
        * Fixed secondary attack not shoving teammates
* **Soldier**
    * Buff Banner
        * No longer applies buffs to teammates
* **Pyro**
    * Flame Thrower
        * Fixed not being able to set teammates on fire
        * Fixed not being able to airblast teammates
    * Manmelter
        * Secondary attack no longer extinguishes teammates
    * Scorch Shot
        * Fixed flare projectiles not applying knockback to teammates
    * Gas Passer
        * Fixed gas clouds not coating teammates
* **Demoman**
    * Grenade Launcher
        * Fixed grenades rarely bouncing off your team's buildings
    * Stickybomb Launcher
        * Fixed not being able to knock around your team's stickybombs
    * Scottish Resistance/Quickiebomb Launcher
        * Fixed not being able to detonate your team's stickybombs
* **Heavy**
    * No special fixes required
* **Engineer**
    * Buildings
        * Sentry Guns now shoot all players except the builder
        * Dispensers and Teleporters now only work for the builder
        * Buildings are now solid to teammates
    * Wrench
        * Now damages your team's buildings instead of repairing them
* **Medic**
    * Crusader's Crossbow
        * Arrows no longer heal teammates
    * Medi Gun
        * Cannot heal teammates anymore (configurable with `sm_friendlyfire_medic_allow_healing`)
* **Sniper**
    * Sniper Rifle
        * Fixed being unable to deal damage to teammates
* **Spy**
    * Can no longer see cloaked teammates
    * Knife
        * Fixed the "backstab ready" animation not playing on teammates
    * Sapper
        * Fixed not being able to sap friendly buildings

## Found a bug?

Please [open an issue](https://github.com/Mikusch/friendlyfire/issues) with detailed steps on how to reproduce your bug.