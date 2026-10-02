#include "StatBoostMgr.h"
#include "StatBoostCfgMgr.h"
#include "WorldPacket.h"
#include "DBCStores.h"

static constexpr char STATBOOST_ADDON_PREFIX[] = "StatBoost";

StatBoostMgr::StatType StatBoostMgr::GetStatTypeFromSubClass(Item* item)
{
    if (item->GetTemplate()->Class == ITEM_CLASS_WEAPON)
    {
        switch (item->GetTemplate()->SubClass)
        {
        case ITEM_SUBCLASS_WEAPON_MACE2:
        case ITEM_SUBCLASS_WEAPON_POLEARM:
        case ITEM_SUBCLASS_WEAPON_SPEAR:
        case ITEM_SUBCLASS_WEAPON_GUN:
        case ITEM_SUBCLASS_WEAPON_BOW:
        case ITEM_SUBCLASS_WEAPON_CROSSBOW:
            switch (urand(0, 2))
            {
            case 0:
                return STAT_TYPE_TANK;

            case 1:
                return STAT_TYPE_PHYS;

            case 2:
                return STAT_TYPE_HYBRID;
            }

        case ITEM_SUBCLASS_WEAPON_THROWN:
            return STAT_TYPE_PHYS;

        case ITEM_SUBCLASS_WEAPON_DAGGER:
            switch (urand(0, 2))
            {
            case 0:
                return STAT_TYPE_PHYS;

            case 1:
                return STAT_TYPE_HYBRID;

            case 2:
                return STAT_TYPE_SPELL;
            }

        case ITEM_SUBCLASS_WEAPON_STAFF:
            switch (urand(0, 3))
            {
            case 0:
                return STAT_TYPE_TANK;

            case 1:
                return STAT_TYPE_PHYS;

            case 2:
                return STAT_TYPE_HYBRID;

            case 3:
                return STAT_TYPE_SPELL;
            }

        case ITEM_SUBCLASS_WEAPON_AXE:
        case ITEM_SUBCLASS_WEAPON_AXE2:
        case ITEM_SUBCLASS_WEAPON_MACE:
        case ITEM_SUBCLASS_WEAPON_SWORD:
        case ITEM_SUBCLASS_WEAPON_SWORD2:
        case ITEM_SUBCLASS_WEAPON_FIST:
            switch (urand(0, 1))
            {
            case 0:
                return STAT_TYPE_TANK;

            case 1:
                return STAT_TYPE_PHYS;
            }

        case ITEM_SUBCLASS_WEAPON_WAND:
            return STAT_TYPE_SPELL;
        }
    }
    else if (item->GetTemplate()->Class == ITEM_CLASS_ARMOR)
    {
        switch (item->GetTemplate()->SubClass)
        {
        case ITEM_SUBCLASS_ARMOR_CLOTH:
            switch (item->GetTemplate()->InventoryType)
            {
            case INVTYPE_CLOAK:
                switch (urand(0, 3))
                {
                case 0:
                    return STAT_TYPE_TANK;

                case 1:
                    return STAT_TYPE_PHYS;

                case 2:
                    return STAT_TYPE_HYBRID;

                case 3:
                    return STAT_TYPE_SPELL;
                }

            default:
                return STAT_TYPE_SPELL;
            }
            break;

        case ITEM_SUBCLASS_ARMOR_LEATHER:
        case ITEM_SUBCLASS_ARMOR_MAIL:
        case ITEM_SUBCLASS_ARMOR_PLATE:
            switch (urand(0, 3))
            {
            case 0:
                return STAT_TYPE_TANK;

            case 1:
                return STAT_TYPE_PHYS;

            case 2:
                return STAT_TYPE_HYBRID;

            case 3:
                return STAT_TYPE_SPELL;
            }

        case ITEM_SUBCLASS_ARMOR_BUCKLER:
        case ITEM_SUBCLASS_ARMOR_SHIELD:
            switch (urand(0, 1))
            {
            case 0:
                return STAT_TYPE_TANK;
            case 1:
                return STAT_TYPE_SPELL;
            }
        }
    }

    return STAT_TYPE_NONE;
}   

StatBoostMgr::StatType StatBoostMgr::ScoreItem(Item* item, bool hasAdditionalSpells)
{
    ScoreData tankScore { STAT_TYPE_TANK, 0 },
        physScore { STAT_TYPE_PHYS, 0 },
        hybridScore { STAT_TYPE_HYBRID, 0 },
        spellScore { STAT_TYPE_SPELL, 0 };

    //Store the scores in a vector so I can order by highest for a winner.
    std::vector<ScoreData*> roleScores;
    roleScores.push_back(&tankScore);
    roleScores.push_back(&physScore);
    roleScores.push_back(&hybridScore);
    roleScores.push_back(&spellScore);

    //TODO: IMPLEMENT SCORING
    auto itemTemplate = item->GetTemplate();
    auto subClass = itemTemplate->SubClass;

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Found {} stats on item.", itemTemplate->StatsCount);
    }

    for (uint32 i = 0; i < itemTemplate->StatsCount; i++)
    {
        auto stat = itemTemplate->ItemStat[i];
        uint32 statType = stat.ItemStatType;

        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "StatType: {}, StatValue: {}", stat.ItemStatType, stat.ItemStatValue);
        }

        sBoostConfigMgr->EnchantScores.Evaluate(0, statType, subClass, tankScore.Score, physScore.Score, spellScore.Score, hybridScore.Score);
    }

    //Sometimes stats are stored as additional spell effects and also need to be checked.
    if (hasAdditionalSpells)
    {
        auto scores = sBoostConfigMgr->EnchantScores.Get();

        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "Found {} spells on item.", itemTemplate->StatsCount);
        }

        for (_Spell const &spell : itemTemplate->Spells)
        {
            if (spell.SpellId)
            {
                auto spellInfo = sSpellMgr->GetSpellInfo(spell.SpellId);
                
                if (!spellInfo || !scores)
                {
                    continue;
                }

                if (sBoostConfigMgr->VerboseEnable)
                {
                    LOG_INFO("module", "SpellId: {}", spell.SpellId);
                }

                for (auto const &score : *scores)
                {
                    if (score.modType == 1)
                    {
                        if (spellInfo->HasAura(static_cast<AuraType>(score.modId)))
                        {
                            sBoostConfigMgr->EnchantScores.Evaluate(1, score.modId, subClass, tankScore.Score, physScore.Score, spellScore.Score, hybridScore.Score);
                        }
                    }
                }
            }
        }
    }

    if (item->GetItemRandomPropertyId() != 0)
    {
        auto propId = item->GetItemRandomPropertyId();

        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "Found random property {}.", propId);
        }

        uint32 enchantIds[5];

        if (propId > 0)
        {
            auto propStoreEntry = sItemRandomPropertiesStore.LookupEntry(propId);
            if (propStoreEntry)
            {
                enchantIds[0] = propStoreEntry->Enchantment[0];
                enchantIds[1] = propStoreEntry->Enchantment[1];
                enchantIds[2] = propStoreEntry->Enchantment[2];
                enchantIds[3] = propStoreEntry->Enchantment[3];
                enchantIds[4] = propStoreEntry->Enchantment[4];
            }
        }
        else if (propId < 0)
        {
            auto suffixStoreEntry = sItemRandomSuffixStore.LookupEntry(-propId);
            if (suffixStoreEntry)
            {
                enchantIds[0] = suffixStoreEntry->Enchantment[0];
                enchantIds[1] = suffixStoreEntry->Enchantment[1];
                enchantIds[2] = suffixStoreEntry->Enchantment[2];
                enchantIds[3] = suffixStoreEntry->Enchantment[3];
                enchantIds[4] = suffixStoreEntry->Enchantment[4];
            }
        }

        for (uint32 i = 0; i < 5; i++)
        {
            auto enchantmentId = enchantIds[i];
            if (enchantmentId == 0)
            {
                continue;
            }

            auto spellItemEntry = sSpellItemEnchantmentStore.LookupEntry(enchantmentId);
            if (!spellItemEntry)
            {
                continue;
            }

            if (spellItemEntry->type[0] != ITEM_ENCHANTMENT_TYPE_STAT)
            {
                continue;
            }

            auto statType = spellItemEntry->spellid[0];
            if (statType == 0)
            {
                continue;
            }

            if (sBoostConfigMgr->VerboseEnable)
            {
                LOG_INFO("module", "Found random enchant {} with statType {}", spellItemEntry->description[0], statType);
            }

            sBoostConfigMgr->EnchantScores.Evaluate(0, statType, subClass, tankScore.Score, physScore.Score, spellScore.Score, hybridScore.Score);
        }
    }
    else
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "No random enchants found.");
        }
    }

    //Tally up the results, the highest score is picked.
    auto winningScore = roleScores[0];

    if (!winningScore)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "No winning score found.");
        }

        return STAT_TYPE_NONE;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Finding winning score.");
    }
    for (auto score : roleScores)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "Score: {}, Type: {}", score->Score, score->StatType);
        }

        if (score->Score > winningScore->Score)
        {
            winningScore = score;
        }
    }

    //No stats on the items could be scored.
    if (winningScore->Score < 1)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "No stats were scored.");
        }

        return STAT_TYPE_NONE;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Scoring with scores: Tank({}), Phys({}), Spell({}), Hybrid({})", tankScore.Score, physScore.Score, spellScore.Score, hybridScore.Score);
    }

    return winningScore->StatType;
}

void StatBoostMgr::MakeSoulbound(Item* item, Player* player)
{
    auto itemTemplate = item->GetTemplate();

    if (itemTemplate->Bonding == BIND_WHEN_EQUIPPED)
    {
        item->SetState(ITEM_CHANGED, player);
        item->SetBinding(true);
    }
}

StatBoostMgr::StatType StatBoostMgr::AnalyzeItem(Item* item)
{
    auto itemTemplate = item->GetTemplate();

    //The spellids need to be checked because the Spells array is always allocated to a fixed size.
    //Thus we need to count how many VALID spells are in the array.
    uint32 spellsCount = 0;
    for (const auto& spell : itemTemplate->Spells)
    {
        if (spell.SpellId)
        {
            spellsCount++;
        }
    }

    if (itemTemplate->StatsCount < 1 && spellsCount < 1 && item->GetItemRandomPropertyId() == 0)
    {
        return GetStatTypeFromSubClass(item);
    }

    return ScoreItem(item, spellsCount);
}

bool StatBoostMgr::IsBoosted(Item* item)
{
    return item->HasFlag(ITEM_FIELD_FLAGS, ITEM_FIELD_FLAG_UNK26);
}

bool StatBoostMgr::BoostItem(Player* player, Item* item, uint32 chance)
{
    if (!item)
    {
        return false;
    }

    //Is not weapon or armor.
    if (!IsEquipment(item))
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Equipment Check");
    }

    if (item->GetTemplate()->Quality < sBoostConfigMgr->MinQuality ||
        item->GetTemplate()->Quality > sBoostConfigMgr->MaxQuality)
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Quality Check. Quality({})", item->GetTemplate()->Quality);
    }

    //Roll for the chance to upgrade.
    uint32 roll = urand(0, 100);

    if (roll > chance)
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Roll Check. Roll({})", roll);
    }

    //Fetch the type of stats that should be applied to the piece.
    StatType statType = AnalyzeItem(item);

    //Failed to find a stat type.
    if (statType == STAT_TYPE_NONE)
    {
        statType = GetStatTypeFromSubClass(item);

        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "No stat type found, got from subclass.");
        }
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Analyze Check. StatType({})", statType);
    }

    uint32 itemClass = item->GetTemplate()->Class;
    uint32 itemSubClass = item->GetTemplate()->SubClass;
    uint32 itemType = item->GetTemplate()->InventoryType;
    uint32 itemLevel = item->GetTemplate()->ItemLevel;

    uint32 itemClassMask = 1 << itemClass;

    if (!itemClassMask)
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed ItemClass Check");
    }

    uint32 itemSubClassMask = 1 << itemSubClass;

    if (!itemSubClassMask)
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed ItemSubClass Check");
    }

    uint32 itemTypeMask = 1 << itemType;

    if (!itemTypeMask)
    {
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed ItemType Check");
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", ">> Trying to get enchant with role mask {}, class {}, subClass {}, itemType {}, and itemlevel {} from pool.", statType, itemClassMask, itemSubClassMask, itemTypeMask, itemLevel);
    }

    // Determine item class filter: 2=weapon, 4=armor, 6=shield
    uint32 itemClassFilter = 0;
    if (itemClass == ITEM_CLASS_WEAPON)
        itemClassFilter = 2;
    else if (itemClass == ITEM_CLASS_ARMOR && itemSubClass == ITEM_SUBCLASS_ARMOR_SHIELD)
        itemClassFilter = 6;
    else if (itemClass == ITEM_CLASS_ARMOR)
        itemClassFilter = 4;

    //Fetch an enchant from the enchant pool.
    auto enchant = sBoostConfigMgr->EnchantPool.Get(statType, itemClassMask, itemSubClassMask, itemTypeMask, itemLevel, itemClassFilter);

    //Failed to find a valid enchant.
    if (!enchant)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "Failed Enchant Check.");
        }

        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Passed Enchant Check. Enchant({})", enchant->Id);
    }

    return EnchantItem(player, item, PROP_ENCHANTMENT_SLOT_4, enchant->Id, sBoostConfigMgr->OverwriteEnchantEnable);
}

EnchantmentSlot StatBoostMgr::GetFreeSocketSlotForItem(Item* item)
{
    auto itemTemplate = item->GetTemplate();

    if (!itemTemplate->Socket[0].Color)
    {
        return SOCK_ENCHANTMENT_SLOT;
    }
    if (!itemTemplate->Socket[1].Color)
    {
        return SOCK_ENCHANTMENT_SLOT_2;
    }
    if (!itemTemplate->Socket[2].Color)
    {
        return SOCK_ENCHANTMENT_SLOT_3;
    }

    return MAX_ENCHANTMENT_SLOT;
}

bool StatBoostMgr::IsEquipment(Item* item)
{
    auto itemTemplate = item->GetTemplate();

    if (itemTemplate->Class != ITEM_CLASS_WEAPON &&
        itemTemplate->Class != ITEM_CLASS_ARMOR)
    {
        return false;
    }

    return true;
}

bool StatBoostMgr::BoostItemFromPool(Player* player, Item* item, uint32 poolGroup)
{
    if (!item || !player)
        return false;

    if (!IsEquipment(item))
        return false;

    uint32 itemLevel = item->GetTemplate()->ItemLevel;
    uint32 itemClass = item->GetTemplate()->Class;
    uint32 itemSubClass = item->GetTemplate()->SubClass;

    // Filter by gear type: weapon/armor/shield
    // 2 = weapon, 4 = armor (non-shield), 6 = shield
    uint32 itemClassFilter = 0;
    if (itemClass == ITEM_CLASS_WEAPON)
        itemClassFilter = 2;
    else if (itemClass == ITEM_CLASS_ARMOR && itemSubClass == ITEM_SUBCLASS_ARMOR_SHIELD)
        itemClassFilter = 6;
    else if (itemClass == ITEM_CLASS_ARMOR)
        itemClassFilter = 4;

    // Compute inventory type bitmask for slot-specific filtering
    uint32 itemTypeBit = 1 << item->GetTemplate()->InventoryType;

    // No role filtering — the scroll's pool determines what enchants can roll
    auto enchant = sBoostConfigMgr->EnchantPool.GetFromPool(poolGroup, itemLevel, itemClassFilter, 0, itemTypeBit);

    if (!enchant)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "[StatBooster] No enchant found in pool {} for iLvl={}, class={}", poolGroup, itemLevel, itemClass);
            if (player)
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("[DEBUG] No enchant in pool {} for iLvl={} class={}", poolGroup, itemLevel, itemClass).c_str());
        }
        return false;
    }

    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "[StatBooster] Pool {} selected enchant {} for iLvl={}", poolGroup, enchant->Id, itemLevel);
        if (player)
            ChatHandler(player->GetSession()).SendSysMessage(
                Acore::StringFormat("[DEBUG] Pool {} selected enchant {} for iLvl={}", poolGroup, enchant->Id, itemLevel).c_str());
    }

    return EnchantItem(player, item, PROP_ENCHANTMENT_SLOT_4, enchant->Id, sBoostConfigMgr->OverwriteEnchantEnable);
}

bool StatBoostMgr::EnchantItem(Player* player, Item* item, EnchantmentSlot slot, uint32 enchantId, bool overwrite)
{
    if (item->GetEnchantmentId(slot) && !overwrite)
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "[StatBooster] EnchantItem BLOCKED: slot {} already has enchant {}, overwrite={}",
                (uint32)slot, item->GetEnchantmentId(slot), overwrite);
            if (player)
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("[DEBUG] EnchantItem BLOCKED: slot={} existing={} overwrite={}",
                        (uint32)slot, item->GetEnchantmentId(slot), overwrite).c_str());
        }
        return false;
    }

    player->ApplyEnchantment(item, false);
    item->SetEnchantment(EnchantmentSlot(slot), enchantId, 0, 0);
    player->ApplyEnchantment(item, true);

    item->SetFlag(ITEM_FIELD_FLAGS, ITEM_FIELD_FLAG_UNK26);

    if (sBoostConfigMgr->VerboseEnable && player)
        ChatHandler(player->GetSession()).SendSysMessage(
            Acore::StringFormat("[DEBUG] EnchantItem OK: slot={} enchant={} applied to {}",
                (uint32)slot, enchantId, item->GetTemplate()->Name1).c_str());

    // Notify addon about the boost
    if (slot == PROP_ENCHANTMENT_SLOT_4 && player)
        SendBoostDataToAddon(player, item->GetTemplate()->ItemId, enchantId);

    return true;
}

void StatBoostMgr::SendBoostDataToAddon(Player* player, uint32 itemEntry, uint32 enchantId)
{
    if (!player || !player->GetSession())
        return;

    std::string payload = Acore::StringFormat("BOOST:{}:{}", itemEntry, enchantId);
    std::string fullMessage = std::string(STATBOOST_ADDON_PREFIX) + "\t" + payload;

    WorldPacket data(SMSG_MESSAGECHAT, 100);
    data << uint8(ChatMsg::CHAT_MSG_WHISPER);
    data << int32(LANG_ADDON);
    data << player->GetGUID();
    data << uint32(0);
    data << player->GetGUID();
    data << uint32(fullMessage.length() + 1);
    data << fullMessage;
    data << uint8(0);

    player->GetSession()->SendPacket(&data);
}

void StatBoostMgr::SendAllBoostDataOnLogin(Player* player)
{
    if (!player || !player->GetSession())
        return;

    // Send EQUIP messages for all equipped boosted items
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (!item || !IsBoosted(item))
            continue;

        uint32 enchantId = item->GetEnchantmentId(PROP_ENCHANTMENT_SLOT_4);
        if (!enchantId)
            continue;

        uint32 itemEntry = item->GetTemplate()->ItemId;
        std::string payload = Acore::StringFormat("EQUIP:{}:{}:{}", slot, itemEntry, enchantId);
        std::string fullMessage = std::string(STATBOOST_ADDON_PREFIX) + "\t" + payload;

        WorldPacket data(SMSG_MESSAGECHAT, 100);
        data << uint8(ChatMsg::CHAT_MSG_WHISPER);
        data << int32(LANG_ADDON);
        data << player->GetGUID();
        data << uint32(0);
        data << player->GetGUID();
        data << uint32(fullMessage.length() + 1);
        data << fullMessage;
        data << uint8(0);

        player->GetSession()->SendPacket(&data);
    }
}

void StatBoostMgr::SendPoolSyncToAddon(Player* player)
{
    if (!player || !player->GetSession())
        return;

    const auto& allEnchants = sBoostConfigMgr->EnchantPool.GetAll();
    if (allEnchants.empty())
        return;

    // Build chunked messages: "SYNC:id,pool,min,max,mask,cf;id,pool,..."
    // WoW 3.3.5a may truncate large addon messages, keep chunks small
    static constexpr size_t MAX_CHUNK = 220;
    std::string chunk;
    uint32 count = 0;

    auto sendChunk = [&]()
    {
        if (chunk.empty())
            return;
        std::string fullMessage = std::string(STATBOOST_ADDON_PREFIX)
            + "\t" + "SYNC:" + chunk;

        WorldPacket data(SMSG_MESSAGECHAT, fullMessage.length() + 50);
        data << uint8(ChatMsg::CHAT_MSG_WHISPER);
        data << int32(LANG_ADDON);
        data << player->GetGUID();
        data << uint32(0);
        data << player->GetGUID();
        data << uint32(fullMessage.length() + 1);
        data << fullMessage;
        data << uint8(0);

        player->GetSession()->SendPacket(&data);
        chunk.clear();
    };

    for (const auto& e : allEnchants)
    {
        if (e.PoolGroup == 0)
            continue;

        std::string entry = Acore::StringFormat(
            "{},{},{},{},{},{}",
            e.Id, e.PoolGroup, e.ILvlMin, e.ILvlMax,
            e.ItemTypeMask, e.ItemClassFilter);

        if (!chunk.empty())
        {
            if (chunk.length() + 1 + entry.length() > MAX_CHUNK)
                sendChunk();
            else
                chunk += ";";
        }
        chunk += entry;
        count++;
    }

    sendChunk();

    // Send end marker
    {
        std::string fullMessage = std::string(STATBOOST_ADDON_PREFIX)
            + "\t" + "SYNC_END";

        WorldPacket data(SMSG_MESSAGECHAT, fullMessage.length() + 50);
        data << uint8(ChatMsg::CHAT_MSG_WHISPER);
        data << int32(LANG_ADDON);
        data << player->GetGUID();
        data << uint32(0);
        data << player->GetGUID();
        data << uint32(fullMessage.length() + 1);
        data << fullMessage;
        data << uint8(0);

        player->GetSession()->SendPacket(&data);
    }

    if (sBoostConfigMgr->VerboseEnable)
        LOG_INFO("module", "[StatBooster] Sent {} pool entries to addon for {}",
            count, player->GetName());
}
