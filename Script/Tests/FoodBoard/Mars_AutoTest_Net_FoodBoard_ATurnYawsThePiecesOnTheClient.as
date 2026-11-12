// The server places the slab, cuts it through the station root along world X and, once quiet, reports the halves; 1.5 s
// later it turns the board 90 degrees and, once quiet, reports again: each half's root is its first root turned 90
// degrees about the station root. On the client the standing pieces are at each step's report, and the turn is raised
// there once, 90 degrees.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ATurnYawsThePiecesOnTheClient
class UCk_AutoTest_Net_FoodBoard_ATurnYawsThePiecesOnTheClient : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 202000.0;
    private const float32 k_TurnDegrees = 90.0f;

    // In parallel: the server's held pieces at step 1, their roots and yaws.
    private TArray<FCk_Handle_FoodPiece> _Step1Pieces;
    private TArray<FVector> _Step1Locations;
    private TArray<float64> _Step1Yaws;
    private FMars_TESTONLY_NetBoardPoseCheck _ClientStep1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
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
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        Await_ServerQuiet(1, 0, n"OnServerCutQuiet");
    }

    UFUNCTION()
    private void OnServerCutQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        _Step1Pieces = _Board.Get_Held();
        for (const auto& Piece : _Step1Pieces)
        {
            _Step1Locations.Add(Get_RootLocation(Piece));
            _Step1Yaws.Add(Get_RootYaw(Piece));
        }

        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerTurn");
    }

    UFUNCTION()
    private void OnServerTurn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(k_TurnDegrees));
        Await_ServerQuiet(1, 1, n"OnServerTurnQuiet");
    }

    UFUNCTION()
    private void OnServerTurnQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(2);
        const auto Pivot = Get_StationRootLocation();
        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(float64(k_TurnDegrees)));
        auto WorstCm = 0.0;
        auto WorstDegrees = 0.0;
        for (int32 Index = 0; Index < _Step1Pieces.Num(); ++Index)
        {
            const auto Expected = Pivot + Yaw.RotateVector(_Step1Locations[Index] - Pivot);
            WorstCm = Math::Max(WorstCm, (Get_RootLocation(_Step1Pieces[Index]) - Expected).Size());
            const auto ExpectedYaw = _Step1Yaws[Index] + float64(k_TurnDegrees);
            WorstDegrees = Math::Max(WorstDegrees, Math::Abs(Math::FindDeltaAngleDegrees(Get_RootYaw(_Step1Pieces[Index]), ExpectedYaw)));
        }

        Assert_Equals_Int(_Step1Pieces.Num(), 2, "the server turned the two halves");
        Assert_True(WorstCm <= constants_foodboard_net_autotest::k_ServerToleranceCm, f"each half's root turned about the station root (worst {WorstCm} cm)");
        Assert_True(WorstDegrees <= constants_foodboard_net_autotest::k_ServerToleranceDegrees, f"each half's yaw turned 90 degrees (worst {WorstDegrees} deg)");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"pieces={_Step1Pieces.Num()} worst {WorstCm} cm {WorstDegrees} deg");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientStep1 = Check_AtReport();
        Assert_True(Get_IsAtReport(_ClientStep1), f"step 1: the client's pieces stand at the report ({Describe_Check(_ClientStep1)})");
        Await_ClientStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Check = Check_AtReport();
        Assert_True(Get_IsAtReport(Check), f"step 2: the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_True(_Turns.Num() == 1 && _Turns[0] == k_TurnDegrees, f"the client raised one turn of 90 (got {_Turns.Num()})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"step1 {Describe_Check(_ClientStep1)}; step2 {Describe_Check(Check)}; turns={_Turns.Num()}");
        End_Client();
    }
}
