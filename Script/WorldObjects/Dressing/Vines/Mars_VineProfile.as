// UMars_VineProfile: everything a vine looks like and how it clings, as a data asset designers duplicate and tune
// (/Game/Mars/Environment/Dressing/Vines/Profiles/Vine<Preset>_Mars_DA, written by Mars.Vine.SeedProfiles). The six presets'
// numbers live in one place, utils_vine::Fill_Preset, shared by the seeding command and the tests. Validate() names the
// first bad field; Get_SolveSignature() joins only the fields that change a solve, so swapping a mesh or a material
// re-emits a vine without re-tracing it.

struct FMars_VineProfile_StemMeshes
{
    // Segment / chord mesh along ForwardAxis, radius 50 cm, 100 cm long (env kit: VineBark_A, VineStemIvy).
    UPROPERTY()
    UStaticMesh Mesh;

    // Picked per segment by stream (VineBark_B); unset = Mesh.
    UPROPERTY()
    UStaticMesh AltMesh;

    // On the free tip of an Air root (VineTip).
    UPROPERTY()
    UStaticMesh TipMesh;

    // Lumps along roots (VineKnot_A); unset = no knots.
    UPROPERTY()
    UStaticMesh KnotMesh;

    UPROPERTY()
    ESplineMeshAxis ForwardAxis = ESplineMeshAxis::X;
}

struct FMars_VineProfile_Radius
{
    UPROPERTY(meta = (ClampMin = "0.01"))
    float32 StartCm = 1.2f;

    // Radius at the tip as a fraction of the start, (0, 1].
    UPROPERTY()
    float32 EndFrac = 0.5f;

    // >1 holds the thickness longer before the tip.
    UPROPERTY(meta = (ClampMin = "0.05"))
    float32 TaperPower = 1.0f;

    // Radius noise along the stem, as a fraction.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 JitterFrac = 0.1f;

    // R0 = StartCm x U(1 - this, 1 + this), drawn once per vine.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "0.9"))
    float32 DrawFrac = 0.0f;
}

struct FMars_VineProfile_Stem
{
    UPROPERTY()
    EMars_VineStemRender Render = EMars_VineStemRender::Instanced;

    UPROPERTY()
    FMars_VineProfile_StemMeshes Meshes;

    UPROPERTY()
    FMars_VineProfile_Radius Radius;

    // Resample length: one segment or chord per step (roots 75, thin roots 40, ivy 10).
    UPROPERTY(meta = (ClampMin = "1.0"))
    float32 SegmentLengthCm = 10.0f;

    // Spline segments: the roll random-walks by up to this much per joint (from a random start), so facets never line
    // up along a root and no segment twists hard.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "180.0"))
    float32 RollJitterDeg = 40.0f;
}

struct FMars_VineProfile_Twist
{
    // 1 = a single stem; 2 = two strands twisting like rope, fused in the middle and forked at both ends.
    UPROPERTY(meta = (ClampMin = "1", ClampMax = "2"))
    int32 Strands = 1;

    UPROPERTY()
    float32 PitchCm = 220.0f;

    // Each strand's radius as a fraction of the root radius.
    UPROPERTY()
    float32 StrandFrac = 0.62f;

    // Strand centre offset from the axis as a fraction of the root radius.
    UPROPERTY()
    float32 OffsetFrac = 0.42f;

    // The length over which the strands fork apart at each end.
    UPROPERTY()
    float32 SplitLengthCm = 90.0f;
}

struct FMars_VineProfile_Meander
{
    // Drops: the sideways wander amplitude and its wavelength along the strand.
    UPROPERTY()
    float32 AmpCm = 3.0f;

    UPROPERTY(meta = (ClampMin = "1.0"))
    float32 WavelengthCm = 40.0f;

    // Creeps: the seeded turn per step.
    UPROPERTY()
    float32 CreepDeg = 8.0f;

    // Drops: a long free hang drifts this far sideways from top to bottom (seeded direction, x U(0.6, 1), an S-curve,
    // scaled down on hangs shorter than 8 m), so tall roots lean instead of hanging plumb. 0 = plumb.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 LeanCm = 0.0f;
}

struct FMars_VineProfile_Attach
{
    // Spline layout: guide samples within this distance of a surface cling to it.
    UPROPERTY()
    float32 ClingRadiusCm = 60.0f;

    // Gap between the stem surface and the host (negative sinks a root in).
    UPROPERTY()
    float32 StandOffCm = 0.5f;

    // Surface-walk step, [2, 200].
    UPROPERTY()
    float32 StepCm = 10.0f;

    UPROPERTY(meta = (ClampMin = "0", ClampMax = "8"))
    int32 SmoothPasses = 2;

    // Trace complex collision (ivy hugs the carved surface) or simple (roots ride the UCX hull).
    UPROPERTY()
    bool TraceComplex = true;

    UPROPERTY()
    FMars_VineProfile_Meander Meander;
}

struct FMars_VineProfile_Fingers
{
    // Min / max finger count; 0 0 = none.
    UPROPERTY()
    FIntPoint Count = FIntPoint(0, 0);

    UPROPERTY()
    FVector2D LengthCm = FVector2D(60.0, 160.0);

    // Finger radius at its root as a fraction of the stem radius there (tip 0.04).
    UPROPERTY()
    float32 RadiusFrac = 0.3f;
}

struct FMars_VineProfile_GroundEnd
{
    // Creep along the floor after touching it (min, max cm).
    UPROPERTY()
    FVector2D CreepCm = FVector2D(30.0, 120.0);

    UPROPERTY()
    FMars_VineProfile_Fingers Fingers;

    // How far a root sinks into the floor, as a fraction of its radius.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 SinkFrac = 0.0f;

    // The fillet radius where the drop turns onto the floor.
    UPROPERTY()
    float32 ContactBendCm = 20.0f;

    // Rootlets: a little coil on contact (min, max cm, 0 0 = none).
    UPROPERTY()
    FVector2D CoilCm = FVector2D(0.0, 0.0);

    // Chance of a litter instance (Strands.LitterMesh) at a floor contact.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 LitterChance = 0.0f;
}

struct FMars_VineProfile_AirEnd
{
    // The band above the floor an air end stops in (min, max cm).
    UPROPERTY()
    FVector2D ClearanceCm = FVector2D(60.0, 250.0);

    // Air length as a fraction of the floor distance (min, max); 0 0 = end inside the clearance band instead.
    UPROPERTY()
    FVector2D LengthFrac = FVector2D(0.35, 0.95);

    // Air length limits (min, max cm; max 0 = none).
    UPROPERTY()
    FVector2D LengthCm = FVector2D(20.0, 0.0);

    // The last 15 % of an air tip curls by this much about a seeded horizontal axis.
    UPROPERTY()
    float32 TipCurlDeg = 60.0f;

    // Floor search depth; no floor within it: a Ground end falls back to Air.
    UPROPERTY()
    float32 MaxDropCm = 3000.0f;

    // Sideways sway of a hanging stretch (cm), wavelength 120 cm.
    UPROPERTY()
    float32 SwayCm = 4.0f;
}

struct FMars_VineProfile_CeilingEnd
{
    UPROPERTY()
    FMars_VineProfile_Fingers Fingers;

    // How far the top of a drop starts inside the ceiling.
    UPROPERTY()
    float32 BuryCm = 20.0f;
}

struct FMars_VineProfile_Ends
{
    UPROPERTY()
    FMars_VineProfile_GroundEnd Ground;

    UPROPERTY()
    FMars_VineProfile_AirEnd Air;

    UPROPERTY()
    FMars_VineProfile_CeilingEnd Ceiling;
}

struct FMars_VineProfile_Branches
{
    // Mean spacing of branch sites along a stem (cm, x U(0.6, 1.4)); 0 = no branches.
    UPROPERTY()
    float32 SpacingCm = 0.0f;

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Chance = 0.45f;

    // Branch angle off the stem in the surface plane (min, max deg).
    UPROPERTY()
    FVector2D AngleDeg = FVector2D(25.0, 60.0);

    UPROPERTY()
    FVector2D LengthCm = FVector2D(15.0, 60.0);

    UPROPERTY(meta = (ClampMin = "0", ClampMax = "1"))
    int32 Depth = 1;

    // Tendrils per air tip (min, max).
    UPROPERTY()
    FIntPoint TipTendrils = FIntPoint(0, 0);
}

struct FMars_VineProfile_LeafFalloff
{
    // Keep probability per leaf site before the falloff.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Density = 1.0f;

    // Full density up to this fraction of the stem, then a fade to TipDensity at the tip.
    UPROPERTY()
    float32 HoldFrac = 0.65f;

    UPROPERTY()
    float32 TipDensity = 0.3f;

    // Leaf scale at the tip, as a fraction.
    UPROPERTY()
    float32 TipScale = 0.6f;
}

struct FMars_VineProfile_Leaves
{
    // Up to three meshes (VineLeaves_A/B/C), picked by Weights; empty = no leaves.
    UPROPERTY()
    TArray<UStaticMesh> Meshes;

    UPROPERTY()
    TArray<float32> Weights;

    UPROPERTY()
    float32 SpacingCm = 7.0f;

    UPROPERTY()
    FVector2D Scale = FVector2D(0.8, 1.25);

    UPROPERTY()
    FMars_VineProfile_LeafFalloff Falloff;

    // On a surface: Z tilts off the normal by up to this much.
    UPROPERTY()
    float32 TiltDeg = 25.0f;

    // Hanging: the leaves droop by this much.
    UPROPERTY()
    float32 DroopDeg = 40.0f;
}

struct FMars_VineProfile_Strands
{
    // Up to three 100 cm cards hanging -Z (moss, rootlets, cobweb); the card is scaled to the traced length.
    UPROPERTY()
    TArray<UStaticMesh> Meshes;

    // Patch density.
    UPROPERTY()
    float32 PerSquareMetre = 6.0f;

    UPROPERTY()
    float32 ClumpSigmaCm = 18.0f;

    // Curtain cards per metre of edge (0 = curtains hang stems only).
    UPROPERTY()
    float32 PerMetre = 0.0f;

    // Card width scale (min, max).
    UPROPERTY()
    FVector2D Width = FVector2D(0.7, 1.4);

    // Litter at a floor contact (organic DeadLeaves_Scatter_A, scaled 0.3 - 0.5).
    UPROPERTY()
    UStaticMesh LitterMesh;
}

struct FMars_VineProfile_Curtain
{
    // Strands per curtain (min, max), unless Shape.StrandCount says otherwise.
    UPROPERTY()
    FIntPoint StrandsRange = FIntPoint(6, 10);

    // Where a strand starts back from the lip on the top (min, max cm).
    UPROPERTY()
    FVector2D TopInsetCm = FVector2D(10.0, 25.0);

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 StragglerChance = 0.12f;
}

struct FMars_VineProfile_Shadows
{
    UPROPERTY()
    bool Stems = true;

    UPROPERTY()
    bool Leaves = true;

    UPROPERTY()
    bool Strands = false;
}

// Per-vine material data, written to custom data (VINES.md, the four-float contract).
struct FMars_VineProfile_Data
{
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "2.0"))
    float32 MossScale = 1.0f;

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 WetAdd = 0.0f;

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Dryness = 0.0f;
}

struct FMars_VineProfile_Rendering
{
    // Unset: the mesh's own slot material (<Slot>_Mars_MI).
    UPROPERTY()
    UMaterialInterface StemMaterial;

    UPROPERTY()
    UMaterialInterface LeafMaterial;

    UPROPERTY()
    UMaterialInterface StrandMaterial;

    UPROPERTY()
    FMars_VineProfile_Shadows Shadows;

    // Leaf and card instance cull (start, end cm).
    UPROPERTY()
    FVector2D CullCm = FVector2D(3500.0, 5000.0);

    // Root segments collide (BlockAll, baked by CkJolt: re-cook the static world after an edit).
    UPROPERTY()
    bool Collision = false;

    UPROPERTY()
    FMars_VineProfile_Data Data;
}

class UMars_VineProfile : UDataAsset
{
    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Stem Stem;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Twist Twist;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Attach Attach;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Ends Ends;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Branches Branches;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Leaves Leaves;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Strands Strands;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Curtain Curtain;

    UPROPERTY(Category = "Vine")
    FMars_VineProfile_Rendering Rendering;
}

//----------------------------------------------------------------------------------------------------------------------
// Validation
//----------------------------------------------------------------------------------------------------------------------

mixin FMars_Validation Validate(const UMars_VineProfile Self)
{
    const FString Name = Self.GetName().ToString();
    const auto& Stem = Self.Stem;
    if (Stem.Render != EMars_VineStemRender::None && ck::Is_NOT_Valid(Stem.Meshes.Mesh))
    { return FMars_Validation(f"[{Name}] Stem.Meshes.Mesh is unset for a drawn stem"); }

    if (Stem.Render == EMars_VineStemRender::None && Self.Strands.Meshes.Num() == 0)
    { return FMars_Validation(f"[{Name}] Strands.Meshes is empty and the stem is not drawn: nothing to show"); }

    if (Stem.Radius.EndFrac <= 0.0f || Stem.Radius.EndFrac > 1.0f)
    { return FMars_Validation(f"[{Name}] Stem.Radius.EndFrac {Stem.Radius.EndFrac} is outside (0, 1]"); }

    if (Stem.Radius.StartCm <= 0.0f)
    { return FMars_Validation(f"[{Name}] Stem.Radius.StartCm must be positive"); }

    if (Stem.SegmentLengthCm < 1.0f)
    { return FMars_Validation(f"[{Name}] Stem.SegmentLengthCm must be at least 1 cm"); }

    const auto& Attach = Self.Attach;
    if (Attach.StepCm < 2.0f || Attach.StepCm > 200.0f)
    { return FMars_Validation(f"[{Name}] Attach.StepCm {Attach.StepCm} is outside [2, 200]"); }

    if (Attach.StandOffCm > Attach.ClingRadiusCm)
    { return FMars_Validation(f"[{Name}] Attach.StandOffCm is larger than Attach.ClingRadiusCm"); }

    if (Self.Twist.Strands == 2 && Self.Twist.PitchCm <= 0.0f)
    { return FMars_Validation(f"[{Name}] Twist.PitchCm must be positive for a twin-strand root"); }

    if (Self.Twist.Strands < 1 || Self.Twist.Strands > 2)
    { return FMars_Validation(f"[{Name}] Twist.Strands must be 1 or 2"); }

    const auto& Ends = Self.Ends;
    TArray<FString> RangeNames;
    TArray<FVector2D> Ranges;
    RangeNames.Add("Ends.Ground.CreepCm"); Ranges.Add(Ends.Ground.CreepCm);
    RangeNames.Add("Ends.Ground.Fingers.LengthCm"); Ranges.Add(Ends.Ground.Fingers.LengthCm);
    RangeNames.Add("Ends.Ground.CoilCm"); Ranges.Add(Ends.Ground.CoilCm);
    RangeNames.Add("Ends.Air.ClearanceCm"); Ranges.Add(Ends.Air.ClearanceCm);
    RangeNames.Add("Ends.Air.LengthFrac"); Ranges.Add(Ends.Air.LengthFrac);
    RangeNames.Add("Ends.Ceiling.Fingers.LengthCm"); Ranges.Add(Ends.Ceiling.Fingers.LengthCm);
    RangeNames.Add("Branches.AngleDeg"); Ranges.Add(Self.Branches.AngleDeg);
    RangeNames.Add("Branches.LengthCm"); Ranges.Add(Self.Branches.LengthCm);
    RangeNames.Add("Leaves.Scale"); Ranges.Add(Self.Leaves.Scale);
    RangeNames.Add("Strands.Width"); Ranges.Add(Self.Strands.Width);
    RangeNames.Add("Curtain.TopInsetCm"); Ranges.Add(Self.Curtain.TopInsetCm);
    RangeNames.Add("Rendering.CullCm"); Ranges.Add(Self.Rendering.CullCm);
    for (int32 Index = 0; Index < Ranges.Num(); ++Index)
    {
        if (Ranges[Index].X > Ranges[Index].Y)
        { return FMars_Validation(f"[{Name}] {RangeNames[Index]} has Min > Max"); }
    }

    if (Ends.Air.LengthCm.Y > 0.0 && Ends.Air.LengthCm.X > Ends.Air.LengthCm.Y)
    { return FMars_Validation(f"[{Name}] Ends.Air.LengthCm has Min > Max"); }

    TArray<FString> CountNames;
    TArray<FIntPoint> Counts;
    CountNames.Add("Ends.Ground.Fingers.Count"); Counts.Add(Ends.Ground.Fingers.Count);
    CountNames.Add("Ends.Ceiling.Fingers.Count"); Counts.Add(Ends.Ceiling.Fingers.Count);
    CountNames.Add("Branches.TipTendrils"); Counts.Add(Self.Branches.TipTendrils);
    CountNames.Add("Curtain.StrandsRange"); Counts.Add(Self.Curtain.StrandsRange);
    for (int32 Index = 0; Index < Counts.Num(); ++Index)
    {
        if (Counts[Index].X > Counts[Index].Y || Counts[Index].X < 0)
        { return FMars_Validation(f"[{Name}] {CountNames[Index]} has Min > Max or a negative count"); }
    }

    if (Ends.Air.MaxDropCm < 50.0f)
    { return FMars_Validation(f"[{Name}] Ends.Air.MaxDropCm must be at least 50 cm"); }

    if (Self.Leaves.Meshes.Num() > 3)
    { return FMars_Validation(f"[{Name}] Leaves.Meshes holds more than 3 meshes"); }

    if (Self.Leaves.Meshes.Num() > 0 && Self.Leaves.SpacingCm < 1.0f)
    { return FMars_Validation(f"[{Name}] Leaves.SpacingCm must be at least 1 cm"); }

    if (Self.Strands.Meshes.Num() > 3)
    { return FMars_Validation(f"[{Name}] Strands.Meshes holds more than 3 meshes"); }

    for (int32 Index = 0; Index < Self.Leaves.Meshes.Num(); ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Leaves.Meshes[Index]))
        { return FMars_Validation(f"[{Name}] Leaves.Meshes[{Index}] is unset"); }
    }

    for (int32 Index = 0; Index < Self.Strands.Meshes.Num(); ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Strands.Meshes[Index]))
        { return FMars_Validation(f"[{Name}] Strands.Meshes[{Index}] is unset"); }
    }

    return FMars_Validation();
}

// The fields that change where a vine's paths go: meshes, materials and data are left out.
mixin FString Get_SolveSignature(const UMars_VineProfile Self)
{
    const auto& S = Self.Stem;
    const auto& A = Self.Attach;
    const auto& E = Self.Ends;
    const auto& B = Self.Branches;
    const auto& T = Self.Twist;
    const auto& C = Self.Curtain;
    auto Out = f"st{int32(S.Render)},{S.Radius.StartCm},{S.Radius.EndFrac},{S.Radius.TaperPower},{S.Radius.DrawFrac},{S.SegmentLengthCm}";
    Out = f"{Out}|tw{T.Strands},{T.PitchCm},{T.StrandFrac},{T.OffsetFrac},{T.SplitLengthCm}";
    Out = f"{Out}|at{A.ClingRadiusCm},{A.StandOffCm},{A.StepCm},{A.SmoothPasses},{A.TraceComplex},{A.Meander.AmpCm},{A.Meander.WavelengthCm},{A.Meander.CreepDeg},{A.Meander.LeanCm}";
    Out = f"{Out}|gr{E.Ground.CreepCm.ToString()},{E.Ground.Fingers.Count.ToString()},{E.Ground.Fingers.LengthCm.ToString()},{E.Ground.Fingers.RadiusFrac},{E.Ground.SinkFrac},{E.Ground.ContactBendCm},{E.Ground.CoilCm.ToString()}";
    Out = f"{Out}|ai{E.Air.ClearanceCm.ToString()},{E.Air.LengthFrac.ToString()},{E.Air.LengthCm.ToString()},{E.Air.TipCurlDeg},{E.Air.MaxDropCm},{E.Air.SwayCm}";
    Out = f"{Out}|ce{E.Ceiling.Fingers.Count.ToString()},{E.Ceiling.Fingers.LengthCm.ToString()},{E.Ceiling.Fingers.RadiusFrac},{E.Ceiling.BuryCm}";
    Out = f"{Out}|br{B.SpacingCm},{B.Chance},{B.AngleDeg.ToString()},{B.LengthCm.ToString()},{B.Depth},{B.TipTendrils.ToString()}";
    Out = f"{Out}|sd{Self.Strands.PerSquareMetre},{Self.Strands.ClumpSigmaCm},{Self.Strands.PerMetre}";
    Out = f"{Out}|cu{C.StrandsRange.ToString()},{C.TopInsetCm.ToString()},{C.StragglerChance}";
    return Out;
}

namespace utils_vine
{
    // The preset numbers (VINES.md, profile defaults). Meshes and materials are left as they are: the seeding command
    // binds the kit meshes, the tests bind engine shapes.
    void Fill_Preset(UMars_VineProfile InProfile, EMars_VinePreset InPreset)
    {
        if (ck::Is_NOT_Valid(InProfile))
        { return; }

        // Start from the struct defaults (ivy-like) so a refill never keeps stale numbers from another preset.
        auto Meshes = InProfile.Stem.Meshes;
        auto LeafMeshes = InProfile.Leaves.Meshes;
        auto LeafWeights = InProfile.Leaves.Weights;
        auto StrandMeshes = InProfile.Strands.Meshes;
        auto Litter = InProfile.Strands.LitterMesh;
        auto Rendering = InProfile.Rendering;

        InProfile.Stem = FMars_VineProfile_Stem();
        InProfile.Twist = FMars_VineProfile_Twist();
        InProfile.Attach = FMars_VineProfile_Attach();
        InProfile.Ends = FMars_VineProfile_Ends();
        InProfile.Branches = FMars_VineProfile_Branches();
        InProfile.Leaves = FMars_VineProfile_Leaves();
        InProfile.Strands = FMars_VineProfile_Strands();
        InProfile.Curtain = FMars_VineProfile_Curtain();
        InProfile.Rendering = FMars_VineProfile_Rendering();

        InProfile.Stem.Meshes = Meshes;
        InProfile.Leaves.Meshes = LeafMeshes;
        InProfile.Leaves.Weights = LeafWeights;
        InProfile.Strands.Meshes = StrandMeshes;
        InProfile.Strands.LitterMesh = Litter;
        InProfile.Rendering.StemMaterial = Rendering.StemMaterial;
        InProfile.Rendering.LeafMaterial = Rendering.LeafMaterial;
        InProfile.Rendering.StrandMaterial = Rendering.StrandMaterial;

        auto& Stem = InProfile.Stem;
        auto& Attach = InProfile.Attach;
        auto& Ends = InProfile.Ends;
        auto& Shadows = InProfile.Rendering.Shadows;

        if (InPreset == EMars_VinePreset::Ivy)
        {
            Stem.Render = EMars_VineStemRender::Instanced;
            Stem.Radius.StartCm = 1.2f;
            Stem.Radius.EndFrac = 0.5f;
            Stem.SegmentLengthCm = 10.0f;
            Attach.ClingRadiusCm = 60.0f;
            Attach.StandOffCm = 0.5f;
            Attach.StepCm = 10.0f;
            Attach.TraceComplex = true;
            Attach.Meander.AmpCm = 3.0f;
            Attach.Meander.WavelengthCm = 40.0f;
            Attach.Meander.CreepDeg = 8.0f;
            Ends.Ground.CreepCm = FVector2D(30.0, 120.0);
            Ends.Air.ClearanceCm = FVector2D(60.0, 250.0);
            Ends.Air.LengthFrac = FVector2D(0.35, 0.95);
            Ends.Air.LengthCm = FVector2D(20.0, 0.0);
            Ends.Air.TipCurlDeg = 70.0f;
            InProfile.Branches.SpacingCm = 35.0f;
            InProfile.Branches.Chance = 0.45f;
            InProfile.Branches.AngleDeg = FVector2D(25.0, 60.0);
            InProfile.Branches.LengthCm = FVector2D(15.0, 60.0);
            InProfile.Branches.TipTendrils = FIntPoint(1, 2);
            InProfile.Leaves.SpacingCm = 6.0f;
            InProfile.Leaves.Scale = FVector2D(1.1, 1.7);
            InProfile.Curtain.StrandsRange = FIntPoint(6, 10);
            // Leaf shadows off: script cannot set ShadowCacheInvalidationBehavior = Rigid on a created HISM, so swaying
            // leaves would invalidate their virtual shadow map pages every frame (VINES.md, shadows).
            Shadows.Stems = false;
            Shadows.Leaves = false;
            Shadows.Strands = false;
        }
        else if (InPreset == EMars_VinePreset::GiantRoot)
        {
            Stem.Render = EMars_VineStemRender::SplineMesh;
            // 2026-10-24 vignettes: the concept roots are massive and lean through the void. Thicker (48 cm) and
            // holding it longer (taper 2.2), a 2 m lean and a wider, longer wander, 72 cm segments on a 500 cm pitch
            // (still ~7 samples a turn) so a 12 m atrium drop with its fingers stays inside the 64-segment budget.
            Stem.Radius.StartCm = 48.0f;
            Stem.Radius.EndFrac = 9.0f / 48.0f;
            Stem.Radius.TaperPower = 2.2f;
            Stem.Radius.JitterFrac = 0.08f;
            Stem.Radius.DrawFrac = 0.2f;
            Stem.SegmentLengthCm = 72.0f;
            InProfile.Twist.Strands = 2;
            InProfile.Twist.PitchCm = 500.0f;
            Attach.ClingRadiusCm = 120.0f;
            Attach.StandOffCm = -0.15f * 35.0f;
            Attach.StepCm = 50.0f;
            Attach.TraceComplex = false;
            Attach.Meander.AmpCm = 80.0f;
            Attach.Meander.WavelengthCm = 520.0f;
            Attach.Meander.CreepDeg = 6.0f;
            Attach.Meander.LeanCm = 220.0f;
            Ends.Ground.CreepCm = FVector2D(60.0, 160.0);
            Ends.Ground.Fingers.Count = FIntPoint(3, 4);
            Ends.Ground.Fingers.LengthCm = FVector2D(60.0, 160.0);
            Ends.Ground.Fingers.RadiusFrac = 0.45f;
            Ends.Ground.SinkFrac = 0.35f;
            Ends.Ground.ContactBendCm = 60.0f;
            Ends.Air.ClearanceCm = FVector2D(80.0, 200.0);
            Ends.Air.LengthFrac = FVector2D(0.0, 0.0);
            Ends.Air.LengthCm = FVector2D(100.0, 0.0);
            Ends.Air.TipCurlDeg = 25.0f;
            Ends.Air.SwayCm = 0.0f;
            Ends.Ceiling.Fingers.Count = FIntPoint(2, 3);
            Ends.Ceiling.Fingers.RadiusFrac = 0.45f;
            Ends.Ceiling.Fingers.LengthCm = FVector2D(40.0, 120.0);
            Ends.Ceiling.BuryCm = 20.0f;
            Shadows.Stems = true;
        }
        else if (InPreset == EMars_VinePreset::ThinRoot)
        {
            Stem.Render = EMars_VineStemRender::SplineMesh;
            Stem.Radius.StartCm = 4.0f;
            Stem.Radius.EndFrac = 0.2f;
            Stem.Radius.TaperPower = 1.5f;
            Stem.Radius.DrawFrac = 0.2f;
            Stem.SegmentLengthCm = 40.0f;
            Attach.ClingRadiusCm = 60.0f;
            Attach.StandOffCm = 0.5f;
            Attach.StepCm = 20.0f;
            Attach.TraceComplex = false;
            Attach.Meander.AmpCm = 10.0f;
            Attach.Meander.WavelengthCm = 120.0f;
            Ends.Ground.CreepCm = FVector2D(20.0, 60.0);
            Ends.Ground.Fingers.Count = FIntPoint(2, 3);
            Ends.Ground.Fingers.LengthCm = FVector2D(20.0, 60.0);
            Ends.Ground.ContactBendCm = 15.0f;
            Ends.Air.ClearanceCm = FVector2D(40.0, 180.0);
            Ends.Air.LengthFrac = FVector2D(0.0, 0.0);
            Ends.Air.LengthCm = FVector2D(30.0, 0.0);
            Ends.Air.TipCurlDeg = 50.0f;
            Ends.Ceiling.Fingers.Count = FIntPoint(0, 2);
            Ends.Ceiling.Fingers.LengthCm = FVector2D(20.0, 40.0);
            Ends.Ceiling.BuryCm = 5.0f;
            InProfile.Branches.SpacingCm = 80.0f;
            InProfile.Branches.Chance = 0.2f;
            InProfile.Branches.LengthCm = FVector2D(20.0, 60.0);
            Shadows.Stems = true;
        }
        else
        {
            // The three stemless card profiles.
            Stem.Render = EMars_VineStemRender::None;
            Attach.TraceComplex = false;
            Attach.StepCm = 10.0f;
            Ends.Ground.CreepCm = FVector2D(0.0, 0.0);
            Ends.Ground.ContactBendCm = 0.0f;
            Ends.Air.TipCurlDeg = 0.0f;
            Ends.Air.SwayCm = 0.0f;
            Shadows.Stems = false;
            Shadows.Leaves = false;
            Shadows.Strands = false;
            if (InPreset == EMars_VinePreset::HangingMoss)
            {
                Ends.Air.ClearanceCm = FVector2D(40.0, 40.0);
                Ends.Air.LengthFrac = FVector2D(0.06, 0.30);
                Ends.Air.LengthCm = FVector2D(15.0, 300.0);
                InProfile.Strands.PerSquareMetre = 6.0f;
                InProfile.Strands.ClumpSigmaCm = 18.0f;
                InProfile.Strands.PerMetre = 4.0f;
                InProfile.Strands.Width = FVector2D(0.7, 1.4);
            }
            else if (InPreset == EMars_VinePreset::Rootlets)
            {
                Ends.Ground.CoilCm = FVector2D(10.0, 30.0);
                Ends.Ground.LitterChance = 0.3f;
                Ends.Air.ClearanceCm = FVector2D(25.0, 25.0);
                Ends.Air.LengthFrac = FVector2D(0.10, 0.60);
                Ends.Air.LengthCm = FVector2D(15.0, 400.0);
                InProfile.Strands.PerSquareMetre = 4.0f;
                InProfile.Strands.ClumpSigmaCm = 14.0f;
                InProfile.Strands.Width = FVector2D(0.8, 1.3);
            }
            else
            {
                Ends.Air.ClearanceCm = FVector2D(25.0, 25.0);
                Ends.Air.LengthFrac = FVector2D(0.0, 0.0);
                Ends.Air.LengthCm = FVector2D(40.0, 110.0);
                // 2026-10-24: at 1 / m2 and 0.6 - 1.1 wide a patch was two thin cards and read as nothing; webs gather
                // in corners and arches, so denser, wider and tighter clumps (the pale VineCobweb_Mars_MI carries the look).
                InProfile.Strands.PerSquareMetre = 3.0f;
                InProfile.Strands.ClumpSigmaCm = 22.0f;
                InProfile.Strands.Width = FVector2D(1.0, 1.7);
            }
        }
    }
}
