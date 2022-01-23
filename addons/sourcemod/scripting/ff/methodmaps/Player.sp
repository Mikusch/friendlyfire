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
	
	public void SetTeam(TFTeam team)
	{
		int index = g_PlayerTeamCount[this._client]++;
		g_PlayerTeam[this._client][index] = TF2_GetClientTeam(this._client);
		SetEntProp(this._client, Prop_Send, "m_iTeamNum", team);
	}
	
	public void ResetTeam()
	{
		int index = --g_PlayerTeamCount[this._client];
		SetEntProp(this._client, Prop_Send, "m_iTeamNum", g_PlayerTeam[this._client][index]);
	}
}
