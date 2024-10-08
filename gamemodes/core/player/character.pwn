#include <YSI_Data\y_iterate>
#include <YSI_Coding\y_hooks>

/**
 * # Header
 */

#define MAX_ACCOUNT_CHARACTERS      (5)

#define MIN_CHARACTER_AGE           (18)
#define MAX_CHARACTER_AGE           (32)

#define DEFAULT_SPAWN_X             (1756.7087)
#define DEFAULT_SPAWN_Y             (-1903.5756)
#define DEFAULT_SPAWN_Z             (13.5643)
#define DEFAULT_SPAWN_A             (270.0000)

static enum E_CHARACTER_DATA {
    DBID:E_CHARACTER_DATABASE_ID,
    E_CHARACTER_NAME[MAX_PLAYER_NAME + 1],
    E_CHARACTER_MONEY,
    E_CHARACTER_SKIN_ID,
    E_CHARACTER_WORLD_ID,
    E_CHARACTER_INTERIOR_ID,
    Float:E_CHARACTER_HEALTH,
    Float:E_CHARACTER_ARMOUR,
    Float:E_CHARACTER_POS_X,
    Float:E_CHARACTER_POS_Y,
    Float:E_CHARACTER_POS_Z,
    Float:E_CHARACTER_POS_A
};

static
    CharacterData[MAX_PLAYERS][MAX_ACCOUNT_CHARACTERS][E_CHARACTER_DATA]
;

static const
    characterDefaultSkinList[][] =
{
    /**
     * 0: Male
     * 1: Female
     */

    {0, 18}, {0, 60}, {0, 230},
    {1, 13}, {1, 56}, {1, 192}
};

static
    bool:playerIsLogged[MAX_PLAYERS char],
    playerSelectCharacterGender[MAX_PLAYERS char],
    playerSelectCharacterAge[MAX_PLAYERS char],
    playerSelectCharacterSkin[MAX_PLAYERS],
    playerSelectCharacterSlotID[MAX_PLAYERS char]
;

new
    Iterator:AccountCharacters[MAX_PLAYERS]<MAX_ACCOUNT_CHARACTERS>
;

/**
 * # Forwards
 */

forward OnCharacterSpawn(playerid);
forward OnCharacterLogOut(playerid);

forward OnCharacterCheck(playerid);
forward OnCharacterRetrieve(playerid, slotid);
forward OnCharacterNameCheck(playerid, const name[]);
forward OnCharacterInsertDatabase(playerid, slotid);

/**
 * # Internal
 */

static Character_CheckDatabase(playerid) {
    new
        query[128]
    ;

    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT `id`, `name` FROM `characters` WHERE `account_id` = %i;", _:GetAccountDatabaseID(playerid));
    mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterCheck", "i", playerid);
}

static ShowCreateCharacterDialog(playerid) {
    new
        menu[MAX_PLAYER_NAME * MAX_ACCOUNT_CHARACTERS + 32] = "Выберите или создайте персонажа:\n"
    ;

    foreach (new i: AccountCharacters[playerid]) {
        format(menu, sizeof (menu), "%s%s\n", menu, CharacterData[playerid][i][E_CHARACTER_NAME]);
    }

    if (Iter_NonFull(AccountCharacters[playerid])) {
        strcat(menu, "{98FB98}+ Создать персонажа");
    }

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_SELECTION, DIALOG_STYLE_TABLIST_HEADERS, "Character Selection", menu, "Выбрать", "Отменить");
}

static SelectCharacterAgeDialog(playerid) {
    new
        menu[128] = "Выберите возраст своего персонажа:\n"
    ;

    for (new i = MIN_CHARACTER_AGE; i <= MAX_CHARACTER_AGE; i++) {
        format(menu, sizeof (menu), "%s%i\n", menu, i);
    }

    strcat(menu, "Другое");

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_AGE_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Возраст персонажа", menu, "Далее", "Назад");
}

static SelectCharacterSkinDialog(playerid) {
    new
        menu[128] = "Выберите скин своего персонажа:\n"
    ;

    for (new i, size = sizeof (characterDefaultSkinList); i < size; i++) {
        format(menu, sizeof (menu), "%s%s: %i\n", menu, characterDefaultSkinList[i][0] ? "Женский" : "Мужской", characterDefaultSkinList[i][1]);
    }

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_SKIN_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Скин персонажа", menu, "Далее", "Назад");
}

static ShowCharacterActionDialog(playerid, slotid) {
    new
        caption[16 + MAX_PLAYER_NAME]
    ;

    strcat(caption, "Персонаж ");
    strcat(caption, CharacterData[playerid][slotid][E_CHARACTER_NAME]);

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_ACTION, DIALOG_STYLE_TABLIST_HEADERS, caption,
	        "Выберите действие с персонажем:\nАвторизоваться за персонажа\nУдалить персонажа",
        "Выбрать", "Отклонить"
    );
}

static Character_SetSpawn(playerid, slotid, skinid, Float:x, Float:y, Float:z, Float:a) {
    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, skinid, x, y, z, a);
    SetPlayerName(playerid, CharacterData[playerid][slotid][E_CHARACTER_NAME]);
    SetCameraBehindPlayer(playerid);
    SpawnPlayer(playerid);

    playerIsLogged{playerid} = true;
    playerSelectCharacterSlotID{playerid} = slotid;

    CallLocalFunction("OnCharacterSpawn", "i", playerid);
}

static Character_SaveData(playerid) {
    if (!playerIsLogged{playerid}) {
        return;   
    }

    new const
        slotid = playerSelectCharacterSlotID{playerid}
    ;

    new
        query[1024]
    ;

    GetPlayerPos(playerid, CharacterData[playerid][slotid][E_CHARACTER_X], CharacterLoadData[E_CHARACTER_Y], CharacterLoadData[E_CHARACTER_Z]);
    GetPlayerFacingAngle(playerid, CharacterData[playerid][slotid][E_CHARACTER_A]);
    GetPlayerHealth(playerid, CharacterData[playerid][slotid][E_CHARACTER_HEALTH]);
    GetPlayerArmour(playerid, CharacterData[playerid][slotid][E_CHARACTER_ARMOUR]);

    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "\
        UPDATE \
            `characters` \
        SET \
            `money` = %i, \
            `skin` = %i, \
            `world` = %i, \
            `interior` = %i, \
            `health` = %f, \
            `armour` = %f, \
            `pos_x` = %f, \
            `pos_y` = %f, \
            `pos_z` = %f, \
            `pos_a` = %f \
        WHERE \
            `id` = %i;",
        GetPlayerMoney(playerid),
        GetPlayerSkin(playerid),
        GetPlayerVirtualWorld(playerid),
        GetPlayerInterior(playerid),
        CharacterData[playerid][slotid][E_CHARACTER_HEALTH],
        CharacterData[playerid][slotid][E_CHARACTER_ARMOUR],
        CharacterData[playerid][slotid][E_CHARACTER_POS_X],
        CharacterData[playerid][slotid][E_CHARACTER_POS_Y],
        CharacterData[playerid][slotid][E_CHARACTER_POS_Z],
        CharacterData[playerid][slotid][E_CHARACTER_POS_A],
        _:CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID]
    );

    mysql_tquery(MYSQL_DEFAULT_HANDLE, query);

    Character_ResetData(playerid);
    CallLocalFunction("OnCharacterLogOut", "i", playerid);
}

static Character_ResetData(playerid) {
    static const
        CHARACTER_DATA_CLEAN[E_CHARACTER_DATA]
    ;

    for (new i; i < MAX_ACCOUNT_CHARACTERS; i++) {
        CharacterData[playerid][i] = CHARACTER_DATA_CLEAN;
    }

    Iter_Clear(AccountCharacters[playerid]);

    playerIsLogged{playerid} = false;
}

/**
 * # External
 */

stock Character_SetDatabaseID(playerid, slotid, DBID:id) {
    CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID] = id;
}

stock DBID:Character_GetDatabaseID(playerid, slotid) {
    return CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID];
}

stock Character_SetName(playerid, slotid, const name[]) {
    format(CharacterData[playerid][slotid][E_CHARACTER_NAME], _, name);
}

stock Character_GetName(playerid, slotid, name[], size = sizeof (name)) {
    format(name, size, CharacterData[playerid][slotid][E_CHARACTER_NAME]);
}

/**
 * # Hooks
 */

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    switch (dialogid) {
        case DIALOG_CHARACTER_SELECTION: {
            if (!response) {
                DelayedKick(playerid, "Decided to leave");

                return 1;
            }

            if (!Iter_Contains(AccountCharacters[playerid], listitem)) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:",
                    "Next", "Back", ReturnPlayerName(playerid)
                );

                return 1;
            }

            playerSelectCharacterSlotID{playerid} = listitem;

            ShowCharacterActionDialog(playerid, listitem);
        }

        case DIALOG_CHARACTER_ACTION: {
            if (!response) {
                ShowCreateCharacterDialog(playerid);

                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            switch (listitem) {
                case 0: {
                    new
                        query[64]
                    ;

                    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT * FROM `characters` WHERE `id` = %i;", _:CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID]);
                    mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterRetrieve", "ii", playerid, slotid);
                }

                case 1: {
                    ShowPlayerDialog(playerid, DIALOG_CHARACTER_CONFIRM_DELETE, DIALOG_STYLE_INPUT, "Delete Character",
                        "{FFFFFF}Please write the character name (%s) below to confirm the deletion:",
                        "Submit", "Back", CharacterData[playerid][slotid][E_CHARACTER_NAME]
                    );
                }
            }
        }

        case DIALOG_CHARACTER_CONFIRM_DELETE: {
            if (!response) {
                ShowCharacterActionDialog(playerid, playerSelectCharacterSlotID{playerid});

                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            if (strcmp(inputtext, CharacterData[playerid][slotid][E_CHARACTER_NAME])) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_CONFIRM_DELETE, DIALOG_STYLE_INPUT, "Delete Character",
                    "{FFFFFF}Please write the character name (%s) below to confirm the deletion:\n\n{FF0000}Wrong name.",
                    "Submit", "Back", CharacterData[playerid][slotid][E_CHARACTER_NAME]
                );

                return 1;
            }

            new const
                DBID:id = CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID]
            ;

            CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID] = INVALID_DATABASE_ID;
            CharacterData[playerid][slotid][E_CHARACTER_NAME][0] = EOS;

            Iter_Remove(AccountCharacters[playerid], slotid);

            ShowCreateCharacterDialog(playerid);

            new
                query[64]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "DELETE FROM `characters` WHERE `id` = %i;", _:id);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query);
        }

        case DIALOG_CHARACTER_NAME_CREATION: {
            if (!response) {
                ShowCreateCharacterDialog(playerid);

                return 1;
            }

            if (!(3 <= strlen(inputtext) <= MAX_PLAYER_NAME)) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:\n\n{FF0000}Enter a name between 3 to %i characters.",
                    "Next", "Back", ReturnPlayerName(playerid), MAX_PLAYER_NAME
                );

                return 1;
            }

            new
                query[128]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT `id` FROM `characters` WHERE `name` = '%e' LIMIT 1;", inputtext);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterNameCheck", "is", playerid, inputtext);
        }
    
        case DIALOG_CHARACTER_GENDER_CREATION: {
            if (!response) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:",
                    "Next", "Back", ReturnPlayerName(playerid)
                );

                return 1;
            }

            playerSelectCharacterGender{playerid} = listitem;

            SelectCharacterAgeDialog(playerid);
        }

        case DIALOG_CHARACTER_AGE_CREATION: {
            if (!response) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_GENDER_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Gender",
                    "Select your character's gender:\nMale\nFemale\nNeutral",
                    "Next", "Back"
                );
                
                return 1;
            }

            playerSelectCharacterAge{playerid} = (MIN_CHARACTER_AGE + listitem);

            SelectCharacterSkinDialog(playerid);
        }

        case DIALOG_CHARACTER_SKIN_CREATION: {
            if (!response) {
                SelectCharacterAgeDialog(playerid);
                
                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            playerSelectCharacterSkin[playerid] = characterDefaultSkinList[listitem][1];

            new
                query[256]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "INSERT INTO `characters` (`account_id`, `name`, `gender`, `age`, `skin`) VALUES (%i, '%e', %i, %i, %i);", _:GetAccountDatabaseID(playerid), CharacterData[playerid][slotid][E_CHARACTER_NAME], playerSelectCharacterGender{playerid}, playerSelectCharacterAge{playerid}, playerSelectCharacterSkin[playerid]);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterInsertDatabase", "ii", playerid, slotid);
        }
    }

    return 1;
}

hook OnPlayerLogIn(playerid) {
    Character_CheckDatabase(playerid);
    
    return 1;
}

hook OnPlayerRegister(playerid) {
    Character_CheckDatabase(playerid);
    
    return 1;
}

hook OnPlayerDisconnect(playerid, reason) {
    Character_SaveData(playerid);

    return 1;
}

/**
 * # Calls
 */

public OnCharacterCheck(playerid) {
    new const
        rows = cache_num_rows()
    ;

    for (new i; i < rows; i++) {
        cache_get_value_int(i, "id", _:CharacterData[playerid][i][E_CHARACTER_DATABASE_ID]);
        cache_get_value(i, "name", CharacterData[playerid][i][E_CHARACTER_NAME]);

        Iter_Add(AccountCharacters[playerid], i);
    }

    ShowCreateCharacterDialog(playerid);

    return 1;
}

public OnCharacterNameCheck(playerid, const name[]) {
    if (cache_num_rows()) {
        ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
            "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:\n\n{FF0000}This name (%s) already exists, enter another name.",
            "Next", "Back", ReturnPlayerName(playerid), name
        );

        return 1;
    }

    new const
        slotid = Iter_Free(AccountCharacters[playerid])
    ;

    format(CharacterData[playerid][slotid][E_CHARACTER_NAME], _, name);

    playerSelectCharacterSlotID{playerid} = slotid;

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_GENDER_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Gender",
        "Select your character's gender:\nMale\nFemale\nNeutral",
        "Next", "Back"
    );

    return 1;
}

public OnCharacterInsertDatabase(playerid, slotid) {
    CharacterData[playerid][slotid][E_CHARACTER_DATABASE_ID] = DBID:cache_insert_id();

    Character_SetSpawn(
        playerid,
        slotid,
        playerSelectCharacterSkin[playerid],
        DEFAULT_SPAWN_X,
        DEFAULT_SPAWN_Y,
        DEFAULT_SPAWN_Z,
        DEFAULT_SPAWN_A
    );

    Iter_Add(AccountCharacters[playerid], slotid);

    return 1;
}

public OnCharacterRetrieve(playerid, slotid) {

    cache_get_value_int(0, "money", CharacterData[playerid][slotid][E_CHARACTER_MONEY]);
    cache_get_value_int(0, "skin", CharacterData[playerid][slotid][E_CHARACTER_SKIN_ID]);
    cache_get_value_int(0, "world", CharacterData[playerid][slotid][E_CHARACTER_WORLD_ID]);
    cache_get_value_int(0, "interior", CharacterData[playerid][slotid][E_CHARACTER_INTERIOR_ID]);
    cache_get_value_float(0, "health", CharacterData[playerid][slotid][E_CHARACTER_HEALTH]);
    cache_get_value_float(0, "armour", CharacterData[playerid][slotid][E_CHARACTER_ARMOUR]);
    cache_get_value_float(0, "pos_x", CharacterData[playerid][slotid][E_CHARACTER_POS_X]);
    cache_get_value_float(0, "pos_y", CharacterData[playerid][slotid][E_CHARACTER_POS_Y]);
    cache_get_value_float(0, "pos_z", CharacterData[playerid][slotid][E_CHARACTER_POS_Z]);
    cache_get_value_float(0, "pos_a", CharacterData[playerid][slotid][E_CHARACTER_POS_A]);

    GivePlayerMoney(playerid, CharacterData[playerid][slotid][E_CHARACTER_MONEY]);
    SetPlayerSkin(playerid, CharacterData[playerid][slotid][E_CHARACTER_SKIN_ID]);
    SetPlayerVirtualWorld(playerid, CharacterData[playerid][slotid][E_CHARACTER_WORLD_ID]);
    SetPlayerInterior(playerid, CharacterData[playerid][slotid][E_CHARACTER_INTERIOR_ID]);

    Character_SetSpawn(
        playerid,
        slotid,
        CharacterData[playerid][slotid][E_CHARACTER_SKIN_ID],
        CharacterData[playerid][slotid][E_CHARACTER_POS_X],
        CharacterData[playerid][slotid][E_CHARACTER_POS_Y],
        CharacterData[playerid][slotid][E_CHARACTER_POS_Z],
        CharacterData[playerid][slotid][E_CHARACTER_POS_A]
    );

    return 1;
}
