// The server sets the meat slab's cook state (+Z sear 0.25, oil coat 0.5) and cuts it in the same frame. Inside 1 s of
// becoming a FoodPiece each client half carries that cook state and its display's oil-coat slot reads above 0. The server
// then writes a second cook state (+Z sear 0.75, oil coat 0.9) on the positive half: the client's copy of that half follows
// it and raises OnCookStateChanged once after the test bound it; the negative half's cook state is unchanged and raises
// nothing.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACookedFoodsHalvesWearItsCookState
class UCk_AutoTest_Net_FoodPiece_ACookedFoodsHalvesWearItsCookState : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 176000.0;
    // Past the client's build, its 1 s look check and its bind.
    private const float32 k_BeforeSecondWriteSeconds = 4.0f;
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const float64 k_LookSeconds = 1.0;
    private const float64 k_FollowSeconds = 5.0;
    private const float32 k_SettleSeconds = 0.5f;

    private FCk_Handle_FoodPiece _Positive;
    private FCk_Handle_FoodPiece _Negative;
    private TOptional<float64> _PositiveSeen;
    private TOptional<float64> _NegativeSeen;
    private float64 _BoundAt = 0.0;
    private float64 _WornAfter = 0.0;
    private int32 _PositiveRaised = 0;
    private int32 _NegativeRaised = 0;

    private FMars_FoodPiece_CookState Get_FirstCookState() { return Make_CookState(0.25f, 0.5f); }

    private FMars_FoodPiece_CookState Get_SecondCookState() { return Make_CookState(0.75f, 0.9f); }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientHalvesWearIt", n"OnClientHalvesWearIt", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        auto Slab = _Rock.As_FoodPiece();
        Slab.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_FirstCookState()));
        Cut(Slab, Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {_Cuts[0].Outcome :n})");
        if (_Cuts[0].Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
            return;
        }

        Publish_PieceReport(Make_CutReport(_CutSources[0], _Cuts[0]));
        WaitSeconds(k_BeforeSecondWriteSeconds, n"OnServerSecondWriteDue");
    }

    UFUNCTION()
    private void OnServerSecondWriteDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Positive = _Cuts[0].Positive;
        Positive.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_SecondCookState()));
        Publish_PieceReport(Get_PieceReport());

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cut={_Cuts[0].Outcome :n} wrote a second cook state on the positive half");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    private bool Get_WearsFirst(FCk_Handle_FoodPiece InPiece)
    {
        const auto Shown = Get_ShownOilCoat(InPiece);
        return Get_IsCookStateEqual(InPiece.Get_CookState(), Get_FirstCookState()) && Shown.IsSet() && Shown.GetValue() > 0.0f;
    }

    // Records when each half became a FoodPiece; done once both wear the first cook state, or 1 s after the later one
    // became a piece.
    UFUNCTION()
    private void Is_ClientHalvesWearIt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Report = Get_PieceReport();
        if (Report.Serial < 1)
        {
            Result.Set(false);
            return;
        }

        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        _Positive = Find_ById(Pieces, Report.PositiveId);
        _Negative = Find_ById(Pieces, Report.NegativeId);
        if (ck::IsValid(_Positive) && _PositiveSeen.IsSet() == false)
        { _PositiveSeen = TOptional<float64>(Get_Now()); }

        if (ck::IsValid(_Negative) && _NegativeSeen.IsSet() == false)
        { _NegativeSeen = TOptional<float64>(Get_Now()); }

        if (_PositiveSeen.IsSet() == false || _NegativeSeen.IsSet() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Later = Math::Max(_PositiveSeen.GetValue(), _NegativeSeen.GetValue());
        Result.Set((Get_WearsFirst(_Positive) && Get_WearsFirst(_Negative)) || Get_Now() - Later > k_LookSeconds);
    }

    UFUNCTION()
    private void OnClientHalvesWearIt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Later = Math::Max(_PositiveSeen.GetValue(), _NegativeSeen.GetValue());
        _WornAfter = Get_Now() - Later;
        Assert_True(Get_WearsFirst(_Positive), f"the positive half wears the cook state inside {k_LookSeconds} s");
        Assert_True(Get_WearsFirst(_Negative), f"the negative half wears the cook state inside {k_LookSeconds} s");

        _Positive.BindTo_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnClientCookStateChanged"));
        _Negative.BindTo_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnClientCookStateChanged"));
        _BoundAt = Get_Now();
        WaitUntil(n"Is_ClientPositiveFollowedOrLate", n"OnClientPositiveFollowedOrLate", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCookStateChanged(FCk_Handle_FoodPiece InPiece)
    {
        if (InPiece == _Positive)
        { ++_PositiveRaised; }
        else
        { ++_NegativeRaised; }
    }

    UFUNCTION()
    private void Is_ClientPositiveFollowedOrLate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Followed = Get_PieceReport().Serial >= 2 && Get_IsCookStateEqual(_Positive.Get_CookState(), Get_SecondCookState());
        auto Result = OutResult;
        Result.Set(Followed || Get_Now() - _BoundAt > k_FollowSeconds);
    }

    UFUNCTION()
    private void OnClientPositiveFollowedOrLate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCookStateEqual(_Positive.Get_CookState(), Get_SecondCookState()), "the positive half follows the second cook state");
        Assert_Equals_Int(_PositiveRaised, 1, "the positive half raised OnCookStateChanged once");
        Assert_True(Get_IsCookStateEqual(_Negative.Get_CookState(), Get_FirstCookState()), "the negative half's cook state is unchanged");
        Assert_Equals_Int(_NegativeRaised, 0, "the negative half raised nothing");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"wornAfter={_WornAfter}s positiveRaised={_PositiveRaised} negativeRaised={_NegativeRaised} {Describe_Tally()}");

        _Positive.UnbindFrom_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnClientCookStateChanged"));
        _Negative.UnbindFrom_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnClientCookStateChanged"));
        End_Client();
    }
}
