// A GiantRoot (two strands, pitch 500 cm, offset 0.42 R, 72 cm segments, a 2 m lean) dropped through a 3-storey (1050 cm) atrium: away from the
// forks at both ends the strand centres are 2 x 0.42 R(s) = 0.84 R(s) apart (+-10 % on 90 % of samples, R the taper
// radius there) and the pair turns 2 pi per pitch about the root (+-10 %). It lays at most 64 spline segments and
// traces at most 3000 times.
class UMars_AutoTest_Vine_TwinStrandRootTwistsAndStaysInsideItsBudgets : UMars_AutoTestRig_Vine
{
    default _Slot = 10;
    private AMars_Vine _Vine;
    private UMars_VineProfile _Profile;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a three-storey atrium", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a giant root", n"Step_Vine");
        Add_Step("its strands twist round each other", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1600.0, 1600.0, 50.0));
        SpawnCeiling(O, O.Z + 1050.0, FVector(1600.0, 1600.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Profile = Make_Profile(EMars_VinePreset::GiantRoot);
        auto Spawn = Make_Spawn(_Profile, EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 900.0);
        Spawn.Seed = 4242;
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto Report = _Vine.Get_Report();
        Assert_True(Report.Segments <= 64, f"at most 64 segments ({Report.Segments})");
        Assert_True(_Vine.Solved.TraceCount <= 3000, f"at most 3000 traces ({_Vine.Solved.TraceCount})");

        const auto Stems = Get_WorldPaths(_Vine, EMars_VinePathKind::Stem);
        Assert_Equals_Int(Stems.Num(), 2, f"two strands ({_Vine.Status})");
        if (Stems.Num() != 2 || Stems[0].Points.Num() != Stems[1].Points.Num())
        {
            Assert_True(false, "the strands pair point for point");
            return;
        }

        const auto& A = Stems[0];
        const auto& B = Stems[1];
        const auto Count = A.Points.Num();
        const auto Frac = float(_Profile.Twist.StrandFrac);
        const auto Original = FVector2D(A.RadiusCm.X / Frac, A.RadiusCm.Y / Frac);
        TArray<FVector> Centre;
        for (int32 Index = 0; Index < Count; ++Index)
        { Centre.Add((A.Points[Index] + B.Points[Index]) * 0.5); }
        const auto Length = utils_vine::Get_PathLength(Centre);
        const auto Split = float(_Profile.Twist.SplitLengthCm);

        int32 Middle = 0;
        int32 Good = 0;
        float S = 0.0;
        float Turned = 0.0;
        float TurnedFrom = -1.0;
        float TurnedTo = 0.0;
        for (int32 Index = 0; Index < Count; ++Index)
        {
            if (Index > 0)
            { S += Centre[Index].Distance(Centre[Index - 1]); }
            if (S < Split || S > Length - Split)
            { continue; }

            ++Middle;
            const auto Expected = 2.0 * float(_Profile.Twist.OffsetFrac) * utils_vine::Get_TaperRadius(_Profile, Original, S / Length);
            const auto Gap = A.Points[Index].Distance(B.Points[Index]);
            if (Math::Abs(Gap / Expected - 1.0) <= 0.1)
            { ++Good; }

            if (Index + 1 < Count)
            {
                const auto T = (Centre[Index + 1] - Centre[Index]).GetSafeNormal();
                const auto U0 = (A.Points[Index] - B.Points[Index]).GetSafeNormal();
                const auto U1 = (A.Points[Index + 1] - B.Points[Index + 1]).GetSafeNormal();
                Turned += Math::Atan2(U0.CrossProduct(U1).DotProduct(T), U0.DotProduct(U1));
                if (TurnedFrom < 0.0)
                { TurnedFrom = S; }
                TurnedTo = S + Centre[Index + 1].Distance(Centre[Index]);
            }
        }
        Assert_True(Middle >= 4, f"the middle of the root was measured ({Middle} samples)");
        Assert_True(float(Good) >= 0.9 * float(Middle), f"the strand centres are 0.84 R apart ({Good} of {Middle})");

        const auto ExpectedTurn = 2.0 * PI * (TurnedTo - TurnedFrom) / float(_Profile.Twist.PitchCm);
        Assert_True(Math::Abs(Math::Abs(Turned) / ExpectedTurn - 1.0) <= 0.1,
            f"the pair turns 2 pi per pitch ({Math::Abs(Turned) :.2} rad over {TurnedTo - TurnedFrom :.0} cm, expected {ExpectedTurn :.2})");
    }
}
