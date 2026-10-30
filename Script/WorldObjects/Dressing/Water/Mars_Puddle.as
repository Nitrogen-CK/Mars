// A loose cluster of puddles with no drip over them (DRIPS_PLAN §7): Count puddles sunflower-spread inside Radius, each
// projected down onto the floor under it and laid as the same two mesh-decal layers the leaks use (PuddleWet darkens,
// PuddleGloss shines). RainRate adds world-anchored rain rings (PuddleGlossRain_Mars_MI, or a material with the
// RainRipples switch on). No collision, Ck.Jolt.NoBake.
class AMars_Puddle : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent PuddleWet;
    default PuddleWet.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent PuddleGloss;
    default PuddleGloss.Mobility = EComponentMobility::Static;

    UPROPERTY(Category = "Puddle", meta = (ClampMin = "1", ClampMax = "64"))
    int32 Count = 4;

    UPROPERTY(Category = "Puddle")
    float32 Radius = 150.0f;

    UPROPERTY(Category = "Puddle")
    int32 Seed = 1;

    // Size, wetness and the rain rate (RingAmp and WaterLevelOffset as on the leaks).
    UPROPERTY(Category = "Puddle")
    FMars_DripImpact Look;
    default Look.SizeMin = 50.0f;
    default Look.SizeMax = 130.0f;

    // Unset: PuddleGloss_Mars_MI (PuddleGlossRain_Mars_MI when RainRate > 0).
    UPROPERTY(Category = "Puddle")
    UMaterialInterface GlossMaterial;

    UPROPERTY(Category = "Puddle|Physics")
    bool UseStaticMobility = true;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Puddle")
    void Reseed()
    {
        Seed += 1;
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Puddle")
    void Rebuild()
    {
        auto Mesh = utils_drip::Load_Mesh("WetDecalCard_Mars_SM");
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        const auto Mobility = UseStaticMobility ? EComponentMobility::Static : EComponentMobility::Movable;
        SceneRoot.SetMobility(Mobility);
        PuddleWet.SetMobility(Mobility);
        PuddleGloss.SetMobility(Mobility);
        PuddleWet.SetStaticMesh(Mesh);
        PuddleGloss.SetStaticMesh(Mesh);
        PuddleWet.SetMaterial(0, utils_drip::Load_Material("PuddleWet_Mars_MI"));
        auto Gloss = GlossMaterial;
        if (ck::Is_NOT_Valid(Gloss))
        { Gloss = utils_drip::Load_Material(Look.RainRate > 0.0f ? "PuddleGlossRain_Mars_MI" : "PuddleGloss_Mars_MI"); }
        PuddleGloss.SetMaterial(0, Gloss);
        utils_drip::Apply_NoCollision(PuddleWet);
        utils_drip::Apply_NoCollision(PuddleGloss);
        PuddleWet.SetReceivesDecals(false);
        PuddleGloss.SetReceivesDecals(false);
        PuddleWet.SetTranslucentSortPriority(0);
        PuddleGloss.SetTranslucentSortPriority(1);
        PuddleWet.SetCullDistances(0, 6000);
        PuddleGloss.SetCullDistances(0, 6000);
        Tags.AddUnique(utils_drip::k_JoltNoBakeTag);

        PuddleWet.ClearInstances();
        PuddleGloss.ClearInstances();
        PuddleWet.SetNumCustomDataFloats(int32(EMars_PuddleData::Count));
        PuddleGloss.SetNumCustomDataFloats(int32(EMars_PuddleData::Count));
        _WrittenData.Empty();

        const int32 N = Math::Max(Count, 1);
        for (int32 Index = 0; Index < N; ++Index)
        { Lay_Puddle(Index, N); }

        PuddleWet.MarkRenderStateDirty();
        PuddleGloss.MarkRenderStateDirty();
    }

    int32 Get_PuddleCount() const
    {
        return PuddleWet.GetInstanceCount();
    }

    float Get_PuddleValue(int32 InInstance, EMars_PuddleData InSlot) const
    {
        const int32 Index = InInstance * int32(EMars_PuddleData::Count) + int32(InSlot);
        return _WrittenData.IsValidIndex(Index) ? _WrittenData[Index] : -99999.0;
    }

    // Script cannot read the ISM's PerInstanceSMCustomData: Rebuild keeps a mirror of every float it writes.
    private TArray<float> _WrittenData;

    private void Lay_Puddle(int32 InIndex, int32 InCount)
    {
        const float R = float(Radius) * Math::Sqrt((float(InIndex) + 0.5) / float(InCount));
        const float Theta = 2.39996 * float(InIndex) + utils_drip::Roll(Seed, 0, 6) * 6.2831853;
        const FVector Local = FVector(R * Math::Cos(Theta), R * Math::Sin(Theta), 0.0);
        const FVector Point = GetActorTransform().TransformPosition(Local);
        const auto Hit = utils_drip::Trace_WorldStatic(this, Point + FVector(0.0, 0.0, 50.0), Point - FVector(0.0, 0.0, 500.0));
        if (!Hit.bBlockingHit || Hit.ImpactNormal.Z < 0.7 || utils_drip::Is_WaterHit(Hit))
        { return; }

        const float Size = Math::Lerp(float(Look.SizeMin), float(Look.SizeMax), utils_drip::Roll(Seed, InIndex, 4));
        const auto Rotation = utils_drip::Make_SurfaceRotation(Hit.ImpactNormal, utils_drip::Roll(Seed, InIndex, 7) * 360.0);
        const auto At = FTransform(Rotation, Hit.ImpactPoint + Hit.ImpactNormal * float(Look.WaterLevelOffset),
            FVector(Size / 100.0, Size / 100.0, 1.0));
        TArray<float> Data;
        Data.SetNum(int32(EMars_PuddleData::Count));
        Data[int32(EMars_PuddleData::Seed)] = utils_drip::Roll(Seed, InIndex, 8);
        Data[int32(EMars_PuddleData::Wetness)] = float(Look.Wetness);
        Data[int32(EMars_PuddleData::RainRate)] = float(Look.RainRate);
        Data[int32(EMars_PuddleData::Aspect)] = utils_drip::Roll(Seed, InIndex, 9);
        const int32 Wet = PuddleWet.AddInstance(At, true);
        const int32 Gloss = PuddleGloss.AddInstance(At, true);
        for (int32 Value = 0; Value < Data.Num(); ++Value)
        {
            PuddleWet.SetCustomDataValue(Wet, Value, float32(Data[Value]), false);
            PuddleGloss.SetCustomDataValue(Gloss, Value, float32(Data[Value]), false);
            _WrittenData.Add(float(float32(Data[Value])));
        }
    }
}
