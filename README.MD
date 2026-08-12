# [TF2] Friendly Fire Fix

A SourceMod plugin for Team Fortress 2 that fixes broken interactions during friendly fire.

> [!NOTE]
> This plugin does nothing if `mp_friendlyfire` is not enabled.

## Requirements

* SourceMod 1.12+
* [Mikusch/PluginStateManager](https://github.com/Mikusch/PluginStateManager) (compile only)

## What Does This Do?

`mp_friendlyfire` allows teammates to damage each other, but the vast majority of weapons and mechanics were not made with it in mind, and thus do nothing if two players are on the same team.
This plugin hooks into various game functions to rewrite and fix that behavior.

> [!NOTE]
> The following changes only apply while `mp_friendlyfire` is `1`.

### Changes

* **General**
    * Projectiles collide with teammates instead of passing through them
    * Your team's stickybombs can be destroyed with regular weapons
    * Taunt kills work on teammates
* **Halloween spells**
    * The Fireball spell burns and knocks back teammates
    * The Bats spell stuns, bleeds and launches teammates
    * The Ball O' Lightning zaps teammates
    * A teammate's pumpkin bombs detonate when shot instead of vanishing
* **Scout**
    * Shortstop
        * Secondary attack shoves teammates
    * Flying Guillotine
        * Cleavers damage teammates
* **Soldier**
    * Righteous Bison
        * Energy rings hit teammates instead of passing through them
* **Pyro**
    * Flame Thrower
        * Teammates can be set on fire
        * Projectiles fired by your own team can be reflected
    * Dragon's Fury
        * Fireballs damage teammates on a direct hit
    * Scorch Shot
        * Flare projectiles apply knockback to teammates
* **Demoman**
    * Grenade Launcher
        * Grenades explode on your team's buildings instead of bouncing off them
    * Stickybomb Launcher
        * Your team's stickybombs can be knocked around
    * Scottish Resistance/Quickiebomb Launcher
        * Your team's stickybombs can be detonated
* **Heavy**
    * Huo-Long Heater
        * The ring of fire burns teammates
* **Engineer**
    * Buildings
        * Your team's buildings can be damaged, your own are still off limits
    * Short Circuit
        * The energy orb zaps teammates and destroys their projectiles
    * Pomson 6000
        * Energy rings hit teammates instead of passing through them
* **Sniper**
    * Sniper Rifle
        * Rifles deal damage to teammates, without breaking Machina penetration
    * Huntsman
        * Arrows hit teammates instead of passing through them
* **Spy**
    * Knife
        * The "backstab ready" animation plays on teammates

## Free-for-All Mode

`sm_friendlyfire_teammates_are_enemies` is a separate opt-in that goes considerably further, and it stops teammates from counting as teammates at all.
Interactions that were never meant for your own team start working on them, and every friendly interaction stops.
It effectively turns the game into a free-for-all.

> [!NOTE]
> The following changes only apply while `sm_friendlyfire_teammates_are_enemies` is `1`.

### Changes

* **General**
    * Jars coat teammates instead of extinguishing them
    * Radius buffs like the Buff Banner no longer affect teammates
    * Self-cast spells no longer buff teammates
    * Grappling Hooks latch onto teammates
    * Teammates collide with eachother
    * Teammates no longer glow after spawning
* **Pyro**
    * Airblast pushes teammates around instead of extinguishing them
    * Gas Passer clouds coat teammates
    * Manmelter secondary attack no longer extinguishes teammates
    * Thermal Thruster launches and landings knock teammates around instead of extinguishing them
* **Soldier**
    * Mantreads can stomp teammates
* **Engineer**
    * Sentry Guns shoot all players except the builder, and can be wrangled onto teammates
    * Dispensers and Teleporters only work for the builder
    * Buildings are solid to teammates
    * The Wrench damages your team's buildings instead of repairing them
* **Medic**
    * The Medi Gun cannot heal teammates
    * Crusader's Crossbow arrows no longer heal teammates
* **Sniper**
    * The Sydney Sleeper no longer extinguishes burning teammates
* **Spy**
    * Cloaked teammates are invisible to you
    * Sappers can be placed on your team's buildings
