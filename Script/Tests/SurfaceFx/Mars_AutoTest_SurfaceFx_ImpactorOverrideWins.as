// An impactor's override on a row beats that row's own cell, and is checked at each row of the chain: Gritty (no row)
// reaches Stone's override; a kind Stone has neither way falls to Default, where Default's own override wins; a kind
// nobody overrides plays the plain cell; no impactor never reads an override.
class UMars_AutoTest_SurfaceFx_ImpactorOverrideWins : UMars_AutoTestRig_SurfaceFx
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("resolve with and without an impactor", n"Step_Resolve");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Resolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Table = Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Make_Cell(Make_Variant(0.0f, "StoneImpact")));

        auto StoneOverride = FMars_SurfaceFx_Kinds();
        StoneOverride.ByKind.Add(GameplayTags::SurfaceFx_Impact, Make_Cell(Make_Variant(0.0f, "ImpactorStoneImpact")));
        FMars_SurfaceFx_Row Stone;
        Table.Rows.Find(GameplayTags::Surface_Stone, Stone);
        Stone.ByImpactor.Add(Get_Impactor(), StoneOverride);
        Table.Rows.Add(GameplayTags::Surface_Stone, Stone);

        auto DefaultOverride = FMars_SurfaceFx_Kinds();
        DefaultOverride.ByKind.Add(GameplayTags::SurfaceFx_Footstep, Make_Cell(Make_Variant(0.0f, "ImpactorDefaultStep")));
        FMars_SurfaceFx_Row Default;
        Table.Rows.Find(GameplayTags::Surface_Default, Default);
        Default.ByImpactor.Add(Get_Impactor(), DefaultOverride);
        Table.Rows.Add(GameplayTags::Surface_Default, Default);

        const auto Valid = Table.Validate();
        Assert_True(Valid.IsValid(), f"the test table validates (error: {Valid.Get_Error()})");

        Assert_Plays(Table, With_Impactor(Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 1.0f)), "ImpactorStoneImpact");
        Assert_Plays(Table, With_Impactor(Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone_Gritty, 1.0f)), "ImpactorStoneImpact");
        Assert_Plays(Table, With_Impactor(Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Stone, 1.0f)), "ImpactorDefaultStep");
        Assert_Plays(Table, With_Impactor(Make_Event(GameplayTags::SurfaceFx_Land, GameplayTags::Surface_Stone, 1.0f)), "DefaultLand");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 1.0f), "StoneImpact");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Stone, 1.0f), "DefaultStep");
    }

    // The Impactor root: the config declares no Impactor.* child yet, and any valid tag keys an override.
    private FGameplayTag Get_Impactor() const
    {
        return GameplayTags::Impactor;
    }

    private FMars_SurfaceFx_Event With_Impactor(const FMars_SurfaceFx_Event& InEvent) const
    {
        auto Event = InEvent;
        Event.Impactor = Get_Impactor();
        return Event;
    }
}
