// The server lays a drumstick, writes its cook state battered once it rests, and a step later slices it by hand through its
// centre and spawns both halves in one frame; the whole drumstick stays alive on the server. The client's whole drumstick
// wears its battered shell before the halves stand; once both stand it reads Superseded and wears no shell.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AReplacedBatteredFoodWearsNothing
class UCk_AutoTest_Net_FoodPiece_AReplacedBatteredFoodWearsNothing : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 188000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    // Frames the client watches the replaced drumstick once both halves stand.
    private const int32 k_WatchFrames = 30;

    // Client: whether the whole drumstick wore its shell before any half stood, and the frames since both halves stood with
    // the ones in which it did not read Superseded or still wore a shell.
    private bool _HadShell = false;
    private int32 _ReplacedFrames = 0;
    private int32 _ReplacedBad = 0;

    protected UCk_InventoryItem_Definition Get_RigFoodItem() override
    {
        return mars_items::Food_Drumstick();
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            WaitUntil(n"Is_ClientWatched", n"OnClientWatched", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        auto Food = _Rock.As_FoodPiece();
        auto Battered = Food.Get_CookState();
        Battered.Battered = 1.0f;
        Food.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Battered));
        WaitSeconds(k_StepSeconds, n"OnServerSlice");
    }

    UFUNCTION()
    private void OnServerSlice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ByHandHalves();
    }

    protected void On_ServerHalvesHeld() override
    {
        Spawn_P();
        Spawn_N();
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)} battered={_Rock.As_FoodPiece().Get_CookState().Battered}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        const auto Whole = Find_FoodPieceNear(_FloorTop);
        if (ck::Is_NOT_Valid(Whole))
        { return; }

        auto Halves = 0;
        for (const auto& Piece : InStanding)
        {
            if (Piece.Get_IsWhole() == false)
            { ++Halves; }
        }

        const auto HasShell = ck::IsValid(utils_food::TryGet_BatteredShell(Whole));
        if (Halves == 0 && HasShell)
        { _HadShell = true; }

        if (Halves < 2)
        { return; }

        ++_ReplacedFrames;
        if (Get_IsSuperseded(Whole) == false || HasShell)
        { ++_ReplacedBad; }
    }

    UFUNCTION()
    private void Is_ClientWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ReplacedFrames >= k_WatchFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_True(_HadShell, "the whole drumstick wore its battered shell before the halves stood");
        Assert_Equals_Int(_ReplacedBad, 0, "once both halves stand the whole drumstick reads Superseded and wears no shell");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} hadShell={_HadShell} replaced={_ReplacedFrames} bad={_ReplacedBad} {Describe_Tally()}");
        End_Client();
    }
}
