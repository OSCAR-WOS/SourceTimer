Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType) {
	fDamage *= 0;
	return Plugin_Handled;
}

Action Hook_StartTouch(int iCaller, int iActivator) {
	if (!Misc_CheckPlayer(iActivator, PLAYER_ALIVE)) return;
	char[] cEntityName = new char[512];
	char[] cEntityIndex = new char[16];
	int iIndex;

	GetEntPropString(iCaller, Prop_Send, "m_iName", cEntityName, 512);
	SplitString(cEntityName, ":", cEntityIndex, 16);
	iIndex = StringToInt(cEntityIndex);

	if (iIndex == -1) return;

	Zone zZone;
	g_Global.Zones.GetArray(iIndex, zZone);

	switch (zZone.Type) {
		case ZONE_START: {
			gP_Player[iActivator].Record.StartTime = -1.0;
			gP_Player[iActivator].Record.Group = zZone.Group;
			ConVar cnBunny = FindConVar("sv_autobunnyhopping");
			SendConVarValue(iActivator, cnBunny, "0");
		} case ZONE_END: {
			if (gP_Player[iActivator].Record.StartTime <= 0.0) return;
			if (gP_Player[iActivator].Record.Group != zZone.Group) return;

			gP_Player[iActivator].Record.EndTime = GetGameTime() - gP_Player[iActivator].Record.StartTime;
			gP_Player[iActivator].Record.StartTime = 0.0;

			float fServerTime, fPersonalTime;
			if (zZone.RecordIndex[0] != -1) {
				Record rServerBest;
				g_Global.Records.GetArray(zZone.RecordIndex[0], rServerBest);
				fServerTime = rServerBest.EndTime;
			}

			if (zZone.RecordIndex[iActivator] != -1) {
				Record rPersonalBest;
				gP_Player[iActivator].Records.GetArray(zZone.RecordIndex[iActivator], rPersonalBest);
				fPersonalTime = rPersonalBest.EndTime;
			}

			Misc_EndMessage(iActivator, gP_Player[iActivator].Record.Style, gP_Player[iActivator].Record.Group, gP_Player[iActivator].Record.EndTime);
			Zone_Message(iActivator, gP_Player[iActivator].Record.EndTime, fServerTime, fPersonalTime);
			Sql_AddRecord(iActivator, gP_Player[iActivator].Record.Style, gP_Player[iActivator].Record.Group, gP_Player[iActivator].Record.EndTime, view_as<Checkpoints>(gP_Player[iActivator].Checkpoints.Clone()));
			Replay_Save(iActivator, gP_Player[iActivator].Record.Style, gP_Player[iActivator].Record.Group, gP_Player[iActivator].Record.EndTime, gP_Player[iActivator].Replay.Frames.Clone());
			Misc_Record(iActivator, iIndex);
		} case ZONE_CHECKPOINT: {
			if (gP_Player[iActivator].Record.StartTime <= 0.0) return;
			if (gP_Player[iActivator].Record.Group != zZone.Group) return;

			Checkpoints cCheckpoints = gP_Player[iActivator].Checkpoints.FindByZoneId(zZone.Id);
			if (cCheckpoints.Length == 1) return;
			delete cCheckpoints;

			Checkpoint cCheckpoint;
			cCheckpoint.Time = GetGameTime() - gP_Player[iActivator].Record.StartTime;
			cCheckpoint.ZoneId = zZone.Id;

			cCheckpoint.GlobalCheckpointIndex = gP_Player[iActivator].GlobalCheckpointsIndex;
			cCheckpoint.PlayerCheckpointIndex = gP_Player[iActivator].PlayerCheckpointsIndex;

			float fServerTime, fPersonalTime;
			if (zZone.RecordIndex[0] != -1) {
				Checkpoint cServerBest; g_Global.Checkpoints.GetArray(zZone.RecordIndex[0], cServerBest);
				fServerTime = cServerBest.Time;
			}

			if (zZone.RecordIndex[iActivator] != -1) {
				Checkpoint cPersonalBest; gP_Player[iActivator].RecordCheckpoints.GetArray(zZone.RecordIndex[iActivator], cPersonalBest);
				fPersonalTime = cPersonalBest.Time;
			}

			Zone_Message(iActivator, cCheckpoint.Time, fServerTime, fPersonalTime);
			gP_Player[iActivator].Checkpoints.PushArray(cCheckpoint);
			gP_Player[iActivator].PreviousTime = GetGameTime();
		}
	}

	gP_Player[iActivator].CurrentZone = iIndex;
	gP_Player[iActivator].PreviousZone = -1;
}

Action Hook_EndTouch(int iCaller, int iActivator) {
	if (!Misc_CheckPlayer(iActivator, PLAYER_ALIVE)) return;
	char[] cEntityName = new char[512];
	char[] cEntityIndex = new char[16];
	int iIndex;

	GetEntPropString(iCaller, Prop_Send, "m_iName", cEntityName, 512);
	SplitString(cEntityName, ":", cEntityIndex, 16);
	iIndex = StringToInt(cEntityIndex);

	if (iIndex == -1) return;

	Zone zZone;
	g_Global.Zones.GetArray(iIndex, zZone);

	switch (zZone.Type) {
		case ZONE_CHECKPOINT: { }
		case ZONE_END: { }
		case ZONE_START: {
			if (gP_Player[iActivator].Record.StartTime == 0.0) Misc_StartTimer(iActivator);
			if (gP_Player[iActivator].Record.StartTime > 0.0) {
				ConVar cnBunny = FindConVar("sv_autobunnyhopping");
				SendConVarValue(iActivator, cnBunny, "1");
			}
			
			gP_Player[iActivator].Record.Group = zZone.Group;
			gP_Player[iActivator].Record.Style = gP_Player[iActivator].Style;
			gP_Player[iActivator].Checkpoints.Clear();
		}	
	}

	if (gP_Player[iActivator].RecentlyAbused) return;
	gP_Player[iActivator].CurrentZone = -1;
	gP_Player[iActivator].PreviousZone = iIndex;
}

void Hook_ConVarChange(ConVar cvConVar, const char[] cOldValue, const char[] cNewValue) {
	char[] cConVar = new char[64];
	char[] cConVarValue = new char[64];
	cvConVar.GetName(cConVar, 64);

	if (!g_Global.Convars.GetString(cConVar, cConVarValue, 64)) return;
	if (StrEqual(cConVarValue, cNewValue)) return;
	cvConVar.SetString(cConVarValue);
}

Action Hook_JoinTeam(int iClient, char[] cCommand, int iArgc) {
	if (!Misc_CheckPlayer(iClient, PLAYER_VALID)) return;
	char[] cArg1 = new char[8];
	GetCmdArg(1, cArg1, 8);

	int iArg1 = StringToInt(cArg1);
	ChangeClientTeam(iClient, iArg1);
	if (iArg1 != 1) CS_RespawnPlayer(iClient);
}

Action Hook_TextMsg(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init) {
	char[] cBuffer = new char[512];
	msg.ReadString("params", cBuffer, 512, 0);
	for (int i = 0; i < sizeof(C_BlockMessages); i++) {
		if (StrEqual(cBuffer, C_BlockMessages[i], false)) return Plugin_Handled;
	}

	return Plugin_Continue;
}