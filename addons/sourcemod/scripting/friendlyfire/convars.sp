/**
 * Copyright (C) 2022  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma newdecls required
#pragma semicolon 1

#define COMMAND_MAX_LENGTH	512

enum struct ConVarData
{
	char name[COMMAND_MAX_LENGTH];
	char value[COMMAND_MAX_LENGTH];
	char initialValue[COMMAND_MAX_LENGTH];
	ConVar relatedConVar;
}

static ArrayList g_conVars;

void ConVars_Initialize()
{
	g_conVars = new ArrayList(sizeof(ConVarData));
	
	CreateConVar("sm_friendlyfire_version", PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_friendlyfire_medic_allow_healing = CreateConVar("sm_friendlyfire_medic_allow_healing", "0", "Whether Medics are allowed to heal teammates during friendly fire.", _, true, 0.0, true, 1.0);
	sm_friendlyfire_avoidteammates = CreateConVar("sm_friendlyfire_avoidteammates", "0", "Controls how teammates interact when colliding.\n  0: Teammates block each other\n  1: Teammates pass through each other, but push each other away", _, true, 0.0, true, 1.0);
	
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_friendlyfire.AddChangeHook(ConVarChanged_FriendlyFire);
	
	ConVars_AddConVar("tf_avoidteammates", _, sm_friendlyfire_avoidteammates);
	ConVars_AddConVar("tf_spawn_glows_duration", "0");
}

void ConVars_Toggle(bool enable)
{
	if (enable)
	{
		mp_friendlyfire.AddChangeHook(ConVarChanged_FriendlyFire);
	}
	else
	{
		mp_friendlyfire.RemoveChangeHook(ConVarChanged_FriendlyFire);
	}
	
	for (int i = 0; i < g_conVars.Length; i++)
	{
		ConVarData data;
		if (g_conVars.GetArray(i, data))
		{
			if (enable)
			{
				ConVars_Enable(data.name);
			}
			else
			{
				ConVars_Disable(data.name);
			}
		}
	}
}

static void ConVars_AddConVar(const char[] name, const char[] value = "", ConVar relatedConVar = null)
{
	ConVar convar = FindConVar(name);
	if (!convar)
	{
		LogError("Failed to find convar with name %s", name);
		return;
	}
	
	if (!value[0] && !relatedConVar)
	{
		LogError("Invalid data for convar with name %s", name);
		return;
	}
	
	ConVarData data;
	strcopy(data.name, sizeof(data.name), name);
	strcopy(data.value, sizeof(data.value), value);
	data.relatedConVar = relatedConVar;
	
	g_conVars.PushArray(data);
}

static void ConVars_Enable(const char[] name)
{
	int index = g_conVars.FindString(name);
	if (index == -1)
		return;
	
	ConVarData data;
	if (g_conVars.GetArray(index, data))
	{
		ConVar convar = FindConVar(data.name);
		if (!convar)
			return;
		
		// Store the current value so we can reset the convar on disable
		convar.GetString(data.initialValue, sizeof(data.initialValue));
		
		// Copy the value from the setting convar if it isn't set
		if (!data.value[0] && data.relatedConVar)
		{
			char value[COMMAND_MAX_LENGTH];
			data.relatedConVar.GetString(value, sizeof(value));
			strcopy(data.value, sizeof(data.value), value);
			
			data.relatedConVar.AddChangeHook(OnRelatedConVarChanged);
		}
		
		g_conVars.SetArray(index, data);
		
		// Update the current value
		convar.SetString(data.value);
		convar.AddChangeHook(OnConVarChanged);
	}
}

static void ConVars_Disable(const char[] name)
{
	int index = g_conVars.FindString(name);
	if (index == -1)
		return;
	
	ConVarData data;
	if (g_conVars.GetArray(index, data))
	{
		ConVar convar = FindConVar(data.name);
		if (!convar)
			return;
		
		// Restore the old convar value
		convar.RemoveChangeHook(OnConVarChanged);
		convar.SetString(data.initialValue);
		
		if (data.relatedConVar)
			data.relatedConVar.RemoveChangeHook(OnRelatedConVarChanged);
	}
}

static void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[COMMAND_MAX_LENGTH];
	convar.GetName(name, sizeof(name));
	
	int index = g_conVars.FindString(name);
	if (index == -1)
		return;
	
	ConVarData data;
	if (g_conVars.GetArray(index, data))
	{
		if (!StrEqual(newValue, data.value))
		{
			// Update value to reset
			strcopy(data.initialValue, sizeof(data.initialValue), newValue);
			g_conVars.SetArray(index, data);
			
			// Restore our desired value
			convar.SetString(oldValue);
		}
	}
}

static void OnRelatedConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int index = g_conVars.FindValue(convar, ConVarData::relatedConVar);
	if (index == -1)
		return;
	
	ConVarData data;
	if (g_conVars.GetArray(index, data))
	{
		ConVar actualConVar = FindConVar(data.name);
		if (!actualConVar)
			return;
		
		actualConVar.RemoveChangeHook(OnConVarChanged);
		actualConVar.SetString(newValue);
		actualConVar.AddChangeHook(OnConVarChanged);
	}
}

static void ConVarChanged_FriendlyFire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_isEnabled != convar.BoolValue)
	{
		TogglePlugin(convar.BoolValue);
	}
}
