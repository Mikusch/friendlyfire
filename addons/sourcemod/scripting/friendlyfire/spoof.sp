#pragma newdecls required
#pragma semicolon 1

enum struct SpoofedTeam
{
	int ref;
	TFTeam team;
}

enum struct SpoofFrame
{
	int start;
	int owner;
	bool orphaned;
}

static ArrayList g_spoofedTeams;
static ArrayList g_spoofFrames;

void Spoof_Init()
{
	g_spoofedTeams = new ArrayList(sizeof(SpoofedTeam));
	g_spoofFrames = new ArrayList(sizeof(SpoofFrame));
}

void Spoof_BeginFrame(int owner = INVALID_ENT_REFERENCE)
{
	SpoofFrame frame;
	frame.start = g_spoofedTeams.Length;
	frame.owner = GetEntityRefSafe(owner);
	frame.orphaned = false;

	g_spoofFrames.PushArray(frame);
}

void Spoof_EndFrame()
{
	if (!g_spoofFrames.Length)
	{
		LogError("Tried to close a spoof frame while none were open");
		return;
	}

	PopFrame();
	PopOrphanedFrames();
}

void Spoof_OnEntityDestroyed(int entity)
{
	int ref = GetEntityRefSafe(entity);
	if (ref == INVALID_ENT_REFERENCE)
		return;

	for (int i = g_spoofFrames.Length - 1; i >= 0; i--)
	{
		if (g_spoofFrames.Get(i, SpoofFrame::owner) == ref)
		{
			g_spoofFrames.Set(i, true, SpoofFrame::orphaned);
		}
	}

	PopOrphanedFrames();

	// Whatever is left sits in frames somebody else still has to close, and there is nothing to put it back on.
	for (int i = g_spoofedTeams.Length - 1; i >= 0; i--)
	{
		if (g_spoofedTeams.Get(i, SpoofedTeam::ref) == ref)
		{
			g_spoofedTeams.Set(i, INVALID_ENT_REFERENCE, SpoofedTeam::ref);
		}
	}
}

void Spoof_Clear()
{
	RestoreTeams(0);

	g_spoofFrames.Clear();
}

void Spoof_SetTeam(int entity, TFTeam team)
{
	int ref = GetEntityRefSafe(entity);
	if (ref == INVALID_ENT_REFERENCE)
		return;

	SpoofedTeam spoof;
	spoof.ref = ref;
	spoof.team = view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));

	g_spoofedTeams.PushArray(spoof);

	SetEntProp(entity, Prop_Data, "m_iTeamNum", team);
}

void Spoof_ChangeToSpectator(int entity)
{
	Spoof_SetTeam(entity, TFTeam_Spectator);
}

void Spoof_ChangeToOriginalTeam(int entity)
{
	Spoof_SetTeam(entity, Spoof_GetOriginalTeam(entity));
}

TFTeam Spoof_GetOriginalTeam(int entity)
{
	int ref = GetEntityRefSafe(entity);
	if (ref == INVALID_ENT_REFERENCE)
		return TFTeam_Unassigned;

	// The oldest entry holds the team the entity had before the first spoof.
	for (int i = 0; i < g_spoofedTeams.Length; i++)
	{
		if (g_spoofedTeams.Get(i, SpoofedTeam::ref) == ref)
			return g_spoofedTeams.Get(i, SpoofedTeam::team);
	}

	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}

bool Spoof_IsSpoofed(int entity)
{
	int ref = GetEntityRefSafe(entity);
	if (ref == INVALID_ENT_REFERENCE)
		return false;

	return g_spoofedTeams.FindValue(ref, SpoofedTeam::ref) != -1;
}

static void PopFrame()
{
	int top = g_spoofFrames.Length - 1;
	int start = g_spoofFrames.Get(top, SpoofFrame::start);

	g_spoofFrames.Erase(top);

	RestoreTeams(start);
}

static void PopOrphanedFrames()
{
	while (g_spoofFrames.Length && g_spoofFrames.Get(g_spoofFrames.Length - 1, SpoofFrame::orphaned) != 0)
	{
		PopFrame();
	}
}

static void RestoreTeams(int start)
{
	for (int i = g_spoofedTeams.Length - 1; i >= start; i--)
	{
		SpoofedTeam spoof;
		g_spoofedTeams.GetArray(i, spoof);
		g_spoofedTeams.Erase(i);

		int entity = EntRefToEntIndex(spoof.ref);
		if (IsValidEntity(entity))
		{
			SetEntProp(entity, Prop_Data, "m_iTeamNum", spoof.team);
		}
	}
}

static int GetEntityRefSafe(int entity)
{
	if (!IsValidEntity(entity))
		return INVALID_ENT_REFERENCE;

	return IsEntNetworkable(entity) ? EntIndexToEntRef(entity) : entity;
}
