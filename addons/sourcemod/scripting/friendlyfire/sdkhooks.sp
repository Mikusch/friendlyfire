#pragma newdecls required
#pragma semicolon 1

// Weapons we fix by moving ourselves to the spectator team.
// Required for checks that compare the target against us.
int g_spectatorItemIDs[] =
{
	TF_WEAPON_FISTS,				// CTFWeaponBaseMelee::DoMeleeDamage
	TF_WEAPON_KNIFE,				// CTFKnife::BackstabVMThink
	TF_WEAPON_STICKBOMB,			// CTFWeaponBaseMelee::OnSwingHit
};

// The same, but only while teammates are enemies, because these either help a teammate or ignore them.
int g_teammateSpectatorItemIDs[] =
{
	TF_WEAPON_BUFF_ITEM,			// CTFPlayerShared::PulseRageBuff
	TF_WEAPON_FLAMETHROWER,			// CTFFlameThrower::SecondaryAttack
	TF_WEAPON_MEDIGUN,				// CWeaponMedigun::AllowedToHealTarget
	TF_WEAPON_SNIPERRIFLE,			// CTFPlayer::FireBullet
	TF_WEAPON_SNIPERRIFLE_DECAP,	// CTFPlayer::FireBullet
	TF_WEAPON_SNIPERRIFLE_CLASSIC,	// CTFPlayer::FireBullet
};

// Weapons we fix by moving everyone else to our enemy team.
// Required for checks that moving ourselves cannot reach, e.g. ones that run on the weapon.
int g_enemyItemIDs[] =
{
	TF_WEAPON_HANDGUN_SCOUT_PRIMARY,	// CTFPistol_ScoutPrimary::Push
	TF_WEAPON_MINIGUN,					// CTFMinigun::RingOfFireAttack, AttackEnemyProjectiles
};

// The same, but only while teammates are enemies, because these either help a teammate or ignore them.
int g_teammateEnemyItemIDs[] =
{
	TF_WEAPON_GRAPPLINGHOOK,			// CTFGrapplingHook::ActivateRune
	TF_WEAPON_FLAME_BALL,				// CTFWeaponFlameBall::SecondaryAttack
	TF_WEAPON_RAYGUN_REVENGE,			// CTFFlareGun_Revenge::ExtinguishPlayerInternal
	TF_WEAPON_ROCKETPACK,				// CTFRocketPack::Launch
	TF_WEAPON_SPELLBOOK,				// CTFSpellBook::CastKartSpell, which bypasses TossJarThink in kart mode
	TF_WEAPON_LASER_POINTER,			// CTFLaserPointer::UpdateLaserDot
};

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		// Fixes various weapons and items in friendly fire.
		PSM_SDKHook(entity, SDKHook_PreThink, SDKHookCB_Client_PreThink);
		PSM_SDKHook(entity, SDKHook_PreThinkPost, SDKHookCB_EndSpoofFrame_Think);
		PSM_SDKHook(entity, SDKHook_PostThink, SDKHookCB_Client_PostThink);
		PSM_SDKHook(entity, SDKHook_PostThinkPost, SDKHookCB_EndSpoofFrame_Think);
		PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
		PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_EndSpoofFrame_OnTakeDamage);

		// Makes cloaked Spies fully invisible.
		PSM_SDKHook(entity, SDKHook_SetTransmit, SDKHookCB_Client_SetTransmit);
	}
	else
	{
		if (!strncmp(classname, "obj_", 4))
		{
			// Makes objects solid to teammates.
			PSM_SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Object_SpawnPost);

			// Lets teammates damage buildings.
			// CBaseObject::TraceAttack drops the damage before OnTakeDamage ever runs, so both are needed.
			PSM_SDKHook(entity, SDKHook_TraceAttack, SDKHookCB_Object_TraceAttack);
			PSM_SDKHook(entity, SDKHook_TraceAttackPost, SDKHookCB_EndSpoofFrame_TraceAttack);
			PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Object_OnTakeDamage);
			PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_EndSpoofFrame_OnTakeDamage);
		}

		if (!strncmp(classname, "tf_projectile_", 14))
		{
			if (StrEqual(classname, "tf_projectile_cleaver") || StrEqual(classname, "tf_projectile_pipe") || StrEqual(classname, "tf_projectile_arrow") || StrEqual(classname, "tf_projectile_energy_ring") || StrEqual(classname, "tf_projectile_balloffire"))
			{
				// Fixes these dealing no damage to teammates, they all skip anyone sharing their team.
				PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_Projectile_Touch);
				PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_EndSpoofFrame_Touch);
			}
			else if (StrEqual(classname, "tf_projectile_pipe_remote"))
			{
				// Allows detonating teammates' pipebombs.
				PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_ProjectilePipeRemote_OnTakeDamage);
				PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_EndSpoofFrame_OnTakeDamage);
			}
			else if (StrEqual(classname, "tf_projectile_mechanicalarmorb") || StrEqual(classname, "tf_projectile_lightningorb"))
			{
				// Fixes the terminal burst skipping teammates.
				PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_Orb_Touch);
				PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_EndSpoofFrame_Touch);
			}
		}
		else if (StrEqual(classname, "tf_pumpkin_bomb"))
		{
			// Fixes spell pumpkin bombs being deleted instead of detonating.
			PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_PumpkinBomb_OnTakeDamage);
			PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_EndSpoofFrame_OnTakeDamage);
		}
		else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
		{
			// Prevents Dispensers from healing teammates.
			PSM_SDKHook(entity, SDKHook_StartTouch, SDKHookCB_ObjectDispenser_StartTouch);
			PSM_SDKHook(entity, SDKHook_StartTouchPost, SDKHookCB_EndSpoofFrame_Touch);
		}
		else if (StrEqual(classname, "tf_flame_manager"))
		{
			// Fixes Flame Throwers dealing no damage to teammates.
			PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManager_Touch);
			PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_EndSpoofFrame_Touch);
		}
		else if (StrEqual(classname, "tf_gas_manager"))
		{
			// Prevents Gas Passer clouds from coating the thrower.
			PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_GasManager_Touch);
		}
	}
}

static void SDKHookCB_EndSpoofFrame_Think(int entity)
{
	Spoof_EndFrame();
}

static void SDKHookCB_EndSpoofFrame_Touch(int entity, int other)
{
	Spoof_EndFrame();
}

static void SDKHookCB_EndSpoofFrame_OnTakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	Spoof_EndFrame();
}

static void SDKHookCB_EndSpoofFrame_TraceAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	Spoof_EndFrame();
}

// CTFPlayer::PreThink -> CTFPlayerShared::ConditionThink
static void SDKHookCB_Client_PreThink(int client)
{
	Spoof_BeginFrame(client);

	// Disable radius buffs like the Buff Banner.
	if (!AreTeammatesEnemies())
		return;

	if (!IsPulsingRadiusBuff(client))
		return;

	Spoof_ChangeToSpectator(client);
}

// CTFWeaponBase::ItemPostFrame
static void SDKHookCB_Client_PostThink(int client)
{
	Spoof_BeginFrame(client);

	// CTFPlayer::DoTauntAttack
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		// Allows taunt kills to work on both teams.
		Spoof_ChangeToSpectator(client);
		return;
	}

	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
		return;

	int weaponID = SDKCall_CTFWeaponBase_GetWeaponID(activeWeapon);
	bool teammatesAreEnemies = AreTeammatesEnemies();

	// For functions that use GetEnemyTeam(), move everyone else to the enemy team.
	if (IsWeaponIDInList(weaponID, g_enemyItemIDs, sizeof(g_enemyItemIDs)) || (teammatesAreEnemies && IsWeaponIDInList(weaponID, g_teammateEnemyItemIDs, sizeof(g_teammateEnemyItemIDs))))
	{
		Spoof_SetTeamForClients(GetEnemyTeam(TF2_GetClientTeam(client)), client);

		return;
	}

	if (GameRules_GetRoundState() != RoundState_TeamWin || GetClientTeam(client) == GameRules_GetProp("m_iWinningTeam"))
	{
		// For functions that do simple GetTeamNumber() checks, move ourselves to the spectator team.
		if (IsWeaponIDInList(weaponID, g_spectatorItemIDs, sizeof(g_spectatorItemIDs)) || (teammatesAreEnemies && IsWeaponIDInList(weaponID, g_teammateSpectatorItemIDs, sizeof(g_teammateSpectatorItemIDs))))
		{
			Spoof_ChangeToSpectator(client);
		}
	}
}

static Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (victim == attacker)
		return Plugin_Continue;

	// CTFGameRules::FPlayerCanTakeDamage only enforces the truce for RED against BLU, so the spoofs below would defeat it.
	if (GameRules_GetProp("m_bTruceActive"))
		return Plugin_Continue;

	// Falling reads the lander's own team, so they keep it and everyone else moves instead.
	if (damagetype & DMG_FALL)
	{
		TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(victim));
		
		if (AreTeammatesEnemies())
		{
			Spoof_SetTeamForClients(enemyTeam, victim);
		}
		else
		{
			// Stomping is damage, but the shockwave around it is not, so only the one being landed on moves.
			int ground = GetEntPropEnt(victim, Prop_Data, "m_hGroundEntity");
			if (IsEntityClient(ground))
			{
				Spoof_SetTeam(ground, enemyTeam);
			}
		}
		
		return Plugin_Continue;
	}

	// Without an attacking player there is nobody to move out of the way, so move the victim instead.
	// Mostly for boots_falling_stomp.
	Spoof_ChangeToSpectator(IsEntityClient(attacker) ? attacker : victim);
	
	return Plugin_Continue;
}

static Action SDKHookCB_Client_SetTransmit(int entity, int client)
{
	// Teammates can always see each other's cloaked Spies unless teammates are enemies.
	if (!AreTeammatesEnemies())
		return Plugin_Continue;
	
	// Don't transmit invisible Spies to living players.
	if (entity == client || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static Action SDKHookCB_ObjectDispenser_StartTouch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Spoof_ChangeToSpectator(other);
	}

	return Plugin_Continue;
}

static void SDKHookCB_Object_SpawnPost(int entity)
{
	SetObjectSolidToPlayers(entity, AreTeammatesEnemies());
}

static void SpoofObjectAttacker(int victim, int attacker, bool routesToSapper)
{
	if (AreTeammatesEnemies() || !IsEntityClient(attacker))
		return;

	if (ShouldObjectKeepTeams(victim, attacker, routesToSapper))
		return;

	// Another hook already moved this building along, moving the attacker too would pair them up again.
	if (Spoof_IsSpoofed(victim))
		return;

	Spoof_ChangeToSpectator(attacker);
}

static bool IsTruceBlockingObjectDamage(int attacker)
{
	// CBaseObject::OnTakeDamage only blocks RED and BLU attackers during a truce, and ours may be spoofed.
	return IsEntityClient(attacker) && GameRules_GetProp("m_bTruceActive") != 0;
}

static Action SDKHookCB_Object_TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	Spoof_BeginFrame(victim);

	if (IsTruceBlockingObjectDamage(attacker))
		return Plugin_Handled;

	SpoofObjectAttacker(victim, attacker, true);

	return Plugin_Continue;
}

static Action SDKHookCB_Object_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (IsTruceBlockingObjectDamage(attacker))
		return Plugin_Handled;

	SpoofObjectAttacker(victim, attacker, false);

	return Plugin_Continue;
}

static Action SDKHookCB_Projectile_Touch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	if (other == 0)
		return Plugin_Continue;

	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other && !ShouldProjectileKeepTeams(entity, other, owner))
	{
		Spoof_ChangeToSpectator(owner);
		Spoof_ChangeToSpectator(entity);
	}

	return Plugin_Continue;
}

static Action SDKHookCB_ProjectilePipeRemote_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (attacker == -1)
		return Plugin_Continue;

	// We might already be in spectate from another hook, so do not allow damaging our own pipebombs.
	if (FindParentOwnerEntity(victim) == attacker)
		return Plugin_Handled;

	Spoof_ChangeToSpectator(attacker);
	
	return Plugin_Continue;
}

static Action SDKHookCB_FlameManager_Touch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other && !ShouldObjectKeepTeams(other, owner, true))
	{
		Spoof_ChangeToSpectator(owner);
	}

	return Plugin_Continue;
}

static Action SDKHookCB_Orb_Touch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != entity)
	{
		Spoof_ChangeToSpectator(owner);
	}

	return Plugin_Continue;
}

static Action SDKHookCB_PumpkinBomb_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (IsEntityClient(attacker))
	{
		// CTFPumpkinBomb::OnTakeDamage only detonates for an attacker on the pumpkin's own team.
		Spoof_ChangeToOriginalTeam(attacker);
	}

	return Plugin_Continue;
}

static Action SDKHookCB_GasManager_Touch(int entity, int other)
{
	if (FindParentOwnerEntity(entity) == other)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
