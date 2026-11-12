// After the server cuts a whole meat slab it moves the positive half 30 cm along +Y and turns it 90 degrees about Z, and
// reports where both halves now are. Within 3 s the client's copy of the positive half is within 1 cm and 1 degree of the
// server's pose, and its negative half has not moved from where the server left it.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACutPieceFollowsTheAuthoritysPose
class UCk_AutoTest_Net_FoodPiece_ACutPieceFollowsTheAuthoritysPose : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 153000.0;
    private const FVector k_Offset = FVector(0.0, 30.0, 0.0);
    private const float64 k_TurnDegrees = 90.0;
    private const float64 k_ToleranceCm = 1.0;
    private const float64 k_ToleranceDegrees = 1.0;
    private const float64 k_FollowSeconds = 3.0;

    private float64 _FollowStart = 0.0;
    private FCk_Handle _ClientPositive;
    private FCk_Handle _ClientNegative;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientMoveReported", n"OnClientMoveReported", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabStill", n"OnServerSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnServerSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
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
            FinishSuccess();
            return;
        }

        FCk_Handle Positive = _Cuts[0].Positive;
        FCk_Handle Negative = _Cuts[0].Negative;
        const auto PositiveWorld = utils_transform::Get_EntityCurrentTransform(Positive.As_Transform());

        auto Report = Get_PieceReport();
        Report.PositiveLocation = PositiveWorld.GetLocation() + k_Offset;
        Report.PositiveYaw = PositiveWorld.Rotator().Yaw + k_TurnDegrees;
        Report.NegativeLocation = Get_RootLocation(Negative);

        auto Root = Positive.As_Transform();
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(Report.PositiveLocation));
        utils_transform::Request_SetRotation(Root, FCk_Request_Transform_SetRotation(FRotator(0.0, Report.PositiveYaw, 0.0)));
        Publish_PieceReport(Report);
        WaitFrames(2, n"OnServerMoved");
    }

    UFUNCTION()
    private void OnServerMoved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        FCk_Handle Positive = _Cuts[0].Positive;
        const auto World = utils_transform::Get_EntityCurrentTransform(Positive.As_Transform());
        Assert_True(World.GetLocation().Equals(Report.PositiveLocation, 0.01), f"the server's positive half moved ({World.GetLocation()} vs {Report.PositiveLocation})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"moved to {World.GetLocation()} yaw {World.Rotator().Yaw}");
        WaitSeconds(5.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientMoveReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        _ClientPositive = Find_ByKept(Pieces, EMars_FoodPiece_CutSide::Positive);
        _ClientNegative = Find_ByKept(Pieces, EMars_FoodPiece_CutSide::Negative);

        auto Result = OutResult;
        Result.Set(ck::IsValid(_ClientPositive) && ck::IsValid(_ClientNegative) && Get_PieceReport().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientMoveReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FollowStart = System::GetGameTimeInSeconds();
        WaitUntil(n"Is_ClientFollowedOrLate", n"OnClientFollowedOrLate", k_SlowPolls);
    }

    private bool Get_IsFollowing()
    {
        const auto Report = Get_PieceReport();
        const auto World = utils_transform::Get_EntityCurrentTransform(_ClientPositive.As_Transform());
        const auto YawError = Math::Abs(Math::UnwindDegrees(World.Rotator().Yaw - Report.PositiveYaw));
        return World.GetLocation().Equals(Report.PositiveLocation, k_ToleranceCm) && YawError <= k_ToleranceDegrees;
    }

    UFUNCTION()
    private void Is_ClientFollowedOrLate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsLive(_ClientPositive) == false)
        {
            Result.Set(true);
            return;
        }

        Result.Set(Get_IsFollowing() || System::GetGameTimeInSeconds() - _FollowStart > k_FollowSeconds);
    }

    UFUNCTION()
    private void OnClientFollowedOrLate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        Assert_True(Get_IsLive(_ClientPositive), "the client's positive half is live");
        if (Get_IsLive(_ClientPositive) == false)
        {
            FinishSuccess();
            return;
        }

        const auto World = utils_transform::Get_EntityCurrentTransform(_ClientPositive.As_Transform());
        const auto Seconds = System::GetGameTimeInSeconds() - _FollowStart;
        Assert_True(Get_IsFollowing(), f"the client's positive half follows the server's pose within {k_FollowSeconds} s ({World.GetLocation()} yaw {World.Rotator().Yaw} vs {Report.PositiveLocation} yaw {Report.PositiveYaw})");

        const auto NegativeLocation = Get_RootLocation(_ClientNegative);
        Assert_True(NegativeLocation.Equals(Report.NegativeLocation, k_ToleranceCm), f"the client's negative half did not move ({NegativeLocation} vs {Report.NegativeLocation})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"positive at {World.GetLocation()} yaw {World.Rotator().Yaw} after {Seconds} s; negative at {NegativeLocation}");
        FinishSuccess();
    }
}
