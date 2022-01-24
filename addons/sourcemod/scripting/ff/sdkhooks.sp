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

static char g_RocketBasedProjectiles[][] = 
{
	"tf_projectile_rocket", 
	"tf_projectile_flare", 
	"tf_projectile_energy_ball", 
};

void SDKHooks_OnClientConnected(int client)
{
	SDKHook(client, SDKHook_PostThink, SDKHookCB_PlayerPostThink);
	SDKHook(client, SDKHook_PostThinkPost, SDKHookCB_PlayerPostThinkPost);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		// CTFBaseRocket::RocketTouch removes the entity if it hits an enemy, never calling TouchPost.
		// Since rocket-based projectiles already work without this fix, exclude them.
		for (int i = 0; i < sizeof(g_RocketBasedProjectiles); i++)
		{
			if (strcmp(classname, g_RocketBasedProjectiles[i]) == 0)
				return;
		}
		
		SDKHook(entity, SDKHook_Touch, SDKHookCB_ProjectileTouch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_ProjectileTouchPost);
	}
	else if (strcmp(classname, "tf_flame_manager") == 0)
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManagerTouch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_FlameManagerTouchPost);
	}
}

public Action SDKHookCB_ProjectileTouch(int entity, int other)
{
	int owner = FindOwnerEntity(entity);
	if (IsEntityClient(owner) && owner != other)
	{
		Player(owner).SetTeam(TFTeam_Spectator);
		Entity(entity).SetTeam(TFTeam_Spectator);
	}
}

public void SDKHookCB_ProjectileTouchPost(int entity, int other)
{
	int owner = FindOwnerEntity(entity);
	if (IsEntityClient(owner) && owner != other)
	{
		Player(owner).ResetTeam();
		Entity(entity).ResetTeam();
	}
}

public Action SDKHookCB_FlameManagerTouch(int entity, int other)
{
	// Allows Flame Throwers to work on both teams
	int owner = FindOwnerEntity(entity);
	if (IsEntityClient(owner))
		Player(owner).SetTeam(TFTeam_Spectator);
}

public void SDKHookCB_FlameManagerTouchPost(int entity, int other)
{
	int owner = FindOwnerEntity(entity);
	if (IsEntityClient(owner))
		Player(owner).ResetTeam();
}
