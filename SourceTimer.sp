/* Source Timer
*
* Copyright (C) 2019 Oscar Wos // github.com/OSCAR-WOS | theoscar@protonmail.com
*
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or (at your option)
* any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License along with
* this program. If not, see http://www.gnu.org/licenses/.
*/

// Compiler Info: Pawn 1.9 - build 6281

// The following to be put into a Config
#define TEXT_DEFAULT "{white}"
#define TEXT_HIGHLIGHT "{lightred}"
#define TEXT_PREFIX "[{blue}Timer{white}] "
#define BOX_BOUNDRY 120.0

#define PLUGIN_NAME "Source Timer"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <csgocolors>
#include <sourcetimer>

#include "SourceTimer/Variable.sp"
#include "SourceTimer/Admin.sp"
#include "SourceTimer/Misc.sp"
#include "SourceTimer/Zone.sp"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = "Oscar Wos (OSWO)",
	description = "A timer used for recording player times on skill based maps",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/OSWO",
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] cError, int iError) {
	// CreateNative("Timer")
}

public void OnPluginStart() {
	g_Global = new Global();

	g_Global.Players = new Players();
	g_Global.Players.Init();

	g_Global.Timer = CreateTimer(0.1, Timer_Global, _, TIMER_REPEAT);

	ServerCommand("sm_reload_translations");
	LoadTranslations("sourcetimer.phrases");

	RegConsoleCmd("sm_timer", Command_Admin);
	RegConsoleCmd("sm_zone", Command_Zone);
	RegConsoleCmd("sm_addzone", Command_AddZone);

	/*
	RegAdminCmd("sm_timer", Command_Admin, ADMFLAG_RCON, "");
	RegAdminCmd("sm_zone", Command_Zone, ADMFLAG_RCON, "");
	RegAdminCmd("sm_addzone", Command_AddZone, ADMFLAG_RCON, "");
	*/

	// RegAdminCmd("sm_editzone", Command_EditZone, ADMFLAG_RCON, "");
	// RegAdminCmd("sm_delzones", Command_DelZones, ADMFLAG_RCON, "");
}

public void OnMapStart() {
	Misc_PrecacheModels();
}

public void OnClientPostAdminCheck(int iClient) {
	g_Global.Players.InitClient(iClient);
}

public void OnClientDisconnect(int iClient) {
	g_Global.Players.ClearClient(iClient);
}

public Action OnPlayerRunCmd(int iClient, int& iButtons, int& iImpulse, float fVel[3], float fAngles[3], int& iWeapon, int& iSubtype, int& iCmd, int& iTick, int& iSeed, int iMouse[2]) {
	Player pPlayer = view_as<Player>(g_Global.Players.Get(iClient));
	if (pPlayer.Admin.Setting == -1) return;
	if (!((iButtons & IN_ATTACK) || (iButtons & IN_ATTACK2))) return;

	float xPos[3], yPos[3];

	pPlayer.Zone.GetX(xPos);
	pPlayer.Zone.GetY(yPos);

	switch (pPlayer.Admin.Setting) {
		case 0: {
			switch (pPlayer.Admin.Option) {
				case 0: {
					float fEye[3], fAngle[3], fPos[3];

					GetClientEyePosition(iClient, fEye);
					GetClientEyeAngles(iClient, fAngle);

					TR_TraceRayFilter(fEye, fAngle, MASK_SOLID, RayType_Infinite, Filter_HitSelf, iClient);
					if (TR_DidHit()) TR_GetEndPosition(fPos);

					if (iButtons & IN_ATTACK) { g_Global.Players.SetAdminZoneX(iClient, fPos); }
					else { g_Global.Players.SetAdminZoneY(iClient, fPos); }

					Admin_AddZone(iClient);
				}
			}
		} case 1: {
			float fValue = 0.1;

			if (iButtons & IN_ATTACK2) { fValue *= -1; }
			xPos[pPlayer.Admin.Option] += fValue;
			g_Global.Players.SetAdminZoneX(iClient, xPos);
		} case 2: {
			float fValue = 0.1;

			if (iButtons & IN_ATTACK2) { fValue *= -1; }
			yPos[pPlayer.Admin.Option] += fValue;
			g_Global.Players.SetAdminZoneY(iClient, yPos);
		}
	}
}

public Action Timer_Global(Handle hTimer) {
	Timer_Admin();
}
