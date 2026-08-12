#pragma newdecls required
#pragma semicolon 1

TFTeam GetEnemyTeam(TFTeam team)
{
	switch (team)
	{
		case TFTeam_Red: { return TFTeam_Blue; }
		case TFTeam_Blue: { return TFTeam_Red; }
		default: { return team; }
	}
}

TFTeam GetSentryEnemyTeam(TFTeam team)
{
	// CObjectSentrygun::FindTarget maps every team that is not BLU to RED, unlike GetEnemyTeam.
	return team == TFTeam_Blue ? TFTeam_Red : TFTeam_Blue;
}

bool IsEntityClient(int entity)
{
	return 0 < entity <= MaxClients;
}

// Ownership can be a chain, e.g. `CTFFlameManager` -> `CTFFlameThrower` -> `CTFPlayer`.
int FindParentOwnerEntity(int entity)
{
	int parent = -1;

	if (HasEntProp(entity, Prop_Send, "m_hThrower"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hLauncher"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hBuilder"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hOwner"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}

	if (parent != -1 && parent != entity)
	{
		return FindParentOwnerEntity(parent);
	}
	else
	{
		return entity;
	}
}

bool IsEntityBaseObject(int entity)
{
	return HasEntProp(entity, Prop_Data, "CBaseObjectUpgradeThink");
}

bool IsEntityBaseCombatWeapon(int entity)
{
	return HasEntProp(entity, Prop_Data, "CBaseCombatWeaponDefaultTouch");
}

bool IsEntityBaseMelee(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

bool IsEntityBaseGrenadeProjectile(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGrenadeProjDetonateThink");
}

static int GetObjectBuilder(int obj)
{
	if (!HasEntProp(obj, Prop_Send, "m_hBuilder"))
		return -1;

	return GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
}

bool IsObjectFriendly(int obj, int other)
{
	if (!IsValidEntity(obj) || !IsValidEntity(other))
		return false;

	if (obj == other)
		return true;

	// The original team has to be used here, because callers of this function commonly spoof team numbers.
	TFTeam objTeam = Spoof_GetOriginalTeam(obj);
	TFTeam otherTeam = Spoof_GetOriginalTeam(other);

	if (!AreTeammatesEnemies() && objTeam == otherTeam)
		return true;

	int builder = GetObjectBuilder(obj);

	// Map-placed buildings have no builder, see CBaseObject::InitializeMapPlacedObject.
	if (builder == -1 && objTeam == otherTeam)
		return true;

	if (IsEntityClient(other))
	{
		// Buildings treat a Spy disguised as their own team as one of their own.
		if (objTeam != otherTeam && TF2_IsPlayerInCondition(other, TFCond_Disguised) && view_as<TFTeam>(GetEntProp(other, Prop_Send, "m_nDisguiseTeam")) == objTeam)
			return true;

		if (builder == other)
			return true;
	}
	else if (HasEntProp(other, Prop_Send, "m_hBuilder"))
	{
		if (builder != -1 && builder == GetEntPropEnt(other, Prop_Send, "m_hBuilder"))
			return true;
	}

	return false;
}

bool IsObjectSapped(int obj)
{
	return HasEntProp(obj, Prop_Send, "m_bHasSapper") && GetEntProp(obj, Prop_Send, "m_bHasSapper");
}

void SetObjectSolidToPlayers(int entity, bool solid)
{
	SetVariantInt(solid ? SOLID_TO_PLAYER_YES : SOLID_TO_PLAYER_USE_DEFAULT);
	AcceptEntityInput(entity, "SetSolidToPlayer");
}

void SetAllObjectsSolidToPlayers(bool solid)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_*")) != -1)
	{
		SetObjectSolidToPlayers(entity, solid);
	}
}

bool IsJarProjectile(int projectile)
{
	char classname[64];
	if (!GetEntityClassname(projectile, classname, sizeof(classname)))
		return false;

	// CTFProjectile_Cleaver and CTFProjectile_SpellBats inherit TF_PROJECTILE_JAR from CTFProjectile_Jar.
	return !strncmp(classname, "tf_projectile_jar", 17);
}

bool ShouldObjectKeepTeams(int obj, int attacker, bool routesToSapper)
{
	if (!IsEntityBaseObject(obj))
		return false;

	if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == attacker)
		return true;

	return routesToSapper && !AreTeammatesEnemies() && IsObjectSapped(obj);
}

bool IsHelpfulProjectile(int projectile)
{
	switch (SDKCall_CBaseProjectile_GetProjectileType(projectile))
	{
		case TF_PROJECTILE_HEALING_BOLT, TF_PROJECTILE_FESTIVE_HEALING_BOLT, TF_PROJECTILE_BUILDING_REPAIR_BOLT:
		{
			return true;
		}
	}

	return false;
}

bool ShouldProjectileKeepTeams(int projectile, int other, int owner)
{
	if (!IsEntityBaseObject(other))
		return false;

	if (ShouldObjectKeepTeams(other, owner, false))
		return true;

	// Rescue Ranger bolts repair friendly buildings instead of damaging them.
	return IsHelpfulProjectile(projectile) && IsObjectFriendly(other, owner);
}

float GetPercentInvisible(int client)
{
	int offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	return GetEntDataFloat(client, offset);
}

bool IsPulsingRadiusBuff(int client)
{
	// CTFPlayerShared::PulseRageBuff
	if (GetEntProp(client, Prop_Send, "m_bRageDraining"))
		return true;

	// CTFPlayerShared::PulseKingRuneBuff
	if (TF2_IsPlayerInCondition(client, TFCond_KingRune))
		return true;

	// CTFPlayerShared::PulseMedicRadiusHeal
	return TF2_IsPlayerInCondition(client, TFCond_Taunting) || TF2_IsPlayerInCondition(client, TFCond_RadiusHealOnDamage);
}

bool IsThinkPending(int entity, const char[] context)
{
	// The context currently being dispatched reads TICK_NEVER_THINK, see CBaseEntity::PhysicsRunSpecificThink.
	return SDKCall_CBaseEntity_GetNextThink(entity, context) != TICK_NEVER_THINK;
}

bool IsWeaponIDInList(int weaponID, const int[] list, int size)
{
	for (int i = 0; i < size; i++)
	{
		if (weaponID == list[i])
			return true;
	}

	return false;
}

int GameConfGetOffsetOrElseThrow(GameData gamedata, const char[] key)
{
	int offset = gamedata.GetOffset(key);
	if (offset == -1)
		SetFailState("Failed to get offset: %s", key);

	return offset;
}
