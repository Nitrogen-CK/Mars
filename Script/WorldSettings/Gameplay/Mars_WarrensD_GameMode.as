// Warrens layout variant v8d (The Long Loop): the Warrens expedition on the emitted WarrensD plan, over the same
// Anchor.Mars.Warrens.* tags. Assigned by Warrens_VariantD_Mars_MAP's World Settings (build_warrens.py, WARRENS_GAMEMODE).
class AMars_WarrensD_GameMode : AMars_Anchored_GameMode
{
    UMars_AnchorPlan_Def Get_Plan() const override
    { return utils_anchor_resolver::Plan_WarrensD(); }
}
