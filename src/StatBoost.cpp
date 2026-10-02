#include "StatBoost.h"
#include "DBCStores.h"
#include <unordered_map>

void StatBoosterPlayer::OnPlayerLogin(Player* player)
{
    if (!sBoostConfigMgr->Enable)
    {
        return;
    }

    if(sBoostConfigMgr->OnLoginEnable)
    {
        ChatHandler(player->GetSession()).SendSysMessage(sBoostConfigMgr->OnLoginMessage);
    }

    StatBoostMgr::SendAllBoostDataOnLogin(player);
    StatBoostMgr::SendPoolSyncToAddon(player);
}

void StatBoosterPlayer::OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/)
{
    if (!sBoostConfigMgr->Enable)
    {
        return;
    }

    if (sBoostConfigMgr->OnLootItemEnable)
    {
        bool result = StatBoostMgr::BoostItem(player, item, sBoostConfigMgr->LootItemChance);

        if (result)
        {
            if (sBoostConfigMgr->AnnounceBoostEnable)
            {
                ChatHandler(player->GetSession()).SendSysMessage(sBoostConfigMgr->AnnounceLoot);
            }

            if (sBoostConfigMgr->PlaySoundEnable)
            {
                player->PlayDirectSound(sBoostConfigMgr->SoundId);
            }

            if (sBoostConfigMgr->SoulbindOnEnchantLoot && !item->IsSoulBound())
            {
                StatBoostMgr::MakeSoulbound(item, player);
            }
        }
    }
}

void StatBoosterPlayer::OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/)
{
    if (!sBoostConfigMgr->Enable)
    {
        return;
    }

    if (sBoostConfigMgr->OnQuestRewardItemEnable)
    {
        bool result = StatBoostMgr::BoostItem(player, item, sBoostConfigMgr->QuestRewardChance);

        if (result)
        {
            if (sBoostConfigMgr->AnnounceBoostEnable)
            {
                ChatHandler(player->GetSession()).SendSysMessage(sBoostConfigMgr->AnnounceQuest);
            }

            if (sBoostConfigMgr->PlaySoundEnable)
            {
                player->PlayDirectSound(sBoostConfigMgr->SoundId);
            }

            if (sBoostConfigMgr->SoulbindOnEnchantQuest && !item->IsSoulBound())
            {
                StatBoostMgr::MakeSoulbound(item, player);
            }
        }
    }
}

void StatBoosterPlayer::OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/)
{
    if (!sBoostConfigMgr->Enable)
    {
        return;
    }

    if (sBoostConfigMgr->OnCraftItemEnable)
    {
        bool result = StatBoostMgr::BoostItem(player, item, sBoostConfigMgr->CraftItemChance);

        if (result)
        {
            if (sBoostConfigMgr->AnnounceBoostEnable)
            {
                ChatHandler(player->GetSession()).SendSysMessage(sBoostConfigMgr->AnnounceCraft);
            }

            if (sBoostConfigMgr->PlaySoundEnable)
            {
                player->PlayDirectSound(sBoostConfigMgr->SoundId);
            }

            if (sBoostConfigMgr->SoulbindOnEnchantCraft && !item->IsSoulBound())
            {
                StatBoostMgr::MakeSoulbound(item, player);
            }
        }
    }
}

void StatBoosterPlayer::OnPlayerGroupRollRewardItem(Player* player, Item* item, uint32 /*count*/, RollVote /*voteType*/, Roll* /*roll*/)
{
    if (!sBoostConfigMgr->Enable)
    {
        return;
    }

    if (sBoostConfigMgr->OnLootItemEnable)
    {
        bool result = StatBoostMgr::BoostItem(player, item, sBoostConfigMgr->LootItemChance);

        if (result)
        {
            if (sBoostConfigMgr->AnnounceBoostEnable)
            {
                ChatHandler(player->GetSession()).SendSysMessage(sBoostConfigMgr->AnnounceLoot);
            }

            if (sBoostConfigMgr->PlaySoundEnable)
            {
                player->PlayDirectSound(sBoostConfigMgr->SoundId);
            }

            if (sBoostConfigMgr->SoulbindOnEnchantRoll && !item->IsSoulBound())
            {
                StatBoostMgr::MakeSoulbound(item, player);
            }
        }
    }
}

// Cached scroll -> pool mappings, loaded once at config load
struct ScrollPoolEntry
{
    uint32 poolGroup;
    uint32 minILvl;
    uint32 maxILvl;
};
static std::unordered_map<uint32, ScrollPoolEntry> s_ScrollPoolMap;
static bool s_ScrollPoolLoaded = false;

static void LoadScrollPoolMap()
{
    s_ScrollPoolMap.clear();
    // Scan known scroll item ID ranges from config
    static const uint32 scanRanges[][2] = {
        {100001, 100016}
    };
    for (auto& range : scanRanges)
    {
        for (uint32 id = range[0]; id <= range[1]; ++id)
        {
            std::string poolKey = "StatBooster.ScrollPool." + std::to_string(id);
            int32 pool = sConfigMgr->GetOption<int32>(poolKey, -1);
            if (pool >= 0)
            {
                std::string minKey = "StatBooster.ScrollMinILvl." + std::to_string(id);
                std::string maxKey = "StatBooster.ScrollMaxILvl." + std::to_string(id);
                uint32 minILvl = sConfigMgr->GetOption<uint32>(minKey, 0);
                uint32 maxILvl = sConfigMgr->GetOption<uint32>(maxKey, 999);
                s_ScrollPoolMap[id] = { uint32(pool), minILvl, maxILvl };
            }
        }
    }
    s_ScrollPoolLoaded = true;
    LOG_INFO("module", ">> Loaded {} StatBooster scroll pool mappings", s_ScrollPoolMap.size());
}

static uint32 GetScrollPoolGroup(uint32 itemId)
{
    if (itemId == 41605)
        return 0;

    if (!s_ScrollPoolLoaded)
        LoadScrollPoolMap();

    auto it = s_ScrollPoolMap.find(itemId);
    return it != s_ScrollPoolMap.end() ? it->second.poolGroup : 0;
}

// Cached enchantId -> poolGroup mapping, loaded once from DB
struct EnchantPoolInfo
{
    uint32 poolGroup;
    uint32 iLvlMax;
};
static std::unordered_map<uint32, EnchantPoolInfo> s_EnchantPoolCache;
static bool s_EnchantPoolCacheLoaded = false;

static void LoadEnchantPoolCache()
{
    s_EnchantPoolCache.clear();
    QueryResult result = WorldDatabase.Query("SELECT Id, PoolGroup, iLvlMax FROM statbooster_enchant_template");
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 id = fields[0].Get<uint32>();
            uint32 pool = fields[1].Get<uint32>();
            uint32 iLvlMax = fields[2].Get<uint32>();
            auto it = s_EnchantPoolCache.find(id);
            if (it == s_EnchantPoolCache.end() || iLvlMax > it->second.iLvlMax)
                s_EnchantPoolCache[id] = { pool, iLvlMax };
        } while (result->NextRow());
    }
    s_EnchantPoolCacheLoaded = true;
    LOG_INFO("module", ">> Loaded {} StatBooster enchant->pool mappings", s_EnchantPoolCache.size());
}

static uint32 GetEnchantPoolGroup(uint32 enchantId)
{
    if (!enchantId)
        return 0;

    if (!s_EnchantPoolCacheLoaded)
        LoadEnchantPoolCache();

    auto it = s_EnchantPoolCache.find(enchantId);
    return it != s_EnchantPoolCache.end() ? it->second.poolGroup : 0;
}

static uint32 GetEnchantILvlMax(uint32 enchantId)
{
    if (!enchantId)
        return 0;

    if (!s_EnchantPoolCacheLoaded)
        LoadEnchantPoolCache();

    auto it = s_EnchantPoolCache.find(enchantId);
    return it != s_EnchantPoolCache.end() ? it->second.iLvlMax : 0;
}

static bool IsRerollScroll(uint32 itemId)
{
    if (itemId == 41605)
        return true;

    if (!s_ScrollPoolLoaded)
        LoadScrollPoolMap();

    return s_ScrollPoolMap.count(itemId) > 0;
}

bool StatBoosterPlayer::OnPlayerCanCastItemUseSpell(Player* player, Item* item, SpellCastTargets const& targets, uint8 /*cast_count*/, uint32 /*glyphIndex*/)
{
    if (!item)
        return true;

    auto itemTemplate = item->GetTemplate();
    if (!itemTemplate)
        return true;

    if (!IsRerollScroll(itemTemplate->ItemId))
        return true;

    if (!sBoostConfigMgr->Enable)
    {
        ChatHandler(player->GetSession()).SendSysMessage("This item is disabled.");
        return false;
    }

    auto targetItem = targets.GetItemTarget();
    if (!targetItem)
        return false;

    if (sConfigMgr->GetOption<bool>("StatBooster.Reroll.AllowOwnedItemsOnly", true) &&
        targetItem->GetOwner()->GetGUID() != player->GetGUID())
    {
        ChatHandler(player->GetSession()).SendSysMessage("You cannot re-roll items other than your own.");
        return false;
    }

    uint32 poolGroup = GetScrollPoolGroup(itemTemplate->ItemId);
    bool success = false;

    if (poolGroup > 0)
    {
        // Pool scrolls: can ONLY enchant items that are NOT already boosted
        if (StatBoostMgr::IsBoosted(targetItem))
        {
            ChatHandler(player->GetSession()).SendSysMessage("This item already has an enchant. Use an Attribute Recalibrator to re-roll it.");
            return false;
        }

        // Check item level restriction for this scroll (cached from config)
        uint32 targetILvl = targetItem->GetTemplate()->ItemLevel;
        auto it = s_ScrollPoolMap.find(itemTemplate->ItemId);
        if (it != s_ScrollPoolMap.end())
        {
            if (sBoostConfigMgr->VerboseEnable)
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("[DEBUG] Scroll {} pool={} iLvlRange={}-{}, targetILvl={}, targetClass={}, targetName={}",
                        itemTemplate->ItemId, poolGroup, it->second.minILvl, it->second.maxILvl,
                        targetILvl, targetItem->GetTemplate()->Class, targetItem->GetTemplate()->Name1).c_str());

            if (targetILvl < it->second.minILvl || targetILvl > it->second.maxILvl)
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("This scroll works on items with level {}-{}. Your item is level {}.",
                        it->second.minILvl, it->second.maxILvl, targetILvl).c_str());
                return false;
            }
        }
        else
        {
            if (sBoostConfigMgr->VerboseEnable)
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("[DEBUG] Scroll {} NOT FOUND in ScrollPoolMap (map size={})",
                        itemTemplate->ItemId, s_ScrollPoolMap.size()).c_str());
        }

        success = StatBoostMgr::BoostItemFromPool(player, targetItem, poolGroup);
        if (!success)
        {
            if (sBoostConfigMgr->VerboseEnable)
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("[DEBUG] BoostItemFromPool returned false for pool={} iLvl={}",
                        poolGroup, targetILvl).c_str());
        }
    }
    else
    {
        // Attribute Recalibrator (41605): can ONLY re-roll already boosted items
        if (!StatBoostMgr::IsBoosted(targetItem))
        {
            ChatHandler(player->GetSession()).SendSysMessage("This item has no enchant to re-roll. Use a crafted scroll first.");
            return false;
        }

        // Look up which pool the current enchant belongs to (cached) and re-roll within same pool
        uint32 boostEnchId = targetItem->GetEnchantmentId(PROP_ENCHANTMENT_SLOT_4);
        uint32 rerollPool = GetEnchantPoolGroup(boostEnchId);

        if (rerollPool > 0)
        {
            success = StatBoostMgr::BoostItemFromPool(player, targetItem, rerollPool);
        }
        else
        {
            // Fallback: re-roll with random stat pool
            success = StatBoostMgr::BoostItem(player, targetItem, 100);
        }
    }

    if (success)
    {
        player->DestroyItemCount(itemTemplate->ItemId, 1, true);

        uint32 visualId = sConfigMgr->GetOption<uint32>("StatBooster.Reroll.VisualId", 62015);
        player->CastSpell(player, visualId);
    }
    else
    {
        ChatHandler(player->GetSession()).SendSysMessage("This scroll cannot enchant this item. Check item level requirements.");
    }

    return false;
}

void StatBoosterPlayer::OnPlayerResurrect(Player* player, float /*restore_percent*/, bool& /*applySickness*/)
{
    if (!player || !sBoostConfigMgr->Enable)
        return;

    // Re-apply all PROP_ENCHANTMENT_SLOT_4 equip-spell auras lost on death
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (!item || !item->IsEquipped() || !StatBoostMgr::IsBoosted(item))
            continue;

        uint32 enchantId = item->GetEnchantmentId(PROP_ENCHANTMENT_SLOT_4);
        if (!enchantId)
            continue;

        SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(enchantId);
        if (!enchant)
            continue;

        for (int s = 0; s < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++s)
        {
            if (enchant->type[s] == ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL && enchant->spellid[s])
            {
                // Only cast if player doesn't already have this aura
                if (!player->HasAura(enchant->spellid[s]))
                    player->CastSpell(player, enchant->spellid[s], true, item);
            }
        }
    }
}

void StatBoosterWorld::OnAfterConfigLoad(bool /*reload*/)
{
    sBoostConfigMgr->Enable = sConfigMgr->GetOption<bool>("StatBooster.Enable", false);

    //No point loading all of this information if the module is not enabled.
    if (sBoostConfigMgr->Enable)
    {
        sBoostConfigMgr->VerboseEnable = sConfigMgr->GetOption<bool>("StatBooster.VerboseEnable", false);
        sBoostConfigMgr->OnLoginEnable = sConfigMgr->GetOption<bool>("StatBooster.OnLoginEnable", true);
        sBoostConfigMgr->OnLoginMessage = sConfigMgr->GetOption<std::string>("StatBooster.OnLoginMessage", "This server is running the StatBooster module.");

        sBoostConfigMgr->OnLootItemEnable = sConfigMgr->GetOption<bool>("StatBooster.OnLootItemEnable", true);
        sBoostConfigMgr->OnQuestRewardItemEnable = sConfigMgr->GetOption<bool>("StatBooster.OnQuestRewardItemEnable", true);
        sBoostConfigMgr->OnCraftItemEnable = sConfigMgr->GetOption<bool>("StatBooster.OnCraftItemEnable", true);

        sBoostConfigMgr->LootItemChance = sConfigMgr->GetOption<uint32>("StatBooster.LootItemChance", 100);
        sBoostConfigMgr->QuestRewardChance = sConfigMgr->GetOption<uint32>("StatBooster.QuestRewardChance", 100);
        sBoostConfigMgr->CraftItemChance = sConfigMgr->GetOption<uint32>("StatBooster.CraftItemChance", 100);

        sBoostConfigMgr->MinQuality = sConfigMgr->GetOption<uint32>("StatBooster.MinQuality", ITEM_QUALITY_UNCOMMON);
        sBoostConfigMgr->MaxQuality = sConfigMgr->GetOption<uint32>("StatBooster.MaxQuality", ITEM_QUALITY_EPIC);

        sBoostConfigMgr->PlaySoundEnable = sConfigMgr->GetOption<bool>("StatBooster.PlaySoundEnable", true);
        sBoostConfigMgr->SoundId = sConfigMgr->GetOption<uint32>("StatBooster.SoundId", 120);

        sBoostConfigMgr->SoulbindOnEnchantRoll = sConfigMgr->GetOption<bool>("StatBooster.SoulbindOnEnchantRoll", false);
        sBoostConfigMgr->SoulbindOnEnchantLoot = sConfigMgr->GetOption<bool>("StatBooster.SoulbindOnEnchantLoot", false);
        sBoostConfigMgr->SoulbindOnEnchantQuest = sConfigMgr->GetOption<bool>("StatBooster.SoulbindOnEnchantQuest", false);
        sBoostConfigMgr->SoulbindOnEnchantCraft = sConfigMgr->GetOption<bool>("StatBooster.SoulbindOnEnchantCraft", false);

        sBoostConfigMgr->AnnounceBoostEnable = sConfigMgr->GetOption<bool>("StatBooster.AnnounceBoostEnable", true);
        sBoostConfigMgr->AnnounceLoot = sConfigMgr->GetOption<std::string>("StatBooster.AnnounceLoot", "You looted a boosted item.");
        sBoostConfigMgr->AnnounceQuest = sConfigMgr->GetOption<std::string>("StatBooster.AnnounceQuest", "You received a boosted item.");
        sBoostConfigMgr->AnnounceCraft = sConfigMgr->GetOption<std::string>("StatBooster.AnnounceCraft", "You crafted a boosted item.");

        sBoostConfigMgr->OverwriteEnchantEnable = sConfigMgr->GetOption<bool>("StatBooster.OverwriteEnchantEnable", true);

        sBoostConfigMgr->EnchantPool.Load();
        sBoostConfigMgr->EnchantScores.Load();

        LoadScrollPoolMap();
        LoadEnchantPoolCache();
    }
}

ChatCommandTable StatBoosterCommands::GetCommands() const
{
    static ChatCommandTable sbCommandTable =
    {
        { "additem", HandleSBAddItemCommand, SEC_ADMINISTRATOR, Console::No },
        { "sync",    HandleSBSyncCommand,    SEC_PLAYER,        Console::No }
    };

    static ChatCommandTable commandTable =
    {
        { "sb", sbCommandTable }
    };

    return commandTable;
}

bool StatBoosterCommands::HandleSBSyncCommand(ChatHandler* handler)
{
    Player* player = handler->GetPlayer();
    if (!player)
        return false;

    StatBoostMgr::SendPoolSyncToAddon(player);
    return true;
}

bool StatBoosterCommands::HandleSBAddItemCommand(ChatHandler* handler, uint32 itemId, uint32 count, Optional<uint32> suffixId)
{
    if (!itemId || !count)
    {
        handler->SendSysMessage("Invalid arguments, you must supply a valid itemId and count.");
        handler->SendSysMessage("Ex: '.sb additem <itemId> <count> [suffixId]'");
        handler->SetSentErrorMessage(true);
        return false;
    }

    ItemTemplate const* itemTemp = sObjectMgr->GetItemTemplate(itemId);

    if (!itemTemp)
    {
        handler->SendSysMessage("Item template could not be found. Is this a valid item id?");
        handler->SetSentErrorMessage(true);
        return false;
    }

    Player* player = handler->GetPlayer();

    if (!player)
    {
        return false;
    }

    if (player->GetTarget() && player->GetTarget().IsPlayer())
    {
        player = ObjectAccessor::FindPlayer(player->GetTarget());
    }

    uint32 noSpaceForCount = 0;
    ItemPosCountVec dest;
    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, count, &noSpaceForCount);
    
    if (msg != EQUIP_ERR_OK)
    {
        count -= noSpaceForCount;
    }

    if (dest.empty())
    {
        return false;
    }

    Item* item = player->StoreNewItem(dest, itemId, true);

    StatBoostMgr statBoostMgr;
    bool result = statBoostMgr.BoostItem(player, item, 100);

    if (!item)
    {
        return false;
    }

    if (suffixId.has_value())
    {
        item->SetItemRandomProperties(suffixId.value());
    }

    if (result)
    {
        handler->SendSysMessage(Acore::StringFormat("Added boosted item '{}' to '{}'.", itemId, player->GetPlayerName()));
    }
    else
    {
        handler->SendSysMessage(Acore::StringFormat("Added item '{}' to '{}'.", itemId, player->GetPlayerName()));
    }
    
    player->SendNewItem(item, count, true, false, false, true);

    return true;
}

void AddSCStatBoosterScripts()
{
    new StatBoosterCommands();
    new StatBoosterWorld();
    new StatBoosterPlayer();
}
