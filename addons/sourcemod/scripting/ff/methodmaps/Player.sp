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

#pragma newdecls required
#pragma semicolon 1

static int g_PlayerTeamCount[MAXPLAYERS + 1];
static TFTeam g_PlayerTeam[MAXPLAYERS + 1][8];

methodmap Player
{
	public Player(int client)
	{
		return view_as<Player>(client);
	}
	
	property int _client
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int m_iTeamCount
	{
		public get()
		{
			return g_PlayerTeamCount[this._client];
		}
		public set(int count)
		{
			g_PlayerTeamCount[this._client] = count;
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = this.m_iTeamCount++;
		g_PlayerTeam[this._client][index] = TF2_GetClientTeam(this._client);
		TF2_SetTeam(this._client, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	public void ResetTeam()
	{
		int index = --this.m_iTeamCount;
		TF2_SetTeam(this._client, g_PlayerTeam[this._client][index]);
	}
}
