# [TF2] Friendly Fire Fix

This plugin fixes broken interactions during friendly fire in Team Fortress 2.

> [!NOTE]
> This plugin does nothing if `mp_friendlyfire` is not enabled.

## Requirements

* SourceMod 1.12 or 1.13
* [Mikusch/PluginStateManager](https://github.com/Mikusch/PluginStateManager) (compile only)

## What Does This Fix?

`mp_friendlyfire` allows teammates to damage each other, but the vast majority of weapons and mechanics were not made with it in mind, and thus do nothing if two players are on the same team. This plugin hooks into various game functions to rewrite and fix that behavior.

> [!NOTE]
> The following changes only apply while `mp_friendlyfire` is `1`.

### Changes

* **General**
    * Fixed projectiles passing through teammates instead of colliding with them
    * Fixed not being able to destroy your team's stickybombs with regular weapons
    * Fixed taunt kills not working on teammates
* **Halloween spells**
    * Fixed the Fireball spell not burning or knocking back teammates
    * Fixed the Bats spell not stunning, bleeding or launching teammates
    * Fixed the Ball O' Lightning not zapping teammates
    * Fixed a teammate's pumpkin bombs vanishing instead of detonating when shot
* **Scout**
    * Shortstop
        * Fixed secondary attack not shoving teammates
    * Flying Guillotine
        * Fixed cleavers not damaging teammates
* **Soldier**
    * Righteous Bison
        * Fixed energy rings passing through teammates
* **Pyro**
    * Flame Thrower
        * Fixed not being able to set teammates on fire
        * Fixed not being able to reflect projectiles fired by your own team
    * Dragon's Fury
        * Fixed fireballs not damaging teammates on a direct hit
    * Scorch Shot
        * Fixed flare projectiles not applying knockback to teammates
* **Demoman**
    * Grenade Launcher
        * Fixed grenades bouncing off your team's buildings instead of exploding on them
    * Stickybomb Launcher
        * Fixed not being able to knock around your team's stickybombs
    * Scottish Resistance/Quickiebomb Launcher
        * Fixed not being able to detonate your team's stickybombs
* **Heavy**
    * Huo-Long Heater
        * Fixed the ring of fire not burning teammates or destroying their projectiles
* **Engineer**
    * Buildings
        * Fixed not being able to damage your team's buildings, your own are still off limits
    * Short Circuit
        * Fixed the energy orb not zapping teammates or destroying their projectiles
    * Pomson 6000
        * Fixed energy rings passing through teammates
* **Sniper**
    * Sniper Rifle
        * Fixed being unable to deal damage to teammates, without breaking Machina penetration
    * Huntsman
        * Fixed arrows passing through teammates
* **Spy**
    * Knife
        * Fixed the "backstab ready" animation not playing on teammates

## Free-for-All Mode

`sm_ff_teammates_are_enemies` is a separate opt-in that goes considerably further, and it stops teammates from counting as teammates at all.
Interactions that were never meant for your own team start working on them, and every friendly interaction stops. It effectively turns the game into a free-for-all.

> [!NOTE]
> The following changes only apply while `sm_ff_teammates_are_enemies` is `1`.

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
