// An ivy Curtain of 8 strands placed 30 cm past the lip of a 50 cm thick ledge (+X outward): every strand starts on the
// ledge top, creeps over the lip and down the face, leaves the face at the ledge bottom and hangs at least 20 cm below
// it. The hang lengths are correlated fractions of each strand's own floor distance, so they differ (standard deviation
// of the lowest points above 5 cm).
class UMars_AutoTest_Vine_CurtainWrapsTheLipAndHangsEveryStrand : UMars_AutoTestRig_Vine
{
    default _Slot = 7;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a ledge over a floor", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("an ivy curtain at the lip", n"Step_Vine");
        Add_Step("every strand wraps the lip and hangs", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        // x -100 .. 100 (the lip at +100), z -25 .. 25.
        SpawnSlab(O, FVector(2.0, 3.0, 0.5));
        SpawnFloor(O, O.Z - 600.0, FVector(1200.0, 1200.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::Ivy), EMars_VineLayout::Curtain, EMars_VineEnd::Air);
        Spawn.Location = Get_Origin() + FVector(130.0, 0.0, 33.0);
        Spawn.Shape.StrandCount = 8;
        Spawn.Shape.WidthCm = 160.0f;
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto O = Get_Origin();
        const auto Top = O.Z + 25.0;
        const auto Bottom = O.Z - 25.0;
        const auto Lip = O.X + 100.0;
        const auto Stems = Get_WorldPaths(_Vine, EMars_VinePathKind::Stem);
        Assert_Equals_Int(Stems.Num(), 8, f"eight strands ({_Vine.Status})");

        TArray<float> Lows;
        for (int32 Strand = 0; Strand < Stems.Num(); ++Strand)
        {
            bool OnTop = false;
            bool OnFace = false;
            for (auto P : Stems[Strand].Points)
            {
                if (P.X < Lip && P.Z >= Top && P.Z <= Top + 5.0)
                { OnTop = true; }
                if (P.X >= Lip && P.X <= Lip + 6.0 && P.Z >= Bottom && P.Z <= Top)
                { OnFace = true; }
            }
            const auto Low = Get_LowestZ(Stems[Strand]);
            Lows.Add(Low);
            Assert_True(OnTop, f"strand {Strand} starts on the ledge top");
            Assert_True(OnFace, f"strand {Strand} creeps down the face");
            Assert_True(Low < Bottom - 20.0, f"strand {Strand} hangs below the ledge ({Low - Bottom :.0} cm)");
        }

        if (Lows.Num() > 1)
        {
            float Mean = 0.0;
            for (auto Low : Lows)
            { Mean += Low; }
            Mean /= float(Lows.Num());
            float Variance = 0.0;
            for (auto Low : Lows)
            { Variance += (Low - Mean) * (Low - Mean); }
            const auto Deviation = Math::Sqrt(Variance / float(Lows.Num()));
            Assert_True(Deviation > 5.0, f"the strand lengths differ (deviation {Deviation :.1} cm)");
        }
    }
}
