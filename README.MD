# [TF2] Fixed Friendly Fire

This plugin attempts to fix the incredibly broken friendly fire in Team Fortress 2.

**Note:** This does nothing if `mp_friendlyfire` is not enabled.

## What does this fix?

The full list is far too big to write out in detail, but some notable fixes include:

* **General**
    * Fixed jar projectiles not coating teammates
    * Fixed projectiles not colliding with teammates under certain conditions
    * Fixed not being able to destroy friendly stickybombs with regular weapons
* **Scout**
    * Shortstop: Fixed secondary attack not shoving teammates
* **Soldier**
    * Buff Banner: No longer applies buffs to teammates
* **Pyro**
    * Flame Thrower: Fixed not being able to set teammates on fire
    * Flame Thrower: Fixed not being able to airblast teammates
    * Manmelter: No longer extinguishes teammates
    * Scorch Shot: Fixed flare projectiles not applying knockback to teammates
    * Gas Passer: Fixed gas clouds not coating teammates
* **Demoman**
    * Grenade Launcher: Fixed grenades rarely bouncing off friendly buildings
    * Stickybomb Launcher: Fixed not being able to knock around friendly stickybombs
    * Scottish Resistance/Quickiebomb Launcher: Fixed not being able to detonate friendly stickybombs
* **Engineer**
    * Sentry Guns now shoot all players except the builder and spies disguised as the builder
    * Dispensers and Teleporters now only work for the builder and spies disguised as the builder
    * All buildings are now solid to all players
    * Wrench: Fixed being able to repair friendly buildings
* **Sniper**
    * Sniper Rifle: Fixed not being able to deal damage to teammates
* **Spy**
    * Fixed being able to see cloaked teammates
    * Knife: Fixed the "backstab ready" animation not playing on teammates
    * Sapper: Fixed not being able to sap friendly buildings

**Heavy** did not need any special fixes, and **Medic** has been largely untouched.

## Found a bug?

That's great... and bad!

Please [open an issue](https://github.com/Mikusch/friendlyfire/issues) with detailed steps on how to reproduce your bug. I'll take a look at is as soon as I'm available.