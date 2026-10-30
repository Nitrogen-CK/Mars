// Hand-placed drip: a hero leak, a vault line, a cluster, a pipe trickle or a bead patch (DRIPS_PLAN §3.7).
//
// Every moving part is shader maths (Shaders/Water/MarsWet.ush) of game time: this actor only lays the strands out.
// Each strand traces up to the ceiling it hangs from (AttachUp) and down to what it lands on, then becomes:
//   6 drop cards at its impact point (Drops ISM: 4 falling-drop / splash slots, the bead, the thread), whose custom
//     data carries Length (the traced fall; < 0 = Air), Rate, Seed, Jitter, Mode, Slot, DropScale, Surface;
//   1 ring decal (Rings ISM; on still water a translucent ring card in WaterRings, which Single Layer Water needs) whose
//     custom data 0..4 equal the strand's bit for bit, so its rings start on the frame the drop vanishes (same clock);
//   on a floor, a two-layer puddle (PuddleWet darkens, PuddleGloss shines, mesh decals 1.5 cm above the floor).
// Strands that land on still water (Water_Mars_PhysMat or the Mars.Water tag: an AMars_StillWater probe) get rings only.
// Streak.OnWall projects a damp / rust streak down the wall behind the leak (actor +X points out of the wall).
//
// No collision, no shadows, Ck.Jolt.NoBake on every primitive and the actor: adding or moving drips never stales the
// static-world cook. A miss never overwrites a cached hit (unloaded World Partition cells); Trace.Mode = Locked
// freezes the layout.
class AMars_DripLeak : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent Drops;
    default Drops.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent Rings;
    default Rings.Mobility = EComponentMobility::Static;

    // Rings on still water: a translucent card, since Single Layer Water does not receive the decal rings.
    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent WaterRings;
    default WaterRings.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent PuddleWet;
    default PuddleWet.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UInstancedStaticMeshComponent PuddleGloss;
    default PuddleGloss.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UDecalComponent StreakDecal;

    // Pick one, then press ApplyPreset (Custom keeps whatever is set below).
    UPROPERTY(Category = "Drip")
    EMars_DripPreset Preset = EMars_DripPreset::CisternDrip;

    UPROPERTY(Category = "Drip")
    EMars_DripLayout Layout = EMars_DripLayout::Single;

    UPROPERTY(Category = "Drip", meta = (ClampMin = "1", ClampMax = "64"))
    int32 Count = 1;

    // Line: strands spread along actor X over this length (cm).
    UPROPERTY(Category = "Drip")
    float32 LineLength = 600.0f;

    // Cluster: strands inside this radius (cm), sunflower-spread.
    UPROPERTY(Category = "Drip")
    float32 Radius = 120.0f;

    UPROPERTY(Category = "Drip")
    int32 Seed = 1;

    UPROPERTY(Category = "Drip")
    FMars_DripTiming Timing;

    UPROPERTY(Category = "Drip")
    FMars_DripLook Look;

    UPROPERTY(Category = "Drip")
    FMars_DripImpact Impact;

    UPROPERTY(Category = "Drip")
    FMars_DripTrace Trace;

    UPROPERTY(Category = "Drip")
    FMars_DripStreak Streak;

    // Off in tests that rebuild in a game world.
    UPROPERTY(Category = "Drip|Physics")
    bool UseStaticMobility = true;

    // The strands as last traced (world space): a later miss keeps them.
    UPROPERTY(VisibleAnywhere, Category = "Drip|Readout")
    TArray<FMars_DripStrandRecord> CachedStrands;

    // The slowest strand's drops per second after the slot cap (a fast rate on a long fall is lowered).
    UPROPERTY(VisibleAnywhere, Category = "Drip|Readout")
    float32 EffectiveRate = 0.0f;

    // The longest strand's fall time (s).
    UPROPERTY(VisibleAnywhere, Category = "Drip|Readout")
    float32 FallSeconds = 0.0f;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Drip")
    void ApplyPreset()
    {
        if (Preset == EMars_DripPreset::Custom)
        { return; }

        Look.Mode = EMars_DripMode::Drops;
        Impact.Puddles = true;
        Impact.RingAmp = 1.0f;
        Streak.OnWall = false;
        Streak.Mineral = 0.0f;
        if (Preset == EMars_DripPreset::CisternDrip)
        {
            Layout = EMars_DripLayout::Cluster;
            Count = 6;
            Radius = 120.0f;
            Set_Timing(0.25f, 0.9f, 0.6f);
            Set_Puddles(40.0f, 110.0f, 0.85f);
        }
        else if (Preset == EMars_DripPreset::VaultLine)
        {
            Layout = EMars_DripLayout::Line;
            Count = 8;
            LineLength = 600.0f;
            Set_Timing(0.3f, 1.0f, 0.7f);
            Set_Puddles(35.0f, 80.0f, 0.8f);
        }
        else if (Preset == EMars_DripPreset::PipeJoint)
        {
            Layout = EMars_DripLayout::Single;
            Count = 1;
            Look.Mode = EMars_DripMode::DropsWithThread;
            Set_Timing(1.5f, 2.5f, 0.4f);
            Impact.Puddles = false;
            Streak.OnWall = true;
            Streak.Mineral = 0.8f;
        }
        else if (Preset == EMars_DripPreset::PipeTrickle)
        {
            Layout = EMars_DripLayout::Single;
            Count = 1;
            Look.Mode = EMars_DripMode::Stream;
            Set_Timing(6.0f, 9.0f, 0.3f);
            Impact.Puddles = false;
            Streak.OnWall = true;
            Streak.Mineral = 0.8f;
        }
        else if (Preset == EMars_DripPreset::OssuarySeep)
        {
            Layout = EMars_DripLayout::Cluster;
            Count = 3;
            Radius = 40.0f;
            Set_Timing(0.08f, 0.2f, 0.8f);
            // 2026-10-24: 20 - 40 cm at wetness 0.5 vanished under candle light; the seep's floor stain is what reads.
            Set_Puddles(35.0f, 75.0f, 0.8f);
            Streak.OnWall = true;
        }
        else if (Preset == EMars_DripPreset::Beads)
        {
            Layout = EMars_DripLayout::Cluster;
            Count = 12;
            Radius = 30.0f;
            Look.Mode = EMars_DripMode::HangingBead;
            Set_Timing(0.0f, 0.0f, 0.0f);
            Impact.Puddles = false;
        }
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Drip")
    void Reseed()
    {
        Seed += 1;
        Rebuild();
    }

    // Forgets the cached strands and traces again (after the geometry under or over the leak changed).
    UFUNCTION(CallInEditor, Category = "Drip")
    void Retrace()
    {
        CachedStrands.Empty();
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Drip")
    void Rebuild()
    {
        auto CardMesh = utils_drip::Load_Mesh("DropletCard_Mars_SM");
        auto DecalMesh = utils_drip::Load_Mesh("WetDecalCard_Mars_SM");
        if (ck::Is_NOT_Valid(CardMesh) || ck::Is_NOT_Valid(DecalMesh))
        { return; }

        ApplyPhysics();
        Drops.SetStaticMesh(CardMesh);
        Rings.SetStaticMesh(DecalMesh);
        WaterRings.SetStaticMesh(DecalMesh);
        PuddleWet.SetStaticMesh(DecalMesh);
        PuddleGloss.SetStaticMesh(DecalMesh);
        auto DropMaterial = ck::IsValid(Look.DropMaterial) ? Look.DropMaterial : utils_drip::Load_Material("Droplet_Mars_MI");
        Drops.SetMaterial(0, DropMaterial);
        Rings.SetMaterial(0, utils_drip::Load_Material("DripImpact_Mars_MI"));
        WaterRings.SetMaterial(0, utils_drip::Load_Material("DripRingCard_Mars_MI"));
        PuddleWet.SetMaterial(0, utils_drip::Load_Material("PuddleWet_Mars_MI"));
        PuddleGloss.SetMaterial(0, utils_drip::Load_Material("PuddleGloss_Mars_MI"));

        // SetNumCustomDataFloats resets the values: after the clear, before AddInstance.
        Drops.ClearInstances();
        Rings.ClearInstances();
        WaterRings.ClearInstances();
        PuddleWet.ClearInstances();
        PuddleGloss.ClearInstances();
        Drops.SetNumCustomDataFloats(int32(EMars_DripCardData::Count));
        Rings.SetNumCustomDataFloats(int32(EMars_DripRingData::Count));
        WaterRings.SetNumCustomDataFloats(int32(EMars_DripRingData::Count));
        PuddleWet.SetNumCustomDataFloats(int32(EMars_PuddleData::Count));
        PuddleGloss.SetNumCustomDataFloats(int32(EMars_PuddleData::Count));
        _WrittenCardData.Empty();
        _WrittenRingData.Empty();
        _WrittenPuddleData.Empty();

        TArray<FMars_DripStrandRecord> Strands;
        const int32 StrandCount = Get_StrandCount();
        for (int32 Index = 0; Index < StrandCount; ++Index)
        { Strands.Add(Trace_Strand(Index)); }

        EffectiveRate = 0.0f;
        FallSeconds = 0.0f;
        for (int32 Index = 0; Index < Strands.Num(); ++Index)
        { Lay_Strand(Index, Strands[Index]); }

        CachedStrands = Strands;
        Lay_Streak();
        Drops.MarkRenderStateDirty();
        Rings.MarkRenderStateDirty();
        WaterRings.MarkRenderStateDirty();
        PuddleWet.MarkRenderStateDirty();
        PuddleGloss.MarkRenderStateDirty();
    }

    int32 Get_StrandCount() const
    {
        return Layout == EMars_DripLayout::Single ? 1 : Math::Max(Count, 1);
    }

    // The cards each strand gets: one bead card for a bead patch, all six slots otherwise.
    int32 Get_CardsPerStrand() const
    {
        return Is_BeadMode() ? 1 : int32(EMars_DripSlot::Thread) + 1;
    }

    // The custom data last written for one card / ring (rings in laying order, decal or water card; test read-back: script cannot read the ISM's
    // PerInstanceSMCustomData, so Rebuild keeps a mirror of every float it writes).
    float Get_CardValue(int32 InInstance, EMars_DripCardData InSlot) const
    {
        const int32 Index = InInstance * int32(EMars_DripCardData::Count) + int32(InSlot);
        return _WrittenCardData.IsValidIndex(Index) ? _WrittenCardData[Index] : -99999.0;
    }

    float Get_RingValue(int32 InInstance, EMars_DripRingData InSlot) const
    {
        const int32 Index = InInstance * int32(EMars_DripRingData::Count) + int32(InSlot);
        return _WrittenRingData.IsValidIndex(Index) ? _WrittenRingData[Index] : -99999.0;
    }

    float Get_PuddleValue(int32 InInstance, EMars_PuddleData InSlot) const
    {
        const int32 Index = InInstance * int32(EMars_PuddleData::Count) + int32(InSlot);
        return _WrittenPuddleData.IsValidIndex(Index) ? _WrittenPuddleData[Index] : -99999.0;
    }

    private TArray<float> _WrittenCardData;
    private TArray<float> _WrittenRingData;
    private TArray<float> _WrittenPuddleData;

    private bool Is_BeadMode() const
    {
        return Look.Mode == EMars_DripMode::HangingBead || Look.Mode == EMars_DripMode::SittingBead;
    }

    private void Set_Timing(float32 InRateMin, float32 InRateMax, float32 InJitter)
    {
        Timing.RateMin = InRateMin;
        Timing.RateMax = InRateMax;
        Timing.Jitter = InJitter;
    }

    private void Set_Puddles(float32 InSizeMin, float32 InSizeMax, float32 InWetness)
    {
        Impact.Puddles = true;
        Impact.SizeMin = InSizeMin;
        Impact.SizeMax = InSizeMax;
        Impact.Wetness = InWetness;
    }

    private void ApplyPhysics()
    {
        const auto Mobility = UseStaticMobility ? EComponentMobility::Static : EComponentMobility::Movable;
        SceneRoot.SetMobility(Mobility);
        TArray<UPrimitiveComponent> Primitives;
        Primitives.Add(Drops);
        Primitives.Add(Rings);
        Primitives.Add(WaterRings);
        Primitives.Add(PuddleWet);
        Primitives.Add(PuddleGloss);
        for (auto Primitive : Primitives)
        {
            Primitive.SetMobility(Mobility);
            utils_drip::Apply_NoCollision(Primitive);
            Primitive.SetReceivesDecals(false);
        }

        // Mesh decals draw in this order: puddle darkening, its gloss, then the rings on top.
        PuddleWet.SetTranslucentSortPriority(0);
        PuddleGloss.SetTranslucentSortPriority(1);
        Rings.SetTranslucentSortPriority(2);
        Drops.SetCullDistances(0, 4000);
        Rings.SetCullDistances(0, 2500);
        WaterRings.SetCullDistances(0, 2500);
        PuddleWet.SetCullDistances(0, 6000);
        PuddleGloss.SetCullDistances(0, 6000);
        StreakDecal.ComponentTags.AddUnique(utils_drip::k_JoltNoBakeTag);
        Tags.AddUnique(utils_drip::k_JoltNoBakeTag);
    }

    // Actor-local XY of strand InIndex.
    private FVector Get_LocalPoint(int32 InIndex) const
    {
        const int32 N = Get_StrandCount();
        if (Layout == EMars_DripLayout::Line && N > 1)
        {
            const float Spacing = float(LineLength) / float(N - 1);
            const float X = (float(InIndex) / float(N - 1) - 0.5) * float(LineLength)
                + (utils_drip::Roll(Seed, InIndex, 0) - 0.5) * 0.7 * Spacing;
            return FVector(X, (utils_drip::Roll(Seed, InIndex, 5) - 0.5) * 0.2 * Spacing, 0.0);
        }

        if (Layout == EMars_DripLayout::Cluster && N > 1)
        {
            const float R = float(Radius) * Math::Sqrt((float(InIndex) + 0.5) / float(N));
            const float Theta = 2.39996 * float(InIndex) + utils_drip::Roll(Seed, 0, 6) * 6.2831853;
            const float Spacing = float(Radius) * 1.77 / Math::Sqrt(float(N));
            return FVector(R * Math::Cos(Theta) + (utils_drip::Roll(Seed, InIndex, 0) - 0.5) * 0.6 * Spacing,
                R * Math::Sin(Theta) + (utils_drip::Roll(Seed, InIndex, 5) - 0.5) * 0.6 * Spacing, 0.0);
        }

        return FVector::ZeroVector;
    }

    private FMars_DripStrandRecord Trace_Strand(int32 InIndex)
    {
        const bool HasCache = CachedStrands.IsValidIndex(InIndex);
        if (Trace.Mode == EMars_DripTraceMode::Locked && HasCache)
        {
            auto Locked = CachedStrands[InIndex];
            Locked.State = EMars_DripTraceState::Locked;
            return Finish_Strand(InIndex, Locked);
        }

        FVector Source = GetActorTransform().TransformPosition(Get_LocalPoint(InIndex));
        if (Trace.AttachUp)
        {
            const auto Up = utils_drip::Trace_WorldStatic(this, Source + FVector(0.0, 0.0, 1.0),
                Source + FVector(0.0, 0.0, float(Trace.MaxRise)));
            if (Up.bBlockingHit && Up.ImpactNormal.Z < -0.35)
            { Source = Up.ImpactPoint - FVector(0.0, 0.0, 1.0); }
        }

        auto Record = FMars_DripStrandRecord();
        Record.Source = Source;
        if (Trace.Air && Look.Mode != EMars_DripMode::SittingBead)
        {
            Record.Length = -Math::Max(Trace.AirLength, 1.0f);
            Record.Impact.Point = Source + FVector(0.0, 0.0, float(Record.Length));
            Record.Impact.Surface = EMars_DripSurface::Air;
            Record.State = EMars_DripTraceState::Air;
            return Finish_Strand(InIndex, Record);
        }

        const auto Down = utils_drip::Trace_WorldStatic(this, Source, Source - FVector(0.0, 0.0, float(Trace.MaxLength)));
        const bool Landed = Down.bBlockingHit && (Down.Distance >= Trace.MinLength || Look.Mode == EMars_DripMode::SittingBead);
        if (Landed)
        {
            Record.Length = float32(Down.Distance);
            Record.Impact.Point = Down.ImpactPoint;
            Record.Impact.Normal = Down.ImpactNormal;
            if (utils_drip::Is_WaterHit(Down))
            { Record.Impact.Surface = EMars_DripSurface::Water; }
            else if (Down.ImpactNormal.Z < 0.7)
            { Record.Impact.Surface = EMars_DripSurface::Dry; }
            else
            { Record.Impact.Surface = EMars_DripSurface::Floor; }
            Record.State = EMars_DripTraceState::Hit;
            return Finish_Strand(InIndex, Record);
        }

        // A miss never overwrites a cached hit.
        if (HasCache && CachedStrands[InIndex].State != EMars_DripTraceState::MissedNoCache
            && CachedStrands[InIndex].State != EMars_DripTraceState::Air)
        {
            auto Kept = CachedStrands[InIndex];
            Kept.State = EMars_DripTraceState::MissedKeptCached;
            return Finish_Strand(InIndex, Kept);
        }

        Record.Length = -Math::Max(Trace.MaxLength, 1.0f);
        Record.Impact.Point = Source + FVector(0.0, 0.0, float(Record.Length));
        Record.Impact.Surface = EMars_DripSurface::Air;
        Record.State = EMars_DripTraceState::MissedNoCache;
        return Finish_Strand(InIndex, Record);
    }

    // Per-strand rate (log-uniform between the timing bounds) and seed.
    private FMars_DripStrandRecord Finish_Strand(int32 InIndex, FMars_DripStrandRecord InRecord)
    {
        auto Record = InRecord;
        const float Lo = Math::Max(float(Math::Min(Timing.RateMin, Timing.RateMax)), 0.0);
        const float Hi = Math::Max(float(Math::Max(Timing.RateMin, Timing.RateMax)), 0.0);
        if (Hi <= 0.0)
        { Record.Rate = 0.0f; }
        else
        {
            const float L0 = Math::Loge(Math::Max(Lo, 0.001));
            const float L1 = Math::Loge(Math::Max(Hi, 0.001));
            Record.Rate = float32(Math::Exp(Math::Lerp(L0, L1, utils_drip::Roll(Seed, InIndex, 1))));
        }

        const float S = float(Seed) * 0.618 + utils_drip::Roll(Seed, InIndex, 2);
        Record.Seed = float32(S - Math::FloorToFloat(S));
        return Record;
    }

    private void Lay_Strand(int32 InIndex, const FMars_DripStrandRecord& InStrand)
    {
        auto Schedule = FMars_DripSchedule();
        Schedule.Length = float(InStrand.Length);
        Schedule.Rate = float(InStrand.Rate);
        Schedule.Seed = float(InStrand.Seed);
        Schedule.Jitter = float(Timing.Jitter);
        Schedule.Mode = float(int32(Look.Mode));
        Schedule.DropRadius = utils_drip::k_DropRadius * float(Look.DropScale);
        Schedule.Setup();
        if (InStrand.Rate > 0.0f && (EffectiveRate <= 0.0f || Schedule.Get_EffectiveRate() < EffectiveRate))
        { EffectiveRate = float32(Schedule.Get_EffectiveRate()); }
        FallSeconds = float32(Math::Max(float(FallSeconds), Schedule.FallSeconds));

        const float L = Math::Abs(float(InStrand.Length));
        FTransform Card;
        if (Look.Mode == EMars_DripMode::SittingBead)
        { Card = FTransform(FRotator::MakeFromZ(InStrand.Impact.Normal), InStrand.Impact.Point, FVector(0.1, 0.1, 0.1)); }
        else
        { Card = FTransform(FRotator::ZeroRotator, InStrand.Source - FVector(0.0, 0.0, L), FVector(0.1, 0.1, Math::Max(L, 1.0) / 100.0)); }

        TArray<float> Data;
        Data.SetNum(int32(EMars_DripCardData::Count));
        Data[int32(EMars_DripCardData::Length)] = Look.Mode == EMars_DripMode::SittingBead ? 0.0 : float(InStrand.Length);
        Data[int32(EMars_DripCardData::Rate)] = float(InStrand.Rate);
        Data[int32(EMars_DripCardData::Seed)] = float(InStrand.Seed);
        Data[int32(EMars_DripCardData::Jitter)] = float(Timing.Jitter);
        Data[int32(EMars_DripCardData::Mode)] = float(int32(Look.Mode));
        Data[int32(EMars_DripCardData::DropScale)] = float(Look.DropScale);
        Data[int32(EMars_DripCardData::Surface)] = float(int32(InStrand.Impact.Surface));

        const int32 FirstSlot = Is_BeadMode() ? int32(EMars_DripSlot::Bead) : 0;
        const int32 LastSlot = Is_BeadMode() ? int32(EMars_DripSlot::Bead) : int32(EMars_DripSlot::Thread);
        for (int32 Slot = FirstSlot; Slot <= LastSlot; ++Slot)
        {
            const int32 Instance = Drops.AddInstance(Card, true);
            Data[int32(EMars_DripCardData::Slot)] = float(Slot);
            for (int32 Value = 0; Value < Data.Num(); ++Value)
            {
                Drops.SetCustomDataValue(Instance, Value, float32(Data[Value]), false);
                _WrittenCardData.Add(float(float32(Data[Value])));
            }
        }

        const bool Lands = InStrand.Length > 0.0f && !Is_BeadMode();
        if (!Lands || InStrand.Impact.Surface == EMars_DripSurface::Dry || Impact.RingAmp <= 0.0f)
        { return; }

        const bool OnWater = InStrand.Impact.Surface == EMars_DripSurface::Water;
        const FVector N = OnWater ? FVector::UpVector : InStrand.Impact.Normal;
        const FVector RingAt = InStrand.Impact.Point + (OnWater ? FVector(0.0, 0.0, 0.3) : N * 1.0);
        const auto RingRotation = utils_drip::Make_SurfaceRotation(N, utils_drip::Roll(Seed, InIndex, 3) * 360.0);
        auto RingPool = OnWater ? WaterRings : Rings;
        const int32 Ring = RingPool.AddInstance(FTransform(RingRotation, RingAt, FVector(0.6, 0.6, 1.0)), true);
        for (int32 Value = 0; Value < int32(EMars_DripRingData::RingAmp); ++Value)
        {
            RingPool.SetCustomDataValue(Ring, Value, float32(Data[Value]), false);
            _WrittenRingData.Add(float(float32(Data[Value])));
        }
        RingPool.SetCustomDataValue(Ring, int32(EMars_DripRingData::RingAmp), Impact.RingAmp, false);
        _WrittenRingData.Add(float(Impact.RingAmp));

        if (OnWater || !Impact.Puddles)
        { return; }

        const float Size = Math::Lerp(float(Impact.SizeMin), float(Impact.SizeMax), utils_drip::Roll(Seed, InIndex, 4));
        const auto PuddleRotation = utils_drip::Make_SurfaceRotation(N, utils_drip::Roll(Seed, InIndex, 7) * 360.0);
        const auto PuddleAt = FTransform(PuddleRotation, InStrand.Impact.Point + N * float(Impact.WaterLevelOffset),
            FVector(Size / 100.0, Size / 100.0, 1.0));
        TArray<float> Puddle;
        Puddle.SetNum(int32(EMars_PuddleData::Count));
        Puddle[int32(EMars_PuddleData::Seed)] = utils_drip::Roll(Seed, InIndex, 8);
        Puddle[int32(EMars_PuddleData::Wetness)] = float(Impact.Wetness);
        Puddle[int32(EMars_PuddleData::RainRate)] = float(Impact.RainRate);
        Puddle[int32(EMars_PuddleData::Aspect)] = utils_drip::Roll(Seed, InIndex, 9);
        const int32 Wet = PuddleWet.AddInstance(PuddleAt, true);
        const int32 Gloss = PuddleGloss.AddInstance(PuddleAt, true);
        for (int32 Value = 0; Value < Puddle.Num(); ++Value)
        {
            PuddleWet.SetCustomDataValue(Wet, Value, float32(Puddle[Value]), false);
            PuddleGloss.SetCustomDataValue(Gloss, Value, float32(Puddle[Value]), false);
            _WrittenPuddleData.Add(float(float32(Puddle[Value])));
        }
    }

    // A damp / rust streak down the wall behind the leak: trace along -X to the wall, then down the wall to the floor.
    private void Lay_Streak()
    {
        StreakDecal.SetVisibility(false);
        if (!Streak.OnWall)
        { return; }

        auto Material = utils_drip::Load_Material(Streak.Mineral > 0.5f ? "WetStreakRust_Mars_MI" : "WetStreakDamp_Mars_MI");
        auto Placement = FMars_DripStreakPlacement();
        Placement.Origin = GetActorLocation();
        Placement.Out = GetActorForwardVector();
        Placement.Spec = Streak;
        Placement.Seed = float32(utils_drip::Roll(Seed, 0, 11));
        StreakDecal.SetDecalMaterial(Material);
        utils_drip::Place_Streak(this, StreakDecal, Placement);
    }
}
