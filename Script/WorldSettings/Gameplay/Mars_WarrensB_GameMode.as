// Warrens layout variant v8b (The Cascade): the Warrens expedition on the emitted WarrensB plan, over the same
// Anchor.Mars.Warrens.* tags. Assigned by Warrens_VariantB_Mars_MAP's World Settings (build_warrens.py, WARRENS_GAMEMODE).
class AMars_WarrensB_GameMode : AMars_Anchored_GameMode
{
    UMars_AnchorPlan_Def Get_Plan() const override
    { return utils_anchor_resolver::Plan_WarrensB(); }
}
