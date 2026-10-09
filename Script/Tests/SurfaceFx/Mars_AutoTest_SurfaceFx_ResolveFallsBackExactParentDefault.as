// Per kind, an event plays its surface's own row, else the nearest parent row that has the kind, else Surface.Default's:
// Gritty lands on its own row, steps on Stone's and impacts on Default's. A child row is never a fallback (Stone has no
// landing of its own and lands on Default, not Gritty), and untagged or row-less surfaces play Default.
class UMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault : UMars_AutoTestRig_SurfaceFx
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("resolve along the surface's tag chain", n"Step_Resolve");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Resolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Table = Make_TableWithStone(GameplayTags::SurfaceFx_Footstep, Make_Cell(Make_Variant(0.0f, "StoneStep")));
        auto Gritty = FMars_SurfaceFx_Row();
        Gritty.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Land, Make_Cell(Make_Variant(0.0f, "GrittyLand")));
        Table.Rows.Add(GameplayTags::Surface_Stone_Gritty, Gritty);

        const auto Valid = Table.Validate();
        Assert_True(Valid.IsValid(), f"the test table validates (error: {Valid.Get_Error()})");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Land, GameplayTags::Surface_Stone_Gritty, 1.0f), "GrittyLand");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Stone_Gritty, 1.0f), "StoneStep");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone_Gritty, 1.0f), "DefaultImpact");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Stone, 1.0f), "StoneStep");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Land, GameplayTags::Surface_Stone, 1.0f), "DefaultLand");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, FGameplayTag(), 1.0f), "DefaultStep");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Grass, 1.0f), "DefaultStep");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Land, GameplayTags::Surface_Default, 1.0f), "DefaultLand");
    }
}
