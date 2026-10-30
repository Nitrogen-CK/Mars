// The vine emitter: turns a solve into components, deterministically from (Solved, seed) and without a single trace.
// Roots become spline-mesh chains; thin stems, leaves, knots, tips, strand cards and litter become instances, one HISM
// per mesh actually used, created on demand. Every created component is tagged Mars.Vine.Emitted (the actor destroys
// them before a rebuild) and carries four custom-data floats (VINES.md, the four-float contract). Every slot is
// zero-neutral (a primitive without custom data reads 0), so the masters encode offsets: MossScale - 1, WindWeight - 1
// and LengthCm / 100 - 1.

enum EMars_VineBatchKind
{
    // Paint master layout: VarSeed, MossScale - 1, WetAdd, 0.
    Stem,
    // Foliage master layout: VarSeed, Dryness, WindWeight - 1, LengthCm / 100 - 1.
    Leaf,
    Strand
}

struct FMars_Vine_Batch
{
    UStaticMesh Mesh;
    EMars_VineBatchKind Kind = EMars_VineBatchKind::Stem;
    TArray<FTransform> Transforms;
    // Four floats per instance.
    TArray<float32> Data;
}

// The measured shape of a stem mesh: its length and radius along / across the forward axis, and where it starts.
struct FMars_Vine_MeshFrame
{
    float LengthCm = 100.0;
    float RadiusCm = 50.0;
    float StartCm = 0.0;
}

struct FMars_Vine_Emitter
{
    AActor Owner;
    FMars_Vine_Request Req;
    // Static in a construction script; Movable when a game-world Rebuild emits (a registered Static component refuses
    // SetStaticMesh after BeginPlay).
    bool Static = true;
    TArray<FMars_Vine_Batch> Batches;
    TArray<UPrimitiveComponent> Created;
    FMars_Vine_Report Report;
    float VarSeed = 0.0;

    FMars_Vine_Report Emit(const FMars_Vine_Solved& InSolved)
    {
        auto P = Req.Profile;
        auto TintStream = utils_vine::Make_Stream(InSolved.EffectiveSeed, 0, EMars_VineStream::Tint);
        VarSeed = utils_vine::Frac(TintStream);
        Report.Paths = InSolved.Paths.Num();
        Report.Traces = InSolved.TraceCount;

        for (int32 Index = 0; Index < InSolved.Paths.Num(); ++Index)
        {
            const auto& Path = InSolved.Paths[Index];
            if (Path.Kind == EMars_VinePathKind::Strand)
            {
                if (Path.Group < 0)
                { Emit_Litter(Path, Index, InSolved.EffectiveSeed); }
                else
                { Emit_Card(Path, Index, InSolved.EffectiveSeed); }
                continue;
            }

            if (Path.Points.Num() < 2)
            { continue; }

            if (P.Stem.Render == EMars_VineStemRender::SplineMesh)
            {
                Emit_Segments(Path, Index, InSolved.EffectiveSeed);
                Emit_Knots(Path, Index, InSolved.EffectiveSeed);
            }
            else if (P.Stem.Render == EMars_VineStemRender::Instanced)
            {
                Emit_Chords(Path);
                if (Path.Kind != EMars_VinePathKind::Finger)
                { Emit_Leaves(Path, Index, InSolved.EffectiveSeed); }
            }
        }

        Flush();
        return Report;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Shared
    //------------------------------------------------------------------------------------------------------------------

    EComponentMobility Get_Mobility() const
    {
        return Static ? EComponentMobility::Static : EComponentMobility::Movable;
    }

    FMars_Vine_MeshFrame Get_MeshFrame(const UStaticMesh InMesh) const
    {
        FMars_Vine_MeshFrame Frame;
        if (ck::Is_NOT_Valid(InMesh))
        { return Frame; }

        const auto Bounds = InMesh.GetBounds();
        const auto E = Bounds.BoxExtent;
        const auto O = Bounds.Origin;
        if (Req.Profile.Stem.Meshes.ForwardAxis == ESplineMeshAxis::Z)
        {
            Frame.LengthCm = Math::Max(2.0 * E.Z, 1.0);
            Frame.RadiusCm = Math::Max(Math::Max(E.X, E.Y), 0.1);
            Frame.StartCm = O.Z - E.Z;
        }
        else
        {
            Frame.LengthCm = Math::Max(2.0 * E.X, 1.0);
            Frame.RadiusCm = Math::Max(Math::Max(E.Y, E.Z), 0.1);
            Frame.StartCm = O.X - E.X;
        }
        return Frame;
    }

    // The stem radius at arc length InS of InPath (taper plus a slow jitter).
    float Get_Radius(const FMars_Vine_Path& InPath, float InS, float InLength) const
    {
        auto P = Req.Profile;
        const auto Base = utils_vine::Get_TaperRadius(P, InPath.RadiusCm, InS / Math::Max(InLength, 1.0));
        const auto Jitter = float(P.Stem.Radius.JitterFrac) * Math::PerlinNoise1D(InS / 37.0 + float(InPath.Group) * 7.31 + 0.5);
        return Math::Max(Base * (1.0 + Jitter), 0.05);
    }

    // A rotation whose ForwardAxis runs along InDir with its next axis toward InUp.
    FQuat Get_AxisRotation(FVector InDir, FVector InUp) const
    {
        const auto Up = utils_vine::TangentOf(InUp, InDir, utils_vine::Get_AnyPerpendicular(InDir));
        if (Req.Profile.Stem.Meshes.ForwardAxis == ESplineMeshAxis::Z)
        { return FRotator::MakeFromXZ(Up, InDir).Quaternion(); }

        return FRotator::MakeFromXZ(InDir, Up).Quaternion();
    }

    FVector Get_AxisScale(float InAlong, float InAcross) const
    {
        if (Req.Profile.Stem.Meshes.ForwardAxis == ESplineMeshAxis::Z)
        { return FVector(InAcross, InAcross, InAlong); }

        return FVector(InAlong, InAcross, InAcross);
    }

    void Add_Instance(UStaticMesh InMesh, EMars_VineBatchKind InKind, FTransform InTransform, FVector4 InData)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return; }

        int32 Found = -1;
        for (int32 Index = 0; Index < Batches.Num(); ++Index)
        {
            if (Batches[Index].Mesh == InMesh && Batches[Index].Kind == InKind)
            {
                Found = Index;
                break;
            }
        }
        if (Found < 0)
        {
            FMars_Vine_Batch Batch;
            Batch.Mesh = InMesh;
            Batch.Kind = InKind;
            Batches.Add(Batch);
            Found = Batches.Num() - 1;
        }

        Batches[Found].Transforms.Add(InTransform);
        Batches[Found].Data.Add(float32(InData.X));
        Batches[Found].Data.Add(float32(InData.Y));
        Batches[Found].Data.Add(float32(InData.Z));
        Batches[Found].Data.Add(float32(InData.W));
    }

    FVector4 Get_StemData() const
    {
        const auto D = Req.Profile.Rendering.Data;
        return FVector4(VarSeed, float(D.MossScale) - 1.0, float(D.WetAdd), 0.0);
    }

    void Apply_Common(UPrimitiveComponent InComponent, bool InCollides)
    {
        InComponent.ComponentTags.AddUnique(utils_vine::EmittedTag);
        if (InCollides)
        {
            InComponent.SetCollisionProfileName(collision::profile::BlockAll);
            InComponent.ComponentTags.Remove(utils_vine::JoltNoBakeTag);
        }
        else
        {
            InComponent.SetCollisionProfileName(collision::profile::NoCollision);
            InComponent.ComponentTags.AddUnique(utils_vine::JoltNoBakeTag);
        }
        Created.Add(InComponent);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Roots: spline-mesh chains, knots, tips
    //------------------------------------------------------------------------------------------------------------------

    void Emit_Segments(const FMars_Vine_Path& InPath, int32 InIndex, int32 InSeed)
    {
        auto P = Req.Profile;
        const auto& Points = InPath.Points;
        const auto Count = Points.Num();
        const auto Length = utils_vine::Get_PathLength(Points);
        const auto Rights = utils_vine::Rmf_Frames(Points, InPath.Normals);
        auto MeshStream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Card);
        auto RollStream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Roll);

        TArray<float> Radii;
        TArray<float> Rolls;
        float S = 0.0;
        float Roll = RollStream.RandRange(0.0, 360.0);
        for (int32 Index = 0; Index < Count; ++Index)
        {
            if (Index > 0)
            { S += Points[Index].Distance(Points[Index - 1]); }
            Radii.Add(Get_Radius(InPath, S, Length));
            Rolls.Add(Roll);
            Roll += RollStream.RandRange(-1.0, 1.0) * float(P.Stem.RollJitterDeg);
        }

        for (int32 Index = 0; Index < Count - 1; ++Index)
        {
            if (Report.Segments >= utils_vine::k_MaxSegments)
            { return; }

            auto Mesh = P.Stem.Meshes.Mesh;
            if (ck::IsValid(P.Stem.Meshes.AltMesh) && utils_vine::Frac(MeshStream) < 0.5)
            { Mesh = P.Stem.Meshes.AltMesh; }

            const auto T0 = (Points[Math::Min(Index + 1, Count - 1)] - Points[Math::Max(Index - 1, 0)]) * (Index == 0 ? 1.0 : 0.5);
            const auto T1 = (Points[Math::Min(Index + 2, Count - 1)] - Points[Index]) * (Index + 2 >= Count ? 1.0 : 0.5);

            auto Segment = USplineMeshComponent::Create(Owner);
            Segment.SetMobility(Get_Mobility());
            Segment.SetStaticMesh(Mesh);
            if (ck::IsValid(P.Rendering.StemMaterial))
            { Segment.SetMaterial(0, P.Rendering.StemMaterial); }
            Segment.SetForwardAxis(P.Stem.Meshes.ForwardAxis, false);
            Segment.SetStartAndEnd(Points[Index], T0, Points[Index + 1], T1, false);
            // Every segment scales by the primary mesh's radius: the alternate's bounds include its knot bulge, but both
            // share the end rings, so scaling each by its own bounds would step the rings at every joint.
            const auto Frame0 = Get_MeshFrame(P.Stem.Meshes.Mesh);
            Segment.SetStartScale(FVector2D(Radii[Index] / Frame0.RadiusCm, Radii[Index] / Frame0.RadiusCm), false);
            Segment.SetEndScale(FVector2D(Radii[Index + 1] / Frame0.RadiusCm, Radii[Index + 1] / Frame0.RadiusCm), false);
            Segment.SetSplineUpDir(Rights[Index], false);
            Segment.SetStartRollDegrees(float32(Rolls[Index]), false);
            Segment.SetEndRollDegrees(float32(Rolls[Index + 1] + Get_JointRollFix(Rights, T1, Index)), false);
            TArray<float32> Data;
            const auto D = Get_StemData();
            Data.Add(float32(D.X));
            Data.Add(float32(D.Y));
            Data.Add(float32(D.Z));
            Data.Add(float32(D.W));
            Segment.SetDefaultCustomPrimitiveDataFloatArray(0, Data);
            Segment.SetCastShadow(P.Rendering.Shadows.Stems);
            Segment.SetAffectDistanceFieldLighting(false);
            Apply_Common(Segment, Req.Collides);
            Segment.UpdateMesh();
            ++Report.Segments;
        }

        // A tip on a free root end.
        if (InPath.Grounded == false && InPath.Kind == EMars_VinePathKind::Stem && ck::IsValid(P.Stem.Meshes.TipMesh))
        {
            const auto TipFrame = Get_MeshFrame(P.Stem.Meshes.TipMesh);
            const auto Dir = (Points[Count - 1] - Points[Count - 2]).GetSafeNormal();
            const auto R = Radii[Count - 1];
            FTransform Tip;
            Tip.SetRotation(Get_AxisRotation(Dir, Rights[Count - 1]));
            Tip.SetScale3D(Get_AxisScale(R * 3.0 / TipFrame.LengthCm, R / TipFrame.RadiusCm));
            Tip.SetLocation(Points[Count - 1] - Dir * (TipFrame.StartCm * R * 3.0 / TipFrame.LengthCm));
            Add_Instance(P.Stem.Meshes.TipMesh, EMars_VineBatchKind::Stem, Tip, Get_StemData());
        }
    }

    // A spline mesh builds its end frame from its own up direction: BaseX = Up x T, then rolls it by -roll about T
    // (SplineMeshSceneProxyDesc.cpp, CalcSliceTransformAtSplineOffset). Segment i and i + 1 use different ups, so the
    // ring at their shared joint would turn by the angle between the two BaseX vectors there; adding that angle to
    // segment i's end roll makes both rings land on the same vertices (no sliver at any joint).
    float Get_JointRollFix(const TArray<FVector>& InRights, FVector InTangent, int32 InSegment) const
    {
        if (InSegment + 1 >= InRights.Num() - 1)
        { return 0.0; }

        const auto T = InTangent.GetSafeNormal();
        const auto Mine = InRights[InSegment].CrossProduct(T).GetSafeNormal();
        const auto Next = InRights[InSegment + 1].CrossProduct(T).GetSafeNormal();
        if (Mine.IsNearlyZero() || Next.IsNearlyZero())
        { return 0.0; }
        return Math::RadiansToDegrees(Math::Atan2(Next.CrossProduct(Mine).DotProduct(T), Next.DotProduct(Mine)));
    }

    // Lumps along a root, a Poisson process at 0.5 per metre.
    void Emit_Knots(const FMars_Vine_Path& InPath, int32 InIndex, int32 InSeed)
    {
        auto P = Req.Profile;
        if (ck::Is_NOT_Valid(P.Stem.Meshes.KnotMesh) || InPath.Kind == EMars_VinePathKind::Tendril)
        { return; }

        auto Stream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Knot);
        const auto Frame = Get_MeshFrame(P.Stem.Meshes.KnotMesh);
        const auto Length = utils_vine::Get_PathLength(InPath.Points);
        const auto Rate = 0.5 / 100.0;
        float Next = -Math::Loge(Math::Max(utils_vine::Frac(Stream), 1.0e-4)) / Rate;
        float S = 0.0;
        for (int32 Index = 1; Index < InPath.Points.Num(); ++Index)
        {
            const auto A = InPath.Points[Index - 1];
            const auto B = InPath.Points[Index];
            const auto SegLength = A.Distance(B);
            while (Next <= S + SegLength)
            {
                const auto T = (Next - S) / Math::Max(SegLength, 1.0e-3);
                const auto C = utils_vine::VLerp(A, B, T);
                const auto Dir = (B - A).GetSafeNormal();
                const auto R = Get_Radius(InPath, Next, Length);
                const auto Out = utils_vine::Get_AnyPerpendicular(Dir).RotateAngleAxis(Stream.RandRange(0.0, 360.0), Dir);
                FTransform Knot;
                Knot.SetLocation(C + Out * (R * 0.6));
                Knot.SetRotation(FRotator::MakeFromXZ(Dir, Out).Quaternion());
                const auto Scale = R * Stream.RandRange(0.5, 0.8) / Frame.RadiusCm;
                Knot.SetScale3D(FVector(Scale, Scale, Scale));
                Add_Instance(P.Stem.Meshes.KnotMesh, EMars_VineBatchKind::Stem, Knot, Get_StemData());
                Next += -Math::Loge(Math::Max(utils_vine::Frac(Stream), 1.0e-4)) / Rate;
            }
            S += SegLength;
        }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Thin stems: instanced chords and leaves
    //------------------------------------------------------------------------------------------------------------------

    void Emit_Chords(const FMars_Vine_Path& InPath)
    {
        auto P = Req.Profile;
        auto Mesh = P.Stem.Meshes.Mesh;
        const auto Frame = Get_MeshFrame(Mesh);
        const auto& Points = InPath.Points;
        const auto Length = utils_vine::Get_PathLength(Points);
        const auto Rights = utils_vine::Rmf_Frames(Points, InPath.Normals);
        float S = 0.0;
        for (int32 Index = 0; Index < Points.Num() - 1; ++Index)
        {
            if (Report.Chords >= utils_vine::k_MaxChords)
            { return; }

            const auto Delta = Points[Index + 1] - Points[Index];
            const auto SegLength = Delta.Size();
            if (SegLength < 0.01)
            { continue; }

            const auto Dir = Delta / SegLength;
            const auto R = Get_Radius(InPath, S + SegLength * 0.5, Length);
            const auto Along = SegLength * 1.1 / Frame.LengthCm;
            FTransform Chord;
            Chord.SetRotation(Get_AxisRotation(Dir, Rights[Index]));
            Chord.SetScale3D(Get_AxisScale(Along, R / Frame.RadiusCm));
            Chord.SetLocation(Points[Index] - Dir * (SegLength * 0.05 + Frame.StartCm * Along));
            Add_Instance(Mesh, EMars_VineBatchKind::Stem, Chord, Get_StemData());
            ++Report.Chords;
            S += SegLength;
        }
    }

    UStaticMesh Pick_Weighted(TArray<UStaticMesh>& InMeshes, const TArray<float32>& InWeights, FRandomStream& InStream)
    {
        if (InMeshes.Num() == 0)
        { return nullptr; }

        float Total = 0.0;
        for (int32 Index = 0; Index < InMeshes.Num(); ++Index)
        { Total += Index < InWeights.Num() ? Math::Max(float(InWeights[Index]), 0.0) : 1.0; }

        auto Pick = utils_vine::Frac(InStream) * Total;
        for (int32 Index = 0; Index < InMeshes.Num(); ++Index)
        {
            Pick -= Index < InWeights.Num() ? Math::Max(float(InWeights[Index]), 0.0) : 1.0;
            if (Pick <= 0.0)
            { return InMeshes[Index]; }
        }
        return InMeshes.Last();
    }

    // Leaves every Spacing x U(0.6, 1.4), thinning and shrinking toward the tip; surface leaves lie on the host, hanging
    // leaves face outward and droop.
    void Emit_Leaves(const FMars_Vine_Path& InPath, int32 InIndex, int32 InSeed)
    {
        auto P = Req.Profile;
        auto Leaves = P.Leaves;
        if (Leaves.Meshes.Num() == 0)
        { return; }

        auto Stream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Leaf);
        const auto& Points = InPath.Points;
        const auto Length = utils_vine::Get_PathLength(Points);
        const auto Outward = Owner.GetActorForwardVector();
        float Next = float(Leaves.SpacingCm) * Stream.RandRange(0.2, 1.0);
        float S = 0.0;
        float Side = 1.0;
        const auto Dryness = float(P.Rendering.Data.Dryness);
        for (int32 Index = 1; Index < Points.Num(); ++Index)
        {
            const auto A = Points[Index - 1];
            const auto B = Points[Index];
            const auto SegLength = A.Distance(B);
            const auto Tangent = SegLength > 0.01 ? (B - A) / SegLength : FVector::UpVector;
            while (Next <= S + SegLength)
            {
                if (Report.Leaves >= utils_vine::k_MaxLeaves)
                { return; }

                const auto Frac = Next / Math::Max(Length, 1.0);
                const auto T = (Next - S) / Math::Max(SegLength, 1.0e-3);
                Next += float(Leaves.SpacingCm) * Stream.RandRange(0.6, 1.4);
                const auto Hold = float(Leaves.Falloff.HoldFrac);
                const auto Fade = Frac < Hold ? 1.0 : Math::Lerp(1.0, float(Leaves.Falloff.TipDensity), (Frac - Hold) / Math::Max(1.0 - Hold, 0.01));
                const auto Keep = float(Leaves.Falloff.Density) * Fade;
                const auto Draw = utils_vine::Frac(Stream);
                auto Mesh = Pick_Weighted(Leaves.Meshes, Leaves.Weights, Stream);
                const auto Scale = utils_vine::Rand(Stream, Leaves.Scale) * Math::Lerp(1.0, float(Leaves.Falloff.TipScale), Frac);
                const auto Spin = Stream.RandRange(-1.0, 1.0);
                const auto Yaw = Stream.RandRange(-60.0, 60.0);
                Side = -Side;
                if (Draw >= Keep)
                { continue; }

                const auto C = utils_vine::VLerp(A, B, T);
                const auto N = InPath.Normals[T < 0.5 ? Index - 1 : Index];
                const auto R = Get_Radius(InPath, Next, Length);
                FVector Z;
                FVector X;
                FVector Position;
                if (N.IsNearlyZero() == false)
                {
                    Z = N.RotateAngleAxis(Spin * float(Leaves.TiltDeg), Tangent);
                    X = Tangent.RotateAngleAxis(70.0 * Side + Spin * 15.0, N);
                    Position = C + N.CrossProduct(Tangent).GetSafeNormal() * (R * Side);
                }
                else
                {
                    const auto Horizontal = utils_vine::TangentOf(Outward, FVector::UpVector, FVector::ForwardVector);
                    Z = Horizontal.RotateAngleAxis(Yaw, FVector::UpVector);
                    const auto Across = Z.CrossProduct(FVector::UpVector).GetSafeNormal() * Side;
                    X = Across.RotateAngleAxis(-float(Leaves.DroopDeg) * Side, Z);
                    Position = C + Across * R;
                }
                FTransform Leaf;
                Leaf.SetLocation(Position);
                Leaf.SetRotation(FRotator::MakeFromXZ(utils_vine::TangentOf(X, Z, Tangent), Z).Quaternion());
                Leaf.SetScale3D(FVector(Scale, Scale, Scale));
                Add_Instance(Mesh, EMars_VineBatchKind::Leaf, Leaf, FVector4(VarSeed, Dryness, 0.0, 0.0));
                ++Report.Leaves;
            }
            S += SegLength;
        }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Cards and litter
    //------------------------------------------------------------------------------------------------------------------

    // A 100 cm card hanging from its top, stretched to the strand: scale (w, w, L / 100), L / 100 - 1 in custom data slot 3.
    void Emit_Card(const FMars_Vine_Path& InPath, int32 InIndex, int32 InSeed)
    {
        auto P = Req.Profile;
        if (InPath.Points.Num() < 2 || P.Strands.Meshes.Num() == 0 || Report.Cards >= utils_vine::k_MaxCards)
        { return; }

        auto Stream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Card);
        const auto Top = InPath.Points[0];
        const auto Length = Math::Max(Top.Z - InPath.Points[1].Z, 1.0);
        TArray<float32> Weights;
        auto Mesh = Pick_Weighted(P.Strands.Meshes, Weights, Stream);
        const auto Width = InPath.RadiusCm.X > 0.0 ? InPath.RadiusCm.X : 1.0;
        FTransform Card;
        Card.SetLocation(Top);
        Card.SetRotation(FRotator(Stream.RandRange(-3.0, 3.0), Stream.RandRange(0.0, 360.0), Stream.RandRange(-3.0, 3.0)).Quaternion());
        Card.SetScale3D(FVector(Width, Width, Length / 100.0));
        const auto Wind = Stream.RandRange(0.6, 1.2);
        Add_Instance(Mesh, EMars_VineBatchKind::Strand, Card, FVector4(VarSeed, float(P.Rendering.Data.Dryness), Wind - 1.0, Length / 100.0 - 1.0));
        ++Report.Cards;
    }

    void Emit_Litter(const FMars_Vine_Path& InPath, int32 InIndex, int32 InSeed)
    {
        auto P = Req.Profile;
        if (InPath.Points.Num() < 1 || ck::Is_NOT_Valid(P.Strands.LitterMesh))
        { return; }

        auto Stream = utils_vine::Make_Stream(InSeed, InIndex, EMars_VineStream::Litter);
        const auto Scale = Stream.RandRange(0.3, 0.5);
        FTransform Litter;
        Litter.SetLocation(InPath.Points[0]);
        Litter.SetRotation(FRotator(0.0, Stream.RandRange(0.0, 360.0), 0.0).Quaternion());
        Litter.SetScale3D(FVector(Scale, Scale, Scale));
        Add_Instance(P.Strands.LitterMesh, EMars_VineBatchKind::Leaf, Litter, FVector4(VarSeed, 0.7, -0.8, 0.0));
    }

    //------------------------------------------------------------------------------------------------------------------
    // One HISM per (mesh, kind) used
    //------------------------------------------------------------------------------------------------------------------

    void Flush()
    {
        auto P = Req.Profile;
        for (const auto& Batch : Batches)
        {
            if (Batch.Transforms.Num() == 0)
            { continue; }

            auto Hism = UHierarchicalInstancedStaticMeshComponent::Create(Owner);
            Hism.SetMobility(Get_Mobility());
            Hism.SetStaticMesh(Batch.Mesh);
            Apply_Common(Hism, false);
            Hism.SetNumCustomDataFloats(4);
            Hism.AddInstances(Batch.Transforms, false, false);

            const auto Count = Batch.Transforms.Num();
            for (int32 Instance = 0; Instance < Count; ++Instance)
            {
                for (int32 Slot = 0; Slot < 4; ++Slot)
                {
                    const auto Last = Instance == Count - 1 && Slot == 3;
                    Hism.SetCustomDataValue(Instance, Slot, Batch.Data[Instance * 4 + Slot], Last);
                }
            }

            UMaterialInterface Override;
            bool Shadows = P.Rendering.Shadows.Stems;
            if (Batch.Kind == EMars_VineBatchKind::Leaf)
            {
                Override = P.Rendering.LeafMaterial;
                Shadows = P.Rendering.Shadows.Leaves;
            }
            else if (Batch.Kind == EMars_VineBatchKind::Strand)
            {
                Override = P.Rendering.StrandMaterial;
                Shadows = P.Rendering.Shadows.Strands;
            }
            else
            { Override = P.Rendering.StemMaterial; }

            if (ck::IsValid(Override))
            { Hism.SetMaterial(0, Override); }

            Hism.SetCastShadow(Shadows);
            if (Batch.Kind != EMars_VineBatchKind::Stem)
            {
                Hism.SetCullDistances(Math::RoundToInt(P.Rendering.CullCm.X), Math::RoundToInt(P.Rendering.CullCm.Y));
                Hism.SetWorldPositionOffsetDisableDistance(3000);
                Hism.SetAffectDistanceFieldLighting(false);
            }
        }
    }
}
