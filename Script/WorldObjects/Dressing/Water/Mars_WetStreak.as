// A hand-placed damp or rust streak down a wall (DRIPS_PLAN §3.10): place it in front of the wall with +X pointing out
// of it, at the height the water seeps from. It traces back to the wall, then down the wall to the floor for its
// length, and projects WetStreak_Mars_M there (Rust when Mineral > 0.5, else Damp). The decal colour carries Seed,
// Dampness, Flow (cm/s / 100) and Mineral to the material.
class AMars_WetStreak : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UDecalComponent StreakDecal;

    UPROPERTY(Category = "Streak")
    FMars_DripStreak Streak;
    default Streak.OnWall = true;

    UPROPERTY(Category = "Streak")
    int32 Seed = 1;

    // Unset: WetStreakRust_Mars_MI when Mineral > 0.5, else WetStreakDamp_Mars_MI.
    UPROPERTY(Category = "Streak")
    UMaterialInterface StreakMaterial;

    // The traced length (cm); 0 when no wall was found.
    UPROPERTY(VisibleAnywhere, Category = "Streak|Readout")
    float32 TracedLength = 0.0f;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Streak")
    void Rebuild()
    {
        Tags.AddUnique(utils_drip::k_JoltNoBakeTag);
        StreakDecal.ComponentTags.AddUnique(utils_drip::k_JoltNoBakeTag);
        auto Material = StreakMaterial;
        if (ck::Is_NOT_Valid(Material))
        { Material = utils_drip::Load_Material(Streak.Mineral > 0.5f ? "WetStreakRust_Mars_MI" : "WetStreakDamp_Mars_MI"); }
        StreakDecal.SetDecalMaterial(Material);

        auto Placement = FMars_DripStreakPlacement();
        Placement.Origin = GetActorLocation();
        Placement.Out = GetActorForwardVector();
        Placement.Spec = Streak;
        Placement.Seed = float32(utils_drip::Roll(Seed, 0, 11));
        TracedLength = float32(utils_drip::Place_Streak(this, StreakDecal, Placement));
    }
}
