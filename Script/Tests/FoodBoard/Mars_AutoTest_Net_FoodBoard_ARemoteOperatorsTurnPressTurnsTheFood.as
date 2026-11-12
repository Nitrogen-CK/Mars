// The server places the slab, seats the subject and applies the seed to the subject's InputIntents as a remote sample; 10
// frames later a remote sample carries one turn press (Drop). The authority's reader turns the board: it raises one turn
// of 90 degrees and the slab's root turns 90 degrees about the station root. The client raises the same turn and its
// whole food stands at the report.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood
class UCk_AutoTest_Net_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 211000.0;

    private FVector _PlacedLocation;
    private float64 _PlacedYaw = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        Begin_OperatorRig();
        if (Get_IsServer() == false)
        {
            Await_ClientStep(1, n"OnClientStep1");
            return;
        }

        Begin_ServerBoardWithSlab(InHandle);
    }

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PlacedLocation = Get_RootLocation(_Rock);
        _PlacedYaw = Get_RootYaw(_Rock);
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_RemoteThen(n"OnServerSeeded");
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Press_RemoteTurn();
        Await_ServerQuiet(0, 1, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        const auto Pivot = Get_StationRootLocation();
        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(float64(utils_cutting::k_TurnDegrees)));
        const auto Expected = Pivot + Yaw.RotateVector(_PlacedLocation - Pivot);
        const auto ErrorCm = (Get_RootLocation(_Rock) - Expected).Size();
        const auto ErrorDegrees = Math::Abs(Math::FindDeltaAngleDegrees(Get_RootYaw(_Rock), _PlacedYaw + float64(utils_cutting::k_TurnDegrees)));
        Assert_True(_Turns.Num() == 1 && _Turns[0] == utils_cutting::k_TurnDegrees, f"the server raised one turn of 90 (got {_Turns.Num()})");
        Assert_True(ErrorCm <= constants_foodboard_net_autotest::k_ServerToleranceCm, f"the slab's root turned about the station root ({ErrorCm} cm off)");
        Assert_True(ErrorDegrees <= constants_foodboard_net_autotest::k_ServerToleranceDegrees, f"the slab's yaw turned 90 degrees ({ErrorDegrees} deg off)");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"turns={_Turns.Num()} off {ErrorCm} cm {ErrorDegrees} deg");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Check = Check_AtReport();
        Assert_True(_Turns.Num() == 1 && _Turns[0] == utils_cutting::k_TurnDegrees, f"the client raised one turn of 90 (got {_Turns.Num()})");
        Assert_True(Get_IsAtReport(Check), f"the client's whole food stands at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"turns={_Turns.Num()} {Describe_Check(Check)}");
        End_Client();
    }
}
