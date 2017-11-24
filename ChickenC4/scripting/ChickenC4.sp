#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.2.0"

ConVar hEnable;
ConVar hVisible;
ConVar hFollow;
ConVar hChance;
ConVar hMessage;
bool chickenEnabled;
bool chickenEnabledNR; //Admin enabled it for next round.

public Plugin myinfo = {
    name = "Chicken C4",
    author = "Mitchell",
    description = "CHICKEN C4 WAT.",
    version = PLUGIN_VERSION,
    url = "http://mtch.tech/"
};

public void OnPluginStart() {
    hEnable = CreateConVar("sm_chickc4_enable", "1", "Enable this plugin?");
    hVisible = CreateConVar("sm_chickc4_visible", "0", "Set to 1 for the chicken to be visible.");
    hFollow = CreateConVar("sm_chickc4_follow", "0", "Set to 1 for the chicken to auto follow the planter.");
    hChance = CreateConVar("sm_chickc4_chance", "100", "Chance, 0 to 100 if the round becomes a chicken c4 round.");
    hMessage = CreateConVar("sm_chickc4_message", "1", "Warn the players that the c4 is on a chicken?");
    AutoExecConfig();
    
    CreateConVar("sm_chickenc4_version", PLUGIN_VERSION, "Chicken C4 Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);    
    HookEvent("bomb_planted", BombPlanted_Event);
    HookEvent("bomb_begindefuse", BombDefusing_Event);
    HookEvent("bomb_abortdefuse", BombAborting_Event);
    HookEvent("round_end", Cleanup_Event);
    HookEvent("round_freeze_end", RoundFreezeEnd_Event);
    
    RegAdminCmd("sm_chickenc4", Command_EnableChickenC4, ADMFLAG_CHEATS);
}
public Action Command_EnableChickenC4(int client, int args) {
    if(!client) {
        return Plugin_Handled;
    }
    if(hEnable.BoolValue) {
        if(chickenEnabledNR) {
            PrintToChat(client, "Chicken C4 \x0Fdeactivated\x01 for next round!");
        } else {
            PrintToChat(client, "Chicken C4 \x04activated\x01 for next round!");
        }
        chickenEnabledNR = !chickenEnabledNR;
    } else {
        PrintToChat(client, "Chicken C4 plugin is disabled.");
    }
    return Plugin_Handled;
}

public Action BombPlanted_Event(Event event, const char[] name, bool dontBroadcast) {
    if(!chickenEnabled) {
        return Plugin_Continue;
    }
    
    int player = GetClientOfUserId(event.GetInt("userid"));
    if(player < 1 || player > MaxClients || !IsClientInGame(player)) {
        return Plugin_Continue;
    }
    
    int c4 = -1;
    c4 = FindEntityByClassname(c4, "planted_c4");
    if(c4 != -1) {
        int chicken = CreateEntityByName("chicken");
        if(chicken != -1) {
            float pos[3];
            GetEntPropVector(player, Prop_Data, "m_vecOrigin", pos);
            DispatchSpawn(chicken);
            SetEntProp(chicken, Prop_Data, "m_takedamage", 0);
            SetEntProp(chicken, Prop_Send, "m_fEffects", 0);
            SetEntProp(chicken, Prop_Send, "m_iPendingTeamNum", -8);
            TeleportEntity(chicken, pos, NULL_VECTOR, NULL_VECTOR);
            TeleportEntity(c4, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
            SetVariantString("!activator");
            AcceptEntityInput(c4, "SetParent", chicken, c4, 0);
            if(hVisible.BoolValue) {
                pos[0] = -1.0;
                pos[1] = 0.0;
                pos[2] = 9.5;
                TeleportEntity(c4, pos, NULL_VECTOR, NULL_VECTOR);
            } else {
                SetEntityRenderMode(chicken, RENDER_NONE);
            }
            if(hFollow.BoolValue) {
                SetEntPropEnt(chicken, Prop_Send, "m_leader", player);
            }
            PrintToChatAll("m_nSolidType: %i", GetEntProp(chicken, Prop_Send, "m_nSolidType"));
            PrintToChatAll("m_usSolidFlags: %i", GetEntProp(chicken, Prop_Send, "m_usSolidFlags"));
        }
    }
    return Plugin_Continue;
}

public Action BombDefusing_Event(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(event.GetInt("userid"));
    if(player < 1 || player > MaxClients || !IsClientInGame(player)) {
        return Plugin_Continue;
    }
    
    int oldChicken = -1;
    while((oldChicken = FindEntityByClassname(oldChicken, "chicken")) != -1) {
        if(IsValidEntity(oldChicken) && GetEntProp(oldChicken, Prop_Send, "m_iPendingTeamNum") == -8) {
            //SetEntPropEnt(oldChicken, Prop_Send, "m_leader", player);
            CreatePropBlock(oldChicken);
        }
    }
    return Plugin_Continue;
}

public Action BombAborting_Event(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(event.GetInt("userid"));
    if(player < 1 || player > MaxClients || !IsClientInGame(player)) {
        return Plugin_Continue;
    }
    
    int oldChicken = -1;
    while((oldChicken = FindEntityByClassname(oldChicken, "prop_dynamic")) != -1) {
        if(IsValidEntity(oldChicken) && GetEntProp(oldChicken, Prop_Send, "m_iPendingTeamNum") == -8) {
            AcceptEntityInput(oldChicken, "Kill");
        }
    }
    return Plugin_Continue;
}

public void CreatePropBlock(int chicken) {
    float pos[3];
    float ang[3];
    GetEntPropVector(chicken, Prop_Send, "m_vecOrigin", pos);
    GetEntPropVector(chicken, Prop_Send, "m_angRotation", ang);
    int viewingEntity = CreateEntityByName("prop_dynamic_override");
    if(viewingEntity != -1) {
        PrecacheModel("models/props_junk/cinderblock01a.mdl");
        DispatchKeyValue(viewingEntity, "model", "models/props_junk/cinderblock01a.mdl");
        DispatchKeyValue(viewingEntity, "solid", "6");
        DispatchKeyValue(viewingEntity, "rendermode", "10");
        DispatchKeyValue(viewingEntity, "disableshadows", "1");
        DispatchSpawn(viewingEntity);
        SetEntProp(viewingEntity, Prop_Send, "m_iPendingTeamNum", -8);
        pos[2] += 15.0;
        TeleportEntity(viewingEntity, pos, ang, NULL_VECTOR);
    }
}

public Action Cleanup_Event(Event event, const char[] name, bool dontBroadcast) {
    int oldChicken = -1;
    while((oldChicken = FindEntityByClassname(oldChicken, "chicken")) != -1) {
        if(IsValidEntity(oldChicken) && GetEntProp(oldChicken, Prop_Send, "m_iPendingTeamNum") == -8) {
            AcceptEntityInput(oldChicken, "Kill");
        }
    }
    oldChicken = -1;
    while((oldChicken = FindEntityByClassname(oldChicken, "prop_dynamic")) != -1) {
        if(IsValidEntity(oldChicken) && GetEntProp(oldChicken, Prop_Send, "m_iPendingTeamNum") == -8) {
            AcceptEntityInput(oldChicken, "Kill");
        }
    }
}

public Action RoundFreezeEnd_Event(Event event, const char[] name, bool dontBroadcast) {
    chickenEnabled = false;
    //Check if we should enable it this round?
    if(hEnable.BoolValue) {
        if(chickenEnabledNR) {
            chickenEnabled = true;
            chickenEnabledNR = false;
        } else {
            int chance = hChance.IntValue;
            if(chance == 100 || (chance > 0 && GetRandomInt(0, 100) <= chance)) {
                chickenEnabled = true;
            }
        }
    }
    if(chickenEnabled && hMessage.BoolValue) {
        //Message the players.
        PrintToChatAll(" \x0F[\x10ChickenC4\x0F]\x01 Chicken C4 Round activated.");
    }
}