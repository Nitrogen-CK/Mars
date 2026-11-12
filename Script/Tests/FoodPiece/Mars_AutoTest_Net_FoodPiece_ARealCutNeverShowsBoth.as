// The server cuts the meat slab for real five times, a second apart, each time the heaviest Ready piece through the middle
// of its local X bounds. On the client no frame of the whole test shows a piece standing with one it was cut from, the
// replay loads no mesh (it shares the slab's own import, so the first cut waits for no load), and six pieces stand at
// the end, each matching the authority's geometry. The frames in which nothing stood are logged with the sample frame of
// each: the slab's entity can end a frame before its halves are built.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ARealCutNeverShowsBoth
class UCk_AutoTest_Net_FoodPiece_ARealCutNeverShowsBoth : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 185000.0;
    private const float32 k_CutSeconds = 1.0f;
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const int32 k_CutCount = 5;

    private int32 _CutsAsked = 0;
    // Client: the sample frames in which nothing stood.
    private TArray<int32> _NeitherFrames;
    private int32 _LastNeither = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            WaitUntil(n"Is_ClientSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        Cut_Heaviest();
    }

    // The heaviest Ready piece at the test's X, the whole slab included, through the middle of its local X bounds.
    private void Cut_Heaviest()
    {
        auto Candidates = Get_ReadyPiecesNear(_FloorTop);
        if (Get_IsFoodReady(_Rock))
        { Candidates.Add(_Rock.As_FoodPiece()); }

        auto Heaviest = FCk_Handle_FoodPiece();
        for (const auto& Piece : Candidates)
        {
            if (Piece.Get_IsCutting() == false && (ck::Is_NOT_Valid(Heaviest) || Piece.Get_MassKg() > Heaviest.Get_MassKg()))
            { Heaviest = Piece; }
        }

        ++_CutsAsked;
        Assert_True(ck::IsValid(Heaviest), f"cut {_CutsAsked} found a Ready piece");
        if (ck::IsValid(Heaviest))
        { Cut(Heaviest, Make_MiddlePlane(Heaviest, 0)); }

        if (_CutsAsked < k_CutCount)
        {
            WaitSeconds(k_CutSeconds, n"OnServerNextCut");
            return;
        }

        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerNextCut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut_Heaviest();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), k_CutCount, "every cut was made");
        Assert_Equals_Int(Get_ReadyPieceCountNear(_FloorTop), k_CutCount + 1, "six pieces on the server");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cuts={Get_CutCount(EMars_FoodPiece_CutOutcome::Cut)} pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (_Neither != _LastNeither)
        { _NeitherFrames.Add(_SampleFrame); }

        _LastNeither = _Neither;
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        auto Result = OutResult;
        Result.Set(_WholeStood && Standing.Num() == k_CutCount + 1 && Get_AreChecked(Standing));
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        const auto Standing = Get_StandingNear(_FloorTop);
        auto NeitherAt = FString();
        for (const auto Frame : _NeitherFrames)
        { NeitherAt += f"{Frame} "; }

        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_Equals_Int(Get_Tally().MeshImports, 0, "the replay loaded no mesh: it shares the slab's import");
        Assert_Equals_Int(Standing.Num(), k_CutCount + 1, "six pieces stand");
        Assert_Equals_Int(Get_CheckCount(Standing, EMars_FoodPiece_CheckResult::Matches), k_CutCount + 1, "every standing piece matches the authority");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} standing={Standing.Num()} matches={Get_CheckCount(Standing, EMars_FoodPiece_CheckResult::Matches)} neitherAt=[{NeitherAt}] {Describe_Tally()}");
        End_Client();
    }
}
