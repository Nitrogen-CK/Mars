// The shipped table validates, has a row for every surface tag a Mars phys mat carries, plays each surface's own steps
// (Carpet walks below a run's speed ratio and runs above it), plays impacts in the light / heavy bands, and every asset it
// names loads.
class UMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads : UMars_AutoTestRig_SurfaceFx
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate and resolve the shipped table", n"Step_Resolve");
        Add_Step("load every asset it names", n"Step_Load");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Resolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Table = utils_surface_fx::Get_Table();
        const auto Valid = Table.Validate();
        Assert_True(Valid.IsValid(), f"the shipped table validates (error: {Valid.Get_Error()})");

        TArray<FGameplayTag> Surfaces;
        Surfaces.Add(GameplayTags::Surface_Default);
        Surfaces.Add(GameplayTags::Surface_Stone);
        Surfaces.Add(GameplayTags::Surface_Stone_Gritty);
        Surfaces.Add(GameplayTags::Surface_Dirt);
        Surfaces.Add(GameplayTags::Surface_Grass);
        Surfaces.Add(GameplayTags::Surface_Mud);
        Surfaces.Add(GameplayTags::Surface_Sand);
        Surfaces.Add(GameplayTags::Surface_Carpet);
        Surfaces.Add(GameplayTags::Surface_Wood);
        Surfaces.Add(GameplayTags::Surface_Metal);
        Surfaces.Add(GameplayTags::Surface_Flesh);
        for (auto Surface : Surfaces)
        { Assert_True(Table.Rows.Contains(Surface), f"the shipped table has a {Surface} row"); }

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, FGameplayTag(), 1.0f), "Stone_Footstep_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Land, GameplayTags::Surface_Stone_Gritty, 400.0f), "StoneGritty_Landed_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Grass, 1.0f), "Grass_Footstep_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Wood, 1.0f), "Stone_Footstep_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Carpet, 1.0f), "Carpet_Walk_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Footstep, GameplayTags::Surface_Carpet, 1.6f), "Carpet_Run_Mars_SND");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Metal, 50.0f), "");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Metal, 150.0f), "ItemImpact_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Metal, 400.0f), "HitImpact_Metal_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Flesh, 400.0f), "HitImpact_Flesh_Mars_SND");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Sand, 400.0f), "HitImpact_Default_Mars_SND");
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Table = utils_surface_fx::Get_Table();

        TArray<FString> Named;
        for (auto Row : Table.Rows)
        {
            Collect_Named(Row.Value.Kinds, Named);
            for (auto Override : Row.Value.ByImpactor)
            { Collect_Named(Override.Value, Named); }
        }

        TArray<UObject> Loaded;
        utils_surface_fx::Load_Assets(Table, Loaded);
        Assert_True(Named.Num() > 0, "the shipped table names assets");
        Assert_Equals_Int(Loaded.Num(), Named.Num(), "every asset the shipped table names loads");
    }

    private void Collect_Named(const FMars_SurfaceFx_Kinds& InKinds, TArray<FString>& OutNamed) const
    {
        for (auto Kind : InKinds.ByKind)
        {
            for (auto Variant : Kind.Value.Variants)
            {
                if (Variant.Sound.IsNull() == false)
                { OutNamed.AddUnique(Variant.Sound.ToString()); }

                if (Variant.Vfx.IsNull() == false)
                { OutNamed.AddUnique(Variant.Vfx.ToString()); }

                if (Variant.Shake.IsNull() == false)
                { OutNamed.AddUnique(Variant.Shake.ToString()); }
            }
        }
    }
}
