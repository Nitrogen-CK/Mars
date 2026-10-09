// Surface FX: footsteps, landings and impacts as one lookup. An event names its kind (SurfaceFx.*), the surface's tags
// (the Surface.* tag on its UCk_PhysicalMaterialWithTags), an optional impactor (Impactor.*) and an intensity in the
// kind's units; the table answers with the FX to play. Resolve is pure; Play is the only side effect. There is no
// feature and no state: an emitter builds the event where it happens and calls Play.

namespace constants_surface_fx
{
    // How far below a capsule's base a ground probe reaches: a step down or a slope under the capsule's centre.
    const float64 k_GroundProbeMarginCm = 50.0;

    // An item's contact normal speed (cm/s) that knocks, and where the light knock gives way to a heavy hit.
    const float32 k_ImpactLightMinSpeed = 100.0f;
    const float32 k_ImpactHeavyMinSpeed = 300.0f;

    // The light knock's volume across [k_ImpactLightMinSpeed, k_ImpactHeavyMinSpeed].
    const float32 k_ImpactLightMinVolume = 0.2f;
    const float32 k_ImpactLightMaxVolume = 0.5f;

    // Gait SpeedRatio is ground speed over the walk speed: a run is past the midpoint of walk (1.0) and sprint (700 / 420).
    const float32 k_RunSpeedRatio = 1.33f;
}

//----------------------------------------------------------------------------------------------------------------------
// The table
//----------------------------------------------------------------------------------------------------------------------

// One intensity band of a cell, from MinIntensity up to the next variant's. The event's intensity maps, clamped, from
// IntensityRange onto VolumeRange; the pitch is 1 +- a random PitchJitter.
struct FMars_SurfaceFx_Variant
{
    UPROPERTY()
    float32 MinIntensity = 0.0f;

    UPROPERTY()
    TSoftObjectPtr<USoundBase> Sound;

    UPROPERTY()
    TSoftObjectPtr<UNiagaraSystem> Vfx;

    // Shakes the local player's camera, and only for an event the local player caused.
    UPROPERTY()
    TSoftClassPtr<UCameraShakeBase> Shake;

    UPROPERTY()
    FVector2D IntensityRange = FVector2D(0.0, 1.0);

    UPROPERTY()
    FVector2D VolumeRange = FVector2D(1.0, 1.0);

    UPROPERTY()
    float32 PitchJitter = 0.0f;
}

// Variants in strictly ascending MinIntensity. A struct because a TMap value cannot be a bare TArray.
struct FMars_SurfaceFx_Cell
{
    UPROPERTY()
    TArray<FMars_SurfaceFx_Variant> Variants;
}

// SurfaceFx.* kind -> cell.
struct FMars_SurfaceFx_Kinds
{
    UPROPERTY()
    TMap<FGameplayTag, FMars_SurfaceFx_Cell> ByKind;
}

// One surface's FX, and per Impactor.* tag the kinds that impactor plays differently on it.
struct FMars_SurfaceFx_Row
{
    UPROPERTY()
    FMars_SurfaceFx_Kinds Kinds;

    UPROPERTY()
    TMap<FGameplayTag, FMars_SurfaceFx_Kinds> ByImpactor;
}

class UMars_SurfaceFx_Table : UDataAsset
{
    // Surface.* -> row. Surface.Default is required and has every kind any row uses, so a kind always resolves.
    UPROPERTY()
    TMap<FGameplayTag, FMars_SurfaceFx_Row> Rows;

    // Another pawn's events play this much quieter, and not at all beyond EarshotDistance (cm) from the local pawn.
    UPROPERTY()
    float32 RemoteVolumeScale = 0.5f;

    UPROPERTY()
    float32 EarshotDistance = 2500.0f;
}

//----------------------------------------------------------------------------------------------------------------------
// Events
//----------------------------------------------------------------------------------------------------------------------

struct FMars_SurfaceFx_Contact
{
    UPROPERTY()
    FVector Location;

    // Away from the surface; zero leaves the Vfx unrotated.
    UPROPERTY()
    FVector Normal;
}

struct FMars_SurfaceFx_Event
{
    // SurfaceFx.*
    UPROPERTY()
    FGameplayTag Kind;

    // The surface's phys mat tags; none plays Surface.Default.
    UPROPERTY()
    FGameplayTagContainer SurfaceTags;

    // Optional Impactor.*
    UPROPERTY()
    FGameplayTag Impactor;

    UPROPERTY()
    FMars_SurfaceFx_Contact Contact;

    // Footstep: gait SpeedRatio. Land: landing speed, cm/s. Impact: contact normal speed, cm/s.
    UPROPERTY()
    float32 Intensity = 0.0f;

    // Whose event, for local, remote and shake playback. Optional: an invalid one plays as the world's.
    UPROPERTY()
    FCk_Handle Instigator;
}

// The variant an event picked, at the event's intensity. Soft, so Resolve loads nothing; Play loads.
struct FMars_SurfaceFx_Resolved
{
    UPROPERTY()
    TSoftObjectPtr<USoundBase> Sound;

    UPROPERTY()
    TSoftObjectPtr<UNiagaraSystem> Vfx;

    UPROPERTY()
    TSoftClassPtr<UCameraShakeBase> Shake;

    UPROPERTY()
    float32 Volume = 1.0f;

    UPROPERTY()
    float32 PitchJitter = 0.0f;
}

// A straight-down probe for the surface under something.
struct FMars_SurfaceFx_GroundQuery
{
    UPROPERTY()
    FVector Origin;

    UPROPERTY()
    float64 DepthCm = 0.0;

    // Usually the prober itself.
    UPROPERTY()
    TArray<AActor> Ignored;
}

struct FMars_SurfaceFx_Ground
{
    UPROPERTY()
    FMars_SurfaceFx_Contact Contact;

    // What the hit primitive's body reports: its override, else its mesh's, else the engine default.
    UPROPERTY()
    UPhysicalMaterial PhysicalMaterial;

    UPROPERTY()
    FGameplayTagContainer SurfaceTags;
}

// A gait's monotonic event counters at one moment (CkGait Get_FootfallCount, Get_LandingCount).
struct FMars_SurfaceFx_GaitCounts
{
    UPROPERTY()
    int32 Footfalls = 0;

    UPROPERTY()
    int32 Landings = 0;
}

// How many footsteps and landings an emitter plays for a change in a gait's counters.
struct FMars_SurfaceFx_GaitEmits
{
    UPROPERTY()
    int32 Footsteps = 0;

    UPROPERTY()
    int32 Lands = 0;
}

//----------------------------------------------------------------------------------------------------------------------
// Validation
//----------------------------------------------------------------------------------------------------------------------

mixin FMars_Validation Validate(const FMars_SurfaceFx_Variant& Self)
{
    if (Math::IsFinite(Self.MinIntensity) == false)
    { return FMars_Validation("a variant has a non-finite MinIntensity"); }

    if (Math::IsFinite(Self.IntensityRange.X) == false || Math::IsFinite(Self.IntensityRange.Y) == false
        || Self.IntensityRange.X > Self.IntensityRange.Y)
    { return FMars_Validation(f"a variant at {Self.MinIntensity} has an IntensityRange that is not finite and ascending"); }

    if (Math::IsFinite(Self.VolumeRange.X) == false || Math::IsFinite(Self.VolumeRange.Y) == false
        || Self.VolumeRange.X < 0.0 || Self.VolumeRange.Y < 0.0)
    { return FMars_Validation(f"a variant at {Self.MinIntensity} has a VolumeRange that is not finite and non-negative"); }

    if (Math::IsFinite(Self.PitchJitter) == false || Self.PitchJitter < 0.0f || Self.PitchJitter >= 1.0f)
    { return FMars_Validation(f"a variant at {Self.MinIntensity} has a PitchJitter outside [0, 1)"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_SurfaceFx_Cell& Self)
{
    if (Self.Variants.Num() == 0)
    { return FMars_Validation("a cell has no variants"); }

    for (int32 Index = 0; Index < Self.Variants.Num(); ++Index)
    {
        const auto Result = Self.Variants[Index].Validate();
        if (Result.IsValid() == false)
        { return Result; }

        if (Index > 0 && Self.Variants[Index].MinIntensity <= Self.Variants[Index - 1].MinIntensity)
        { return FMars_Validation(f"a cell's variants are not in strictly ascending MinIntensity at index {Index}"); }
    }

    return FMars_Validation();
}

// Every kind valid, present in InDefault (so it can always fall back) and its cell valid.
mixin FMars_Validation Validate(const FMars_SurfaceFx_Kinds& Self, const FMars_SurfaceFx_Kinds& InDefault)
{
    for (auto Kind : Self.ByKind)
    {
        if (Kind.Key.IsValid() == false)
        { return FMars_Validation("an invalid kind tag"); }

        if (InDefault.ByKind.Contains(Kind.Key) == false)
        { return FMars_Validation(f"kind {Kind.Key} is missing from the {GameplayTags::Surface_Default} row"); }

        const auto Result = Kind.Value.Validate();
        if (Result.IsValid() == false)
        { return FMars_Validation(f"kind {Kind.Key}: {Result.Get_Error()}"); }
    }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const UMars_SurfaceFx_Table Self)
{
    FMars_SurfaceFx_Row DefaultRow;
    if (Self.Rows.Find(GameplayTags::Surface_Default, DefaultRow) == false)
    { return FMars_Validation(f"[{Self.GetName()}] has no {GameplayTags::Surface_Default} row"); }

    if (Math::IsFinite(Self.RemoteVolumeScale) == false || Self.RemoteVolumeScale < 0.0f)
    { return FMars_Validation(f"[{Self.GetName()}] has a RemoteVolumeScale that is not finite and non-negative"); }

    if (Math::IsFinite(Self.EarshotDistance) == false || Self.EarshotDistance <= 0.0f)
    { return FMars_Validation(f"[{Self.GetName()}] has an EarshotDistance that is not finite and positive"); }

    for (auto Row : Self.Rows)
    {
        if (Row.Key.IsValid() == false)
        { return FMars_Validation(f"[{Self.GetName()}] has a row with an invalid surface tag"); }

        const auto KindsResult = Row.Value.Kinds.Validate(DefaultRow.Kinds);
        if (KindsResult.IsValid() == false)
        { return FMars_Validation(f"[{Self.GetName()}] row {Row.Key}: {KindsResult.Get_Error()}"); }

        for (auto Override : Row.Value.ByImpactor)
        {
            if (Override.Key.IsValid() == false)
            { return FMars_Validation(f"[{Self.GetName()}] row {Row.Key} has an invalid impactor tag"); }

            const auto OverrideResult = Override.Value.Validate(DefaultRow.Kinds);
            if (OverrideResult.IsValid() == false)
            { return FMars_Validation(f"[{Self.GetName()}] row {Row.Key} impactor {Override.Key}: {OverrideResult.Get_Error()}"); }
        }
    }

    return FMars_Validation();
}

//----------------------------------------------------------------------------------------------------------------------
// Resolve, play
//----------------------------------------------------------------------------------------------------------------------

namespace utils_surface_fx
{
    // Empty for a null phys mat or one without tags.
    FGameplayTagContainer Get_SurfaceTags(UPhysicalMaterial InPhysicalMaterial)
    {
        return utils_physics::Get_PhysicalMaterialTags(InPhysicalMaterial);
    }

    // A simple-collision Visibility trace straight down from InQuery.Origin; false when it hits nothing.
    bool TryGet_SurfaceUnder(const FMars_SurfaceFx_GroundQuery& InQuery, FMars_SurfaceFx_Ground& OutGround)
    {
        const auto End = InQuery.Origin - FVector(0.0, 0.0, InQuery.DepthCm);
        const auto TraceComplex = false;
        const auto IgnoreSelf = false;

        FHitResult Hit;
        if (System::LineTraceSingle(InQuery.Origin, End, ETraceTypeQuery::Visibility, TraceComplex, InQuery.Ignored,
                EDrawDebugTrace::None, Hit, IgnoreSelf) == false)
        { return false; }

        UPhysicalMaterial PhysicalMaterial = Hit.PhysMaterial;
        OutGround.Contact.Location = Hit.ImpactPoint;
        OutGround.Contact.Normal = Hit.ImpactNormal;
        OutGround.PhysicalMaterial = PhysicalMaterial;
        OutGround.SurfaceTags = Get_SurfaceTags(PhysicalMaterial);
        return true;
    }

    // The variant InEvent plays: the first cell for its kind along impactor override -> surface row -> parent rows ->
    // Surface.Default, then that cell's highest variant at or below the intensity. Unset when the cell has none; a
    // quieter event never falls through to another row.
    TOptional<FMars_SurfaceFx_Resolved> Resolve(const UMars_SurfaceFx_Table InTable, const FMars_SurfaceFx_Event& InEvent)
    {
        FMars_SurfaceFx_Cell Cell;
        if (TryGet_Cell(InTable, InEvent, Cell) == false)
        { return TOptional<FMars_SurfaceFx_Resolved>(); }

        auto Index = -1;
        for (int32 Candidate = 0; Candidate < Cell.Variants.Num(); ++Candidate)
        {
            if (Cell.Variants[Candidate].MinIntensity <= InEvent.Intensity)
            { Index = Candidate; }
        }

        if (Index < 0)
        { return TOptional<FMars_SurfaceFx_Resolved>(); }

        const auto& Variant = Cell.Variants[Index];
        auto Resolved = FMars_SurfaceFx_Resolved();
        Resolved.Sound = Variant.Sound;
        Resolved.Vfx = Variant.Vfx;
        Resolved.Shake = Variant.Shake;
        Resolved.Volume = Get_Volume(Variant, InEvent.Intensity);
        Resolved.PitchJitter = Variant.PitchJitter;
        return TOptional<FMars_SurfaceFx_Resolved>(Resolved);
    }

    bool TryGet_Cell(const UMars_SurfaceFx_Table InTable, const FMars_SurfaceFx_Event& InEvent, FMars_SurfaceFx_Cell& OutCell)
    {
        auto Surface = Get_DeepestSurfaceRow(InTable, InEvent.SurfaceTags);
        while (Surface.IsValid())
        {
            FMars_SurfaceFx_Row Row;
            if (InTable.Rows.Find(Surface, Row) && TryGet_RowCell(Row, InEvent, OutCell))
            { return true; }

            Surface = Surface.RequestDirectParent();
        }

        FMars_SurfaceFx_Row DefaultRow;
        return InTable.Rows.Find(GameplayTags::Surface_Default, DefaultRow) && TryGet_RowCell(DefaultRow, InEvent, OutCell);
    }

    // The row's override for the event's impactor, else the row's own.
    bool TryGet_RowCell(const FMars_SurfaceFx_Row& InRow, const FMars_SurfaceFx_Event& InEvent, FMars_SurfaceFx_Cell& OutCell)
    {
        FMars_SurfaceFx_Kinds Override;
        if (InEvent.Impactor.IsValid() && InRow.ByImpactor.Find(InEvent.Impactor, Override)
            && Override.ByKind.Find(InEvent.Kind, OutCell))
        { return true; }

        return InRow.Kinds.ByKind.Find(InEvent.Kind, OutCell);
    }

    // The most specific non-default row InTags carries (a row's tag or a child of it); invalid when there is none.
    FGameplayTag Get_DeepestSurfaceRow(const UMars_SurfaceFx_Table InTable, const FGameplayTagContainer& InTags)
    {
        auto Deepest = FGameplayTag();
        auto DeepestDepth = 0;
        for (auto Row : InTable.Rows)
        {
            if (Row.Key == GameplayTags::Surface_Default || InTags.HasTag(Row.Key) == false)
            { continue; }

            const auto Depth = Get_TagDepth(Row.Key);
            if (Depth > DeepestDepth)
            {
                Deepest = Row.Key;
                DeepestDepth = Depth;
            }
        }

        return Deepest;
    }

    // Surface.Stone.Gritty is 3.
    int32 Get_TagDepth(FGameplayTag InTag)
    {
        auto Depth = 0;
        auto Tag = InTag;
        while (Tag.IsValid())
        {
            ++Depth;
            Tag = Tag.RequestDirectParent();
        }

        return Depth;
    }

    float32 Get_Volume(const FMars_SurfaceFx_Variant& InVariant, float32 InIntensity)
    {
        const auto From = InVariant.IntensityRange.X;
        const auto To = InVariant.IntensityRange.Y;
        auto Alpha = InIntensity >= To ? 1.0 : 0.0;
        if (To > From)
        { Alpha = Math::Clamp((InIntensity - From) / (To - From), 0.0, 1.0); }

        const auto Low = InVariant.VolumeRange.X;
        const auto High = InVariant.VolumeRange.Y;
        return float32(Low + (High - Low) * Alpha);
    }

    // One emit per counter increment from InSeen to InNow. A counter behind InSeen (a replaced gait) emits nothing; the
    // caller keeps InNow as its next InSeen either way.
    FMars_SurfaceFx_GaitEmits Get_GaitEmits(const FMars_SurfaceFx_GaitCounts& InSeen, const FMars_SurfaceFx_GaitCounts& InNow)
    {
        auto Emits = FMars_SurfaceFx_GaitEmits();
        Emits.Footsteps = Math::Max(InNow.Footfalls - InSeen.Footfalls, 0);
        Emits.Lands = Math::Max(InNow.Landings - InSeen.Landings, 0);
        return Emits;
    }

    FMars_SurfaceFx_GaitCounts Get_GaitCounts(const FCk_Handle_Gait& InGait)
    {
        auto Counts = FMars_SurfaceFx_GaitCounts();
        Counts.Footfalls = InGait.Get_FootfallCount();
        Counts.Landings = InGait.Get_LandingCount();
        return Counts;
    }

    // Resolves InEvent against the shipped table and plays it on this machine: the sound and the Vfx at the contact, and
    // the shake when the local player caused it. Another pawn's event plays at the table's RemoteVolumeScale, and not
    // at all beyond its EarshotDistance from the local pawn.
    void Play(const FMars_SurfaceFx_Event& InEvent)
    {
        const auto Table = Get_Table();
        const auto Resolved = Resolve(Table, InEvent);
        if (Resolved.IsSet() == false)
        { return; }

        FMars_SurfaceFx_Resolved Fx = Resolved.GetValue();
        const auto Control = Get_InstigatorControl(InEvent.Instigator);
        if (Control == ECk_Utils_Net_IsLocallyControlled_Result::IsNotLocallyControlled)
        {
            if (Get_IsWithinEarshot(InEvent.Contact.Location, Table.EarshotDistance) == false)
            { return; }

            Fx.Volume = Fx.Volume * Table.RemoteVolumeScale;
        }

        Play_Sound(Fx, InEvent.Contact);
        Play_Vfx(Fx, InEvent.Contact);

        if (Control == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { Play_Shake(Fx); }
    }

    // IsNotValidPawn for no instigator or one that is not a pawn: the world's own events play as local ones without a shake.
    ECk_Utils_Net_IsLocallyControlled_Result Get_InstigatorControl(const FCk_Handle& InInstigator)
    {
        if (ck::Is_NOT_Valid(InInstigator))
        { return ECk_Utils_Net_IsLocallyControlled_Result::IsNotValidPawn; }

        return utils_net::Get_IsEntityLocallyControlled_ByPlayer(InInstigator);
    }

    // Measured from the local pawn, which the listener follows.
    bool Get_IsWithinEarshot(FVector InLocation, float32 InDistance)
    {
        auto LocalPawn = Gameplay::GetPlayerPawn(0);
        if (ck::Is_NOT_Valid(LocalPawn))
        { return false; }

        const auto Distance = float(InDistance);
        return InLocation.DistSquared(LocalPawn.GetActorLocation()) <= Distance * Distance;
    }

    void Play_Sound(const FMars_SurfaceFx_Resolved& InFx, const FMars_SurfaceFx_Contact& InContact)
    {
        if (InFx.Sound.IsNull())
        { return; }

        auto Sound = System::LoadAsset_Blocking(InFx.Sound);
        if (ck::EnsureIfNot(ck::IsValid(Sound), f"[SurfaceFx] sound [{InFx.Sound.ToString()}] did not load"))
        { return; }

        const auto Jitter = float(InFx.PitchJitter);
        const auto Pitch = float32(1.0 + Math::RandRange(-Jitter, Jitter));
        Gameplay::PlaySoundAtLocation(Sound, InContact.Location, FRotator::ZeroRotator, InFx.Volume, Pitch);
    }

    void Play_Vfx(const FMars_SurfaceFx_Resolved& InFx, const FMars_SurfaceFx_Contact& InContact)
    {
        if (InFx.Vfx.IsNull())
        { return; }

        auto Template = System::LoadAsset_Blocking(InFx.Vfx);
        if (ck::EnsureIfNot(ck::IsValid(Template), f"[SurfaceFx] Vfx [{InFx.Vfx.ToString()}] did not load"))
        { return; }

        auto Rotation = FRotator::ZeroRotator;
        if (InContact.Normal.SizeSquared() > 0.0)
        { Rotation = FRotator::MakeFromZ(InContact.Normal); }

        const auto AutoDestroy = true;
        const auto AutoActivate = true;
        const auto PreCullCheck = true;
        Niagara::SpawnSystemAtLocation(Template, InContact.Location, Rotation, FVector::OneVector,
            AutoDestroy, AutoActivate, ENCPoolMethod::None, PreCullCheck);
    }

    void Play_Shake(const FMars_SurfaceFx_Resolved& InFx)
    {
        if (InFx.Shake.IsNull())
        { return; }

        auto Controller = Gameplay::GetPlayerController(0);
        if (ck::Is_NOT_Valid(Controller) || ck::Is_NOT_Valid(Controller.PlayerCameraManager))
        { return; }

        TSubclassOf<UCameraShakeBase> ShakeClass;
        ShakeClass = System::LoadClassAsset_Blocking(InFx.Shake);
        if (ck::EnsureIfNot(ShakeClass.IsValid(), f"[SurfaceFx] shake [{InFx.Shake.ToString()}] did not load"))
        { return; }

        Controller.PlayerCameraManager.StartCameraShake(ShakeClass, 1.0f, ECameraShakePlaySpace::CameraLocal, FRotator::ZeroRotator);
    }

    // Loads every asset InTable names into OutLoaded. Whoever holds OutLoaded keeps them resident, so Play finds them
    // loaded instead of loading on a footstep.
    void Load_Assets(const UMars_SurfaceFx_Table InTable, TArray<UObject>& OutLoaded)
    {
        for (auto Row : InTable.Rows)
        {
            Load_KindsAssets(Row.Value.Kinds, OutLoaded);
            for (auto Override : Row.Value.ByImpactor)
            { Load_KindsAssets(Override.Value, OutLoaded); }
        }
    }

    void Load_KindsAssets(const FMars_SurfaceFx_Kinds& InKinds, TArray<UObject>& OutLoaded)
    {
        for (auto Kind : InKinds.ByKind)
        {
            for (auto Variant : Kind.Value.Variants)
            {
                if (Variant.Sound.IsNull() == false)
                { Hold_Loaded(System::LoadAsset_Blocking(Variant.Sound), Variant.Sound.ToString(), OutLoaded); }

                if (Variant.Vfx.IsNull() == false)
                { Hold_Loaded(System::LoadAsset_Blocking(Variant.Vfx), Variant.Vfx.ToString(), OutLoaded); }

                if (Variant.Shake.IsNull() == false)
                { Hold_Loaded(System::LoadClassAsset_Blocking(Variant.Shake), Variant.Shake.ToString(), OutLoaded); }
            }
        }
    }

    void Hold_Loaded(UObject InAsset, const FString& InPath, TArray<UObject>& OutLoaded)
    {
        if (ck::EnsureIfNot(ck::IsValid(InAsset), f"[SurfaceFx] [{InPath}] did not load"))
        { return; }

        OutLoaded.AddUnique(InAsset);
    }
}
