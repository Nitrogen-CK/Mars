// The vine solver: traces the room on the Visibility channel and lays polylines (stems, branches, tendrils, fingers,
// strands) with a deterministic surface walk. Pure function of (request, actor transform, guide points, room): the
// result is cached on the actor (FMars_Vine_Solved) and emission never traces. VINES.md has the algorithm notes.

// The effective inputs of one solve: the actor's own fields, resolved.
struct FMars_Vine_Request
{
    UMars_VineProfile Profile;
    EMars_VineLayout Layout = EMars_VineLayout::Drop;
    EMars_VineEnd End = EMars_VineEnd::Air;
    FMars_Vine_Shape Shape;
    int32 Seed = 1;
    // PCG writes the traced length here (Air drops and patches use it as the strand length).
    float LengthOverrideCm = 0.0;
    bool Collides = false;
}

// What the solver needs from its actor: the world it traces, its frame and the guide.
struct FMars_Vine_SolveContext
{
    AActor Owner;
    FTransform Frame;
    TArray<AActor> Ignored;
    // Spline layout: the guide points, actor-local.
    TArray<FVector> Guide;
}

namespace utils_vine
{
    uint32 Hash_Fnv1a(const FString& InText)
    {
        auto Hash = uint32(2166136261);
        for (int32 Index = 0; Index < InText.Len(); ++Index)
        {
            Hash = Hash ^ uint32(uint16(InText[Index]));
            Hash = Hash * uint32(16777619);
        }
        return Hash;
    }

    // A stream per (seed, index, purpose), mixed first: FRandomStream is an LCG, so raw consecutive seeds give nearly
    // the same first draws.
    FRandomStream Make_Stream(int32 InSeed, int32 InIndex, EMars_VineStream InPurpose)
    {
        const auto Purpose = Hash_Fnv1a(f"{int32(InPurpose)}vine");
        const auto Mixed = Purpose ^ (uint32(InSeed) * uint32(2654435761)) ^ (uint32(InIndex + 1) * uint32(40503));
        return FRandomStream(int32(Mixed));
    }

    // The seed a vine uses when its Seed is 0: a hash of its position in 10 cm cells, so Alt-drag copies differ.
    int32 Get_PositionSeed(FVector InLocation)
    {
        const auto X = Math::RoundToInt(InLocation.X / 10.0);
        const auto Y = Math::RoundToInt(InLocation.Y / 10.0);
        const auto Z = Math::RoundToInt(InLocation.Z / 10.0);
        const auto Hash = int32(Hash_Fnv1a(f"{X},{Y},{Z}"));
        return Hash == 0 ? 1 : Hash;
    }

    FVector VLerp(FVector InA, FVector InB, float InT)
    {
        return InA + (InB - InA) * InT;
    }

    float Rand(FRandomStream& InStream, FVector2D InRange)
    {
        return InStream.RandRange(InRange.X, InRange.Y);
    }

    int32 RandInt(FRandomStream& InStream, FIntPoint InRange)
    {
        return InStream.RandRange(InRange.X, InRange.Y);
    }

    float Frac(FRandomStream& InStream)
    {
        return float(InStream.GetFraction());
    }

    // B projected onto the plane of N, normalised; InFallback when B is (nearly) parallel to N.
    FVector TangentOf(FVector InB, FVector InN, FVector InFallback)
    {
        const auto T = InB - InN * InN.DotProduct(InB);
        if (T.SizeSquared() < 1.0e-6)
        {
            const auto F = InFallback - InN * InN.DotProduct(InFallback);
            return F.SizeSquared() < 1.0e-6 ? Get_AnyPerpendicular(InN) : F.GetSafeNormal();
        }
        return T.GetSafeNormal();
    }

    FVector Get_AnyPerpendicular(FVector InN)
    {
        auto Axis = Math::Abs(InN.Z) < 0.9 ? FVector::UpVector : FVector::ForwardVector;
        return InN.CrossProduct(Axis).GetSafeNormal();
    }

    FVector Quantize(FVector InV, float InStep)
    {
        return FVector(Math::RoundToFloat(InV.X / InStep) * InStep, Math::RoundToFloat(InV.Y / InStep) * InStep,
            Math::RoundToFloat(InV.Z / InStep) * InStep);
    }

    float Get_PathLength(const TArray<FVector>& InPoints)
    {
        float Length = 0.0;
        for (int32 Index = 1; Index < InPoints.Num(); ++Index)
        { Length += InPoints[Index].Distance(InPoints[Index - 1]); }
        return Length;
    }

    // The taper radius at arc fraction InFrac of a path whose ends are InRadius (x start, y end), without jitter.
    float Get_TaperRadius(const UMars_VineProfile InProfile, FVector2D InRadius, float InFrac)
    {
        const auto EndFrac = InRadius.X > 0.0 ? InRadius.Y / InRadius.X : 1.0;
        const auto Power = Math::Max(float(InProfile.Stem.Radius.TaperPower), 0.05);
        return InRadius.X * Math::Lerp(1.0, EndFrac, Math::Pow(Math::Clamp(InFrac, 0.0, 1.0), Power));
    }

    // Rotation-minimising frames (double reflection): one "right" vector per point, perpendicular to the tangent.
    // The first is the surface normal where there is one, else a horizontal perpendicular.
    TArray<FVector> Rmf_Frames(const TArray<FVector>& InPoints, const TArray<FVector>& InNormals)
    {
        TArray<FVector> Rights;
        const auto Count = InPoints.Num();
        if (Count < 2)
        {
            Rights.Add(FVector::RightVector);
            return Rights;
        }

        TArray<FVector> Tangents;
        for (int32 Index = 0; Index < Count; ++Index)
        {
            const auto A = InPoints[Math::Max(Index - 1, 0)];
            const auto B = InPoints[Math::Min(Index + 1, Count - 1)];
            auto T = (B - A).GetSafeNormal();
            if (T.IsNearlyZero())
            { T = FVector::ForwardVector; }
            Tangents.Add(T);
        }

        auto R0 = InNormals.Num() > 0 ? InNormals[0] : FVector::ZeroVector;
        if (R0.IsNearlyZero() || Math::Abs(R0.DotProduct(Tangents[0])) > 0.95)
        {
            R0 = Tangents[0].CrossProduct(FVector::UpVector);
            if (R0.SizeSquared() < 1.0e-4)
            { R0 = Tangents[0].CrossProduct(FVector::ForwardVector); }
        }
        R0 = TangentOf(R0, Tangents[0], FVector::RightVector);
        Rights.Add(R0);

        for (int32 Index = 0; Index < Count - 1; ++Index)
        {
            const auto V1 = InPoints[Index + 1] - InPoints[Index];
            const auto C1 = V1.DotProduct(V1);
            auto R = Rights[Index];
            if (C1 < 1.0e-8)
            {
                Rights.Add(R);
                continue;
            }
            const auto RL = R - V1 * (2.0 / C1 * V1.DotProduct(R));
            const auto TL = Tangents[Index] - V1 * (2.0 / C1 * V1.DotProduct(Tangents[Index]));
            const auto V2 = Tangents[Index + 1] - TL;
            const auto C2 = V2.DotProduct(V2);
            auto Next = C2 < 1.0e-8 ? RL : RL - V2 * (2.0 / C2 * V2.DotProduct(RL));
            Next = TangentOf(Next, Tangents[Index + 1], R);
            Rights.Add(Next);
        }
        return Rights;
    }

    // Laplacian smoothing that keeps both ends; on surface points the move is projected onto the tangent plane so the
    // stand-off holds without re-tracing.
    void Smooth(FMars_Vine_Path& InOutPath, int32 InPasses)
    {
        for (int32 Pass = 0; Pass < InPasses; ++Pass)
        {
            const auto Source = InOutPath.Points;
            for (int32 Index = 1; Index < Source.Num() - 1; ++Index)
            {
                auto Delta = (Source[Index - 1] + Source[Index + 1]) * 0.5 - Source[Index];
                const auto N = InOutPath.Normals[Index];
                if (N.IsNearlyZero() == false)
                { Delta = Delta - N * N.DotProduct(Delta); }
                InOutPath.Points[Index] = Source[Index] + Delta * 0.5;
            }
        }
    }

    // Drops points closer than InMinCm (keeping the last).
    void Thin(FMars_Vine_Path& InOutPath, float InMinCm)
    {
        if (InOutPath.Points.Num() < 3)
        { return; }

        FMars_Vine_Path Out = InOutPath;
        Out.Points.Reset();
        Out.Normals.Reset();
        Out.Points.Add(InOutPath.Points[0]);
        Out.Normals.Add(InOutPath.Normals[0]);
        const auto Last = InOutPath.Points.Num() - 1;
        for (int32 Index = 1; Index < Last; ++Index)
        {
            if (InOutPath.Points[Index].Distance(Out.Points.Last()) < InMinCm)
            { continue; }
            Out.Points.Add(InOutPath.Points[Index]);
            Out.Normals.Add(InOutPath.Normals[Index]);
        }
        if (Out.Points.Num() > 1 && InOutPath.Points[Last].Distance(Out.Points.Last()) < InMinCm * 0.5)
        {
            Out.Points.RemoveAt(Out.Points.Num() - 1);
            Out.Normals.RemoveAt(Out.Normals.Num() - 1);
        }
        Out.Points.Add(InOutPath.Points[Last]);
        Out.Normals.Add(InOutPath.Normals[Last]);
        InOutPath = Out;
    }

    // Centripetal Catmull-Rom point between P1 and P2 at InT (Barry-Goldman, alpha 0.5).
    FVector CatmullRom(const TArray<FVector>& InP, int32 InSegment, float InT)
    {
        const auto Count = InP.Num();
        const auto P1 = InP[InSegment];
        const auto P2 = InP[InSegment + 1];
        const auto P0 = InSegment > 0 ? InP[InSegment - 1] : P1 * 2.0 - P2;
        const auto P3 = InSegment + 2 < Count ? InP[InSegment + 2] : P2 * 2.0 - P1;
        const auto T0 = 0.0;
        const auto T1 = T0 + Math::Max(Math::Sqrt(P0.Distance(P1)), 1.0e-3);
        const auto T2 = T1 + Math::Max(Math::Sqrt(P1.Distance(P2)), 1.0e-3);
        const auto T3 = T2 + Math::Max(Math::Sqrt(P2.Distance(P3)), 1.0e-3);
        const auto T = Math::Lerp(T1, T2, InT);
        const auto A1 = P0 * ((T1 - T) / (T1 - T0)) + P1 * ((T - T0) / (T1 - T0));
        const auto A2 = P1 * ((T2 - T) / (T2 - T1)) + P2 * ((T - T1) / (T2 - T1));
        const auto A3 = P2 * ((T3 - T) / (T3 - T2)) + P3 * ((T - T2) / (T3 - T2));
        const auto B1 = A1 * ((T2 - T) / (T2 - T0)) + A2 * ((T - T0) / (T2 - T0));
        const auto B2 = A2 * ((T3 - T) / (T3 - T1)) + A3 * ((T - T1) / (T3 - T1));
        return B1 * ((T2 - T) / (T2 - T1)) + B2 * ((T - T1) / (T2 - T1));
    }

    // Arc-length resample to about InSegmentCm (both ends kept); normals come from the nearer source point.
    void Resample(FMars_Vine_Path& InOutPath, float InSegmentCm)
    {
        const auto Source = InOutPath.Points;
        const auto Count = Source.Num();
        if (Count < 2)
        { return; }

        TArray<float> Cumulative;
        Cumulative.Add(0.0);
        for (int32 Index = 1; Index < Count; ++Index)
        { Cumulative.Add(Cumulative.Last() + Source[Index].Distance(Source[Index - 1])); }

        const auto Length = Cumulative.Last();
        if (Length < 1.0e-3)
        { return; }

        const auto Samples = Math::Max(1, Math::RoundToInt(Length / Math::Max(InSegmentCm, 1.0)));
        TArray<FVector> Points;
        TArray<FVector> Normals;
        int32 Segment = 0;
        for (int32 Sample = 0; Sample <= Samples; ++Sample)
        {
            const auto S = Length * float(Sample) / float(Samples);
            while (Segment < Count - 2 && Cumulative[Segment + 1] < S)
            { ++Segment; }
            const auto SegLength = Math::Max(Cumulative[Segment + 1] - Cumulative[Segment], 1.0e-6);
            const auto T = Math::Clamp((S - Cumulative[Segment]) / SegLength, 0.0, 1.0);
            if (Sample == 0)
            { Points.Add(Source[0]); }
            else if (Sample == Samples)
            { Points.Add(Source[Count - 1]); }
            else
            { Points.Add(CatmullRom(Source, Segment, T)); }
            Normals.Add(InOutPath.Normals[T < 0.5 ? Segment : Segment + 1]);
        }
        InOutPath.Points = Points;
        InOutPath.Normals = Normals;
    }
}

//----------------------------------------------------------------------------------------------------------------------
// Validation and budgets
//----------------------------------------------------------------------------------------------------------------------

namespace utils_vine
{
    // The room height a budget estimate assumes for a hanging strand (three 3.5 m storeys); taller rooms are capped at runtime
    // by the trace and instance budgets instead.
    const float k_EstimateDropCm = 1050.0;

    int32 Get_StrandCount(const FMars_Vine_Request& InRequest)
    {
        const auto Profile = InRequest.Profile;
        if (InRequest.Layout == EMars_VineLayout::Curtain)
        { return InRequest.Shape.StrandCount > 0 ? InRequest.Shape.StrandCount : Profile.Curtain.StrandsRange.Y; }

        if (InRequest.Layout == EMars_VineLayout::Creep || InRequest.Layout == EMars_VineLayout::Wrap)
        { return Math::Clamp(InRequest.Shape.StrandCount > 0 ? InRequest.Shape.StrandCount : 1, 1, 3); }

        if (InRequest.Layout == EMars_VineLayout::Patch)
        {
            const auto Radius = float(InRequest.Shape.PatchRadiusCm) / 100.0;
            return Math::Max(1, Math::RoundToInt(float(Profile.Strands.PerSquareMetre) * PI * Radius * Radius));
        }
        return 1;
    }

    // The worst-case work of a request, from the profile, the shape and the layout's sample counts.
    FMars_Vine_Budget Get_WorstCase(const FMars_Vine_Request& InRequest)
    {
        FMars_Vine_Budget Budget;
        const auto P = InRequest.Profile;
        const auto Step = Math::Max(float(P.Attach.StepCm), 2.0);
        const auto Strands = Get_StrandCount(InRequest);
        const auto Drop = Math::Min(float(P.Ends.Air.MaxDropCm), k_EstimateDropCm);

        // Per strand: the length it walks on a surface and the length it hangs.
        float Surface = 0.0;
        // An air strand hangs at most its length fraction of the drop (and its length cap); a ground one the whole drop.
        float Hang = Drop;
        if (InRequest.End == EMars_VineEnd::Air && InRequest.Shape.GroundShare <= 0.0f)
        {
            if (P.Ends.Air.LengthFrac.Y > 0.0)
            { Hang = Drop * float(P.Ends.Air.LengthFrac.Y); }
            if (P.Ends.Air.LengthCm.Y > 0.0)
            { Hang = Math::Min(Hang, float(P.Ends.Air.LengthCm.Y)); }
        }
        int32 FixedTraces = 3;
        if (InRequest.Layout == EMars_VineLayout::Creep)
        { Surface = InRequest.Shape.HeightCm > 0.0f ? float(InRequest.Shape.HeightCm) : 400.0; FixedTraces = 16; }
        else if (InRequest.Layout == EMars_VineLayout::Curtain)
        { Surface = 200.0; }
        else if (InRequest.Layout == EMars_VineLayout::Wrap)
        {
            const auto Height = InRequest.Shape.HeightCm > 0.0f ? float(InRequest.Shape.HeightCm) : 600.0;
            Surface = Height * 1.5;
            FixedTraces = Math::CeilToInt(float(InRequest.Shape.Turns) * 24.0) + 2;
            Hang = 0.0;
        }
        else if (InRequest.Layout == EMars_VineLayout::Spline)
        {
            Surface = 400.0;
            FixedTraces = Math::CeilToInt(Surface / Step) * 14;
        }

        const auto Ground = P.Ends.Ground;
        const auto GroundCreep = float(Ground.CreepCm.Y) + float(Ground.Fingers.Count.Y) * float(Ground.Fingers.LengthCm.Y);
        const auto CeilingCreep = float(P.Ends.Ceiling.Fingers.Count.Y) * float(P.Ends.Ceiling.Fingers.LengthCm.Y);
        const auto Walked = Surface + GroundCreep + CeilingCreep;
        const auto BranchSites = P.Branches.SpacingCm > 0.0f ? (Surface + Hang) / (float(P.Branches.SpacingCm) * 0.6) * float(P.Branches.Chance) : 0.0;
        const auto BranchWalk = BranchSites * float(P.Branches.LengthCm.Y) * (Surface / Math::Max(Surface + Hang, 1.0));

        Budget.Traces = Strands * (FixedTraces + 10 + Math::CeilToInt((Walked + BranchWalk) / Step * 3.0));
        if (P.Stem.Render == EMars_VineStemRender::None)
        {
            Budget.Cards = Strands;
            Budget.Traces = Strands * 3 + FixedTraces;
            return Budget;
        }

        const auto StemLength = Surface + Hang + GroundCreep + CeilingCreep + BranchSites * float(P.Branches.LengthCm.Y);
        const auto MainLength = Surface + Hang + float(Ground.CreepCm.Y);
        const auto Segment = Math::Max(float(P.Stem.SegmentLengthCm), 1.0);
        // Fingers, branches and tendrils resample to at most 3 pieces each (Finish_Paths).
        const auto SidePaths = Ground.Fingers.Count.Y + P.Ends.Ceiling.Fingers.Count.Y + Math::CeilToInt(BranchSites);
        const auto SidePieces = SidePaths * 3;
        if (P.Stem.Render == EMars_VineStemRender::SplineMesh)
        { Budget.Segments = (Math::CeilToInt(MainLength / Segment) * P.Twist.Strands + SidePieces) * Strands; }
        else
        { Budget.Chords = Math::CeilToInt(StemLength / Segment) * Strands; }

        if (P.Leaves.Meshes.Num() > 0)
        {
            const auto Density = float(P.Leaves.Falloff.Density);
            // At the mean spacing (the emitter caps the count at its budget anyway).
            Budget.Leaves = Math::CeilToInt(StemLength * float(Strands) / Math::Max(float(P.Leaves.SpacingCm), 1.0) * Density);
        }
        return Budget;
    }
}

mixin FMars_Validation Validate(const FMars_Vine_Request& Self)
{
    if (ck::Is_NOT_Valid(Self.Profile))
    { return FMars_Validation("no profile"); }

    if (Self.Layout == EMars_VineLayout::Wrap && Self.Shape.Turns <= 0.0f)
    { return FMars_Validation("Shape.Turns must be positive for a Wrap"); }

    if (Self.Layout == EMars_VineLayout::Patch && Self.Shape.PatchRadiusCm <= 0.0f)
    { return FMars_Validation("Shape.PatchRadiusCm must be positive for a Patch"); }

    if (Self.Layout == EMars_VineLayout::Curtain && Self.Shape.WidthCm <= 0.0f)
    { return FMars_Validation("Shape.WidthCm must be positive for a Curtain"); }

    const auto Budget = utils_vine::Get_WorstCase(Self);
    if (Budget.Cards > utils_vine::k_MaxCards)
    { return FMars_Validation(f"the worst case hangs {Budget.Cards} cards (budget {utils_vine::k_MaxCards}): a lower Strands.PerSquareMetre"); }

    if (Budget.Traces > utils_vine::k_MaxTraces)
    { return FMars_Validation(f"the worst case needs {Budget.Traces} traces (budget {utils_vine::k_MaxTraces}): fewer strands or a longer Attach.StepCm"); }

    if (Budget.Segments > utils_vine::k_MaxSegments)
    { return FMars_Validation(f"the worst case lays {Budget.Segments} spline segments (budget {utils_vine::k_MaxSegments}): a longer Stem.SegmentLengthCm"); }

    if (Budget.Leaves > utils_vine::k_MaxLeaves)
    { return FMars_Validation(f"the worst case grows {Budget.Leaves} leaves (budget {utils_vine::k_MaxLeaves}): a wider Leaves.SpacingCm or fewer strands"); }

    if (Budget.Chords > utils_vine::k_MaxChords)
    { return FMars_Validation(f"the worst case lays {Budget.Chords} stem chords (budget {utils_vine::k_MaxChords})"); }

    return FMars_Validation();
}

//----------------------------------------------------------------------------------------------------------------------
// The solver
//----------------------------------------------------------------------------------------------------------------------

struct FMars_Vine_Solver
{
    FMars_Vine_Request Req;
    FMars_Vine_SolveContext Ctx;
    int32 Traces = 0;
    int32 NoFloor = 0;
    // The drawn root radius of this vine (StartCm x U(1 +- DrawFrac)).
    float R0 = 1.0;
    // World-space paths while solving.
    TArray<FMars_Vine_Path> Work;
    TArray<FVector> Litter;

    FMars_Vine_Solved Solve()
    {
        FMars_Vine_Solved Out;
        Out.EffectiveSeed = Req.Seed;
        const auto P = Req.Profile;
        auto RadiusStream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Len);
        const auto Draw = float(P.Stem.Radius.DrawFrac);
        R0 = float(P.Stem.Radius.StartCm) * RadiusStream.RandRange(1.0 - Draw, 1.0 + Draw);

        if (Req.Layout == EMars_VineLayout::Drop)
        { Solve_Drop(); }
        else if (Req.Layout == EMars_VineLayout::Curtain)
        { Solve_Curtain(); }
        else if (Req.Layout == EMars_VineLayout::Creep)
        { Solve_Creep(); }
        else if (Req.Layout == EMars_VineLayout::Wrap)
        { Solve_Wrap(); }
        else if (Req.Layout == EMars_VineLayout::Patch)
        { Solve_Patch(); }
        else
        { Solve_Spline(); }

        if (P.Branches.SpacingCm > 0.0f && P.Stem.Render != EMars_VineStemRender::None)
        { Grow_Branches(); }

        Finish_Paths(Out);
        Out.TraceCount = Traces;
        Out.NoFloorCount = NoFloor;
        Out.Valid = true;
        return Out;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Surface primitives
    //------------------------------------------------------------------------------------------------------------------

    bool Ray(FVector InStart, FVector InEnd, FMars_Vine_SurfaceHit& OutHit)
    {
        OutHit.Hit = false;
        if (Traces >= utils_vine::k_MaxTraces)
        { return false; }

        ++Traces;
        FHitResult Hit;
        if (System::LineTraceSingle(InStart, InEnd, ETraceTypeQuery::Visibility, Req.Profile.Attach.TraceComplex, Ctx.Ignored,
                EDrawDebugTrace::None, Hit, true) == false)
        { return false; }

        if (Hit.bStartPenetrating)
        { return false; }

        OutHit.Hit = true;
        OutHit.P = utils_vine::Quantize(Hit.ImpactPoint, 0.1);
        OutHit.N = utils_vine::Quantize(Hit.ImpactNormal, 0.001).GetSafeNormal();
        OutHit.Distance = InStart.Distance(Hit.ImpactPoint);
        return true;
    }

    FMars_Vine_SurfaceHit Probe(const FMars_Vine_ProbeQuery& InQuery)
    {
        FMars_Vine_SurfaceHit Best;
        if (InQuery.HintN.IsNearlyZero() == false)
        {
            Ray(InQuery.P + InQuery.HintN * InQuery.RadiusCm, InQuery.P - InQuery.HintN * InQuery.RadiusCm, Best);
            return Best;
        }

        TArray<FVector> Dirs;
        Dirs.Add(FVector(1, 0, 0)); Dirs.Add(FVector(-1, 0, 0)); Dirs.Add(FVector(0, 1, 0));
        Dirs.Add(FVector(0, -1, 0)); Dirs.Add(FVector(0, 0, 1)); Dirs.Add(FVector(0, 0, -1));
        for (int32 Corner = 0; Corner < 8; ++Corner)
        {
            const auto D = FVector((Corner & 1) != 0 ? 1.0 : -1.0, (Corner & 2) != 0 ? 1.0 : -1.0, (Corner & 4) != 0 ? 1.0 : -1.0);
            Dirs.Add(D.GetSafeNormal());
        }

        auto BestDistance = InQuery.RadiusCm * 2.0;
        for (auto Dir : Dirs)
        {
            FMars_Vine_SurfaceHit Hit;
            if (Ray(InQuery.P, InQuery.P + Dir * InQuery.RadiusCm, Hit) && Hit.Distance < BestDistance)
            {
                BestDistance = Hit.Distance;
                Best = Hit;
            }
        }
        return Best;
    }

    // The surface walk (VINES.md): concave corners climb onto the facing surface, convex edges wrap round, an edge that
    // drops into air ends the walk with LeftSurface. Appends centreline points (surface + N x LiftCm) to InOutPath.
    FMars_Vine_CreepResult Creep(const FMars_Vine_CreepQuery& InQuery, FRandomStream& InStream, FMars_Vine_Path& InOutPath)
    {
        FMars_Vine_CreepResult Result;
        auto S = InQuery.Start.P;
        auto N = InQuery.Start.N;
        auto D = utils_vine::TangentOf(InQuery.Dir, N, FVector::UpVector);
        const auto Step = Math::Max(InQuery.StepCm, 1.0);
        const auto Lift = InQuery.LiftCm;
        const auto Height = Math::Max(Lift, 2.0);
        const auto MaxIterations = Math::CeilToInt(InQuery.LengthCm / Step) * 3 + 8;
        Result.Last = InQuery.Start;
        Result.Dir = D;

        for (int32 Iteration = 0; Iteration < MaxIterations && Result.WalkedCm < InQuery.LengthCm; ++Iteration)
        {
            if (Traces >= utils_vine::k_MaxTraces)
            { break; }

            if (InQuery.Steer.MeanderDeg > 0.0)
            { D = D.RotateAngleAxis(InStream.RandRange(-1.0, 1.0) * InQuery.Steer.MeanderDeg, N); }

            if (InQuery.Steer.BiasWeight > 0.0)
            {
                const auto Toward = utils_vine::TangentOf(InQuery.Steer.Bias, N, D);
                D = utils_vine::TangentOf(utils_vine::VLerp(D, Toward, InQuery.Steer.BiasWeight), N, D);
            }

            const auto Above = S + N * Height;
            const auto Q = S + D * Step;

            // Concave corner: the facing surface is within the step.
            FMars_Vine_SurfaceHit Fwd;
            if (Ray(Above, Above + D * (Step + Height), Fwd))
            {
                const auto OldN = N;
                N = Fwd.N;
                S = Fwd.P;
                const auto Prefer = InQuery.Steer.BiasWeight > 0.0 ? InQuery.Steer.Bias : D;
                D = utils_vine::TangentOf(Prefer, N, OldN);
                Result.WalkedCm += Step;
                Append(InOutPath, S + N * Lift, N);
                Result.Last.P = S;
                Result.Last.N = N;
                continue;
            }

            FMars_Vine_SurfaceHit Down;
            if (Ray(Q + N * Math::Max(Step, Height), Q - N * Step * 2.0, Down))
            {
                Result.WalkedCm += S.Distance(Down.P);
                S = Down.P;
                N = utils_vine::VLerp(N, Down.N, 0.7).GetSafeNormal();
                D = utils_vine::TangentOf(D, N, D);
                Append(InOutPath, S + N * Lift, N);
                Result.Last.P = S;
                Result.Last.N = N;
                continue;
            }

            // Convex edge: come back under the edge toward the surface below it.
            FMars_Vine_SurfaceHit Wrap;
            const auto Below = N * (Height + Step);
            if (Ray(Q - Below, S - Below, Wrap) == false)
            {
                Result.LeftSurface = true;
                break;
            }

            if (InQuery.Steer.StopOnUnderside && Wrap.N.Z < -0.5)
            {
                Result.LeftSurface = true;
                break;
            }

            D = N * -1.0;
            N = Wrap.N;
            D = utils_vine::TangentOf(D, N, D);
            Result.WalkedCm += S.Distance(Wrap.P);
            S = Wrap.P;
            Append(InOutPath, S + N * Lift, N);
            Result.Last.P = S;
            Result.Last.N = N;
        }

        Result.Dir = D;
        return Result;
    }

    void Append(FMars_Vine_Path& InOutPath, FVector InP, FVector InN)
    {
        InOutPath.Points.Add(InP);
        InOutPath.Normals.Add(InN);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Free ends
    //------------------------------------------------------------------------------------------------------------------

    float Get_GroundShare()
    {
        if (Req.Shape.GroundShare >= 0.0f)
        { return float(Req.Shape.GroundShare); }

        return Req.End == EMars_VineEnd::Ground ? 1.0 : 0.0;
    }

    // The radius a stem has where it meets the floor (its taper held by TaperPower).
    float Get_ContactRadius(float InRadius)
    {
        const auto EndFrac = float(Req.Profile.Stem.Radius.EndFrac);
        return InRadius * Math::Lerp(1.0, EndFrac, Math::Pow(0.8, Math::Max(float(Req.Profile.Stem.Radius.TaperPower), 0.05)));
    }

    // Ground or Air for the end of InOutPath at InQuery.From (the last point).
    void Finish_Free(FMars_Vine_Path& InOutPath, const FMars_Vine_EndQuery& InQuery, FRandomStream& InStream)
    {
        const auto Air = Req.Profile.Ends.Air;
        FMars_Vine_SurfaceHit Floor;
        const auto HasFloor = Ray(InQuery.From - FVector(0, 0, 1), InQuery.From - FVector(0, 0, float(Air.MaxDropCm)), Floor) && Floor.N.Z > 0.3;
        auto Ground = utils_vine::Frac(InStream) < Get_GroundShare();
        if (Ground && HasFloor == false)
        {
            ++NoFloor;
            Ground = false;
        }

        if (Ground)
        { End_Ground(InOutPath, InQuery, Floor, InStream); }
        else
        { End_Air(InOutPath, InQuery, HasFloor ? Floor.Distance + 1.0 : float(Air.MaxDropCm), InStream); }
    }

    // The vertical extent of an air strand: inside the clearance band (LengthFrac 0 0) or a fraction of the floor
    // distance, clamped so no point is below floor + ClearanceMin.
    float Get_AirDrop(const FMars_Vine_EndQuery& InQuery, float InFloorDistance, FRandomStream& InStream)
    {
        const auto Air = Req.Profile.Ends.Air;
        const auto Clear = utils_vine::Rand(InStream, Air.ClearanceCm);
        float Vertical = 0.0;
        if (Air.LengthFrac.Y > 0.0)
        {
            const auto Frac = InQuery.LengthFrac >= 0.0 ? InQuery.LengthFrac : utils_vine::Rand(InStream, Air.LengthFrac);
            Vertical = InFloorDistance * Frac;
        }
        else
        { Vertical = InFloorDistance - Clear; }

        if (Req.LengthOverrideCm > 0.0)
        { Vertical = Req.LengthOverrideCm; }
        if (InQuery.CapCm > 0.0)
        { Vertical = Math::Min(Vertical, InQuery.CapCm); }
        if (Air.LengthCm.Y > 0.0)
        { Vertical = Math::Min(Vertical, float(Air.LengthCm.Y)); }
        if (Req.Shape.LengthCm > 0.0f && Req.Layout != EMars_VineLayout::Creep)
        { Vertical = Math::Min(Vertical, float(Req.Shape.LengthCm)); }

        Vertical = Math::Max(Vertical, float(Air.LengthCm.X));
        Vertical = Math::Min(Vertical, InFloorDistance - float(Air.ClearanceCm.X));
        return Math::Max(Vertical, 0.0);
    }

    void End_Air(FMars_Vine_Path& InOutPath, const FMars_Vine_EndQuery& InQuery, float InFloorDistance, FRandomStream& InStream)
    {
        const auto Air = Req.Profile.Ends.Air;
        const auto Vertical = Get_AirDrop(InQuery, InFloorDistance, InStream);
        if (Vertical < 1.0)
        { return; }

        // The last 15 % curls as an arc turning by Curl from vertical; it reaches sinc(Curl) of its length down, so the
        // hang is lengthened to land the lowest point at the drawn height.
        const auto Curl = Math::DegreesToRadians(Math::Clamp(float(Air.TipCurlDeg), 0.0, 90.0));
        const auto Sinc = Curl > 1.0e-3 ? Math::Sin(Curl) / Curl : 1.0;
        const auto Length = Vertical / (0.85 + 0.15 * Sinc);
        Hang(InOutPath, InQuery.From, Length * 0.85, InStream);

        if (Curl > 1.0e-3)
        {
            const auto Yaw = InStream.RandRange(0.0, 360.0);
            const auto Out = FVector(1, 0, 0).RotateAngleAxis(Yaw, FVector::UpVector);
            const auto Tail = Length * 0.15;
            const auto Steps = Math::Max(2, Math::CeilToInt(Tail / 8.0));
            auto Point = InOutPath.Points.Last();
            for (int32 Index = 1; Index <= Steps; ++Index)
            {
                const auto Angle = Curl * (float(Index) - 0.5) / float(Steps);
                const auto Dir = FVector(0, 0, -1) * Math::Cos(Angle) + Out * Math::Sin(Angle);
                Point = Point + Dir * (Tail / float(Steps));
                Append(InOutPath, Point, FVector::ZeroVector);
            }
        }
        else
        {
            // The hang already covers the whole length when nothing curls.
            Hang(InOutPath, InOutPath.Points.Last(), Length * 0.15, InStream);
        }
    }

    // A free hang straight down with the profile's meander (drops) and sway (hanging ivy), both tapered in at the top.
    void Hang(FMars_Vine_Path& InOutPath, FVector InFrom, float InLength, FRandomStream& InStream)
    {
        if (InLength < 1.0)
        { return; }

        const auto P = Req.Profile;
        const auto Step = Math::Clamp(float(P.Attach.StepCm), 5.0, 50.0);
        const auto Steps = Math::Max(1, Math::CeilToInt(InLength / Step));
        const auto Amp = float(P.Attach.Meander.AmpCm);
        const auto Wave = Math::Max(float(P.Attach.Meander.WavelengthCm), 1.0);
        const auto Sway = float(P.Ends.Air.SwayCm);
        const auto O1 = InStream.RandRange(0.0, 100.0);
        const auto O2 = InStream.RandRange(0.0, 100.0);
        // The lean draws only when set, so a plumb profile's streams (and every solve made before it) stay unchanged.
        auto Lean = FVector::ZeroVector;
        if (P.Attach.Meander.LeanCm > 0.0f)
        {
            const auto LeanYaw = InStream.RandRange(0.0, 360.0);
            const auto LeanAmount = float(P.Attach.Meander.LeanCm) * InStream.RandRange(0.6, 1.0) * Math::Min(InLength / 800.0, 1.0);
            Lean = FVector(1, 0, 0).RotateAngleAxis(LeanYaw, FVector::UpVector) * LeanAmount;
        }
        for (int32 Index = 1; Index <= Steps; ++Index)
        {
            const auto S = InLength * float(Index) / float(Steps);
            const auto Taper = Math::SmoothStep(0.0, 80.0, S) * Math::SmoothStep(0.0, 80.0, InLength - S + 40.0);
            const auto X = Amp * Math::PerlinNoise1D(S / Wave + O1) + Sway * Math::Sin(S / 120.0 * 2.0 * PI + O1);
            const auto Y = Amp * Math::PerlinNoise1D(S / Wave + O2) + Sway * Math::Cos(S / 120.0 * 2.0 * PI + O2);
            const auto T = S / InLength;
            Append(InOutPath, InFrom + FVector(X * Taper, Y * Taper, -S) + Lean * (T * T * (3.0 - 2.0 * T)), FVector::ZeroVector);
        }
    }

    // Hang to the floor, fillet onto it, creep along it in the most open direction, fork into fingers.
    void End_Ground(FMars_Vine_Path& InOutPath, const FMars_Vine_EndQuery& InQuery, const FMars_Vine_SurfaceHit& InFloor, FRandomStream& InStream)
    {
        const auto P = Req.Profile;
        const auto Ground = P.Ends.Ground;
        const auto Rc = InQuery.RadiusCm;
        const auto Lift = P.Stem.Render == EMars_VineStemRender::SplineMesh ? Rc * (1.0 - float(Ground.SinkFrac)) : Rc + float(P.Attach.StandOffCm);
        const auto Bend = Math::Max(float(Ground.ContactBendCm), 0.0);
        const auto Nf = InFloor.N;
        InOutPath.Grounded = true;

        // Above the floor point straight under the end.
        const auto Under = FVector(InQuery.From.X, InQuery.From.Y, InFloor.P.Z);
        const auto HangLength = InQuery.From.Z - (Under.Z + Lift + Bend);
        Hang(InOutPath, InQuery.From, HangLength, InStream);

        auto Stream = utils_vine::Make_Stream(Req.Seed, InOutPath.Group, EMars_VineStream::Finger);
        const auto Open = Get_OpenDirection(Under, Nf, Stream);
        const auto Bottom = InOutPath.Points.Last();

        if (Bend > 0.5)
        {
            const auto Centre = Bottom + Open * Bend;
            for (int32 Index = 1; Index <= 4; ++Index)
            {
                const auto Theta = 0.5 * PI * float(Index) / 4.0;
                Append(InOutPath, Centre - Open * (Bend * Math::Cos(Theta)) - Nf * (Bend * Math::Sin(Theta)), FVector::ZeroVector);
            }
        }

        const auto Landing = InOutPath.Points.Last();
        FMars_Vine_SurfaceHit Start;
        Start.Hit = true;
        Start.P = Landing - Nf * Lift;
        Start.N = Nf;
        InOutPath.Normals[InOutPath.Normals.Num() - 1] = Nf;

        const auto CreepLength = utils_vine::Rand(Stream, Ground.CreepCm);
        if (CreepLength > 1.0)
        {
            FMars_Vine_CreepQuery Query;
            Query.Start = Start;
            Query.Dir = Open;
            Query.LengthCm = CreepLength;
            Query.StepCm = P.Attach.StepCm;
            Query.LiftCm = Lift;
            Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg;
            Creep(Query, Stream, InOutPath);
        }

        if (P.Stem.Render == EMars_VineStemRender::None && Ground.LitterChance > 0.0f && utils_vine::Frac(Stream) < Ground.LitterChance)
        { Litter.Add(Start.P); }

        const auto FingerCount = utils_vine::RandInt(Stream, Ground.Fingers.Count);
        const auto Phi0 = Stream.RandRange(0.0, 2.0 * PI);
        for (int32 Finger = 0; Finger < FingerCount; ++Finger)
        {
            const auto Yaw = Phi0 + 2.0 * PI * float(Finger) / float(FingerCount) + Stream.RandRange(-0.35, 0.35);
            const auto Dir = utils_vine::TangentOf(FVector(Math::Cos(Yaw), Math::Sin(Yaw), 0.0), Nf, Open);
            FMars_Vine_Path Path;
            Path.Kind = EMars_VinePathKind::Finger;
            Path.Group = InOutPath.Group;
            Path.Grounded = true;
            Path.RadiusCm = FVector2D(Rc * float(Ground.Fingers.RadiusFrac), Rc * 0.04 + 0.2);
            const auto FingerLift = Path.RadiusCm.X * (1.0 - float(Ground.SinkFrac));
            Append(Path, Under + Nf * (Lift + Math::Max(Bend, 30.0)), FVector::ZeroVector);
            FMars_Vine_SurfaceHit FingerStart;
            FingerStart.Hit = true;
            FingerStart.P = Under + Dir * (Rc * 0.5);
            FingerStart.N = Nf;
            Append(Path, FingerStart.P + Nf * FingerLift, Nf);
            FMars_Vine_CreepQuery Query;
            Query.Start = FingerStart;
            Query.Dir = Dir;
            Query.LengthCm = utils_vine::Rand(Stream, Ground.Fingers.LengthCm);
            Query.StepCm = Math::Min(float(P.Attach.StepCm), 25.0);
            Query.LiftCm = FingerLift;
            Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg * 2.0;
            Creep(Query, Stream, Path);
            Work.Add(Path);
        }
    }

    // The most open of 8 horizontal directions 30 cm above the floor, jittered +-30 degrees.
    FVector Get_OpenDirection(FVector InFloorPoint, FVector InNormal, FRandomStream& InStream)
    {
        const auto Origin = InFloorPoint + InNormal * 30.0;
        const auto Phase = InStream.RandRange(0.0, 45.0);
        auto Best = FVector::ForwardVector;
        auto BestDistance = -1.0;
        for (int32 Index = 0; Index < 8; ++Index)
        {
            const auto Dir = FVector(1, 0, 0).RotateAngleAxis(Phase + 45.0 * float(Index), FVector::UpVector);
            FMars_Vine_SurfaceHit Hit;
            const auto Distance = Ray(Origin, Origin + Dir * 200.0, Hit) ? Hit.Distance : 200.0;
            if (Distance > BestDistance + 1.0)
            {
                BestDistance = Distance;
                Best = Dir;
            }
        }
        const auto Jittered = Best.RotateAngleAxis(InStream.RandRange(-30.0, 30.0), FVector::UpVector);
        return utils_vine::TangentOf(Jittered, InNormal, Best);
    }

    // Root fingers spreading over the ceiling from the top of a drop.
    void Flare_Ceiling(const FMars_Vine_SurfaceHit& InCeiling, int32 InGroup, float InRadius)
    {
        const auto Ceiling = Req.Profile.Ends.Ceiling;
        auto Stream = utils_vine::Make_Stream(Req.Seed, InGroup + 100, EMars_VineStream::Finger);
        const auto Count = utils_vine::RandInt(Stream, Ceiling.Fingers.Count);
        const auto Phi0 = Stream.RandRange(0.0, 2.0 * PI);
        for (int32 Finger = 0; Finger < Count; ++Finger)
        {
            const auto Yaw = Phi0 + 2.0 * PI * float(Finger) / float(Count) + Stream.RandRange(-0.35, 0.35);
            const auto Dir = utils_vine::TangentOf(FVector(Math::Cos(Yaw), Math::Sin(Yaw), 0.0), InCeiling.N, FVector::ForwardVector);
            FMars_Vine_Path Path;
            Path.Kind = EMars_VinePathKind::Finger;
            Path.Group = InGroup;
            Path.RadiusCm = FVector2D(InRadius * float(Ceiling.Fingers.RadiusFrac), InRadius * 0.04 + 0.2);
            const auto Lift = Path.RadiusCm.X * 0.5;
            Append(Path, InCeiling.P + InCeiling.N * 30.0, FVector::ZeroVector);
            FMars_Vine_SurfaceHit Start;
            Start.Hit = true;
            Start.P = InCeiling.P + Dir * (InRadius * 0.5);
            Start.N = InCeiling.N;
            Append(Path, Start.P + Start.N * Lift, Start.N);
            FMars_Vine_CreepQuery Query;
            Query.Start = Start;
            Query.Dir = Dir;
            Query.LengthCm = utils_vine::Rand(Stream, Ceiling.Fingers.LengthCm);
            Query.StepCm = Math::Min(float(Req.Profile.Attach.StepCm), 25.0);
            Query.LiftCm = Lift;
            Query.Steer.MeanderDeg = Req.Profile.Attach.Meander.CreepDeg * 2.0;
            Creep(Query, Stream, Path);
            Work.Add(Path);
        }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Layouts
    //------------------------------------------------------------------------------------------------------------------

    FMars_Vine_Path Make_Stem(int32 InGroup)
    {
        FMars_Vine_Path Path;
        Path.Group = InGroup;
        Path.Kind = Req.Profile.Stem.Render == EMars_VineStemRender::None ? EMars_VinePathKind::Strand : EMars_VinePathKind::Stem;
        Path.RadiusCm = FVector2D(R0, R0 * float(Req.Profile.Stem.Radius.EndFrac));
        return Path;
    }

    void Solve_Drop()
    {
        const auto P = Req.Profile;
        const auto Origin = Ctx.Frame.GetLocation();
        auto Stem = Make_Stem(0);
        auto Stream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Strand);

        FMars_Vine_SurfaceHit Ceiling;
        auto Top = Origin;
        if (Ray(Origin, Origin + FVector(0, 0, 300.0), Ceiling) && Ceiling.N.Z < -0.2)
        {
            Top = Ceiling.P;
            Append(Stem, Ceiling.P + FVector(0, 0, float(P.Ends.Ceiling.BuryCm)), FVector::ZeroVector);
            if (P.Stem.Render != EMars_VineStemRender::None)
            { Flare_Ceiling(Ceiling, 0, R0); }
        }
        Append(Stem, Top - FVector(0, 0, 1.0), FVector::ZeroVector);

        if (Stem.Kind == EMars_VinePathKind::Strand)
        {
            Finish_Strand(Stem, Stream);
            return;
        }

        FMars_Vine_EndQuery End;
        End.From = Stem.Points.Last();
        End.RadiusCm = Get_ContactRadius(R0);
        Finish_Free(Stem, End, Stream);
        Work.Add(Stem);
    }

    // A strand card: top and bottom only. Ground strands reach the floor (rootlets coil a little on it), air strands
    // stop by the profile's air rules.
    void Finish_Strand(FMars_Vine_Path& InOutStrand, FRandomStream& InStream)
    {
        FMars_Vine_EndQuery End;
        End.From = InOutStrand.Points.Last();
        Finish_Strand_With(InOutStrand, End, InStream);
    }

    void Finish_Strand_With(FMars_Vine_Path& InOutStrand, const FMars_Vine_EndQuery& InQuery, FRandomStream& InStream)
    {
        const auto P = Req.Profile;
        FMars_Vine_SurfaceHit Floor;
        const auto HasFloor = Ray(InQuery.From - FVector(0, 0, 1), InQuery.From - FVector(0, 0, float(P.Ends.Air.MaxDropCm)), Floor) && Floor.N.Z > 0.3;
        auto Ground = utils_vine::Frac(InStream) < Get_GroundShare();
        if (Ground && HasFloor == false)
        {
            ++NoFloor;
            Ground = false;
        }

        auto Top = InOutStrand.Points[0];
        float Length = 0.0;
        if (Ground)
        {
            Length = Floor.Distance + 1.0 + utils_vine::Rand(InStream, P.Ends.Ground.CoilCm);
            InOutStrand.Grounded = true;
            if (P.Ends.Ground.LitterChance > 0.0f && utils_vine::Frac(InStream) < P.Ends.Ground.LitterChance)
            { Litter.Add(Floor.P); }
        }
        else
        {
            const auto Distance = HasFloor ? Floor.Distance + 1.0 : float(P.Ends.Air.MaxDropCm);
            Length = (InOutStrand.Points.Last() - Top).Size() + Get_AirDrop(InQuery, Distance, InStream);
        }

        InOutStrand.Points.Reset();
        InOutStrand.Normals.Reset();
        Append(InOutStrand, Top, FVector::ZeroVector);
        Append(InOutStrand, Top - FVector(0, 0, Math::Max(Length, 1.0)), FVector::ZeroVector);
        InOutStrand.RadiusCm = FVector2D(utils_vine::Rand(InStream, P.Strands.Width), 1.0);
        Work.Add(InOutStrand);
    }

    // Strands at y_k along the local Y edge: find the face behind, the top behind it, creep forward over the lip and down
    // the face, then hang from where the face ends (a baluster gap or the ledge bottom). Lengths are correlated.
    void Solve_Curtain()
    {
        const auto P = Req.Profile;
        const auto Origin = Ctx.Frame.GetLocation();
        const auto Fwd = Ctx.Frame.GetRotation().GetForwardVector();
        const auto Side = Ctx.Frame.GetRotation().GetRightVector();
        auto CountStream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Strand);
        const auto Count = Req.Shape.StrandCount > 0 ? Req.Shape.StrandCount : utils_vine::RandInt(CountStream, P.Curtain.StrandsRange);
        const auto Width = float(Req.Shape.WidthCm);

        // Correlated length fractions: a control value every 3 strands, cosine-interpolated.
        auto LenStream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Len);
        TArray<float> Controls;
        for (int32 Index = 0; Index <= Math::IntegerDivisionTrunc(Count, 3) + 2; ++Index)
        { Controls.Add(utils_vine::Frac(LenStream)); }

        for (int32 Strand = 0; Strand < Count; ++Strand)
        {
            auto Stream = utils_vine::Make_Stream(Req.Seed, Strand, EMars_VineStream::Strand);
            const auto Alpha = Count > 1 ? float(Strand) / float(Count - 1) - 0.5 : 0.0;
            const auto Y = Alpha * Width + Stream.RandRange(-0.15, 0.15) * Width / float(Math::Max(Count, 1));
            const auto S = Origin + Side * Y;

            const auto Cell = float(Strand) / 3.0;
            const auto C0 = Math::FloorToInt(Cell);
            const auto T = (1.0 - Math::Cos((Cell - float(C0)) * PI)) * 0.5;
            auto LengthFrac = Math::Lerp(Controls[C0], Controls[C0 + 1], T);
            const auto Range = P.Ends.Air.LengthFrac;
            LengthFrac = Math::Lerp(float(Range.X), float(Range.Y), LengthFrac);
            if (utils_vine::Frac(Stream) < P.Curtain.StragglerChance)
            { LengthFrac = Math::Min(LengthFrac * 1.35, 1.0); }

            auto Stem = Make_Stem(Strand);
            FMars_Vine_SurfaceHit Face;
            FMars_Vine_SurfaceHit TopHit;
            const auto FaceFound = Ray(S - FVector(0, 0, 15.0), S - FVector(0, 0, 15.0) - Fwd * 80.0, Face);
            const auto TopFound = FaceFound && Ray(Face.P - Fwd * 10.0 + FVector(0, 0, 40.0), Face.P - Fwd * 10.0 - FVector(0, 0, 40.0), TopHit)
                && TopHit.N.Z > 0.5;

            FMars_Vine_EndQuery End;
            End.RadiusCm = Get_ContactRadius(R0);
            End.LengthFrac = LengthFrac;
            if (TopFound)
            {
                const auto Lift = R0 + float(P.Attach.StandOffCm);
                FMars_Vine_SurfaceHit Start;
                Start.Hit = true;
                Start.N = TopHit.N;
                Start.P = TopHit.P - Fwd * utils_vine::Rand(Stream, P.Curtain.TopInsetCm);
                FMars_Vine_SurfaceHit Snap;
                if (Ray(Start.P + FVector(0, 0, 20.0), Start.P - FVector(0, 0, 20.0), Snap))
                { Start = Snap; }
                Append(Stem, Start.P + Start.N * Lift, Start.N);

                FMars_Vine_CreepQuery Query;
                Query.Start = Start;
                Query.Dir = Fwd;
                Query.LengthCm = 400.0;
                Query.StepCm = P.Attach.StepCm;
                Query.LiftCm = Lift;
                Query.Steer.Bias = FVector(0, 0, -1);
                Query.Steer.BiasWeight = 0.35;
                Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg;
                Query.Steer.StopOnUnderside = true;
                Creep(Query, Stream, Stem);
                End.From = Stem.Points.Last();
            }
            else
            {
                Append(Stem, S, FVector::ZeroVector);
                End.From = S;
            }

            if (Stem.Kind == EMars_VinePathKind::Strand)
            {
                Finish_Strand_With(Stem, End, Stream);
                continue;
            }

            Finish_Free(Stem, End, Stream);
            Work.Add(Stem);
        }
    }

    // Up the nearest surface with a +Z bias; Ground creeps down from the start to the floor and along it first.
    void Solve_Creep()
    {
        const auto P = Req.Profile;
        const auto Origin = Ctx.Frame.GetLocation();
        const auto Host = Probe(FMars_Vine_ProbeQuery(Origin, FVector::ZeroVector, 150.0));
        if (Host.Hit == false)
        { return; }

        const auto Count = Math::Clamp(Req.Shape.StrandCount > 0 ? Req.Shape.StrandCount : 1, 1, 3);
        const auto Height = Req.Shape.HeightCm > 0.0f ? float(Req.Shape.HeightCm) : 400.0;
        const auto Lift = R0 + float(P.Attach.StandOffCm);
        for (int32 Index = 0; Index < Count; ++Index)
        {
            auto Stream = utils_vine::Make_Stream(Req.Seed, Index, EMars_VineStream::Strand);
            const auto Fan = Count == 1 ? 0.0 : Math::Lerp(-35.0, 35.0, float(Index) / float(Count - 1));
            const auto Up = utils_vine::TangentOf(FVector::UpVector, Host.N, Ctx.Frame.GetRotation().GetForwardVector());
            const auto Dir = Up.RotateAngleAxis(Fan + Stream.RandRange(-8.0, 8.0), Host.N);

            auto Stem = Make_Stem(Index);
            auto GroundShare = Get_GroundShare();
            if (utils_vine::Frac(Stream) < GroundShare)
            {
                // Down to the floor (the concave corner turns it onto the floor) and along it; reversed so the stem runs
                // from its ground end up.
                FMars_Vine_Path Down;
                Append(Down, Host.P + Host.N * Lift, Host.N);
                FMars_Vine_CreepQuery Query;
                Query.Start = Host;
                Query.Dir = FVector(0, 0, -1);
                Query.LengthCm = (Origin.Z - Host.P.Z) + 600.0 + utils_vine::Rand(Stream, P.Ends.Ground.CreepCm);
                Query.StepCm = P.Attach.StepCm;
                Query.LiftCm = Lift;
                Query.Steer.Bias = FVector(0, 0, -1);
                Query.Steer.BiasWeight = 0.3;
                Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg;
                Down = Creep_Grounded(Query, Stream, Down);
                Stem.Grounded = true;
                for (int32 Point = Down.Points.Num() - 1; Point >= 1; --Point)
                { Append(Stem, Down.Points[Point], Down.Normals[Point]); }
            }

            Append(Stem, Host.P + Host.N * Lift, Host.N);
            FMars_Vine_CreepQuery Climb;
            Climb.Start = Host;
            Climb.Dir = Dir;
            Climb.LengthCm = Height;
            Climb.StepCm = P.Attach.StepCm;
            Climb.LiftCm = Lift;
            Climb.Steer.Bias = FVector::UpVector;
            Climb.Steer.BiasWeight = 0.3;
            Climb.Steer.MeanderDeg = P.Attach.Meander.CreepDeg;
            const auto Result = Creep(Climb, Stream, Stem);
            if (Result.LeftSurface)
            {
                FMars_Vine_EndQuery End;
                End.From = Stem.Points.Last();
                End.RadiusCm = Get_ContactRadius(R0);
                End_Air(Stem, End, 200.0, Stream);
            }
            Add_Tendrils(Stem, Stream);
            Work.Add(Stem);
        }
    }

    // A creep down that stops once it has walked the creep length after reaching an up-facing surface.
    FMars_Vine_Path Creep_Grounded(const FMars_Vine_CreepQuery& InQuery, FRandomStream& InStream, FMars_Vine_Path InPath)
    {
        auto Path = InPath;
        const auto P = Req.Profile;
        Creep(InQuery, InStream, Path);
        // Trim the walk to CreepCm past the first up-facing point.
        float Walked = 0.0;
        bool OnFloor = false;
        const auto Limit = utils_vine::Rand(InStream, P.Ends.Ground.CreepCm);
        for (int32 Index = 1; Index < Path.Points.Num(); ++Index)
        {
            if (OnFloor == false && Path.Normals[Index].Z > 0.7)
            { OnFloor = true; }
            if (OnFloor)
            { Walked += Path.Points[Index].Distance(Path.Points[Index - 1]); }
            if (Walked > Limit)
            {
                const auto Keep = Index + 1;
                while (Path.Points.Num() > Keep)
                {
                    Path.Points.RemoveAt(Path.Points.Num() - 1);
                    Path.Normals.RemoveAt(Path.Normals.Num() - 1);
                }
                break;
            }
        }
        return Path;
    }

    // A coil round the actor's local Z axis: rays inward from 2 m out, one per sample.
    void Solve_Wrap()
    {
        const auto P = Req.Profile;
        const auto Axis = Ctx.Frame.GetRotation().GetUpVector();
        const auto Along = Ctx.Frame.GetRotation().GetForwardVector();
        const auto Across = Ctx.Frame.GetRotation().GetRightVector();
        const auto Origin = Ctx.Frame.GetLocation();
        auto Height = float(Req.Shape.HeightCm);
        if (Height <= 0.0)
        {
            FMars_Vine_SurfaceHit Ceiling;
            Height = Ray(Origin + Axis * 5.0, Origin + Axis * 600.0, Ceiling) ? Ceiling.Distance - 15.0 : 600.0;
        }

        const auto Count = Math::Clamp(Req.Shape.StrandCount > 0 ? Req.Shape.StrandCount : 1, 1, 3);
        const auto Samples = Math::Max(4, Math::CeilToInt(float(Req.Shape.Turns) * 24.0));
        const auto Lift = R0 + float(P.Attach.StandOffCm);
        for (int32 Index = 0; Index < Count; ++Index)
        {
            auto Stream = utils_vine::Make_Stream(Req.Seed, Index, EMars_VineStream::Strand);
            const auto Theta0 = 2.0 * PI * float(Index) / float(Count)
                + utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Meander).RandRange(0.0, 2.0 * PI);
            auto Stem = Make_Stem(Index);
            FMars_Vine_SurfaceHit First;
            for (int32 Sample = 0; Sample <= Samples; ++Sample)
            {
                const auto Theta = Theta0 + 2.0 * PI * float(Req.Shape.Turns) * float(Sample) / float(Samples);
                const auto Z = Height * float(Sample) / float(Samples);
                const auto Centre = Origin + Axis * Z;
                const auto Radial = Along * Math::Cos(Theta) + Across * Math::Sin(Theta);
                FMars_Vine_SurfaceHit Hit;
                if (Ray(Centre + Radial * 200.0, Centre, Hit) == false)
                { continue; }
                if (First.Hit == false)
                { First = Hit; }
                Append(Stem, Hit.P + Hit.N * Lift, Hit.N);
            }

            if (Stem.Points.Num() < 2)
            { continue; }

            if (utils_vine::Frac(Stream) < Get_GroundShare())
            {
                // A short creep out over the floor from the base, prepended so the stem runs from the ground up.
                FMars_Vine_SurfaceHit Floor;
                if (Ray(First.P + First.N * 10.0, First.P + First.N * 10.0 - Axis * 60.0, Floor))
                {
                    FMars_Vine_Path Out;
                    FMars_Vine_CreepQuery Query;
                    Query.Start = Floor;
                    Query.Dir = First.N;
                    Query.LengthCm = utils_vine::Rand(Stream, P.Ends.Ground.CreepCm);
                    Query.StepCm = P.Attach.StepCm;
                    Query.LiftCm = Lift;
                    Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg;
                    Append(Out, Floor.P + Floor.N * Lift, Floor.N);
                    Creep(Query, Stream, Out);
                    FMars_Vine_Path Joined = Stem;
                    Joined.Points.Reset();
                    Joined.Normals.Reset();
                    for (int32 Point = Out.Points.Num() - 1; Point >= 0; --Point)
                    { Append(Joined, Out.Points[Point], Out.Normals[Point]); }
                    for (int32 Point = 0; Point < Stem.Points.Num(); ++Point)
                    { Append(Joined, Stem.Points[Point], Stem.Normals[Point]); }
                    Joined.Grounded = true;
                    Stem = Joined;
                }
            }
            Add_Tendrils(Stem, Stream);
            Work.Add(Stem);
        }
    }

    // Clumped strands hanging from the underside above a disc: clump centres in the disc, strands Gaussian round them,
    // a clump length drawn once and varied per strand.
    void Solve_Patch()
    {
        const auto P = Req.Profile;
        const auto Origin = Ctx.Frame.GetLocation();
        const auto Radius = float(Req.Shape.PatchRadiusCm);
        const auto Count = utils_vine::Get_StrandCount(Req);
        const auto Clumps = Math::Max(1, Math::IntegerDivisionTrunc(Count, 5));
        auto Stream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Strand);
        TArray<FVector> Centres;
        TArray<float> ClumpFrac;
        for (int32 Clump = 0; Clump < Clumps; ++Clump)
        {
            const auto R = Radius * Math::Sqrt(utils_vine::Frac(Stream));
            const auto A = Stream.RandRange(0.0, 2.0 * PI);
            Centres.Add(Origin + FVector(R * Math::Cos(A), R * Math::Sin(A), 0.0));
            ClumpFrac.Add(utils_vine::Frac(Stream));
        }

        const auto Sigma = float(P.Strands.ClumpSigmaCm);
        for (int32 Strand = 0; Strand < Count; ++Strand)
        {
            auto StrandStream = utils_vine::Make_Stream(Req.Seed, Strand, EMars_VineStream::Card);
            const auto Clump = Strand % Clumps;
            // Box-Muller.
            const auto U1 = Math::Max(utils_vine::Frac(StrandStream), 1.0e-6);
            const auto U2 = utils_vine::Frac(StrandStream);
            const auto Mag = Sigma * Math::Sqrt(-2.0 * Math::Loge(U1));
            const auto Base = Centres[Clump] + FVector(Mag * Math::Cos(2.0 * PI * U2), Mag * Math::Sin(2.0 * PI * U2), 0.0);

            FMars_Vine_SurfaceHit Top;
            if (Ray(Base, Base + FVector(0, 0, 2000.0), Top) == false || Top.N.Z >= -0.2)
            { continue; }

            auto Path = Make_Stem(Strand);
            Path.Kind = EMars_VinePathKind::Strand;
            Append(Path, Top.P + FVector(0, 0, 2.0), FVector::ZeroVector);
            FMars_Vine_EndQuery End;
            End.From = Top.P - FVector(0, 0, 1.0);
            const auto Range = P.Ends.Air.LengthFrac;
            if (Range.Y > 0.0)
            { End.LengthFrac = Math::Lerp(float(Range.X), float(Range.Y), ClumpFrac[Clump]) * StrandStream.RandRange(0.7, 1.3); }
            Finish_Strand_With(Path, End, StrandStream);
        }
    }

    // The guide, resampled at the step: samples near a surface cling to it (distance-weighted), far ones stay put.
    void Solve_Spline()
    {
        const auto P = Req.Profile;
        if (Ctx.Guide.Num() < 2)
        { return; }

        FMars_Vine_Path Guide;
        for (auto Point : Ctx.Guide)
        { Append(Guide, Ctx.Frame.TransformPosition(Point), FVector::ZeroVector); }

        const auto Rc = Math::Max(float(P.Attach.ClingRadiusCm), 1.0);
        const auto Lift = R0 + float(P.Attach.StandOffCm);
        auto Stem = Make_Stem(0);
        for (auto Point : Guide.Points)
        {
            const auto Hit = Probe(FMars_Vine_ProbeQuery(Point, FVector::ZeroVector, Rc));
            if (Hit.Hit == false)
            {
                Append(Stem, Point, FVector::ZeroVector);
                continue;
            }
            const auto W = 1.0 - Math::SmoothStep(0.5 * Rc, Rc, Hit.Distance);
            const auto Clung = Hit.P + Hit.N * Lift;
            Append(Stem, utils_vine::VLerp(Point, Clung, W), W > 0.5 ? Hit.N : FVector::ZeroVector);
        }

        auto Stream = utils_vine::Make_Stream(Req.Seed, 0, EMars_VineStream::Strand);
        if (Stem.Normals.Last().IsNearlyZero())
        {
            FMars_Vine_EndQuery End;
            End.From = Stem.Points.Last();
            End.RadiusCm = Get_ContactRadius(R0);
            Finish_Free(Stem, End, Stream);
        }
        Add_Tendrils(Stem, Stream);
        Work.Add(Stem);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Branches, tendrils
    //------------------------------------------------------------------------------------------------------------------

    // Curled tips on an air end, no traces.
    void Add_Tendrils(const FMars_Vine_Path& InStem, FRandomStream& InStream)
    {
        const auto P = Req.Profile;
        if (InStem.Grounded || InStem.Points.Num() < 2 || P.Branches.TipTendrils.Y <= 0)
        { return; }

        const auto Tip = InStem.Points.Last();
        const auto Dir = (Tip - InStem.Points[InStem.Points.Num() - 2]).GetSafeNormal();
        const auto Count = utils_vine::RandInt(InStream, P.Branches.TipTendrils);
        for (int32 Index = 0; Index < Count; ++Index)
        {
            FMars_Vine_Path Tendril;
            Tendril.Kind = EMars_VinePathKind::Tendril;
            Tendril.Group = InStem.Group;
            Tendril.RadiusCm = FVector2D(InStem.RadiusCm.Y * 0.6, InStem.RadiusCm.Y * 0.25);
            const auto Length = InStream.RandRange(10.0, 25.0);
            const auto Axis = utils_vine::Get_AnyPerpendicular(Dir).RotateAngleAxis(InStream.RandRange(0.0, 360.0), Dir);
            auto Point = Tip;
            auto Heading = Dir.RotateAngleAxis(InStream.RandRange(-30.0, 30.0), Axis);
            Append(Tendril, Point, FVector::ZeroVector);
            for (int32 Step = 0; Step < 6; ++Step)
            {
                Heading = Heading.RotateAngleAxis(90.0 / 6.0 * (1.0 + float(Step) * 0.3), Axis);
                Point = Point + Heading * (Length / 6.0);
                Append(Tendril, Point, FVector::ZeroVector);
            }
            Work.Add(Tendril);
        }
    }

    // Side shoots off the main stems: on a surface a short creep in the tangent plane, hanging a short dangle.
    void Grow_Branches()
    {
        const auto P = Req.Profile;
        const auto Branches = P.Branches;
        const auto Stems = Work.Num();
        for (int32 StemIndex = 0; StemIndex < Stems; ++StemIndex)
        {
            const auto Stem = Work[StemIndex];
            if (Stem.Kind != EMars_VinePathKind::Stem || Stem.Points.Num() < 3)
            { continue; }

            auto Stream = utils_vine::Make_Stream(Req.Seed, StemIndex, EMars_VineStream::Branch);
            const auto Length = utils_vine::Get_PathLength(Stem.Points);
            float Walked = 0.0;
            float Next = float(Branches.SpacingCm) * Stream.RandRange(0.6, 1.4);
            float Side = 1.0;
            for (int32 Index = 1; Index < Stem.Points.Num() - 1; ++Index)
            {
                Walked += Stem.Points[Index].Distance(Stem.Points[Index - 1]);
                if (Walked < Next)
                { continue; }

                Next = Walked + float(Branches.SpacingCm) * Stream.RandRange(0.6, 1.4);
                if (utils_vine::Frac(Stream) >= Branches.Chance)
                { continue; }

                Side = -Side;
                const auto Tangent = (Stem.Points[Index + 1] - Stem.Points[Index - 1]).GetSafeNormal();
                const auto N = Stem.Normals[Index];
                const auto R = utils_vine::Get_TaperRadius(P, Stem.RadiusCm, Walked / Math::Max(Length, 1.0)) * 0.7;
                FMars_Vine_Path Branch;
                Branch.Kind = EMars_VinePathKind::Branch;
                Branch.Group = StemIndex;
                Branch.RadiusCm = FVector2D(R, R * float(P.Stem.Radius.EndFrac));
                Append(Branch, Stem.Points[Index], N);
                const auto BranchLength = utils_vine::Rand(Stream, Branches.LengthCm);
                if (N.IsNearlyZero())
                {
                    // A dangling tendril off a hanging stretch.
                    const auto Out = Tangent.CrossProduct(FVector::UpVector).GetSafeNormal() * Side;
                    auto Point = Stem.Points[Index];
                    const auto Steps = Math::Max(2, Math::CeilToInt(BranchLength / 10.0));
                    for (int32 Step = 1; Step <= Steps; ++Step)
                    {
                        const auto A = float(Step) / float(Steps);
                        Point = Point + (Out * (1.0 - A) * 0.6 + FVector(0, 0, -1)).GetSafeNormal() * (BranchLength / float(Steps));
                        Append(Branch, Point, FVector::ZeroVector);
                    }
                }
                else
                {
                    const auto Angle = utils_vine::Rand(Stream, Branches.AngleDeg) * Side;
                    FMars_Vine_SurfaceHit Start;
                    Start.Hit = true;
                    Start.N = N;
                    Start.P = Stem.Points[Index] - N * (Stem.RadiusCm.X + float(P.Attach.StandOffCm));
                    FMars_Vine_CreepQuery Query;
                    Query.Start = Start;
                    Query.Dir = Tangent.RotateAngleAxis(Angle, N);
                    Query.LengthCm = BranchLength;
                    Query.StepCm = P.Attach.StepCm;
                    Query.LiftCm = R + float(P.Attach.StandOffCm);
                    Query.Steer.MeanderDeg = P.Attach.Meander.CreepDeg * 1.5;
                    Creep(Query, Stream, Branch);
                }
                if (Branch.Points.Num() >= 2)
                { Work.Add(Branch); }
            }
        }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Post-processing: smooth, resample, twin strands, quantise, actor-local
    //------------------------------------------------------------------------------------------------------------------

    void Finish_Paths(FMars_Vine_Solved& OutSolved)
    {
        const auto P = Req.Profile;
        for (int32 WorkIndex = 0; WorkIndex < Work.Num(); ++WorkIndex)
        {
            auto Path = Work[WorkIndex];
            if (Path.Points.Num() < 2)
            { continue; }

            if (Path.Kind != EMars_VinePathKind::Strand)
            {
                utils_vine::Thin(Path, float(P.Attach.StepCm) * 0.5 * (Path.Kind == EMars_VinePathKind::Stem ? 1.0 : 0.4));
                utils_vine::Smooth(Path, P.Attach.SmoothPasses);
                // Side paths (fingers, branches, tendrils) get at least 3 pieces and, for roots, at most 3.
                const auto SideLength = utils_vine::Get_PathLength(Path.Points) / 3.0;
                auto Segment = float(P.Stem.SegmentLengthCm);
                if (Path.Kind != EMars_VinePathKind::Stem)
                {
                    Segment = P.Stem.Render == EMars_VineStemRender::SplineMesh ? Math::Max(SideLength, 2.0)
                        : Math::Min(Segment, Math::Max(SideLength, 2.0));
                }
                utils_vine::Resample(Path, Segment);
            }

            if (Path.Kind == EMars_VinePathKind::Stem && P.Twist.Strands == 2 && P.Stem.Render == EMars_VineStemRender::SplineMesh)
            {
                for (int32 Strand = 0; Strand < 2; ++Strand)
                { Add_Local(OutSolved, Twist(Path, Strand)); }
                continue;
            }
            Add_Local(OutSolved, Path);
        }

        for (auto Site : Litter)
        {
            FMars_Vine_Path Path;
            Path.Kind = EMars_VinePathKind::Strand;
            Path.Group = -1;
            Path.Grounded = true;
            Path.RadiusCm = FVector2D(0.0, 0.0);
            Append(Path, Site, FVector::UpVector);
            Add_Local(OutSolved, Path);
        }
    }

    // Strand k of a twin root: the centreline offset by d(s) round the RMF frame at 2 pi s / Pitch + k pi; the offset
    // grows near both ends so the strands fork.
    FMars_Vine_Path Twist(const FMars_Vine_Path& InPath, int32 InStrand)
    {
        const auto P = Req.Profile;
        const auto T = P.Twist;
        FMars_Vine_Path Out = InPath;
        Out.Points.Reset();
        Out.Group = InPath.Group;
        Out.RadiusCm = FVector2D(InPath.RadiusCm.X * float(T.StrandFrac), InPath.RadiusCm.Y * float(T.StrandFrac));
        const auto Rights = utils_vine::Rmf_Frames(InPath.Points, InPath.Normals);
        const auto Length = utils_vine::Get_PathLength(InPath.Points);
        const auto Theta0 = utils_vine::Make_Stream(Req.Seed, InPath.Group, EMars_VineStream::Roll).RandRange(0.0, 2.0 * PI);
        const auto Split = Math::Max(float(T.SplitLengthCm), 1.0);
        float S = 0.0;
        for (int32 Index = 0; Index < InPath.Points.Num(); ++Index)
        {
            if (Index > 0)
            { S += InPath.Points[Index].Distance(InPath.Points[Index - 1]); }

            const auto A = InPath.Points[Math::Max(Index - 1, 0)];
            const auto B = InPath.Points[Math::Min(Index + 1, InPath.Points.Num() - 1)];
            const auto Tangent = (B - A).GetSafeNormal();
            const auto R = Rights[Index];
            const auto Bi = Tangent.CrossProduct(R).GetSafeNormal();
            const auto Radius = utils_vine::Get_TaperRadius(P, InPath.RadiusCm, S / Math::Max(Length, 1.0));
            const auto Fork = Math::Max(Math::SmoothStep(Length - Split, Length, S), 1.0 - Math::SmoothStep(0.0, Split, S));
            const auto D = Radius * float(T.OffsetFrac) * (1.0 + 0.8 * Fork);
            const auto Theta = Theta0 + 2.0 * PI * S / float(T.PitchCm) + PI * float(InStrand);
            Out.Points.Add(InPath.Points[Index] + (R * Math::Cos(Theta) + Bi * Math::Sin(Theta)) * D);
        }
        return Out;
    }

    void Add_Local(FMars_Vine_Solved& OutSolved, const FMars_Vine_Path& InWorld)
    {
        FMars_Vine_Path Local = InWorld;
        for (int32 Index = 0; Index < Local.Points.Num(); ++Index)
        {
            Local.Points[Index] = utils_vine::Quantize(Ctx.Frame.InverseTransformPosition(InWorld.Points[Index]), 0.1);
            const auto N = InWorld.Normals[Index];
            Local.Normals[Index] = N.IsNearlyZero() ? FVector::ZeroVector
                : utils_vine::Quantize(Ctx.Frame.InverseTransformVectorNoScale(N), 0.001);
        }
        OutSolved.Paths.Add(Local);
    }
}
