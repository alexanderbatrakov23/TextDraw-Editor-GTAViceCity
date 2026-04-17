#include <a_vicemp>
#include <keysdefine>
#include <custommenu>

/*
		Есть варнинги на них внимание не обращаем,
		поскольку это заготовки к следующему обновлению.
		Опять же используется кастомное Gui,
		отдельное спасибо Олегу Штекеру за кастомное меню custommenu
		
		Основные клавиши:
		M - Открыть главное меню редактора

		1/2 - Переключение между созданными текстдравами (предыдущий/следующий)

		L - Удалить текущий выбранный текстдрав

		C - Копировать текущий текстдрав (создается копия со смещением +10 пикселей)
		
		N - Остановить режим редактирования полностью

		E - Экспортировать все текстдравы в готовый pawn-код
		
		Режим позиционирования:
		W / Стрелка вверх - переместить текстдрав вверх

		S / Стрелка вниз - переместить текстдрав вниз

		A / Стрелка влево - переместить текстдрав влево

		D / Стрелка вправо - переместить текстдрав вправо
		
		Режим размера:
		W / Стрелка вверх - увеличить высоту (для спрайтов/бокса) или размер букв по Y

		S / Стрелка вниз - уменьшить высоту (для спрайтов/бокса) или размер букв по Y

		A / Стрелка влево - уменьшить ширину (для спрайтов/бокса) или размер букв по X

		D / Стрелка вправо - увеличить ширину (для спрайтов/бокса) или размер букв по X
		
		Дополнительно в режиме редактирования:
		5 - заморозить персонажа (чтобы не мешал)

		6 - разморозить персонажа
*/

#define MAX_TEXTSDRAWS 50

#define COLOR_CYAN 0x00FFFFFF
#define COLOR_GREEN 0x00FF00FF
#define COLOR_RED 0xFF0000FF
#define COLOR_YELLOW 0xFFFF00FF
#define COLOR_WHITE 0xFFFFFFFF

#define TEXT_DRAW_FONT_BANK			0
#define TEXT_DRAW_FONT_STANDARD		1
#define TEXT_DRAW_FONT_HEADING		2
#define TEXT_DRAW_FONT_SPRITE_DRAW	4

#define TD_TYPE_GLOBAL		0
#define TD_TYPE_PLAYER		1

enum TD_DATA
{
    tdID,//Для глобальных: Text:tdID, для персональных: PlayerText:tdID (храним как число)
    bool:tdActive,
    tdType,//0 - глобальный, 1 - персональный
    tdName[32],//Имя переменной для экспорта
    tdText[256],
    Float:tdX,
    Float:tdY,
    Float:tdLetterX,
    Float:tdLetterY,
    tdFont,
    tdColor,
    tdBoxColor,
    bool:tdUseBox,
    tdProportional,
    tdShadowSize,
    tdOutlineSize,
    tdAlignment,
    tdBackgroundColor,
    tdString[256],//Для спрайтов или текста
    bool:tdIsSprite,
    Float:tdWidth,
    Float:tdHeight
}

new PlayerTD[MAX_PLAYERS][MAX_TEXTSDRAWS][TD_DATA];
new CurrentTD[MAX_PLAYERS];
new EditingTD[MAX_PLAYERS];
new TDEditSubMode[MAX_PLAYERS];//0 - позиция, 1 - размер
new TDEditSpeed[MAX_PLAYERS];
new TDMenuState[MAX_PLAYERS];
new TDWaitingForInput[MAX_PLAYERS];
new TDTempString[MAX_PLAYERS][256];
new TDCreateType[MAX_PLAYERS];//0 - глобальный, 1 - персональный

new ColorNames[][32] = {
    "Белый", "Красный", "Зеленый", "Синий", "Желтый",
    "Голубой", "Розовый", "Оранжевый", "Серый", "Черный"
};

new ColorValues[] = {
    0xFFFFFFFF, 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFF00FF,
    0x00FFFFFF, 0xFF00FFFF, 0xFF9900FF, 0x808080FF, 0x000000FF
};

new ExportVarCount[MAX_PLAYERS];
new ExportVarNames[MAX_PLAYERS][MAX_TEXTSDRAWS][32];

public OnFilterScriptInit()
{
    print("\n=========================================");
    print("  TextDraw Editor v1.0");
    print("  by Alexander");
    print("=========================================\n");
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        DestroyAllTD(i);
        UnloadCustomMenuTextDraws(i);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    CurrentTD[playerid] = -1;
    EditingTD[playerid] = 0;
    TDEditSubMode[playerid] = 0;
    TDEditSpeed[playerid] = 1;
    TDMenuState[playerid] = 0;
    TDWaitingForInput[playerid] = 0;
    TDCreateType[playerid] = TD_TYPE_GLOBAL;

    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        PlayerTD[playerid][i][tdActive] = false;
        PlayerTD[playerid][i][tdID] = 0;
        format(PlayerTD[playerid][i][tdName], 32, "TextDraw_%d", i + 1);
    }

    LoadCustomMenuTextdraws(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    DestroyAllTD(playerid);
    UnloadCustomMenuTextDraws(playerid);
    return 1;
}

public OnPlayerKeyPress(playerid, key)
{
    if(key == WK_KEY_5)
    {
        TogglePlayerControllable(playerid, false);
        return 1;
    }
    if(key == WK_KEY_6)
    {
        TogglePlayerControllable(playerid, true);
        return 1;
    }
    if(key == WK_KEY_N)
    {
        ToggleTDEditMode(playerid);
        return 1;
    }
    if(key == WK_KEY_M)
    {
        ShowTDMainMenu(playerid);
        return 1;
    }

    if(key == WK_KEY_1)
    {
        SelectPreviousTD(playerid);
        return 1;
    }
    if(key == WK_KEY_2)
    {
        SelectNextTD(playerid);
        return 1;
    }

    if(key == WK_KEY_L)
    {
        DeleteCurrentTD(playerid);
        return 1;
    }

    if(key == WK_KEY_C)
    {
        CopyCurrentTD(playerid);
        return 1;
    }

    if(key == WK_KEY_E)
    {
        ExportTDToCode(playerid);
        return 1;
    }

    if(!EditingTD[playerid] || CurrentTD[playerid] == -1) return 1;

    new idx = CurrentTD[playerid];
    if(!PlayerTD[playerid][idx][tdActive]) return 1;

    new Float:speed = 1.0;
    if(TDEditSpeed[playerid] == 2) speed = 5.0;
    else if(TDEditSpeed[playerid] == 0) speed = 0.2;

    new bool:updated = false;

    if(TDEditSubMode[playerid] == 0)
    {
        if(key == WK_KEY_W || key == WK_KEY_UP)
        {
            PlayerTD[playerid][idx][tdY] -= speed;
            updated = true;
        }
        else if(key == WK_KEY_S || key == WK_KEY_DOWN)
        {
            PlayerTD[playerid][idx][tdY] += speed;
            updated = true;
        }
        else if(key == WK_KEY_A || key == WK_KEY_LEFT)
        {
            PlayerTD[playerid][idx][tdX] -= speed;
            updated = true;
        }
        else if(key == WK_KEY_D || key == WK_KEY_RIGHT)
        {
            PlayerTD[playerid][idx][tdX] += speed;
            updated = true;
        }
    }
    else if(TDEditSubMode[playerid] == 1)
    {
        if(key == WK_KEY_W || key == WK_KEY_UP)
        {
            if(PlayerTD[playerid][idx][tdIsSprite] || PlayerTD[playerid][idx][tdUseBox])
            {
                PlayerTD[playerid][idx][tdHeight] -= speed * 0.05;
            }
            else
            {
                PlayerTD[playerid][idx][tdLetterY] -= speed * 0.05;
            }
            updated = true;
        }
        else if(key == WK_KEY_S || key == WK_KEY_DOWN)
        {
            if(PlayerTD[playerid][idx][tdIsSprite] || PlayerTD[playerid][idx][tdUseBox])
            {
                PlayerTD[playerid][idx][tdHeight] += speed * 0.05;
            }
            else
            {
                PlayerTD[playerid][idx][tdLetterY] += speed * 0.05;
            }
            updated = true;
        }
        else if(key == WK_KEY_A || key == WK_KEY_LEFT)
        {
            if(PlayerTD[playerid][idx][tdIsSprite] || PlayerTD[playerid][idx][tdUseBox])
            {
                PlayerTD[playerid][idx][tdWidth] -= speed * 0.05;
            }
            else
            {
                PlayerTD[playerid][idx][tdLetterX] -= speed * 0.05;
            }
            updated = true;
        }
        else if(key == WK_KEY_D || key == WK_KEY_RIGHT)
        {
            if(PlayerTD[playerid][idx][tdIsSprite] || PlayerTD[playerid][idx][tdUseBox])
            {
                PlayerTD[playerid][idx][tdWidth] += speed * 0.05;
            }
            else
            {
                PlayerTD[playerid][idx][tdLetterX] += speed * 0.05;
            }
            updated = true;
        }
    }

    if(updated)
    {
        UpdateTD(playerid, idx);
        ShowTDInfo(playerid, idx);
    }

    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    if(PlayerCustomMenuCreated[playerid] == 1)
    {
        OnPlayerChangeKeyCustomMenu(playerid, newkeys);
        return 1;
    }
    return 1;
}

public OnPlayerText(playerid, text[])
{
    if(TDWaitingForInput[playerid] == 1)
    {
        new idx = CurrentTD[playerid];
        if(idx != -1 && PlayerTD[playerid][idx][tdActive])
        {
            format(PlayerTD[playerid][idx][tdString], 256, text);
            UpdateTD(playerid, idx);
            TDWaitingForInput[playerid] = 0;

            HideCustomMenuForPlayer(playerid);
            ClearCustomMenuTempDate(playerid);

            SendClientMessage(playerid, COLOR_GREEN, "Текст установлен!");
        }
        return 0;
    }
    else if(TDWaitingForInput[playerid] == 2)
    {
        new idx = CurrentTD[playerid];
        if(idx != -1 && PlayerTD[playerid][idx][tdActive])
        {
            format(PlayerTD[playerid][idx][tdString], 256, text);
            PlayerTD[playerid][idx][tdIsSprite] = true;
            PlayerTD[playerid][idx][tdFont] = TEXT_DRAW_FONT_SPRITE_DRAW;

            UpdateTD(playerid, idx);
            TDWaitingForInput[playerid] = 0;

            HideCustomMenuForPlayer(playerid);
            ClearCustomMenuTempDate(playerid);

            SendClientMessage(playerid, COLOR_GREEN, "Спрайт создан!");
        }
        return 0;
    }
    else if(TDWaitingForInput[playerid] == 3)
    {
        new idx = CurrentTD[playerid];
        if(idx != -1)
        {
            format(PlayerTD[playerid][idx][tdName], 32, text);
            format(ExportVarNames[playerid][idx], 32, text);
            TDWaitingForInput[playerid] = 0;
            SendClientMessage(playerid, COLOR_GREEN, "Имя переменной сохранено!");
        }
        return 0;
    }
    return 1;
}

ShowTDMainMenu(playerid)
{
    CreatePlayerCustomMenu(playerid, 10);

    SetPlayerStringCustomMenu(playerid, 0, "TextDraw Editor");
    SetPlayerStringCustomMenu(playerid, 1, "Создать глобальный текст (Bank)");
    SetPlayerStringCustomMenu(playerid, 2, "Создать глобальный текст (Standard)");
    SetPlayerStringCustomMenu(playerid, 3, "Создать глобальный текст (Heading)");
    SetPlayerStringCustomMenu(playerid, 4, "Создать глобальный спрайт (TXD)");
    SetPlayerStringCustomMenu(playerid, 5, "Создать персональный текст");
    SetPlayerStringCustomMenu(playerid, 6, "Создать персональный спрайт");
    SetPlayerStringCustomMenu(playerid, 7, "Выбрать текстдрав");
    SetPlayerStringCustomMenu(playerid, 8, "Режим редактирования");
    SetPlayerStringCustomMenu(playerid, 9, "Настройки");
    SetPlayerStringCustomMenu(playerid, 10, "Удалить текстдрав");

    TDMenuState[playerid] = 1;
    ShowCustomMenuForPlayer(playerid);
    return 1;
}

ShowTDSettingsMenu(playerid)
{
    CreatePlayerCustomMenu(playerid, 8);

    new title[64];
    format(title, 64, "Настройки (Скорость: %s)",
        TDEditSpeed[playerid] == 0 ? ("Медленная") : (TDEditSpeed[playerid] == 1 ? ("Нормальная") : ("Быстрая")));

    SetPlayerStringCustomMenu(playerid, 0, title);
    SetPlayerStringCustomMenu(playerid, 1, "Скорость: Медленная (0.2)");
    SetPlayerStringCustomMenu(playerid, 2, "Скорость: Нормальная (1.0)");
    SetPlayerStringCustomMenu(playerid, 3, "Скорость: Быстрая (5.0)");
    SetPlayerStringCustomMenu(playerid, 4, "Режим: Перемещение");
    SetPlayerStringCustomMenu(playerid, 5, "Режим: Размер");
    SetPlayerStringCustomMenu(playerid, 6, "Цвет текста");
    SetPlayerStringCustomMenu(playerid, 7, "Цвет фона (бокс)");
    SetPlayerStringCustomMenu(playerid, 8, "Изменить имя переменной");

    TDMenuState[playerid] = 5;
    ShowCustomMenuForPlayer(playerid);
    return 1;
}

ShowColorMenu(playerid, type)
{
    CreatePlayerCustomMenu(playerid, 10);

    SetPlayerStringCustomMenu(playerid, 0, "Выберите цвет");
    for(new i = 0; i < 10; i++)
    {
        SetPlayerStringCustomMenu(playerid, i + 1, ColorNames[i]);
    }

    TDMenuState[playerid] = 7 + type;
    ShowCustomMenuForPlayer(playerid);
    return 1;
}

ShowTDListMenu(playerid)
{
    new count = 0;
    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        if(PlayerTD[playerid][i][tdActive]) count++;
    }

    if(count == 0)
    {
        SendClientMessage(playerid, COLOR_RED, "У вас нет текстдравов!");
        return 0;
    }

    new menuItems = (count > 7) ? 7 : count;
    CreatePlayerCustomMenu(playerid, menuItems + 1);

    SetPlayerStringCustomMenu(playerid, 0, "Ваши текстдравы");

    new itemIndex = 1;
    for(new i = 0; i < MAX_TEXTSDRAWS && itemIndex <= menuItems; i++)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            new itemName[64];
            if(PlayerTD[playerid][i][tdIsSprite])
            {
                format(itemName, 64, "#%d: Спрайт [%s]", i + 1, PlayerTD[playerid][i][tdName]);
            }
            else
            {
                new text[32];
                strmid(text, PlayerTD[playerid][i][tdString], 0, 15, 32);
                format(itemName, 64, "#%d: %s [%s]", i + 1, text, PlayerTD[playerid][i][tdName]);
            }
            SetPlayerStringCustomMenu(playerid, itemIndex, itemName);
            itemIndex++;
        }
    }

    TDMenuState[playerid] = 3;
    ShowCustomMenuForPlayer(playerid);
    return 1;
}

ShowDeleteConfirmation(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Нет выбранного текстдрава!");
        return 0;
    }

    CreatePlayerCustomMenu(playerid, 3);

    new confirmMsg[64];
    format(confirmMsg, 64, "Удалить текстдрав #%d?", CurrentTD[playerid] + 1);
    SetPlayerStringCustomMenu(playerid, 0, confirmMsg);
    SetPlayerStringCustomMenu(playerid, 1, "Да");
    SetPlayerStringCustomMenu(playerid, 2, "Нет");

    TDMenuState[playerid] = 4;
    ShowCustomMenuForPlayer(playerid);
    return 1;
}

forward ShowTDSettingsMenuEx(playerid);
public ShowTDSettingsMenuEx(playerid)
{
    ShowTDSettingsMenu(playerid);
}

forward ShowTDListMenuEx(playerid);
public ShowTDListMenuEx(playerid)
{
    ShowTDListMenu(playerid);
}

forward ShowColorMenuEx(playerid, type);
public ShowColorMenuEx(playerid, type)
{
    ShowColorMenu(playerid, type);
}

public OnPlayerEnterCustomMenu(playerid, playercustommenuid)
{
    new id = playercustommenuid;

    if(TDMenuState[playerid] == 1)
    {
        HideCustomMenuForPlayer(playerid);
        ClearCustomMenuTempDate(playerid);

        if(id == 1)
        {
            CreateNewTextTD(playerid, TD_TYPE_GLOBAL, TEXT_DRAW_FONT_BANK, "Bank Text");
        }
        else if(id == 2)
        {
            CreateNewTextTD(playerid, TD_TYPE_GLOBAL, TEXT_DRAW_FONT_STANDARD, "Standard Text");
        }
        else if(id == 3)
        {
            CreateNewTextTD(playerid, TD_TYPE_GLOBAL, TEXT_DRAW_FONT_HEADING, "Heading Text");
        }
        else if(id == 4)
        {
            CreateNewSpriteTD(playerid, TD_TYPE_GLOBAL);
        }
        else if(id == 5)
        {
            CreateNewTextTD(playerid, TD_TYPE_PLAYER, TEXT_DRAW_FONT_STANDARD, "Player Text");
        }
        else if(id == 6)
        {
            CreateNewSpriteTD(playerid, TD_TYPE_PLAYER);
        }
        else if(id == 7)
        {
            SetTimerEx("ShowTDListMenuEx", 100, 0, "d", playerid);
        }
        else if(id == 8)
        {
            ToggleTDEditMode(playerid);
        }
        else if(id == 9)
        {
            SetTimerEx("ShowTDSettingsMenuEx", 100, 0, "d", playerid);
        }
        else if(id == 10)
        {
            ShowDeleteConfirmation(playerid);
        }
    }
    else if(TDMenuState[playerid] == 3)
    {
        new count = 0;
        new selectedIdx = -1;

        for(new i = 0; i < MAX_TEXTSDRAWS; i++)
        {
            if(PlayerTD[playerid][i][tdActive])
            {
                count++;
                if(count == id)
                {
                    selectedIdx = i;
                    break;
                }
            }
        }

        if(selectedIdx != -1)
        {
            CurrentTD[playerid] = selectedIdx;
            HideCustomMenuForPlayer(playerid);
            ClearCustomMenuTempDate(playerid);

            ShowTDInfo(playerid, selectedIdx);
            SendClientMessage(playerid, COLOR_GREEN, "Текстдрав выбран! Используйте M для меню.");
        }
    }
    else if(TDMenuState[playerid] == 4)
    {
        HideCustomMenuForPlayer(playerid);
        ClearCustomMenuTempDate(playerid);

        if(id == 1)
        {
            DeleteCurrentTD(playerid);
        }
    }
    else if(TDMenuState[playerid] == 5)
    {
        HideCustomMenuForPlayer(playerid);
        ClearCustomMenuTempDate(playerid);

        if(id == 1)
        {
            TDEditSpeed[playerid] = 0;
            SendClientMessage(playerid, COLOR_GREEN, "Скорость: Медленная (0.2)");
        }
        else if(id == 2)
        {
            TDEditSpeed[playerid] = 1;
            SendClientMessage(playerid, COLOR_GREEN, "Скорость: Нормальная (1.0)");
        }
        else if(id == 3)
        {
            TDEditSpeed[playerid] = 2;
            SendClientMessage(playerid, COLOR_GREEN, "Скорость: Быстрая (5.0)");
        }
        else if(id == 4)
        {
            TDEditSubMode[playerid] = 0;
            SendClientMessage(playerid, COLOR_GREEN, "Режим: Перемещение (WASD)");
        }
        else if(id == 5)
        {
            TDEditSubMode[playerid] = 1;
            SendClientMessage(playerid, COLOR_GREEN, "Режим: Размер (WASD)");
        }
        else if(id == 6)
        {
            SetTimerEx("ShowColorMenuEx", 100, 0, "dd", playerid, 0);
        }
        else if(id == 7)
        {
            SetTimerEx("ShowColorMenuEx", 100, 0, "dd", playerid, 1);
        }
        else if(id == 8)
        {
            if(CurrentTD[playerid] != -1)
            {
                TDWaitingForInput[playerid] = 3;
                SendClientMessage(playerid, COLOR_YELLOW, "Введите новое имя переменной:");
            }
        }
    }
    else if(TDMenuState[playerid] == 7)
    {
        HideCustomMenuForPlayer(playerid);
        ClearCustomMenuTempDate(playerid);

        if(CurrentTD[playerid] != -1)
        {
            new idx = CurrentTD[playerid];
            PlayerTD[playerid][idx][tdColor] = ColorValues[id - 1];
            UpdateTD(playerid, idx);
            SendClientMessage(playerid, COLOR_GREEN, "Цвет текста изменен!");
        }
    }
    else if(TDMenuState[playerid] == 8)
    {
        HideCustomMenuForPlayer(playerid);
        ClearCustomMenuTempDate(playerid);

        if(CurrentTD[playerid] != -1)
        {
            new idx = CurrentTD[playerid];
            PlayerTD[playerid][idx][tdBoxColor] = ColorValues[id - 1];
            UpdateTD(playerid, idx);
            SendClientMessage(playerid, COLOR_GREEN, "Цвет фона изменен!");
        }
    }

    return 1;
}

public OnPlayerExitCustomMenu(playerid)
{
    HideCustomMenuForPlayer(playerid);
    ClearCustomMenuTempDate(playerid);
    TDMenuState[playerid] = 0;
    SendClientMessage(playerid, COLOR_WHITE, "Меню закрыто");
    return 1;
}

CreateNewTextTD(playerid, type, font, const defaultText[])
{
    new freeSlot = -1;
    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        if(!PlayerTD[playerid][i][tdActive])
        {
            freeSlot = i;
            break;
        }
    }

    if(freeSlot == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Достигнут лимит текстдравов (50)!");
        return 0;
    }

    PlayerTD[playerid][freeSlot][tdActive] = true;
    PlayerTD[playerid][freeSlot][tdType] = type;
    PlayerTD[playerid][freeSlot][tdIsSprite] = false;
    PlayerTD[playerid][freeSlot][tdUseBox] = false;
    PlayerTD[playerid][freeSlot][tdX] = 320.0;
    PlayerTD[playerid][freeSlot][tdY] = 240.0;
    PlayerTD[playerid][freeSlot][tdLetterX] = 0.5;
    PlayerTD[playerid][freeSlot][tdLetterY] = 1.0;
    PlayerTD[playerid][freeSlot][tdFont] = font;
    PlayerTD[playerid][freeSlot][tdColor] = 0xFFFFFFFF;
    PlayerTD[playerid][freeSlot][tdBoxColor] = 0x80808080;
    PlayerTD[playerid][freeSlot][tdProportional] = 1;
    PlayerTD[playerid][freeSlot][tdShadowSize] = 0;
    PlayerTD[playerid][freeSlot][tdOutlineSize] = 0;
    PlayerTD[playerid][freeSlot][tdAlignment] = 1;
    PlayerTD[playerid][freeSlot][tdBackgroundColor] = 0x000000FF;
    format(PlayerTD[playerid][freeSlot][tdString], 256, defaultText);
    format(PlayerTD[playerid][freeSlot][tdName], 32, "TextDraw_%d", freeSlot + 1);

    if(type == TD_TYPE_GLOBAL)
    {
        PlayerTD[playerid][freeSlot][tdID] = _:TextDrawCreate(PlayerTD[playerid][freeSlot][tdX],
            PlayerTD[playerid][freeSlot][tdY], PlayerTD[playerid][freeSlot][tdString]);
    }
    else
    {
        PlayerTD[playerid][freeSlot][tdID] = _:CreatePlayerTextDraw(playerid,
            PlayerTD[playerid][freeSlot][tdX],
            PlayerTD[playerid][freeSlot][tdY],
            PlayerTD[playerid][freeSlot][tdString]);
    }

    ApplyTDSettings(playerid, freeSlot);

    if(type == TD_TYPE_GLOBAL)
    {
        TextDrawShowForPlayer(playerid, Text:PlayerTD[playerid][freeSlot][tdID]);
    }
    else
    {
        PlayerTextDrawShow(playerid, PlayerText:PlayerTD[playerid][freeSlot][tdID]);
    }

    CurrentTD[playerid] = freeSlot;

    TDWaitingForInput[playerid] = 1;
    SendClientMessage(playerid, COLOR_YELLOW, "Введите текст для текстдрава:");

    new msg[128];
	new typeStr[16];
	if(type == TD_TYPE_GLOBAL)
	    typeStr = "глобальный";
	else
	    typeStr = "персональный";

	format(msg, 128, "Создан %s текстдрав #%d (Шрифт %d)", typeStr, freeSlot + 1, font);
	SendClientMessage(playerid, COLOR_GREEN, msg);

    return 1;
}

CreateNewSpriteTD(playerid, type)
{
    new freeSlot = -1;
    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        if(!PlayerTD[playerid][i][tdActive])
        {
            freeSlot = i;
            break;
        }
    }

    if(freeSlot == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Достигнут лимит текстдравов (50)!");
        return 0;
    }

    PlayerTD[playerid][freeSlot][tdActive] = true;
    PlayerTD[playerid][freeSlot][tdType] = type;
    PlayerTD[playerid][freeSlot][tdIsSprite] = true;
    PlayerTD[playerid][freeSlot][tdUseBox] = false;
    PlayerTD[playerid][freeSlot][tdX] = 320.0;
    PlayerTD[playerid][freeSlot][tdY] = 240.0;
    PlayerTD[playerid][freeSlot][tdWidth] = 100.0;
    PlayerTD[playerid][freeSlot][tdHeight] = 50.0;
    PlayerTD[playerid][freeSlot][tdFont] = TEXT_DRAW_FONT_SPRITE_DRAW;
    PlayerTD[playerid][freeSlot][tdColor] = 0xFFFFFFFF;
    PlayerTD[playerid][freeSlot][tdProportional] = 1;
    PlayerTD[playerid][freeSlot][tdShadowSize] = 0;
    PlayerTD[playerid][freeSlot][tdOutlineSize] = 0;
    PlayerTD[playerid][freeSlot][tdAlignment] = 1;
    format(PlayerTD[playerid][freeSlot][tdString], 256, "VMP/TXD/black.TXD:black:black");
    format(PlayerTD[playerid][freeSlot][tdName], 32, "Sprite_%d", freeSlot + 1);

    if(type == TD_TYPE_GLOBAL)
    {
        PlayerTD[playerid][freeSlot][tdID] = _:TextDrawCreate(PlayerTD[playerid][freeSlot][tdX],
            PlayerTD[playerid][freeSlot][tdY], PlayerTD[playerid][freeSlot][tdString]);
    }
    else
    {
        PlayerTD[playerid][freeSlot][tdID] = _:CreatePlayerTextDraw(playerid,
            PlayerTD[playerid][freeSlot][tdX],
            PlayerTD[playerid][freeSlot][tdY],
            PlayerTD[playerid][freeSlot][tdString]);
    }

    ApplyTDSettings(playerid, freeSlot);

    if(type == TD_TYPE_GLOBAL)
    {
        TextDrawShowForPlayer(playerid, Text:PlayerTD[playerid][freeSlot][tdID]);
    }
    else
    {
        PlayerTextDrawShow(playerid, PlayerText:PlayerTD[playerid][freeSlot][tdID]);
    }

    CurrentTD[playerid] = freeSlot;

    TDWaitingForInput[playerid] = 2;
    SendClientMessage(playerid, COLOR_YELLOW, "Введите строку спрайта (например: VMP/TXD/black.TXD:black:black):");

    new msg[128];
	new typeStr[16];
	if(type == TD_TYPE_GLOBAL)
	    typeStr = "глобальный";
	else
	    typeStr = "персональный";

	format(msg, 128, "Создан %s спрайт #%d", typeStr, freeSlot + 1);
	SendClientMessage(playerid, COLOR_GREEN, msg);

    return 1;
}

ApplyTDSettings(playerid, idx)
{
    if(PlayerTD[playerid][idx][tdType] == TD_TYPE_GLOBAL)
    {
        TextDrawFont(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdFont]);
        TextDrawColor(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdColor]);
        TextDrawSetProportional(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdProportional]);
        TextDrawSetShadow(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdShadowSize]);
        TextDrawAlignment(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdAlignment]);

        if(PlayerTD[playerid][idx][tdIsSprite])
        {
            TextDrawTextSize(Text:PlayerTD[playerid][idx][tdID],
                PlayerTD[playerid][idx][tdWidth], PlayerTD[playerid][idx][tdHeight]);
            TextDrawSetString(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdString]);
        }
        else
        {
            TextDrawLetterSize(Text:PlayerTD[playerid][idx][tdID],
                PlayerTD[playerid][idx][tdLetterX], PlayerTD[playerid][idx][tdLetterY]);
            TextDrawSetString(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdString]);
        }

        if(PlayerTD[playerid][idx][tdUseBox])
        {
            TextDrawUseBox(Text:PlayerTD[playerid][idx][tdID], 1);
            TextDrawBoxColor(Text:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdBoxColor]);
        }
    }
    else
    {
        PlayerTextDrawFont(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdFont]);
        PlayerTextDrawColor(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdColor]);
        PlayerTextDrawSetProportional(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdProportional]);
        PlayerTextDrawSetShadow(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdShadowSize]);
        PlayerTextDrawAlignment(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdAlignment]);

        if(PlayerTD[playerid][idx][tdIsSprite])
        {
            PlayerTextDrawTextSize(playerid, PlayerText:PlayerTD[playerid][idx][tdID],
                PlayerTD[playerid][idx][tdWidth], PlayerTD[playerid][idx][tdHeight]);
            PlayerTextDrawSetString(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdString]);
        }
        else
        {
            PlayerTextDrawLetterSize(playerid, PlayerText:PlayerTD[playerid][idx][tdID],
                PlayerTD[playerid][idx][tdLetterX], PlayerTD[playerid][idx][tdLetterY]);
            PlayerTextDrawSetString(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdString]);
        }

        if(PlayerTD[playerid][idx][tdUseBox])
        {
            PlayerTextDrawUseBox(playerid, PlayerText:PlayerTD[playerid][idx][tdID], 1);
            PlayerTextDrawBoxColor(playerid, PlayerText:PlayerTD[playerid][idx][tdID], PlayerTD[playerid][idx][tdBoxColor]);
        }
    }
}

UpdateTD(playerid, idx)
{
    if(PlayerTD[playerid][idx][tdType] == TD_TYPE_GLOBAL)
    {
        TextDrawDestroy(Text:PlayerTD[playerid][idx][tdID]);

        if(PlayerTD[playerid][idx][tdIsSprite])
        {
            PlayerTD[playerid][idx][tdID] = _:TextDrawCreate(PlayerTD[playerid][idx][tdX],
                PlayerTD[playerid][idx][tdY], PlayerTD[playerid][idx][tdString]);
        }
        else
        {
            PlayerTD[playerid][idx][tdID] = _:TextDrawCreate(PlayerTD[playerid][idx][tdX],
                PlayerTD[playerid][idx][tdY], PlayerTD[playerid][idx][tdString]);
        }

        ApplyTDSettings(playerid, idx);
        TextDrawShowForPlayer(playerid, Text:PlayerTD[playerid][idx][tdID]);
    }
    else
    {
        PlayerTextDrawDestroy(playerid, PlayerText:PlayerTD[playerid][idx][tdID]);

        if(PlayerTD[playerid][idx][tdIsSprite])
        {
            PlayerTD[playerid][idx][tdID] = _:CreatePlayerTextDraw(playerid,
                PlayerTD[playerid][idx][tdX],
                PlayerTD[playerid][idx][tdY],
                PlayerTD[playerid][idx][tdString]);
        }
        else
        {
            PlayerTD[playerid][idx][tdID] = _:CreatePlayerTextDraw(playerid,
                PlayerTD[playerid][idx][tdX],
                PlayerTD[playerid][idx][tdY],
                PlayerTD[playerid][idx][tdString]);
        }

        ApplyTDSettings(playerid, idx);
        PlayerTextDrawShow(playerid, PlayerText:PlayerTD[playerid][idx][tdID]);
    }
}

DeleteCurrentTD(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Нет выбранного текстдрава!");
        return 0;
    }

    new idx = CurrentTD[playerid];

    if(PlayerTD[playerid][idx][tdType] == TD_TYPE_GLOBAL)
    {
        TextDrawDestroy(Text:PlayerTD[playerid][idx][tdID]);
    }
    else
    {
        PlayerTextDrawDestroy(playerid, PlayerText:PlayerTD[playerid][idx][tdID]);
    }

    PlayerTD[playerid][idx][tdActive] = false;

    SendClientMessage(playerid, COLOR_GREEN, "Текстдрав удален!");

    SelectNextTD(playerid);

    return 1;
}

CopyCurrentTD(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Нет выбранного текстдрава!");
        return 0;
    }

    new freeSlot = -1;
    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        if(!PlayerTD[playerid][i][tdActive])
        {
            freeSlot = i;
            break;
        }
    }

    if(freeSlot == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Достигнут лимит текстдравов!");
        return 0;
    }

    new src = CurrentTD[playerid];

    PlayerTD[playerid][freeSlot][tdActive] = true;
    PlayerTD[playerid][freeSlot][tdType] = PlayerTD[playerid][src][tdType];
    PlayerTD[playerid][freeSlot][tdIsSprite] = PlayerTD[playerid][src][tdIsSprite];
    PlayerTD[playerid][freeSlot][tdUseBox] = PlayerTD[playerid][src][tdUseBox];
    PlayerTD[playerid][freeSlot][tdX] = PlayerTD[playerid][src][tdX] + 10.0;
    PlayerTD[playerid][freeSlot][tdY] = PlayerTD[playerid][src][tdY] + 10.0;
    PlayerTD[playerid][freeSlot][tdLetterX] = PlayerTD[playerid][src][tdLetterX];
    PlayerTD[playerid][freeSlot][tdLetterY] = PlayerTD[playerid][src][tdLetterY];
    PlayerTD[playerid][freeSlot][tdFont] = PlayerTD[playerid][src][tdFont];
    PlayerTD[playerid][freeSlot][tdColor] = PlayerTD[playerid][src][tdColor];
    PlayerTD[playerid][freeSlot][tdBoxColor] = PlayerTD[playerid][src][tdBoxColor];
    PlayerTD[playerid][freeSlot][tdProportional] = PlayerTD[playerid][src][tdProportional];
    PlayerTD[playerid][freeSlot][tdShadowSize] = PlayerTD[playerid][src][tdShadowSize];
    PlayerTD[playerid][freeSlot][tdOutlineSize] = PlayerTD[playerid][src][tdOutlineSize];
    PlayerTD[playerid][freeSlot][tdAlignment] = PlayerTD[playerid][src][tdAlignment];
    PlayerTD[playerid][freeSlot][tdBackgroundColor] = PlayerTD[playerid][src][tdBackgroundColor];
    PlayerTD[playerid][freeSlot][tdWidth] = PlayerTD[playerid][src][tdWidth];
    PlayerTD[playerid][freeSlot][tdHeight] = PlayerTD[playerid][src][tdHeight];
    format(PlayerTD[playerid][freeSlot][tdString], 256, PlayerTD[playerid][src][tdString]);
    format(PlayerTD[playerid][freeSlot][tdName], 32, "Copy_%s", PlayerTD[playerid][src][tdName]);

    if(PlayerTD[playerid][freeSlot][tdType] == TD_TYPE_GLOBAL)
    {
        if(PlayerTD[playerid][freeSlot][tdIsSprite])
        {
            PlayerTD[playerid][freeSlot][tdID] = _:TextDrawCreate(PlayerTD[playerid][freeSlot][tdX],
                PlayerTD[playerid][freeSlot][tdY], PlayerTD[playerid][freeSlot][tdString]);
        }
        else
        {
            PlayerTD[playerid][freeSlot][tdID] = _:TextDrawCreate(PlayerTD[playerid][freeSlot][tdX],
                PlayerTD[playerid][freeSlot][tdY], PlayerTD[playerid][freeSlot][tdString]);
        }
    }
    else
    {
        if(PlayerTD[playerid][freeSlot][tdIsSprite])
        {
            PlayerTD[playerid][freeSlot][tdID] = _:CreatePlayerTextDraw(playerid,
                PlayerTD[playerid][freeSlot][tdX],
                PlayerTD[playerid][freeSlot][tdY],
                PlayerTD[playerid][freeSlot][tdString]);
        }
        else
        {
            PlayerTD[playerid][freeSlot][tdID] = _:CreatePlayerTextDraw(playerid,
                PlayerTD[playerid][freeSlot][tdX],
                PlayerTD[playerid][freeSlot][tdY],
                PlayerTD[playerid][freeSlot][tdString]);
        }
    }

    ApplyTDSettings(playerid, freeSlot);

    if(PlayerTD[playerid][freeSlot][tdType] == TD_TYPE_GLOBAL)
    {
        TextDrawShowForPlayer(playerid, Text:PlayerTD[playerid][freeSlot][tdID]);
    }
    else
    {
        PlayerTextDrawShow(playerid, PlayerText:PlayerTD[playerid][freeSlot][tdID]);
    }

    CurrentTD[playerid] = freeSlot;

    SendClientMessage(playerid, COLOR_GREEN, "Текстдрав скопирован!");
    return 1;
}

ToggleTDEditMode(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Сначала выберите текстдрав!");
        return 0;
    }

    EditingTD[playerid] = !EditingTD[playerid];

    if(EditingTD[playerid])
    {
        TogglePlayerControllable(playerid, false);

        SendClientMessage(playerid, COLOR_GREEN, "========== РЕЖИМ РЕДАКТИРОВАНИЯ ВКЛЮЧЕН ==========");
        SendClientMessage(playerid, COLOR_WHITE, "1/2 - переключить режим (позиция/размер)");
        SendClientMessage(playerid, COLOR_WHITE, "WASD - перемещение/изменение размера");
        SendClientMessage(playerid, COLOR_YELLOW, "Используйте меню (M) для настроек");
        SendClientMessage(playerid, COLOR_YELLOW, "E - экспорт в код | L - удалить");
        ShowTDInfo(playerid, CurrentTD[playerid]);
    }
    else
    {
        TogglePlayerControllable(playerid, true);

        SendClientMessage(playerid, COLOR_RED, "========== РЕЖИМ РЕДАКТИРОВАНИЯ ВЫКЛЮЧЕН ==========");
    }

    return 1;
}

SelectNextTD(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        for(new i = 0; i < MAX_TEXTSDRAWS; i++)
        {
            if(PlayerTD[playerid][i][tdActive])
            {
                CurrentTD[playerid] = i;
                ShowTDInfo(playerid, i);
                return 1;
            }
        }
        SendClientMessage(playerid, COLOR_RED, "Нет текстдравов!");
        return 0;
    }

    new next = CurrentTD[playerid] + 1;
    for(new i = next; i < MAX_TEXTSDRAWS; i++)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            CurrentTD[playerid] = i;
            ShowTDInfo(playerid, i);
            return 1;
        }
    }

    for(new i = 0; i < CurrentTD[playerid]; i++)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            CurrentTD[playerid] = i;
            ShowTDInfo(playerid, i);
            return 1;
        }
    }

    SendClientMessage(playerid, COLOR_RED, "Нет других текстдравов!");
    return 0;
}

SelectPreviousTD(playerid)
{
    if(CurrentTD[playerid] == -1)
    {
        for(new i = MAX_TEXTSDRAWS - 1; i >= 0; i--)
        {
            if(PlayerTD[playerid][i][tdActive])
            {
                CurrentTD[playerid] = i;
                ShowTDInfo(playerid, i);
                return 1;
            }
        }
        SendClientMessage(playerid, COLOR_RED, "Нет текстдравов!");
        return 0;
    }

    new prev = CurrentTD[playerid] - 1;
    for(new i = prev; i >= 0; i--)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            CurrentTD[playerid] = i;
            ShowTDInfo(playerid, i);
            return 1;
        }
    }

    for(new i = MAX_TEXTSDRAWS - 1; i > CurrentTD[playerid]; i--)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            CurrentTD[playerid] = i;
            ShowTDInfo(playerid, i);
            return 1;
        }
    }

    SendClientMessage(playerid, COLOR_RED, "Нет других текстдравов!");
    return 0;
}

ShowTDInfo(playerid, idx)
{
    new msg[256];
	new globalType[8];
	if(PlayerTD[playerid][idx][tdType] == TD_TYPE_GLOBAL)
	    globalType = "GLOBAL";
	else
	    globalType = "PLAYER";

	new fontName[16];
	switch(PlayerTD[playerid][idx][tdFont])
	{
	    case TEXT_DRAW_FONT_BANK: fontName = "Bank";
	    case TEXT_DRAW_FONT_STANDARD: fontName = "Standard";
	    case TEXT_DRAW_FONT_HEADING: fontName = "Heading";
	    default: fontName = "Unknown";
	}

	format(msg, 256, "Текстдрав #%d [%s] [%s] | X:%.1f Y:%.1f | Буквы:%.2fx%.2f",
	    idx + 1,
	    globalType,
	    fontName,
	    PlayerTD[playerid][idx][tdX], PlayerTD[playerid][idx][tdY],
	    PlayerTD[playerid][idx][tdLetterX], PlayerTD[playerid][idx][tdLetterY]);
	SendClientMessage(playerid, COLOR_CYAN, msg);
}

DestroyAllTD(playerid)
{
    for(new i = 0; i < MAX_TEXTSDRAWS; i++)
    {
        if(PlayerTD[playerid][i][tdActive])
        {
            if(PlayerTD[playerid][i][tdType] == TD_TYPE_GLOBAL)
            {
                TextDrawDestroy(Text:PlayerTD[playerid][i][tdID]);
            }
            else
            {
                PlayerTextDrawDestroy(playerid, PlayerText:PlayerTD[playerid][i][tdID]);
            }
            PlayerTD[playerid][i][tdActive] = false;
        }
    }
    CurrentTD[playerid] = -1;
}


ExportTDToCode(playerid)
{
    new filename[64], playerName[MAX_PLAYER_NAME];
    GetPlayerName(playerid, playerName, 24);
    format(filename, 64, "TD_Export_%s.pwn", playerName);

    new File:file = fopen(filename, io_write);
    if(file)
    {
        new line[1024], count = 0;

        fwrite(file, "// TextDraw Editor v1.0 Export\n");
        fwrite(file, "// Generated by Alexander\n\n");

        new globalCount = 0;
        for(new i = 0; i < MAX_TEXTSDRAWS; i++)
        {
            if(PlayerTD[playerid][i][tdActive] && PlayerTD[playerid][i][tdType] == TD_TYPE_GLOBAL)
            {
                format(line, 1024, "new Text:%s;\n", PlayerTD[playerid][i][tdName]);
                fwrite(file, line);
                globalCount++;
            }
        }

        if(globalCount > 0) fwrite(file, "\n");

        new playerCount = 0;
        for(new i = 0; i < MAX_TEXTSDRAWS; i++)
        {
            if(PlayerTD[playerid][i][tdActive] && PlayerTD[playerid][i][tdType] == TD_TYPE_PLAYER)
            {
                format(line, 1024, "new PlayerText:%s[MAX_PLAYERS];\n", PlayerTD[playerid][i][tdName]);
                fwrite(file, line);
                playerCount++;
            }
        }

        if(playerCount > 0) fwrite(file, "\n");

        if(globalCount > 0)
        {
            fwrite(file, "public OnGameModeInit()\n{\n");

            for(new i = 0; i < MAX_TEXTSDRAWS; i++)
            {
                if(PlayerTD[playerid][i][tdActive] && PlayerTD[playerid][i][tdType] == TD_TYPE_GLOBAL)
                {
                    format(line, 1024, "    %s = TextDrawCreate(%.2f, %.2f, \"%s\");\n",
                        PlayerTD[playerid][i][tdName],
                        PlayerTD[playerid][i][tdX],
                        PlayerTD[playerid][i][tdY],
                        PlayerTD[playerid][i][tdString]);
                    fwrite(file, line);

                    if(PlayerTD[playerid][i][tdIsSprite])
                    {
                        format(line, 1024, "    TextDrawFont(%s, %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdFont]);
                        fwrite(file, line);
                        format(line, 1024, "    TextDrawTextSize(%s, %.2f, %.2f);\n",
                            PlayerTD[playerid][i][tdName],
                            PlayerTD[playerid][i][tdWidth],
                            PlayerTD[playerid][i][tdHeight]);
                        fwrite(file, line);
                    }
                    else
                    {
                        format(line, 1024, "    TextDrawFont(%s, %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdFont]);
                        fwrite(file, line);
                        format(line, 1024, "    TextDrawLetterSize(%s, %.2f, %.2f);\n",
                            PlayerTD[playerid][i][tdName],
                            PlayerTD[playerid][i][tdLetterX],
                            PlayerTD[playerid][i][tdLetterY]);
                        fwrite(file, line);
                    }

                    format(line, 1024, "    TextDrawColor(%s, 0x%x);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdColor]);
                    fwrite(file, line);
                    format(line, 1024, "    TextDrawSetProportional(%s, %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdProportional]);
                    fwrite(file, line);
                    format(line, 1024, "    TextDrawSetShadow(%s, %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdShadowSize]);
                    fwrite(file, line);
                    format(line, 1024, "    TextDrawAlignment(%s, %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdAlignment]);
                    fwrite(file, line);

                    if(PlayerTD[playerid][i][tdUseBox])
                    {
                        format(line, 1024, "    TextDrawUseBox(%s, 1);\n", PlayerTD[playerid][i][tdName]);
                        fwrite(file, line);
                        format(line, 1024, "    TextDrawBoxColor(%s, 0x%x);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdBoxColor]);
                        fwrite(file, line);
                    }

                    fwrite(file, "\n");
                }
            }

            fwrite(file, "    return 1;\n}\n\n");
        }

        if(playerCount > 0)
        {
            fwrite(file, "public OnPlayerConnect(playerid)\n{\n");

            for(new i = 0; i < MAX_TEXTSDRAWS; i++)
            {
                if(PlayerTD[playerid][i][tdActive] && PlayerTD[playerid][i][tdType] == TD_TYPE_PLAYER)
                {
                    format(line, 1024, "    %s[playerid] = CreatePlayerTextDraw(playerid, %.2f, %.2f, \"%s\");\n",
                        PlayerTD[playerid][i][tdName],
                        PlayerTD[playerid][i][tdX],
                        PlayerTD[playerid][i][tdY],
                        PlayerTD[playerid][i][tdString]);
                    fwrite(file, line);

                    if(PlayerTD[playerid][i][tdIsSprite])
                    {
                        format(line, 1024, "    PlayerTextDrawFont(playerid, %s[playerid], %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdFont]);
                        fwrite(file, line);
                        format(line, 1024, "    PlayerTextDrawTextSize(playerid, %s[playerid], %.2f, %.2f);\n",
                            PlayerTD[playerid][i][tdName],
                            PlayerTD[playerid][i][tdWidth],
                            PlayerTD[playerid][i][tdHeight]);
                        fwrite(file, line);
                    }
                    else
                    {
                        format(line, 1024, "    PlayerTextDrawFont(playerid, %s[playerid], %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdFont]);
                        fwrite(file, line);
                        format(line, 1024, "    PlayerTextDrawLetterSize(playerid, %s[playerid], %.2f, %.2f);\n",
                            PlayerTD[playerid][i][tdName],
                            PlayerTD[playerid][i][tdLetterX],
                            PlayerTD[playerid][i][tdLetterY]);
                        fwrite(file, line);
                    }

                    format(line, 1024, "    PlayerTextDrawColor(playerid, %s[playerid], 0x%x);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdColor]);
                    fwrite(file, line);
                    format(line, 1024, "    PlayerTextDrawSetProportional(playerid, %s[playerid], %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdProportional]);
                    fwrite(file, line);
                    format(line, 1024, "    PlayerTextDrawSetShadow(playerid, %s[playerid], %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdShadowSize]);
                    fwrite(file, line);
                    format(line, 1024, "    PlayerTextDrawAlignment(playerid, %s[playerid], %d);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdAlignment]);
                    fwrite(file, line);

                    if(PlayerTD[playerid][i][tdUseBox])
                    {
                        format(line, 1024, "    PlayerTextDrawUseBox(playerid, %s[playerid], 1);\n", PlayerTD[playerid][i][tdName]);
                        fwrite(file, line);
                        format(line, 1024, "    PlayerTextDrawBoxColor(playerid, %s[playerid], 0x%x);\n", PlayerTD[playerid][i][tdName], PlayerTD[playerid][i][tdBoxColor]);
                        fwrite(file, line);
                    }

                    fwrite(file, "    PlayerTextDrawShow(playerid, %s[playerid]);\n\n", PlayerTD[playerid][i][tdName]);
                }
            }

            fwrite(file, "    return 1;\n}\n\n");
        }

        if(playerCount > 0)
        {
            fwrite(file, "public OnPlayerDisconnect(playerid, reason)\n{\n");

            for(new i = 0; i < MAX_TEXTSDRAWS; i++)
            {
                if(PlayerTD[playerid][i][tdActive] && PlayerTD[playerid][i][tdType] == TD_TYPE_PLAYER)
                {
                    format(line, 1024, "    PlayerTextDrawDestroy(playerid, %s[playerid]);\n", PlayerTD[playerid][i][tdName]);
                    fwrite(file, line);
                }
            }

            fwrite(file, "    return 1;\n}\n");
        }

        fclose(file);

        new msg[128];
        format(msg, 128, "Экспортировано %d текстдравов в файл %s", globalCount + playerCount, filename);
        SendClientMessage(playerid, COLOR_GREEN, msg);
    }
    return 1;
}
