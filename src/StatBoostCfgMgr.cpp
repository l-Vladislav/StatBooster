#include "StatBoostCfgMgr.h"

std::vector<StatBoosterConfig::EnchantScore>* StatBoosterConfig::EnchantScorePool::Get()
{
    return &scores;
}

void StatBoosterConfig::EnchantScorePool::Add(EnchantScore score)
{
    scores.push_back(score);
}

void StatBoosterConfig::EnchantScorePool::Clear()
{
    scores.clear();
}

void StatBoosterConfig::EnchantScorePool::Evaluate(uint32 modType, uint32 modId, uint32 subclass, uint32& tankScore, uint32& physScore, uint32& spellScore, uint32& hybridScore)
{
    if (sBoostConfigMgr->VerboseEnable)
    {
        LOG_INFO("module", "Finding scores for ModType: {}, ModId: {}, Subclass: {}", modType, modId, subclass);
    }

    auto scoreIter = std::find_if(scores.begin(), scores.end(), [modType, modId, subclass](EnchantScore& enchantScore)
    {
            return (enchantScore.modType == modType && enchantScore.modId == modId && (enchantScore.subclass == subclass || enchantScore.subclass == 0));
    });

    if (scoreIter != scores.end())
    {
        if (sBoostConfigMgr->VerboseEnable)
        {
            LOG_INFO("module", "Scoring Item: Tank({}), Phys({}), Spell({}), Hybrid({})", scoreIter->tankScore, scoreIter->physScore, scoreIter->spellScore, scoreIter->hybridScore);
        }

        tankScore += scoreIter->tankScore;
        physScore += scoreIter->physScore;
        spellScore += scoreIter->spellScore;
        hybridScore += scoreIter->hybridScore;
    }
}

bool StatBoosterConfig::EnchantScorePool::Load()
{
    try
    {
        uint32 enchantCount = 0;

        QueryResult qResult = WorldDatabase.Query("SELECT `mod_type`, `mod_id`, `subclass`, `tank_score`, `phys_score`, `spell_score`, `hybrid_score` FROM `statbooster_enchant_scores`");

        if (!qResult)
        {
            LOG_INFO("module", "Failed to load StatBooster enchant scores from statbooster_enchant_scores table.");
            return false;
        }

        LOG_INFO("module", "Loading StatBooster enchant scores from statbooster_enchant_scores...");

        sBoostConfigMgr->EnchantScores.Clear();

        do
        {
            Field* fields = qResult->Fetch();

            EnchantScore enchantScore;

            enchantScore.modType = fields[0].Get<uint32>();
            enchantScore.modId = fields[1].Get<uint32>();
            enchantScore.subclass = fields[2].Get<uint32>();
            enchantScore.tankScore = fields[3].Get<uint32>();
            enchantScore.physScore = fields[4].Get<uint32>();
            enchantScore.spellScore = fields[5].Get<uint32>();
            enchantScore.hybridScore = fields[6].Get<uint32>();

            enchantCount++;
            sBoostConfigMgr->EnchantScores.Add(enchantScore);

            if (sBoostConfigMgr->VerboseEnable)
            {
                LOG_INFO("module", ">> Loaded enchant score type {} with id {} subclass {} with scores {}, {}, {}, {}",
                    enchantScore.modType, enchantScore.modId, enchantScore.subclass, enchantScore.tankScore, enchantScore.physScore, enchantScore.spellScore, enchantScore.hybridScore);
            }
        } while (qResult->NextRow());

        LOG_INFO("module", Acore::StringFormat(">> Loaded {} stat booster enchant scores", enchantCount));
    }
    catch (std::exception ex)
    {
        LOG_INFO("module", "Failed to load enchant scores with message: {}", ex.what());
        LOG_INFO("module", "Disabling StatBooster module.");
        sBoostConfigMgr->Enable = false;
        return false;
    }
    return true;
}

StatBoosterConfig* StatBoosterConfig::GetInstance()
{
    if (!instance)
    {
        instance = new StatBoosterConfig();
    }

    return instance;
}

void StatBoosterConfig::EnchantPool::Add(EnchantDefinition definition)
{
    pool.push_back(definition);
}

EnchantDefinition* StatBoosterConfig::EnchantPool::Get(uint32 roleMask, uint32 classMask, uint32 subClassMask, uint32 itemTypeMask, uint32 itemLevel, uint32 itemClassFilter)
{
    std::shuffle(std::begin(pool), std::end(pool), randomEngine);

    auto iterator = std::find_if(pool.begin(), pool.end(), [&](const EnchantDefinition& data)
    {
            return ((data.RoleMask & roleMask) == roleMask || data.RoleMask == 0) &&
                ((data.ClassMask & classMask) == classMask || data.ClassMask == 0) &&
                ((data.SubClassMask & subClassMask) == subClassMask || data.SubClassMask == 0) &&
                ((data.ItemTypeMask & itemTypeMask) == itemTypeMask || data.ItemTypeMask == 0) &&
                (itemLevel >= data.ILvlMin && itemLevel <= data.ILvlMax) &&
                (itemClassFilter == 0 || data.ItemClassFilter == 0 || data.ItemClassFilter == itemClassFilter);
    });

    if (!(iterator == pool.end()))
    {
        return &(*iterator);
    }

    return 0;
}

EnchantDefinition* StatBoosterConfig::EnchantPool::GetFromPool(uint32 poolGroup, uint32 itemLevel, uint32 itemClassFilter, uint32 roleMask, uint32 itemTypeBit)
{
    std::shuffle(std::begin(pool), std::end(pool), randomEngine);

    auto iterator = std::find_if(pool.begin(), pool.end(), [&](const EnchantDefinition& data)
    {
        if (data.PoolGroup != poolGroup)
            return false;
        if (itemLevel < data.ILvlMin || itemLevel > data.ILvlMax)
            return false;
        // Filter by item class: 0=any, otherwise must match
        if (itemClassFilter > 0 && data.ItemClassFilter > 0 && data.ItemClassFilter != itemClassFilter)
            return false;
        // Filter by role: 0=any role matches, otherwise check bitmask
        if (roleMask > 0 && data.RoleMask > 0 && (data.RoleMask & roleMask) == 0)
            return false;
        // Filter by inventory slot: 0=any slot, otherwise check bitmask
        if (itemTypeBit > 0 && data.ItemTypeMask > 0 && (data.ItemTypeMask & itemTypeBit) == 0)
            return false;
        return true;
    });

    if (!(iterator == pool.end()))
    {
        return &(*iterator);
    }

    return 0;
}

bool StatBoosterConfig::EnchantPool::Load()
{
    try
    {
        uint32 enchantCount = 0;

        QueryResult qResult = WorldDatabase.Query("SELECT `Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, IFNULL(`PoolGroup`, 0), IFNULL(`ItemClassFilter`, 0) FROM `statbooster_enchant_template`");

        if (!qResult)
        {
            LOG_INFO("module", "Failed to load StatBooster enchant definitions from statbooster_enchant_template table.");
            return false;
        }

        LOG_INFO("module", "Loading StatBooster enchants from statbooster_enchant_template...");

        sBoostConfigMgr->EnchantPool.Clear();

        do
        {
            Field* fields = qResult->Fetch();

            EnchantDefinition enchantDef;

            enchantDef.Id = fields[0].Get<uint32>();
            enchantDef.ILvlMin = fields[1].Get<uint32>();
            enchantDef.ILvlMax = fields[2].Get<uint32>();
            enchantDef.RoleMask = fields[3].Get<uint32>();
            enchantDef.ClassMask = fields[4].Get<uint32>();
            enchantDef.SubClassMask = fields[5].Get<uint32>();
            enchantDef.ItemTypeMask = fields[6].Get<uint32>();
            enchantDef.PoolGroup = fields[7].Get<uint32>();
            enchantDef.ItemClassFilter = fields[8].Get<uint32>();

            enchantCount++;
            sBoostConfigMgr->EnchantPool.Add(enchantDef);

            if (sBoostConfigMgr->VerboseEnable)
            {
                LOG_INFO("module", ">> Loaded enchant id {} with role mask {}, class mask {}, subclass mask {}, and type mask {}", enchantDef.Id, enchantDef.RoleMask, enchantDef.ClassMask, enchantDef.SubClassMask, enchantDef.ItemTypeMask);
            }
        } while (qResult->NextRow());

        LOG_INFO("module", Acore::StringFormat(">> Loaded {} stat booster enchant definitions", enchantCount));
    }
    catch (std::exception ex)
    {
        LOG_INFO("module", "Failed to load enchant table with message: {}", ex.what());
        LOG_INFO("module", "Disabling StatBooster module.");
        sBoostConfigMgr->Enable = false;
        return false;
    }

    return true;
}

void StatBoosterConfig::EnchantPool::Clear()
{
    pool.clear();
}
