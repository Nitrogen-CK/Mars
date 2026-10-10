// A piece the settle never sees come to rest is frozen where it is once it has settled for Settle.MaxSeconds, and lands
// there. The platter drops its piece from so high over its floor that the free fall outlasts k_MaxSeconds about twice:
// every drift sample sees the piece move and Jolt never puts it to sleep, so the watchdog gives up on it in mid-fall. The
// settle's own record of the piece reads FreezeCause TimedOut with at least k_MaxSeconds on its clock; OnLoaded fires once,
// no sooner than k_MaxSeconds after the drop and before the tuners' default MaxSeconds; and the piece is held, Kinematic
// and on the root, still above the walls where it was falling, and stays where it landed.
// Isolated origin (162000, -70000, -30000).
class UMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(162000.0, -70000.0, -30000.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    // A 5 m drop falls for about a second (sqrt(2 * 5 m / 9.8 m/s2)), twice k_MaxSeconds.
    private const float32 k_DropHeight = 500.0f;
    private const float32 k_MaxSeconds = 0.5f;
    // Float slack on a difference of two game-time stamps.
    private const float64 k_ClockSlack = 0.001;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_JoltBody _Body;

    // Game time P was first seen settling (dropped), and landed (OnLoaded).
    private TOptional<float64> _DropSeconds;
    private TOptional<float64> _LandedSeconds;
    // The settle's record of P the first time it was seen frozen.
    private TOptional<EMars_Platter_FreezeCause> _FreezeCause;
    private float32 _FreezeSettleSeconds = 0.0f;
    // Where P was when it landed: its world location, and its bounds centre's height over the floor.
    private FVector _LandedWorld;
    private float64 _LandedCentreHeight = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Platter_Spec(1, FMars_Platter_Bounds(FVector2D(15.0, 15.0), 40.0f, k_DropHeight));
        Spec.Settle.MaxSeconds = k_MaxSeconds;
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Spec);
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLandedRecordingWhenAndWhere"));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("give P a dynamic body", n"Step_GiveBody");
        Add_Step_WaitUntil("P's body is added", n"Check_BodyAdded", 0, 0);
        Add_Step("load P", n"Step_Load");
        Add_Step_WaitUntil("P dropped, was frozen while still falling and landed", n"Check_LandedWatchingTheSettle", k_SlowPolls, 0);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("the settle timed P out at MaxSeconds, and P landed and stays where it was falling", n"Step_AssertTimedOutWhereItFell");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_GiveBody(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Body = Give_Body(_P);
    }

    UFUNCTION()
    private void Check_BodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_Body));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Dynamic, "P's body starts Dynamic");
        Load(_Platter, _P);
    }

    // Every poll, the settle's record of P: the first sight of it is the drop, the first sight of its freeze names the cause.
    UFUNCTION()
    private void Check_LandedWatchingTheSettle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Settling = TryGet_SettlingOf(_P);
        if (Settling.IsSet())
        {
            if (_DropSeconds.IsSet() == false)
            { _DropSeconds = TOptional<float64>(System::GetGameTimeInSeconds()); }

            const auto Record = Settling.GetValue();
            if (Record.Freeze.IsSet() && _FreezeCause.IsSet() == false)
            {
                _FreezeCause = Record.Freeze;
                _FreezeSettleSeconds = Record.Seconds;
            }
        }

        auto Res = OutResult;
        Res.Set(_LandedSeconds.IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertTimedOutWhereItFell(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(Get_LoadedCountOf(_P), 1, "OnLoaded fired once for P");

        Assert_True(_FreezeCause.IsSet(), "the settle's record of P was seen frozen before P attached");
        Assert_True(_FreezeCause.IsSet() && _FreezeCause.GetValue() == EMars_Platter_FreezeCause::TimedOut,
            "the settle froze P because it was still moving at MaxSeconds (TimedOut), not because it came to rest");
        Assert_True(_FreezeSettleSeconds >= k_MaxSeconds,
            f"the settle's clock had reached MaxSeconds when it froze P ({_FreezeSettleSeconds} s, MaxSeconds {k_MaxSeconds} s)");

        if (_DropSeconds.IsSet() == false || _LandedSeconds.IsSet() == false)
        {
            FinishFailure("P's drop or its landing was never seen");
            return;
        }

        const auto Defaults = FMars_Platter_SettleTuners();
        const auto DefaultMaxSeconds = float64(Defaults.MaxSeconds);
        const auto Settled = _LandedSeconds.GetValue() - _DropSeconds.GetValue();
        Assert_True(Settled >= float64(k_MaxSeconds) - k_ClockSlack, f"P landed no sooner than MaxSeconds after its drop ({Settled :.3} s)");
        Assert_True(Settled < DefaultMaxSeconds, f"P landed before the tuners' default MaxSeconds [{DefaultMaxSeconds}] ({Settled :.3} s)");

        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is held, Kinematic and a scene-node child of the root");
        const auto WallHeight = float64(_Platter.Get_Spec().Bounds.WallHeight);
        Assert_True(_LandedCentreHeight > WallHeight,
            f"P landed in mid-fall, above the walls ({_LandedCentreHeight :.1} cm over the floor, walls {WallHeight} cm)");

        const auto Now = Get_World(_P).GetLocation();
        Assert_True(Now.Equals(_LandedWorld, 0.5), f"P stays where it landed (at {Now}, landed at {_LandedWorld})");
    }

    UFUNCTION()
    private void OnLandedRecordingWhenAndWhere(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (InPiece != _P || _LandedSeconds.IsSet())
        { return; }

        _LandedSeconds = TOptional<float64>(System::GetGameTimeInSeconds());
        _LandedWorld = Get_World(_P).GetLocation();
        _LandedCentreHeight = Get_CentreHeight(_P);
    }

    // The settle's record of InPiece (its clock, its freeze); unset while it is queued and once it landed.
    private TOptional<FMars_Platter_Settling> TryGet_SettlingOf(FCk_Handle_FoodPiece InPiece)
    {
        const auto& State = _Platter.Get_Fragment(FMars_Fragment_Platter);
        for (const auto& Settling : State.Settling)
        {
            if (Settling.Piece == InPiece)
            { return TOptional<FMars_Platter_Settling>(Settling); }
        }

        return TOptional<FMars_Platter_Settling>();
    }

    // How high InPiece's bounds centre stands over the platter's floor, in the root's frame.
    private float64 Get_CentreHeight(FCk_Handle_FoodPiece InPiece) const
    {
        const auto CentreWorld = Get_World(InPiece).TransformPosition(Get_BoundsCenter(InPiece));
        return Get_PlatterWorld(_Platter).InverseTransformPosition(CentreWorld).Z;
    }
}
