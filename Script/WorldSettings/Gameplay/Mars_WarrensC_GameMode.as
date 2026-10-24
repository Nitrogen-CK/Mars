// Warrens layout variant v8c (Two Towers and the Canal): the Warrens expedition on the emitted WarrensC plan, over the same
// Anchor.Mars.Warrens.* tags. Assigned by Warrens_VariantC_Mars_MAP's World Settings (build_warrens.py, WARRENS_GAMEMODE).
class AMars_WarrensC_GameMode : AMars_Anchored_GameMode
{
    UMars_AnchorPlan_Def Get_Plan() const override
    { return utils_anchor_resolver::Plan_WarrensC(); }
}
