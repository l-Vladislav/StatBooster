-- EnchantDB.lua — StatBooster enchant database
-- Pool structure synced from server on login; names are local (cosmetic)

local _, SB = ...
SB.DB = {}
SB.DB.Synced = false
SB.DB.OnSyncCallback = nil -- set by UI to update indicator

-- Bitwise AND for WoW 3.3.5a (no bit library)
local function band(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bitval
        end
        bitval = bitval * 2
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return result
end
SB.band = band  -- expose for SpellbookTab

-- Scroll item → { pool, iLvlMin, iLvlMax, name }
SB.DB.Scrolls = {
    -- Pool 1: Battle (Blacksmithing)
    [100001] = { pool = 1, min = 1,  max = 25,  name = "\208\145\208\190\208\181\208\178\208\190\208\185 \208\191\209\131\208\187 (T1)" },
    [100002] = { pool = 1, min = 26, max = 45,  name = "\208\145\208\190\208\181\208\178\208\190\208\185 \208\191\209\131\208\187 (T2)" },
    [100003] = { pool = 1, min = 46, max = 65,  name = "\208\145\208\190\208\181\208\178\208\190\208\185 \208\191\209\131\208\187 (T3)" },
    [100004] = { pool = 1, min = 66, max = 92,  name = "\208\145\208\190\208\181\208\178\208\190\208\185 \208\191\209\131\208\187 (T4)" },
    -- Pool 2: Warding (Leatherworking)
    [100005] = { pool = 2, min = 1,  max = 25,  name = "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185 \208\191\209\131\208\187 (T1)" },
    [100006] = { pool = 2, min = 26, max = 45,  name = "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185 \208\191\209\131\208\187 (T2)" },
    [100007] = { pool = 2, min = 46, max = 65,  name = "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185 \208\191\209\131\208\187 (T3)" },
    [100008] = { pool = 2, min = 66, max = 92,  name = "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185 \208\191\209\131\208\187 (T4)" },
    -- Pool 3: Arcana (Enchanting)
    [100009] = { pool = 3, min = 1,  max = 25,  name = "\208\162\208\176\208\185\208\189\209\139\208\185 \208\191\209\131\208\187 (T1)" },
    [100010] = { pool = 3, min = 26, max = 45,  name = "\208\162\208\176\208\185\208\189\209\139\208\185 \208\191\209\131\208\187 (T2)" },
    [100011] = { pool = 3, min = 46, max = 65,  name = "\208\162\208\176\208\185\208\189\209\139\208\185 \208\191\209\131\208\187 (T3)" },
    [100012] = { pool = 3, min = 66, max = 92,  name = "\208\162\208\176\208\185\208\189\209\139\208\185 \208\191\209\131\208\187 (T4)" },
    -- Pool 4: Fortune (Inscription)
    [100013] = { pool = 4, min = 1,  max = 25,  name = "\208\159\209\131\208\187 \209\131\208\180\208\176\209\135\208\184 (T1)" },
    [100014] = { pool = 4, min = 26, max = 45,  name = "\208\159\209\131\208\187 \209\131\208\180\208\176\209\135\208\184 (T2)" },
    [100015] = { pool = 4, min = 46, max = 65,  name = "\208\159\209\131\208\187 \209\131\208\180\208\176\209\135\208\184 (T3)" },
    [100016] = { pool = 4, min = 66, max = 92,  name = "\208\159\209\131\208\187 \209\131\208\180\208\176\209\135\208\184 (T4)" },
    -- Recalibrator (all pools)
    [41605]  = { pool = 0, min = 1,  max = 92,  name = "\208\160\208\181\208\186\208\176\208\187\208\184\208\177\209\128\208\176\209\130\208\190\209\128" },
}

-- InventoryType string → bitmask value
SB.DB.SlotMask = {
    INVTYPE_HEAD        = 2,
    INVTYPE_NECK        = 4,
    INVTYPE_SHOULDER    = 8,
    INVTYPE_CHEST       = 1048608,
    INVTYPE_ROBE        = 1048608,
    INVTYPE_WAIST       = 64,
    INVTYPE_LEGS        = 128,
    INVTYPE_FEET        = 256,
    INVTYPE_WRIST       = 512,
    INVTYPE_HAND        = 1024,
    INVTYPE_FINGER      = 2048,
    INVTYPE_TRINKET     = 4096,
    INVTYPE_CLOAK       = 65536,
    INVTYPE_SHIELD      = 16384,
    INVTYPE_WEAPON      = 8192,
    INVTYPE_2HWEAPON    = 131072,
    INVTYPE_WEAPONMAINHAND = 2097152,
    INVTYPE_WEAPONOFFHAND  = 4194304,
    INVTYPE_HOLDABLE    = 4194304,
    INVTYPE_RANGED      = 8192,
    INVTYPE_RANGEDRIGHT = 8192,
    INVTYPE_THROWN       = 8192,
}

-- Item class constants
local WEAPON = 2
local ARMOR = 4

-- ItemClassFilter: 0=any, 2=weapon, 4=armor, 6=shield
local function MatchesClassFilter(filter, itemClass, itemSubClass, invType)
    if filter == 0 then return true end
    if filter == 2 then return itemClass == WEAPON end
    if filter == 4 then return itemClass == ARMOR end
    if filter == 6 then return itemClass == ARMOR and invType == "INVTYPE_SHIELD" end
    return false
end

-- ═══════════════════════════════════════
-- Enchant ID → Russian display name (generated from SpellItemEnchantment_custom.csv)
-- Cosmetic only — pool structure comes from server
-- Server uses 90xxx (Fortune/Arcana auras) and 91xxx (##SB## stat copies)
-- To regenerate: grep DBC CSV, strip ##SB## and pool prefixes
-- ═══════════════════════════════════════
SB.DB.EnchantNames = {
    [90001] = "+5% к скорости передвижения",
    [90002] = "+8% к скорости передвижения",
    [90003] = "Хождение по воде",
    [90004] = "+15% к скорости плавания",
    [90005] = "+3% к скорости маунта",
    [90007] = "Обнаружение незаметности",
    [90008] = "+6 ко всем сопротивлениям",
    [90009] = "+10 ко всем сопротивлениям",
    [90010] = "+6 к здоровью за 5 сек.",
    [90011] = "+10 к здоровью за 5 сек.",
    [90012] = "+2% к угрозе",
    [90013] = "+20 к блокированию",
    [90014] = "+27 к блокированию",
    [90015] = "+22 к силе атаки",
    [90016] = "+30 к силе атаки",
    [90017] = "+40 к силе атаки",
    [90018] = "-4% к угрозе",
    [90019] = "+11 к силе заклинаний",
    [90020] = "+21 к силе заклинаний",
    [90021] = "+35 к силе заклинаний",
    [90022] = "+4 к мане за 5 сек.",
    [90023] = "+6 к мане за 5 сек.",
    [90024] = "+15 ко всем сопротивлениям",
    [90025] = "+14 к здоровью за 5 сек.",
    [90026] = "+10% к регенерации здоровья",
    [90027] = "-10% к длительности страха",
    [90028] = "-10% к длительности оглушения",
    [90029] = "+10% к получению репутации",
    [90030] = "Шипы (3 урона)",
    [90031] = "Шипы (18 урона)",
    [90032] = "Шипы (25 урона)",
    [90034] = "Замедленное падение",
    [90035] = "1% отражения заклинаний",
    [90036] = "+16 к урону при ударе",
    [90037] = "Огненный удар",
    [90040] = "Огненное оружие",
    [90041] = "Похищение жизни",
    [90042] = "Леденящий холод",
    [90043] = "Нечестивое проклятие",
    [90044] = "Крестоносец",
    [90045] = "+43 к силе заклинаний",
    [90046] = "+13 к мане за 5 сек.",
    [90047] = "+60 к силе атаки",
    [90048] = "+20 ко всем сопротивлениям",
    [90049] = "+16 к здоровью за 5 сек.",
    [90050] = "+3 к периодическому исцелению",
    [90051] = "+5 к урону при ударе по вам",
    [90052] = "+5 к урону в ближнем бою",
    [90053] = "+7 к урону в ближнем бою",
    [90054] = "+3 к здоровью за 5 сек.",
    [90055] = "+2 ко всем сопротивлениям",
    [90070] = "Оплот жизни",
    [90071] = "Смертельный мороз",
    [90072] = "Палач",
    [90073] = "Убийца великанов",
    [90074] = "Чародейский взрыв",
    [90075] = "Чародейский взрыв",
    [90076] = "Чародейский взрыв",
    [90077] = "Подводное дыхание",
    [90078] = "Кольцо льда",
    [90079] = "Кольцо льда",
    [90080] = "Кольцо льда",
    [90081] = "Морозный доспех",
    [90082] = "Жертвенный огонь",
    [90083] = "Жертвенный огонь",
    [90084] = "Жертвенный огонь",
    [90085] = "Жертвенный огонь",
    [90086] = "Кровавый союз",
    [90087] = "Кровавый союз",
    [90088] = "Кровавый союз",
    [90089] = "Кровавый союз",
    [90090] = "Чародейский взрыв",
    -- Arcane Vellum pool (Pool 3) — school spell damage
    [90100] = "+3 к урону огнем",
    [90101] = "+3 к урону льдом",
    [90102] = "+3 к урону природой",
    [90103] = "+3 к урону тенью",
    [90104] = "+3 к урону тайной магией",
    [90105] = "+3 к урону светом",
    [90106] = "+5 к урону огнем",
    [90107] = "+5 к урону льдом",
    [90108] = "+5 к урону природой",
    [90109] = "+5 к урону тенью",
    [90110] = "+5 к урону тайной магией",
    [90111] = "+5 к урону светом",
    [90112] = "+7 к урону огнем",
    [90113] = "+7 к урону льдом",
    [90114] = "+7 к урону природой",
    [90115] = "+7 к урону тенью",
    [90116] = "+7 к урону тайной магией",
    [90117] = "+7 к урону светом",
    [90118] = "+10 к урону огнем",
    [90119] = "+10 к урону льдом",
    [90120] = "+10 к урону природой",
    [90121] = "+10 к урону тенью",
    [90122] = "+10 к урону тайной магией",
    [90123] = "+10 к урону светом",
    -- Arcane Vellum pool — Intellect
    [90130] = "+3 к интеллекту",
    [90131] = "+6 к интеллекту",
    [90132] = "+9 к интеллекту",
    [90133] = "+12 к интеллекту",
    -- Arcane Vellum pool — Spirit
    [90134] = "+3 к духу",
    [90135] = "+6 к духу",
    [90136] = "+9 к духу",
    [90137] = "+12 к духу",
    -- Fortune T4 trinket proc (Mark of the Chosen)
    [90138] = "Знак избранного",
    [91001] = "+5 к рейтингу защиты",
    [91002] = "+3 к духу",
    [91003] = "+1 к выносливости",
    [91004] = "+1 к силе",
    [91005] = "+2 к силе",
    [91006] = "+3 к силе",
    [91007] = "+2 к выносливости",
    [91008] = "+3 к выносливости",
    [91009] = "+1 к ловкости",
    [91010] = "+2 к ловкости",
    [91011] = "+3 к ловкости",
    [91012] = "+1 к интеллекту",
    [91013] = "+2 к интеллекту",
    [91014] = "+3 к интеллекту",
    [91015] = "+1 к духу",
    [91016] = "+2 к духу",
    [91017] = "+4 к ловкости",
    [91018] = "+5 к ловкости",
    [91019] = "+6 к ловкости",
    [91020] = "+7 к ловкости",
    [91021] = "+4 к интеллекту",
    [91022] = "+5 к интеллекту",
    [91023] = "+6 к интеллекту",
    [91024] = "+7 к интеллекту",
    [91025] = "+4 к духу",
    [91026] = "+5 к духу",
    [91027] = "+6 к духу",
    [91028] = "+7 к духу",
    [91029] = "+4 к выносливости",
    [91030] = "+5 к выносливости",
    [91031] = "+6 к выносливости",
    [91032] = "+7 к выносливости",
    [91033] = "+4 к силе",
    [91034] = "+5 к силе",
    [91035] = "+6 к силе",
    [91036] = "+7 к силе",
    [91037] = "+2 к рейтингу защиты",
    [91038] = "+3 к рейтингу защиты",
    [91039] = "+4 к рейтингу защиты",
    [91040] = "+7 к рейтингу защиты",
    [91041] = "+14 к рейтингу критического удара",
    [91042] = "+28 к рейтингу критического удара",
    [91043] = "+42 к рейтингу критического удара",
    [91044] = "+56 к рейтингу критического удара",
    [91045] = "+1 к силе заклинаний",
    [91046] = "+2 к силе заклинаний",
    [91047] = "+4 к силе заклинаний",
    [91048] = "+5 к силе заклинаний",
    [91049] = "+6 к силе заклинаний",
    [91050] = "+7 к силе заклинаний",
    [91051] = "+8 к силе заклинаний",
    [91052] = "+15 к здоровью",
    [91053] = "+20 к мане",
    [91054] = "+8 к ловкости",
    [91055] = "+32 к броне",
    [91056] = "+40 к броне",
    [91057] = "+36 к броне",
    [91058] = "+44 к броне",
    [91059] = "+48 к броне",
    [91060] = "+9 к ловкости",
    [91061] = "+8 к интеллекту",
    [91062] = "+8 к духу",
    [91063] = "+8 к силе",
    [91064] = "+8 к выносливости",
    [91065] = "+9 к интеллекту",
    [91066] = "+9 к духу",
    [91067] = "+9 к выносливости",
    [91068] = "+9 к силе",
    [91069] = "+10 к ловкости",
    [91070] = "+10 к интеллекту",
    [91071] = "+10 к духу",
    [91072] = "+10 к выносливости",
    [91073] = "+10 к силе",
    [91074] = "+11 к ловкости",
    [91075] = "+11 к интеллекту",
    [91076] = "+11 к духу",
    [91077] = "+11 к выносливости",
    [91078] = "+11 к силе",
    [91079] = "+12 к ловкости",
    [91080] = "+12 к интеллекту",
    [91081] = "+12 к духу",
    [91082] = "+12 к выносливости",
    [91083] = "+12 к силе",
    [91084] = "+60 к броне",
    [91085] = "+13 к ловкости",
    [91086] = "+14 к ловкости",
    [91087] = "+13 к интеллекту",
    [91088] = "+14 к интеллекту",
    [91089] = "+13 к духу",
    [91090] = "+14 к духу",
    [91091] = "+13 к выносливости",
    [91092] = "+13 к силе",
    [91093] = "+14 к выносливости",
    [91094] = "+14 к силе",
    [91095] = "+15 к силе",
    [91096] = "+5 к рейтингу блока щитом",
    [91097] = "+30 к мане",
    [91098] = "+50 к мане",
    [91099] = "+10 к рейтингу блока щитом",
    [91100] = "+15 к ловкости",
    [91101] = "+50 к здоровью",
    [91102] = "+65 к мане",
    [91103] = "+10 к рейтингу скорости",
    [91104] = "+16 к ловкости",
    [91105] = "+16 к силе",
    [91106] = "+18 к силе",
    [91107] = "+20 к силе",
    [91108] = "+25 к силе",
    [91109] = "+30 к силе",
    [91110] = "+35 к силе",
    [91111] = "+40 к силе",
    [91112] = "+15 к выносливости",
    [91113] = "+16 к выносливости",
    [91114] = "+18 к выносливости",
    [91115] = "+20 к выносливости",
    [91116] = "+25 к выносливости",
    [91117] = "+30 к выносливости",
    [91118] = "+35 к выносливости",
    [91119] = "+40 к выносливости",
    [91120] = "+18 к ловкости",
    [91121] = "+20 к ловкости",
    [91122] = "+25 к ловкости",
    [91123] = "+30 к ловкости",
    [91124] = "+35 к ловкости",
    [91125] = "+40 к ловкости",
    [91126] = "+15 к интеллекту",
    [91127] = "+16 к интеллекту",
    [91128] = "+18 к интеллекту",
    [91129] = "+20 к интеллекту",
    [91130] = "+25 к интеллекту",
    [91131] = "+30 к интеллекту",
    [91132] = "+35 к интеллекту",
    [91133] = "+40 к интеллекту",
    [91134] = "+15 к духу",
    [91135] = "+16 к духу",
    [91136] = "+18 к духу",
    [91137] = "+20 к духу",
    [91138] = "+25 к духу",
    [91139] = "+30 к духу",
    [91140] = "+40 к духу",
    [91141] = "+35 к духу",
    [91142] = "+45 к силе",
    [91143] = "+46 к силе",
    [91144] = "+45 к выносливости",
    [91145] = "+45 к ловкости",
    [91146] = "+46 к ловкости",
    [91147] = "+45 к интеллекту",
    [91148] = "+46 к интеллекту",
    [91149] = "+45 к духу",
    [91150] = "+46 к духу",
    [91151] = "+150 к мане",
    [91152] = "+100 здоровья",
    [91153] = "+2 к силе атаки",
    [91154] = "+4 к силе атаки",
    [91155] = "+6 к силе атаки",
    [91156] = "+8 к силе атаки",
    [91157] = "+10 к силе атаки",
    [91158] = "+12 к силе атаки",
    [91159] = "+14 к силе атаки",
    [91160] = "+16 к силе атаки",
    [91161] = "+18 к силе атаки",
    [91162] = "+20 к силе атаки",
    [91163] = "+22 к силе атаки",
    [91164] = "+24 к силе атаки",
    [91165] = "+26 к силе атаки",
    [91166] = "+28 к силе атаки",
    [91167] = "+30 к силе атаки",
    [91168] = "+32 к силе атаки",
    [91169] = "+36 к силе атаки",
    [91170] = "+42 к силе атаки",
    [91171] = "+50 к силе атаки",
    [91172] = "+60 к силе атаки",
    [91173] = "+70 к силе атаки",
    [91174] = "+80 к силе атаки",
    [91175] = "+90 к силе атаки",
    [91176] = "+70 к броне",
    [91177] = "+100 к мане",
    [91178] = "+10 к рейтингу защиты",
    [91179] = "+15 к рейтингу защиты",
    [91180] = "+20 к рейтингу защиты",
    [91181] = "+25 к рейтингу защиты",
    [91182] = "+30 к рейтингу защиты",
    [91183] = "+35 к рейтингу защиты",
    [91184] = "+38 к рейтингу защиты",
    [91185] = "+15 к рейтингу блока",
    [91186] = "+20 к рейтингу блока",
    [91187] = "+9 к силе заклинаний",
    [91188] = "+11 к силе заклинаний",
    [91189] = "+15 к силе заклинаний",
    [91190] = "+18 к силе заклинаний",
    [91191] = "+20 к силе заклинаний",
    [91192] = "+25 к силе заклинаний",
    [91193] = "+30 к силе заклинаний",
    [91194] = "+35 к силе заклинаний",
    [91195] = "+40 к силе заклинаний",
    [91196] = "+44 к силе заклинаний",
    [91197] = "+150 к здоровью",
    [91198] = "+120 к броне",
    [91199] = "+7 к рейтингу критического удара",
    [91200] = "+3 к рейтингу критического удара",
    [91201] = "+3 к силе заклинаний",
    [91202] = "+4 к рейтингу блока",
    [91203] = "+3 к рейтингу блока",
    [91204] = "+4 к рейтингу мастерства",
    [91205] = "+170 к броне",
    [91206] = "+54 к силе заклинаний",
    [91207] = "+240 к броне",
    [91208] = "+8 к рейтингу скорости",
    [91209] = "+225 к броне",
    [91210] = "+16 к рейтингу скорости",
    [91211] = "+275 к здоровью",
    [91212] = "+4 к рейтингу скорости",
    [91213] = "+6 к рейтингу скорости",
    [91214] = "+6 к рейтингу блока",
    [91215] = "+6 к рейтингу мастерства",
    [91216] = "+12 к рейтингу пробивания брони",
    [91217] = "+12 к рейтингу мастерства",
    [91218] = "+12 к рейтингу скорости",
    [91219] = "+16 к рейтингу пробивания брони",
    [91220] = "+16 к рейтингу мастерства",
    [91221] = "+20 к мастерству",
    [91222] = "+20 к рейтингу пробивания брони",
    [91223] = "+20 к рейтингу скорости",
    [91224] = "+14 к рейтингу мастерства",
    [91225] = "+14 к рейтингу пробивания брони",
    [91226] = "+14 к рейтингу скорости",
    [91227] = "+34 к рейтингу скорости",
    [91228] = "+34 к рейтингу пробивания брони",
    [91229] = "+34 к рейтингу мастерства",
    [91230] = "+130 к силе атаки",
    [91231] = "+76 к силе заклинаний",
    [91232] = "+4 к рейтингу пробивания брони",
    [91233] = "+8 к рейтингу мастерства",
    [91234] = "+110 к силе атаки",
    [91235] = "+23 к рейтингу скорости",
    [91236] = "+63 к силе заклинаний",
    [91237] = "+81 к силе заклинаний",
    [91238] = "+69 к силе заклинаний",
    [91239] = "+885 к броне",
    [91240] = "+6 к рейтингу пробивания брони",
    [91241] = "+8 к рейтингу пробивания брони",
}


-- ═══════════════════════════════════════
-- Enchant pool data — populated from server sync
-- Format: { pool, name, min, max, mask (optional), cf (optional) }
-- ═══════════════════════════════════════
SB.DB.Enchants = {}

-- Enchant name → pool mapping (for Recalibrator detection)
SB.DB.EnchantNameToPool = {}

-- Debug: dump synced pool data to chat
-- /sb debug        — summary by pool
-- /sb debug 4      — all pool 4 entries
-- /sb debug 4 T4   — pool 4, tier 4 only (iLvl 66-92)
function SB.DB.DumpSyncData(filterPool, filterTier)
    local p = filterPool or 0
    local tierRanges = { {1,25}, {26,45}, {46,65}, {66,92} }
    local tierMin, tierMax = 0, 999
    if filterTier and filterTier >= 1 and filterTier <= 4 then
        tierMin = tierRanges[filterTier][1]
        tierMax = tierRanges[filterTier][2]
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[SB Debug]|r Synced=" .. tostring(SB.DB.Synced) .. " Total=" .. #SB.DB.Enchants)

    if p == 0 then
        -- Summary mode: count by pool and tier
        local poolNames = { "Battle", "Warding", "Arcana", "Fortune" }
        for pool = 1, 4 do
            local counts = {0, 0, 0, 0, total = 0}
            for _, e in ipairs(SB.DB.Enchants) do
                if e.pool == pool then
                    counts.total = counts.total + 1
                    for t = 1, 4 do
                        if e.max >= tierRanges[t][1] and e.min <= tierRanges[t][2] then
                            counts[t] = counts[t] + 1
                        end
                    end
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  |cffffff00%s|r (%d): T1=%d T2=%d T3=%d T4=%d",
                poolNames[pool], counts.total, counts[1], counts[2], counts[3], counts[4]))
        end
        return
    end

    -- Detail mode: list entries for specific pool
    local count = 0
    local tierLabel = filterTier and (" T" .. filterTier) or ""
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Pool " .. p .. tierLabel .. ":|r")
    for i, e in ipairs(SB.DB.Enchants) do
        if e.pool == p and e.max >= tierMin and e.min <= tierMax then
            local m = e.mask or 0
            local c = e.cf or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  [%d-%d] m=%d cf=%d %s", e.min, e.max, m, c, e.name))
            count = count + 1
            if count >= 60 then
                DEFAULT_CHAT_FRAME:AddMessage("  ... (truncated)")
                break
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[SB Debug]|r " .. count .. " entries")
end

local function RebuildNameToPool()
    SB.DB.EnchantNameToPool = {}
    for _, e in ipairs(SB.DB.Enchants) do
        SB.DB.EnchantNameToPool[e.name] = e.pool
    end
end

-- ═══════════════════════════════════════
-- Server sync handler (CHAT_MSG_ADDON)
-- ═══════════════════════════════════════
local syncBuffer = {}

local function ProcessSyncData()
    local newEnchants = {}
    for _, raw in ipairs(syncBuffer) do
        local id, pool, mn, mx, mask, cf = raw:match("^(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
        if id then
            id = tonumber(id)
            pool = tonumber(pool)
            mn = tonumber(mn)
            mx = tonumber(mx)
            mask = tonumber(mask)
            cf = tonumber(cf)
            local name = SB.DB.EnchantNames[id] or ("Enchant #" .. id)
            local entry = { pool = pool, name = name, min = mn, max = mx }
            if mask and mask > 0 then entry.mask = mask end
            if cf and cf > 0 then entry.cf = cf end
            table.insert(newEnchants, entry)
        end
    end

    if #newEnchants > 0 then
        SB.DB.Enchants = newEnchants
        SB.DB.Synced = true
        RebuildNameToPool()
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffff00[StatBooster]|r \208\161\208\184\208\189\209\133\209\128\208\190\208\189\208\184\208\183\208\176\209\134\208\184\209\143: "
            .. "|cff00ff00" .. #newEnchants .. " \209\141\209\132\209\132\208\181\208\186\209\130\208\190\208\178|r")
        if SB.DB.OnSyncCallback then SB.DB.OnSyncCallback() end
    end

    syncBuffer = {}
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")
syncFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix ~= "StatBoost" then return end

    if message:find("^SYNC:") then
        local data = message:sub(6)
        for entry in data:gmatch("[^;]+") do
            table.insert(syncBuffer, entry)
        end
    elseif message == "SYNC_END" then
        ProcessSyncData()
    end
end)

-- ═══════════════════════════════════════
-- Detect current enchant pool from item tooltip
-- ═══════════════════════════════════════
function SB.DB.DetectEnchantPool(itemLink, bag, bagSlot)
    if not itemLink then return nil end

    local scanTip = _G["StatBoostScanTip2"]
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "StatBoostScanTip2", nil, "GameTooltipTemplate")
    end

    local tipSet = false

    if bag and bag == -1 and bagSlot then
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetInventoryItem("player", bagSlot)
        tipSet = true
    elseif bag and bag >= 0 and bagSlot then
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetBagItem(bag, bagSlot)
        tipSet = true
    end

    if not tipSet then
        local itemId = tonumber(itemLink:match("item:(%d+)"))
        if itemId then
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local link = GetContainerItemLink(b, s)
                    if link and tonumber(link:match("item:(%d+)")) == itemId then
                        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        scanTip:ClearLines()
                        scanTip:SetBagItem(b, s)
                        tipSet = true
                        break
                    end
                end
                if tipSet then break end
            end
            if not tipSet then
                for i = 1, 19 do
                    local link = GetInventoryItemLink("player", i)
                    if link and tonumber(link:match("item:(%d+)")) == itemId then
                        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        scanTip:ClearLines()
                        scanTip:SetInventoryItem("player", i)
                        tipSet = true
                        break
                    end
                end
            end
        end
    end

    if not tipSet then return nil end

    local TAG = "##SB##"
    for i = 1, scanTip:NumLines() do
        local line = _G[scanTip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

                if clean:find(TAG, 1, true) then
                    clean = clean:gsub(TAG, "")
                    local trimmed = clean:match("^%s*(.-)%s*$")
                    -- Strip up to TWO prefixes: WoW may prepend "Использование:" /
                    -- "Equip:" / "Chance on hit:" to the spell description line for
                    -- type=3 EQUIP_SPELL enchants. After stripping that, our pool
                    -- prefix ("Удача:", "Тайный:", etc.) remains and must ALSO be
                    -- stripped so displayName equals the canonical enchant name.
                    local displayName = trimmed:gsub("^[^:]+:%s*", "")
                    displayName = displayName:gsub("^[^:]+:%s*", "")

                    -- Pool prefix keywords (Fortune=Удача, Arcana=Тайна, etc.)
                    if clean:find("\208\163\208\180\208\176\209\135\208\176", 1, true) then return 4, displayName end -- Удача
                    if clean:find("\208\145\208\190\208\181\208\178\208\190\208\185", 1, true) then return 1, displayName end -- Боевой
                    if clean:find("\208\151\208\176\209\137\208\184\209\130", 1, true) then return 2, displayName end -- Защит
                    if clean:find("\208\162\208\176\208\185\208\189", 1, true) then return 3, displayName end -- Тайн

                    -- Name lookup fallback
                    local pool = SB.DB.EnchantNameToPool[trimmed]
                    if pool then return pool, displayName end

                    -- Stat keyword detection for 91xxx enchants (no pool prefix)
                    -- Pool 1 (Battle): strength, agility, attack power, crit, haste, arpen, expertise
                    if clean:find("\209\129\208\184\208\187", 1, true) and not clean:find("\208\183\208\176\208\186\208\187", 1, true) then return 1, displayName end -- сил but not закл
                    if clean:find("\208\187\208\190\208\178\208\186", 1, true) then return 1, displayName end -- ловк
                    if clean:find("\208\176\209\130\208\176\208\186", 1, true) then return 1, displayName end -- атак
                    if clean:find("\208\186\209\128\208\184\209\130", 1, true) then return 1, displayName end -- крит
                    if clean:find("\208\191\209\128\208\190\208\189\208\184\208\186", 1, true) then return 1, displayName end -- проник
                    if clean:find("\208\188\208\176\209\129\209\130\208\181\209\128\209\129\209\130\208\178", 1, true) then return 1, displayName end -- мастерств
                    -- Pool 2 (Warding): stamina, defense, block, armor, health
                    if clean:find("\208\178\209\139\208\189\208\190\209\129", 1, true) then return 2, displayName end -- вынос
                    if clean:find("\208\177\209\128\208\190\208\189", 1, true) then return 2, displayName end -- брон
                    if clean:find("\208\177\208\187\208\190\208\186", 1, true) then return 2, displayName end -- блок
                    if clean:find("\208\183\208\180\208\190\209\128\208\190\208\178", 1, true) then return 2, displayName end -- здоров
                    if clean:find("\209\128\208\181\208\185\209\130\208\184\208\189\208\179 \208\183\208\176\209\137", 1, true) then return 2, displayName end -- рейтинг защ
                    -- Pool 3 (Arcana): intellect, spirit, spell power, mana
                    if clean:find("\208\184\208\189\209\130\208\181\208\187\208\187\208\181\208\186\209\130", 1, true) then return 3, displayName end -- интеллект
                    if clean:find("\208\180\209\131\209\133", 1, true) then return 3, displayName end -- дух
                    if clean:find("\208\183\208\176\208\186\208\187", 1, true) then return 3, displayName end -- закл (spell power)
                    if clean:find("\208\188\208\176\208\189", 1, true) then return 3, displayName end -- ман

                    -- Has ##SB## tag but unknown stat — still a boost
                    return -1, displayName
                end
                -- NOTE: Do NOT match non-##SB## lines (like "+27 к силе атаки")
                -- Those are base item stats, not StatBooster enchants
            end
        end
    end
    return nil
end

-- Get matching enchants for an item + scroll combo
function SB.DB.GetMatchingEnchants(scrollId, itemLevel, invType, itemClass, itemSubClass, itemLink, bag, bagSlot)
    local scroll = SB.DB.Scrolls[scrollId]
    if not scroll then return {}, nil end

    local slotBit = SB.DB.SlotMask[invType] or 0
    local targetPool = scroll.pool

    if targetPool == 0 then
        local detectedPool = SB.DB.DetectEnchantPool(itemLink, bag, bagSlot)
        if detectedPool then
            targetPool = detectedPool
        else
            return {}, 0
        end
    end

    local results = {}
    for _, e in ipairs(SB.DB.Enchants) do
        if e.pool == targetPool then
            if itemLevel >= e.min and itemLevel <= e.max then
                local maskOk = true
                if e.mask and e.mask ~= 0 then
                    maskOk = band(e.mask, slotBit) ~= 0
                end

                local cfOk = true
                if e.cf then
                    cfOk = MatchesClassFilter(e.cf, itemClass, itemSubClass, invType)
                end

                if maskOk and cfOk then
                    table.insert(results, e.name)
                end
            end
        end
    end

    return results, targetPool
end
