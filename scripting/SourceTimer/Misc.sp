void Misc_Start() {
	Misc_PrecacheModels();
	Misc_ConVars();
}

bool Misc_CheckPlayer(int iClient, int iType) {
	if (iClient < 1 || iClient >= MaxClients) return false;

	if (iType >= PLAYER_ENTITY) if (!IsValidEntity(iClient)) return false;
	if (iType >= PLAYER_CONNECTED) if (!IsClientConnected(iClient)) return false;
	if (iType >= PLAYER_INGAME) if (!IsClientInGame(iClient)) return false;
	if (iType >= PLAYER_VALID) if (IsFakeClient(iClient)) return false;
	if (iType >= PLAYER_ALIVE) if (!IsPlayerAlive(iClient)) return false;
	return true;
}

void Misc_PrecacheModels() {
	g_Global.Models.BlueGlow = PrecacheModel("sprites/blueglow1.vmt");
	g_Global.Models.RedGlow = PrecacheModel("sprites/purpleglow1.vmt");
	g_Global.Models.Laser = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_Global.Models.Glow = PrecacheModel("materials/sprites/glow01.vmt");
	g_Global.Models.Zone = PrecacheModel("models/error.mdl");
}

int Misc_CalculateZoneType(int iType) {
	return iType % ZONES_TOTAL;
}

int Misc_CalculateZoneGroup(int iGroup) {
	return iGroup % (g_Global.Zones.GetTotalZoneGroups() + 2);
}

void Misc_CalculateCentre(float xPos[3], float yPos[3], float fCentre[3]) {
	for (int i = 0; i < 3; i++) fCentre[i] = (xPos[i] + yPos[i]) / 2;
}

void Misc_CalculateSpawn(float xPos[3], float yPos[3], float fSpawn[3]) {
	for (int i = 0; i < 2; i++) fSpawn[i] = (xPos[i] + yPos[i]) / 2;
	if (xPos[2] < yPos[2]) fSpawn[2] = xPos[2];
	else fSpawn[2] = yPos[2];
}

void Misc_FormatTime(float fTime, char[] cBuffer, int iMaxLength) {
	int iMili = RoundToFloor(fTime * 1000);

	if (iMili < 0) iMili *= -1;
	if (iMili >= 3600000) { Format(cBuffer, iMaxLength, "%02d:", RoundToFloor(float(iMili) / 3600000)); iMili = iMili % 3600000; }
	Format(cBuffer, iMaxLength, "%s%02d:", cBuffer, RoundToFloor(float(iMili) / 60000)); iMili = iMili % 60000;
	Format(cBuffer, iMaxLength, "%s%02d.", cBuffer, RoundToFloor(float(iMili) / 1000)); iMili = iMili % 1000;
	Format(cBuffer, iMaxLength, "%s%03d", cBuffer, iMili);
}

void Misc_FormatTimePrefix(float fTime, float fDiff, char[] cBuffer, int iMaxLength) {
	if (fTime == 0) Format(cBuffer, iMaxLength, "\x0A%s\x01", cBuffer);
	else if (fDiff == 0) Format(cBuffer, iMaxLength, "\x10%s\x01", cBuffer);
	else if (fDiff > 0) Format(cBuffer, iMaxLength, "\x06+%s\x01", cBuffer);
	else Format(cBuffer, iMaxLength, "\x07-%s\x01", cBuffer);
}

void Misc_FormatTimeHud(float fTime, float fDiff, char[] cBuffer, int iMaxLength) {
	if (fTime == 0) Format(cBuffer, iMaxLength, "<font color=\"#B0C3D9\">%s", cBuffer);
	else if (fDiff == 0) Format(cBuffer, iMaxLength, "<font color=\"#E4AE39\">%s", cBuffer);
	else if (fDiff > 0) Format(cBuffer, iMaxLength, "<font color=\"#A2FF47\">+%s", cBuffer);
	else Format(cBuffer, iMaxLength, "<font color=\"#FF4040\">-%s", cBuffer);
}

Action Misc_Run(int iClient) {
	if (IsClientObserver(iClient)) {
		int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if (iTarget != -1) Misc_ShowHud(iClient, iTarget);
	} else {
		Misc_ShowHud(iClient, iClient);
	}
}

void Misc_ShowHud(int iClient, int iTarget) {
	if (gP_Player[iTarget].Record.StartTime > 0.0) {
		char[] cBuffer = new char[4096];
		char[] cTime = new char[32];
		float fTime = GetGameTime();

		Misc_FormatTime(gP_Player[iTarget].Record.StartTime - fTime, cTime, 32);
		FormatEx(cBuffer, 4096, "<pre>Time: %s\t%i/%i", cTime, gP_Player[iTarget].CloneRecordsIndex + 1, gP_Player[iTarget].CloneRecords.Length);

		if (gP_Player[iTarget].PreviousTime != 0.0 && (fTime - gP_Player[iTarget].PreviousTime) < HUD_SHOWPREVIOUS) {
			if (gP_Player[iTarget].Checkpoints.Length > 0) {
				char cServerDiff[64], cPersonalDiff[64];
				float fServerTime, fPersonalTime;
				Checkpoint cCheckpoint; gP_Player[iTarget].Checkpoints.GetArray(gP_Player[iTarget].Checkpoints.Length - 1, cCheckpoint);

				if (gP_Player[iTarget].PreviousZone != -1) {
					Zone zZone; g_Global.Zones.GetArray(gP_Player[iTarget].PreviousZone, zZone);

					if (zZone.RecordIndex[0] != -1) {
						Checkpoint cServerBest; g_Global.Checkpoints.GetArray(zZone.RecordIndex[0], cServerBest);
						fServerTime = cServerBest.Time;
					}

					if (zZone.RecordIndex[iTarget] != -1) {
						Checkpoint cPersonalBest; gP_Player[iTarget].RecordCheckpoints.GetArray(zZone.RecordIndex[iTarget], cPersonalBest);
						fPersonalTime = cPersonalBest.Time;
					}
				}

				Misc_FormatTime(fServerTime - cCheckpoint.Time, cServerDiff, sizeof(cServerDiff));
				Misc_FormatTime(fPersonalTime - cCheckpoint.Time, cPersonalDiff, sizeof(cPersonalDiff));
				Misc_FormatTimeHud(fServerTime, fServerTime - cCheckpoint.Time, cServerDiff, sizeof(cServerDiff));
				Misc_FormatTimeHud(fPersonalTime, fPersonalTime - cCheckpoint.Time, cPersonalDiff, sizeof(cPersonalDiff));
				FormatEx(cBuffer, 4096, "%s\t%s\n", cBuffer, cServerDiff);
				FormatEx(cBuffer, 4096, "%s\t\t\t\t\t\t\t%s", cBuffer, cPersonalDiff);
			}
		} else {
			char cServerTime[64], cPersonalTime[64];
			float fServerTime, fPersonalTime;

			if (gP_Player[iTarget].EndZoneIndex != -1) {
				Zone zZone; g_Global.Zones.GetArray(gP_Player[iTarget].EndZoneIndex, zZone);

				if (zZone.RecordIndex[0] != -1) {
					Record rServerBest; g_Global.Records.GetArray(zZone.RecordIndex[0], rServerBest);
					fServerTime = rServerBest.EndTime;
				}

				if (zZone.RecordIndex[iTarget] != -1) {
					Record rPersonalBest; gP_Player[iTarget].Records.GetArray(zZone.RecordIndex[iTarget], rPersonalBest);
					fPersonalTime = rPersonalBest.EndTime;
				}
			}

			Misc_FormatTime(fServerTime, cServerTime, sizeof(cServerTime));
			Misc_FormatTime(fPersonalTime, cPersonalTime, sizeof(cPersonalTime));
			FormatEx(cBuffer, 4096, "%s\t%s\n", cBuffer, cServerTime);
			FormatEx(cBuffer, 4096, "%s\t\t\t\t\t\t\t%s", cBuffer, cPersonalTime);
		}
		
		FormatEx(cBuffer, 4096, "%s</pre>", cBuffer);
		PrintHintText(iClient, cBuffer);

		if (gP_Player[iTarget].CloneRecordsIndex < gP_Player[iTarget].CloneRecords.Length) {
			Record rRecord; gP_Player[iTarget].CloneRecords.GetArray(gP_Player[iTarget].CloneRecordsIndex, rRecord);
			if ((fTime - gP_Player[iTarget].Record.StartTime) > rRecord.EndTime) gP_Player[iTarget].CloneRecordsIndex++;
		}
	}
}

void Misc_StartTimer(int iClient) {
	if (GetEntityMoveType(iClient) != MOVETYPE_WALK) return;
	gP_Player[iClient].Record.StartTime = GetGameTime();
	gP_Player[iClient].RecentlyAbused = false;
	gP_Player[iClient].Replay.Frame = 0;
	gP_Player[iClient].PreviousTime = 0.0;
	gP_Player[iClient].PreviousZone = 0;
	gP_Player[iClient].CurrentZone = 0;
	gP_Player[iClient].CloneRecordsIndex = 0;
	gP_Player[iClient].EndZoneIndex = g_Global.Zones.FindSingleZone(ZONE_END, gP_Player[iClient].Record.Group);

	gP_Player[iClient].CloneRecords = g_Global.Records.FindByStyleGroup(gP_Player[iClient].Style, gP_Player[iClient].Record.Group);
	SortADTArrayCustom(gP_Player[iClient].CloneRecords, Sort_CloneRecords);
}

public int Sort_CloneRecords(int iIndex1, int iIndex2, Handle alRecords, Handle hTest) {
	Record rRecord1, rRecord2;
	view_as<Records>(alRecords).GetArray(iIndex1, rRecord1);
	view_as<Records>(alRecords).GetArray(iIndex2, rRecord2);

	if (rRecord1.EndTime < rRecord2.EndTime) return -1;
	return 1;
}

void Misc_ConVars() {
	char[] cBuffer = new char[512];

	BuildPath(Path_SM, cBuffer, 512, "configs/convars.txt");
	if (!FileExists(cBuffer)) return;

	File fConVar = OpenFile(cBuffer, "r");
	while (!fConVar.EndOfFile()) {
		if (fConVar.ReadLine(cBuffer, 512)) {
			char[][] cTemp = new char[2][64];
			ExplodeString(cBuffer, " ", cTemp, 2, 64);
			g_Global.Convars.SetString(cTemp[0], cTemp[1], true);

			ConVar cConVar = FindConVar(cTemp[0]);
			cConVar.SetString(cTemp[1]);
			cConVar.AddChangeHook(Hook_ConVarChange);
		}
	}
}

void Misc_SegmentMessage(int iClient, char[] cMessage) {
	for (int i = 1; i <= MaxClients; i++) {
		if (!Misc_CheckPlayer(i, PLAYER_VALID)) continue;
		if (i == iClient) PrintToChat(iClient, "%s", cMessage);
		else {
			if (!IsClientObserver(i)) return;
			int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
			if (i == iTarget) PrintToChat(iClient, "%s", cMessage);
		}
	}
}

void Misc_EndMessage(int iClient, int iStyle, int iGroup, float fTime) {
	char[] cBuffer = new char[512];
	char[] cClientName = new char[64];
	char[] cTime = new char[64];

	GetClientName(iClient, cClientName, 64);
	Misc_FormatTime(fTime, cTime, 64);
	Format(cBuffer, 512, "Finished %i on %i - %s", iGroup, iStyle, cTime);

	for (int i = 1; i <= MaxClients; i++) {
		if (!Misc_CheckPlayer(i, PLAYER_VALID)) continue;
		if (i != iClient) Timer_Message(i, "%s%s%s %s", TEXT_PREFIX, TEXT_DEFAULT, cClientName, cBuffer); 
		Timer_Message(i, "%s%s%s", TEXT_PREFIX, TEXT_DEFAULT, cBuffer); 
	}
}