// The SurfaceFx rig: tables built in the test, whose variants are named by a sound path no asset lives at. Resolve loads
// nothing, so a resolved sound's asset name says which variant won.
UCLASS(Abstract)
class UMars_AutoTestRig_SurfaceFx : UCk_AutoTest_Base
{
    protected TSoftObjectPtr<USoundBase> Make_Sound(const FString& InName) const
    {
        return TSoftObjectPtr<USoundBase>(FSoftObjectPath(f"/Game/Tests/SurfaceFx/{InName}.{InName}"));
    }

    protected FMars_SurfaceFx_Variant Make_Variant(float32 InMinIntensity, const FString& InSoundName) const
    {
        auto Variant = FMars_SurfaceFx_Variant();
        Variant.MinIntensity = InMinIntensity;
        Variant.Sound = Make_Sound(InSoundName);
        return Variant;
    }

    protected FMars_SurfaceFx_Cell Make_Cell(const FMars_SurfaceFx_Variant& InVariant) const
    {
        auto Cell = FMars_SurfaceFx_Cell();
        Cell.Variants.Add(InVariant);
        return Cell;
    }

    // Default plays DefaultStep, DefaultLand and DefaultImpact at any intensity.
    protected UMars_SurfaceFx_Table Make_Table()
    {
        auto Default = FMars_SurfaceFx_Row();
        Default.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Footstep, Make_Cell(Make_Variant(0.0f, "DefaultStep")));
        Default.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Land, Make_Cell(Make_Variant(0.0f, "DefaultLand")));
        Default.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Impact, Make_Cell(Make_Variant(0.0f, "DefaultImpact")));

        auto Table = Cast<UMars_SurfaceFx_Table>(NewObject(this, UMars_SurfaceFx_Table));
        Table.Rows.Add(GameplayTags::Surface_Default, Default);
        return Table;
    }

    // Make_Table plus a Stone row playing InCell for InKind.
    protected UMars_SurfaceFx_Table Make_TableWithStone(FGameplayTag InKind, const FMars_SurfaceFx_Cell& InCell)
    {
        auto Stone = FMars_SurfaceFx_Row();
        Stone.Kinds.ByKind.Add(InKind, InCell);

        auto Table = Make_Table();
        Table.Rows.Add(GameplayTags::Surface_Stone, Stone);
        return Table;
    }

    // InSurface may be invalid: an event on untagged geometry.
    protected FMars_SurfaceFx_Event Make_Event(FGameplayTag InKind, FGameplayTag InSurface, float32 InIntensity) const
    {
        auto Event = FMars_SurfaceFx_Event();
        Event.Kind = InKind;
        if (InSurface.IsValid())
        { Event.SurfaceTags.AddTag(InSurface); }

        Event.Intensity = InIntensity;
        return Event;
    }

    // The resolved sound's asset name; empty when nothing plays.
    protected FString Get_SoundName(const UMars_SurfaceFx_Table InTable, const FMars_SurfaceFx_Event& InEvent) const
    {
        const auto Resolved = utils_surface_fx::Resolve(InTable, InEvent);
        if (Resolved.IsSet() == false)
        { return ""; }

        return Resolved.GetValue().Sound.GetAssetName();
    }

    protected void Assert_Plays(const UMars_SurfaceFx_Table InTable, const FMars_SurfaceFx_Event& InEvent, const FString& InExpected)
    {
        const auto Actual = Get_SoundName(InTable, InEvent);
        Assert_Equals_String(Actual, InExpected,
            f"{InEvent.Kind} on [{InEvent.SurfaceTags.First()}] at {InEvent.Intensity} plays [{InExpected}]");
    }
}
