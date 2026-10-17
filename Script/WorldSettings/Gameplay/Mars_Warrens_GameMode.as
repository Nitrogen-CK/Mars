// The Catacomb Warrens: an anchored expedition on the emitted Warrens plan. Assigned by the map's World Settings.
class AMars_Warrens_GameMode : AMars_Anchored_GameMode
{
    UMars_AnchorPlan_Def Get_Plan() const override
    { return utils_anchor_resolver::Plan_Warrens(); }
}
