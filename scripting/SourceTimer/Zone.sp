enum {
	ZONE_UNDEFINED = -1,
	ZONE_CHECKPOINT = 0,
	ZONE_START = 1,
	ZONE_END = 2
}

void Zone_Draw(float xPos[3], float yPos[3], int iColor, float fDisplay, bool bAll, int iClient = 0) {
	float fPoints[8][3];

	fPoints[0] = xPos;
	fPoints[7] = yPos;

	fPoints[1][0] = fPoints[0][0];
	fPoints[1][1] = fPoints[7][1];
	fPoints[1][2] = fPoints[0][2];

	fPoints[2][0] = fPoints[7][0];
	fPoints[2][1] = fPoints[0][1];
	fPoints[2][2] = fPoints[0][2];

	fPoints[3][0] = fPoints[7][0];
	fPoints[3][1] = fPoints[7][1];
	fPoints[3][2] = fPoints[0][2];

	fPoints[4][0] = fPoints[0][0];
	fPoints[4][1] = fPoints[0][1];
	fPoints[4][2] = fPoints[7][2];

	fPoints[5][0] = fPoints[0][0];
	fPoints[5][1] = fPoints[7][1];
	fPoints[5][2] = fPoints[7][2];

	fPoints[6][0] = fPoints[7][0];
	fPoints[6][1] = fPoints[0][1];
	fPoints[6][2] = fPoints[7][2];

	for (int i = 0; i < 4; i++) { Zone_DrawLine(fPoints[i], fPoints[i + 4], C_Colors[iColor], fDisplay, bAll, iClient); }
	for (int i = 0; i < 2; i++) { Zone_DrawLine(fPoints[0], fPoints[i + 1], C_Colors[iColor], fDisplay, bAll, iClient); }
	for (int i = 0; i < 2; i++) { Zone_DrawLine(fPoints[3], fPoints[i + 1], C_Colors[iColor], fDisplay, bAll, iClient); }
	for (int i = 0; i < 2; i++) { Zone_DrawLine(fPoints[4], fPoints[i + 5], C_Colors[iColor], fDisplay, bAll, iClient); }
	for (int i = 0; i < 2; i++) { Zone_DrawLine(fPoints[7], fPoints[i + 5], C_Colors[iColor], fDisplay, bAll, iClient); }
}

void Zone_DrawAdmin(int iClient, float xPos[3]) {
	float yPos[3];

	for (int i = 0; i < 3; i++) {
		for (int k = 0; k < 3; k++) yPos[k] = xPos[k];

		yPos[i] += 66.6;
		Zone_DrawLine(xPos, yPos, C_Colors[i], TIMER_INTERVAL, false, iClient);
	}
}

void Zone_RayTrace(int iClient, float fPos[3]) {
	float fEye[3], fAngle[3];
	GetClientEyePosition(iClient, fEye);
	GetClientEyeAngles(iClient, fAngle);

	TR_TraceRayFilter(fEye, fAngle, MASK_SOLID, RayType_Infinite, Filter_HitSelf, iClient);
	if (TR_DidHit()) TR_GetEndPosition(fPos);
}

void Zone_DrawSprite(float fPos[3], int iModel, float fSize, bool bAll, int iClient = 0) {
	if (iModel == 0) TE_SetupGlowSprite(fPos, g_Global.Models.BlueGlow, TIMER_INTERVAL, fSize, 249);
	else TE_SetupGlowSprite(fPos, g_Global.Models.RedGlow, TIMER_INTERVAL, fSize, 249);

	if (bAll) TE_SendToAll();
	else TE_SendToClient(iClient);
}

void Zone_DrawLine(float xPos[3], float yPos[3], int iColor[4], float fDisplay, bool bAll, int iClient = 0) {
	TE_SetupBeamPoints(xPos, yPos, g_Global.Models.Laser, g_Global.Models.Glow, 0, 30, fDisplay, 1.0, 1.0, 2, 1.0, iColor, 0);

	if (bAll) TE_SendToAll();
	else TE_SendToClient(iClient);
}

void Zone_NewZone(float xPos[3], float yPos[3], int iType, int iGroup) {
	Zone zZone;

	for (int i = 0; i <= MaxClients; i++) zZone.RecordIndex[i] = -1;

	zZone.SetX(xPos);
	zZone.SetY(yPos);
	zZone.Type = iType;
	zZone.Group = iGroup;
	zZone.Entity = CreateEntityByName("trigger_multiple");
	zZone.Id = g_Global.Zones.Length;

	if (zZone.Entity > 0 && IsValidEntity(zZone.Entity)) {
		char[] cBuffer = new char[512];
		SetEntityModel(zZone.Entity, "models/error.mdl");

		Format(cBuffer, 512, "%i: timer_zone", zZone.Id);
		DispatchKeyValue(zZone.Entity, "targetname", cBuffer);
		DispatchKeyValue(zZone.Entity, "spawnflags", "1088");
		DispatchKeyValue(zZone.Entity, "StartDisabled", "0");

		if (DispatchSpawn(zZone.Entity)) {
			float fMid[3], fVecMin[3], fVecMax[3];
			ActivateEntity(zZone.Entity);

			Misc_CalculateCentre(xPos, yPos, fMid);
			MakeVectorFromPoints(fMid, xPos, fVecMin);
			MakeVectorFromPoints(yPos, fMid, fVecMax);

			for (int i = 0; i < 3; i++) {
				if (fVecMin[i] > 0.0) fVecMin[i] *= -1;
				else if (fVecMax[i] < 0.0) fVecMax[i] *= -1;
			}

			SetEntPropVector(zZone.Entity, Prop_Send, "m_vecMins", fVecMin);
			SetEntPropVector(zZone.Entity, Prop_Send, "m_vecMaxs", fVecMax);

			SetEntProp(zZone.Entity, Prop_Send, "m_nSolidType", 2);
			TeleportEntity(zZone.Entity, fMid, NULL_VECTOR, NULL_VECTOR);

			SDKHook(zZone.Entity, SDKHook_StartTouch, Entity_StartTouch);
			SDKHook(zZone.Entity, SDKHook_EndTouch, Entity_EndTouch);
		}
	}

	g_Global.Zones.PushArray(zZone);
}

public Action Entity_StartTouch(int iCaller, int iActivator) {
	if (!Misc_CheckPlayer(iActivator, PLAYER_INGAME)) { return; }
	char[] cEntityName = new char[512];
	char[] cEntityIndex = new char[16];
	int iIndex;

	GetEntPropString(iCaller, Prop_Send, "m_iName", cEntityName, 512);
	SplitString(cEntityName, ":", cEntityIndex, 16);
	iIndex = g_Global.Zones.FindByZoneId(StringToInt(cEntityIndex));

	if (iIndex == -1) return;

	Zone zZone;
	g_Global.Zones.GetArray(iIndex, zZone);

	switch (zZone.Type) {
		case ZONE_START: {
			gP_Player[iActivator].Record.StartTime = -1.0;
			ConVar cnBunny = FindConVar("sv_autobunnyhopping");
			SendConVarValue(iActivator, cnBunny, "0");
		}
		case ZONE_END: {
			if (gP_Player[iActivator].Record.StartTime == 0.0) return;
			if (gP_Player[iActivator].Record.Group != zZone.Group) return;

			gP_Player[iActivator].Record.EndTime = GetGameTime() - gP_Player[iActivator].Record.StartTime;
			gP_Player[iActivator].Record.StartTime = 0.0;
			gP_Player[iActivator].Record.Id = g_Global.Records.Length + 1;
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

			Zone_Message(iActivator, gP_Player[iActivator].Record.EndTime, fServerTime, fPersonalTime, ZONE_END);
			Checkpoints cCheckpoints = view_as<Checkpoints>(gP_Player[iActivator].Checkpoints.Clone());

			for (int i = 0; i < cCheckpoints.Length; i++) {
				Checkpoint cCheckpoint;
				cCheckpoints.GetArray(i, cCheckpoint);
				cCheckpoint.RecordId = gP_Player[iActivator].Record.Id;

				Zone zCheckpoint;
				g_Global.Zones.GetArray(g_Global.Zones.FindByZoneId(cCheckpoint.ZoneId), zCheckpoint);

				if (zCheckpoint.RecordIndex[0] == -1) zCheckpoint.RecordIndex[0] = g_Global.Checkpoints.Length;
				else {
					Checkpoint cCheckpointServerBest;
					g_Global.Checkpoints.GetArray(zCheckpoint.RecordIndex[0], cCheckpointServerBest);
					if (cCheckpoint.Time < cCheckpointServerBest.Time || cCheckpointServerBest.Time == 0) zCheckpoint.RecordIndex[0] = g_Global.Checkpoints.Length;
				}

				if (zCheckpoint.RecordIndex[iActivator] == -1) zCheckpoint.RecordIndex[iActivator] = gP_Player[iActivator].RecordCheckpoints.Length;
				else {
					Checkpoint cCheckpointPersonalBest;
					gP_Player[iActivator].RecordCheckpoints.GetArray(zCheckpoint.RecordIndex[iActivator], cCheckpointPersonalBest);
					if (cCheckpoint.Time < cCheckpointPersonalBest.Time || cCheckpointPersonalBest.Time == 0) zCheckpoint.RecordIndex[iActivator] = gP_Player[iActivator].RecordCheckpoints.Length;
				}

				g_Global.Zones.SetArray(zCheckpoint.Id, zCheckpoint);
				g_Global.Checkpoints.PushArray(cCheckpoint);
				gP_Player[iActivator].RecordCheckpoints.PushArray(cCheckpoint);
			}

			delete cCheckpoints;

			if (zZone.RecordIndex[0] == -1) zZone.RecordIndex[0] = g_Global.Records.Length;
			else {
				Record rServerBest;
				g_Global.Records.GetArray(zZone.RecordIndex[0], rServerBest);
				if (gP_Player[iActivator].Record.EndTime < rServerBest.EndTime) zZone.RecordIndex[0] = g_Global.Records.Length;
			}

			if (zZone.RecordIndex[iActivator] == -1) zZone.RecordIndex[iActivator] = gP_Player[iActivator].Records.Length;
			else {
				Record rPersonalBest;
				gP_Player[iActivator].Records.GetArray(zZone.RecordIndex[iActivator], rPersonalBest);
				if (gP_Player[iActivator].Record.EndTime < rPersonalBest.EndTime) zZone.RecordIndex[iActivator] = gP_Player[iActivator].Records.Length;
			}

			g_Global.Zones.SetArray(iIndex, zZone);
			g_Global.Records.PushArray(gP_Player[iActivator].Record);
			gP_Player[iActivator].Records.PushArray(gP_Player[iActivator].Record);
		} case ZONE_CHECKPOINT: {
			if (gP_Player[iActivator].Record.StartTime == 0.0) return;
			if (gP_Player[iActivator].Record.Group != zZone.Group) return;

			Checkpoints cCheckpoints = gP_Player[iActivator].Checkpoints.FindByZoneId(zZone.Id);
			if (cCheckpoints.Length == 1) return;
			delete cCheckpoints;

			Checkpoint cCheckpoint;
			cCheckpoint.Time = GetGameTime() - gP_Player[iActivator].Record.StartTime;
			cCheckpoint.ZoneId = zZone.Id;
			gP_Player[iActivator].Checkpoints.PushArray(cCheckpoint);

			float fServerTime, fPersonalTime;

			if (zZone.RecordIndex[0] != -1) {
				Checkpoint cServerBest;
				g_Global.Checkpoints.GetArray(zZone.RecordIndex[0], cServerBest);
				fServerTime = cServerBest.Time;
			}

			if (zZone.RecordIndex[iActivator] != -1) {
				Checkpoint cPersonalBest;
				gP_Player[iActivator].RecordCheckpoints.GetArray(zZone.RecordIndex[iActivator], cPersonalBest);
				fPersonalTime = cPersonalBest.Time;
			}

			Zone_Message(iActivator, cCheckpoint.Time, fServerTime, fPersonalTime, ZONE_CHECKPOINT);
		}
	}

	gP_Player[iActivator].CurrentZone = zZone.Type;
}

public Action Entity_EndTouch(int iCaller, int iActivator) {
	if (!Misc_CheckPlayer(iActivator, PLAYER_INGAME)) { return; }
	char[] cEntityName = new char[512];
	char[] cEntityIndex = new char[16];
	int iIndex;

	GetEntPropString(iCaller, Prop_Send, "m_iName", cEntityName, 512);
	SplitString(cEntityName, ":", cEntityIndex, 16);
	iIndex = g_Global.Zones.FindByZoneId(StringToInt(cEntityIndex));

	if (iIndex == -1) return;

	Zone zZone;
	g_Global.Zones.GetArray(iIndex, zZone);

	switch (zZone.Type) {
		case ZONE_CHECKPOINT: { }
		case ZONE_END: { }
		case ZONE_START: {
			if (gP_Player[iActivator].Record.StartTime == 0.0) gP_Player[iActivator].Record.StartTime = GetGameTime();
			if (gP_Player[iActivator].Record.StartTime > 0.0) {
				ConVar cnBunny = FindConVar("sv_autobunnyhopping");
				SendConVarValue(iActivator, cnBunny, "1");
			}
			

			gP_Player[iActivator].Record.Group = zZone.Group;
			gP_Player[iActivator].Record.Style = gP_Player[iActivator].Style;
			gP_Player[iActivator].Checkpoints.Clear();
		}	
	}

	gP_Player[iActivator].CurrentZone = ZONE_UNDEFINED;
}


void Zone_Message(int iClient, float fTime, float fServerTime, float fPersonalTime, int iZoneType) {
	char cBuffer[512], cTime[32], cServerTime[32], cPersonalTime[32], cServerDiff[32], cPersonalDiff[32];

	if (iZoneType == ZONE_END) Format(cBuffer, sizeof(cBuffer), "END:");
	else if (iZoneType == ZONE_CHECKPOINT) Format(cBuffer, sizeof(cBuffer), "CP:");

	Misc_FormatTime(fTime, cTime, sizeof(cTime));
	Misc_FormatTime(fServerTime, cServerTime, sizeof(cServerTime));
	Misc_FormatTime(fPersonalTime, cPersonalTime, sizeof(cPersonalTime));
	Misc_FormatTime(fServerTime - fTime, cServerDiff, sizeof(cServerDiff));
	Misc_FormatTime(fPersonalTime - fTime, cPersonalDiff, sizeof(cPersonalDiff));

	Misc_FormatTimePrefix(fServerTime, fServerTime - fTime, cServerDiff, sizeof(cServerDiff));
	Misc_FormatTimePrefix(fPersonalTime, fPersonalTime - fTime, cPersonalDiff, sizeof(cPersonalDiff));
	PrintToChat(iClient, "%s %s (PB: \x0B%s\x01) | %s (WB: \x0B%s\x01)", cBuffer, cPersonalDiff, cPersonalTime, cServerDiff, cServerTime);
}

void Zone_Timer() {
	for (int i = 0; i < TIMER_ZONES && g_Global.Render < g_Global.Zones.Length; i++) {
		Zone zZone;
		g_Global.Zones.GetArray(g_Global.Render, zZone);

		float xPos[3], yPos[3];
		zZone.GetX(xPos);
		zZone.GetY(yPos);

		int iColor = zZone.Type + 5;
		if (zZone.Group > 0) iColor += 3;

		Zone_Draw(xPos, yPos, iColor, TIMER_INTERVAL + (g_Global.Zones.Length / TIMER_ZONES) * TIMER_INTERVAL, true);
		g_Global.Render++;
	}

	if (g_Global.Render == g_Global.Zones.Length) g_Global.Render = 0;
}

Action Zone_Run(int iClient, int& iButtons) {
	if (gP_Player[iClient].CurrentZone == ZONE_START) {
		if (gP_Player[iClient].Record.StartTime == -1.0) if (GetEntityFlags(iClient) & FL_ONGROUND) gP_Player[iClient].Record.StartTime = 0.0;
		if (gP_Player[iClient].Record.StartTime == 0.0) if (!(GetEntityFlags(iClient) & FL_ONGROUND)) gP_Player[iClient].Record.StartTime = GetGameTime();
		if (GetEntityFlags(iClient) & FL_ONGROUND) gP_Player[iClient].Record.StartTime = 0.0;
	}

	if (gP_Player[iClient].CurrentZone != ZONE_START) {
		if (!(GetEntityMoveType(iClient) & MOVETYPE_LADDER) && !(GetEntityFlags(iClient) & FL_ONGROUND) && (GetEntProp(iClient, Prop_Data, "m_nWaterLevel") < 2)) {
			iButtons &= ~IN_JUMP;
		}
	}

	if (gP_Player[iClient].Record.StartTime > 0.0) {
		char[] cBuffer = new char[4096];
		char cTime[32];

		Misc_FormatTime(gP_Player[iClient].Record.StartTime - GetGameTime(), cTime, sizeof(cTime));
		FormatEx(cBuffer, 4096, "Time: %s", cTime);

		/*
		if (gP_Player[iClient].CurrentZoneIndex != -1) {
			if (gP_Player[iClient].HudTime - HUD_SHOWPREVIOUS > GetGameTime()) gP_Player[iClient].CurrentZoneIndex = -1;
			Zone zZone;
			g_Global.Zones.GetArray(gP_Player[iClient].CurrentZoneIndex, zZone);

			if (zZone.Type == ZONE_CHECKPOINT) {
				char cServerBestTime[32], cPersonalBestTime[32];
				float fServerBest, fPersonalBest;

				if (zZone.RecordIndex[0] != -1) {
					Checkpoint cServerBest;
					g_Global.Checkpoints.GetArray(zZone.RecordIndex[0], cServerBest);
					fServerBest = cServerBest.Time;
				}

				if (zZone.RecordIndex[iClient] != -1) {
					Checkpoint cPersonalBest;
					gP_Player[iClient].RecordCheckpoints.GetArray(zZone.RecordIndex[iClient], cPersonalBest);
					fPersonalBest = cPersonalBest.Time;
				}

				Misc_FormatTime(fServerBest, cServerBestTime, sizeof(cServerBestTime));
				Misc_FormatTime(fPersonalBest, cPersonalBestTime, sizeof(cPersonalBestTime));

				FormatEx(cBuffer, 4096, "%sSB: %s PB: %s", cBuffer, cServerBestTime, cPersonalBestTime);
			}
		}
		if (gP_Player[iClient].PreviousZoneTime != 0.0) {
			if (gP_Player[iClient].Record.StartTime > (GetGameTime() + HUD_SHOWPREVIOUS)) gP_Player[iClient].PreviousZoneTime = 0.0;
			Zone zZone;
			g_Global.Zones.GetArray(gP_Player[iClient].PreviousZone, zZone);

			if (zZone.Type == ZONE_CHECKPOINT) {
				
			} else if (zZone.Type == ZONE_END) {
			}
		}
		*/
		
		PrintHintText(iClient, cBuffer);
	}
}

bool Filter_HitSelf(int iEntity, int iMask, any aData) {
	if (iEntity == aData) return false;
	return true;
}