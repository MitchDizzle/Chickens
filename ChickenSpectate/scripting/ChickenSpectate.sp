#include <sdkhooks>
#include <sdktools>
#include <clientprefs>
#pragma semicolon 1
#define chatPrefix " \x08[\x0BChickenSpectate\x08]\x01"

Handle cSpectatingChickens;
bool plySpectatingChickens[MAXPLAYERS+1];
int plyViewReference[MAXPLAYERS+1];
ArrayList chickens;
float veOffset[2][3];

#define PLUGIN_VERSION "1.0.0"
public Plugin myinfo = {
	name = "[CS:GO] Chicken Spectator",
	author = "Mitch",
	description = "Spectate through the eyes of chickens.",
	version = PLUGIN_VERSION,
	url = "http://mtch.tech"
};

public void OnPluginStart() {
	CreateConVar("sm_chickenspectate_version", PLUGIN_VERSION, "Version of Chicken Spectator", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);

	RegConsoleCmd("sm_cs", Command_Spectate);
	RegConsoleCmd("sm_chickenspectate", Command_Spectate);
	RegConsoleCmd("sm_sc", Command_SpawnChicken);
	
	cSpectatingChickens = RegClientCookie("chicken_spectate", "Chicken Spectate", CookieAccess_Private);
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			if(AreClientCookiesCached(i)) {
				OnClientCookiesCached(i);
			}
		}
	}
	
	//Store all the chickens within this array for later lookup.
	chickens = new ArrayList();
	
	//HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	
	//This is the viewingEntity offset for attachement.
	veOffset[1][0] = -125.0;
	veOffset[1][1] = 180.0;
	veOffset[0][2] = -5.0;
}

public void OnPluginEnd() {
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {// && isValidRef(plyViewReference[i])) {
			SetClientViewEntity(i, i);
			//SetEntProp(i, Prop_Send, "m_iObserverMode", 0);
		}
	}
}

public OnClientCookiesCached(int client) {
	char sValue[8];
	GetClientCookie(client, cSpectatingChickens, sValue, sizeof(sValue));
	plySpectatingChickens[client] = StringToInt(sValue) > 1;
}

public Action Command_Spectate(int client, int args) {
	if(client <= 0 || !IsClientInGame(client)) {
		ReplyToCommand(client, "You must be ingame to use this command.");
		return Plugin_Handled;
	}
	plySpectatingChickens[client] = !plySpectatingChickens[client];
	SetClientCookie(client, cSpectatingChickens, (plySpectatingChickens[client]) ? "0" : "1");
	PrintToChat(client, "%s Spectating Chickens %s\x01.", chatPrefix, plySpectatingChickens[client] ? "\x04Enabled" : "\x0FDisabled");
	return Plugin_Handled;
}
public Action Command_SpawnChicken(int client, int args) {
	if(client <= 0 || !IsClientInGame(client)) {
		ReplyToCommand(client, "You must be ingame to use this command.");
		return Plugin_Handled;
	}

	float position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	position[2] += 10.0;

	int chicken = CreateEntityByName("chicken");
	DispatchSpawn(chicken);

	int viewingEntity = createViewingEntity();

	SetVariantString("!activator");
	AcceptEntityInput(viewingEntity, "SetParent", chicken, viewingEntity);
	SetVariantString("eyes");
	AcceptEntityInput(viewingEntity, "SetParentAttachment", viewingEntity, viewingEntity);
	TeleportEntity(viewingEntity, veOffset[0], veOffset[1], NULL_VECTOR);
	TeleportEntity(chicken, position, NULL_VECTOR, NULL_VECTOR);
	SetClientViewEntity(client, viewingEntity);
	//SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	return Plugin_Handled;
}

public void Event_RoundEnd(const char[] name, EventHook callback, EventHookMode mode) {
	int index;
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			SetClientViewEntity(i, i);
			//SetEntProp(i, Prop_Send, "m_iObserverMode", 0);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if(StrEqual(classname, "chicken", false)) {
		SDKHook(entity, SDKHook_SpawnPost, HookSpawnPost);
	}
}

public void HookSpawnPost(int entity) {
	if(!IsValidEntity(entity)) {
		return;
	}
	chickens.Push(EntIndexToEntRef(entity));
}

public void spectateEntity(int client, int entity) {
	int viewingEntity = getViewingEntity(client);
	SetVariantString("!activator");
	AcceptEntityInput(viewingEntity, "SetParent", entity, viewingEntity);
	SetVariantString("eyes");
	AcceptEntityInput(viewingEntity, "SetParentAttachment", viewingEntity, viewingEntity);
	TeleportEntity(viewingEntity, veOffset[0], veOffset[1], NULL_VECTOR);
	SetClientViewEntity(client, viewingEntity);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 2);
}

public int createViewingEntity() {
	int viewingEntity = CreateEntityByName("prop_dynamic");
	if(viewingEntity != -1) {
		DispatchKeyValue(viewingEntity, "model", "models/chicken/chicken.mdl");
		DispatchKeyValue(viewingEntity, "solid", "0");
		DispatchKeyValue(viewingEntity, "rendermode", "10");
		DispatchKeyValue(viewingEntity, "disableshadows", "1");
		DispatchSpawn(viewingEntity);
	}
	return viewingEntity;
}

public int getViewingEntity(int client) {
	int viewingEntity = EntRefToEntIndex(plyViewReference[client]);
	if(viewingEntity <= MaxClients || !IsValidEntity(viewingEntity)) {
		viewingEntity = createViewingEntity();
	}
	return viewingEntity;
}
