/*
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

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "tf_projectile_pipe") == 0 || strcmp(classname, "tf_projectile_cleaver") == 0)
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_ProjectileTouch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_ProjectileTouchPost);
	}
}

public Action SDKHookCB_ProjectileTouch(int entity, int other)
{
	// Fixes grenades bouncing off teammates
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner != other)
	{
		Entity(entity).SetTeam(TFTeam_Spectator);
	}
}

public void SDKHookCB_ProjectileTouchPost(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner != other)
	{
		Entity(entity).ResetTeam();
	}
}
