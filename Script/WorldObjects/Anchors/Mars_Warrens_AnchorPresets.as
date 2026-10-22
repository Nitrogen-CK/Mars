// Warrens routes preserve the solved role and reserve a lever only for an authored scout crawl.
// These row indices belong to this table: arch 0, rubble 1, far-side latch 2.
asset Mars_AnchorTable_WarrensRoute of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Route;
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 6.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_Rubble_EntityScript, 2.0f, EMars_Anchor_Role::Closed));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_OneSidedLeverGate_EntityScript, 4.0f, EMars_Anchor_Role::Open, EMars_AnchorRow_Need::LeverSide));
}

class UMars_Warrens_Anchor_Route_EntityScript : UMars_Anchor_Route_EntityScript
{
    protected UMars_AnchorTable_Def Get_Table() const override
    { return Mars_AnchorTable_WarrensRoute; }
}
