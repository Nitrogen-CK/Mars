// The server lays a drumstick, slices it by hand through its centre once it rests and spawns both halves in one frame; a
// step later it writes the whole drumstick's cook state battered (the whole drumstick is still alive on the server). On
// the client, once both halves stand the whole drumstick reads Superseded and its display is hidden; after it has taken
// the battered cook state it still wears no shell and its display stays hidden, for 30 frames.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AReplacedFoodStaysHiddenWhenItsCookStateChanges
class UCk_AutoTest_Net_FoodPiece_AReplacedFoodStaysHiddenWhenItsCookStateChanges : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 190000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const int32 k_WatchFrames = 30;

    // Client: frames since both halves stood, with the ones in which the whole drumstick did not read Superseded or was
    // shown; frames since it took the battered cook state, with the ones in which it wore a shell or was shown.
    private int32 _ReplacedFrames = 0;
    private int32 _ReplacedBad = 0;
    private int32 _BatteredFrames = 0;
    private int32 _BatteredBad = 0;

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
        Begin_ByHandHalves();
    }

    protected void On_ServerHalvesHeld() override
    {
        Spawn_P();
        Spawn_N();
        WaitSeconds(k_StepSeconds, n"OnServerBatter");
    }

    UFUNCTION()
    private void OnServerBatter(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Food = _Rock.As_FoodPiece();
        auto Battered = Food.Get_CookState();
        Battered.Battered = 1.0f;
        Food.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Battered));
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

        if (Halves < 2)
        { return; }

        FCk_Handle Entity = Whole;
        const auto IsHidden = Entity.Is_RuntimeMeshDisplay() && Get_IsShown(Entity) == false;
        ++_ReplacedFrames;
        if (Get_IsSuperseded(Whole) == false || IsHidden == false)
        { ++_ReplacedBad; }

        if (Whole.Get_CookState().Battered < 1.0f)
        { return; }

        ++_BatteredFrames;
        if (ck::IsValid(utils_food::TryGet_BatteredShell(Whole)) || IsHidden == false)
        { ++_BatteredBad; }
    }

    UFUNCTION()
    private void Is_ClientWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BatteredFrames >= k_WatchFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_Equals_Int(_ReplacedBad, 0, "once both halves stand the whole drumstick reads Superseded and its display is hidden");
        Assert_Equals_Int(_BatteredBad, 0, "after the battered cook state the whole drumstick wears no shell and stays hidden");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} replaced={_ReplacedFrames} bad={_ReplacedBad} battered={_BatteredFrames} batteredBad={_BatteredBad} {Describe_Tally()}");
        End_Client();
    }
}
