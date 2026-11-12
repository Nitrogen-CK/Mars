// The server places the slab, seats the subject and applies the seed; 10 frames later a remote sample carries one sweep
// press (Interact_Secondary). The test station has no output dock, so the sweep has no tray: the board refuses it NoRoom
// and keeps the slab where it was placed, releasing nothing. The client raises the same refusal, its count is 1 and its
// whole food stands at the report.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines
class UCk_AutoTest_Net_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 220000.0;

    private FVector _PlacedLocation;

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

    private bool Get_IsRefusedNoRoomOnce()
    {
        return _ReleaseRefusals.Num() == 1 && _ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NoRoom;
    }

    // Server: InEntity is among the board's held pieces.
    private bool Get_IsHeldByBoard(FCk_Handle InEntity)
    {
        for (const auto& Piece : _Board.Get_Held())
        {
            FCk_Handle PieceEntity = Piece;
            if (PieceEntity == InEntity)
            { return true; }
        }

        return false;
    }

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PlacedLocation = Get_RootLocation(_Rock);
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
        Press_RemoteSweep();
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        const auto MovedCm = (Get_RootLocation(_Rock) - _PlacedLocation).Size();
        const auto IsHeld = _Board.Get_Held().Num() == 1 && Get_IsHeldByBoard(_Rock);
        Assert_True(Get_IsRefusedNoRoomOnce(), f"the server refused the sweep NoRoom once (got [{Describe_Refusals()}])");
        Assert_True(IsHeld, f"the server's board still holds the slab (held {_Board.Get_HeldCount()})");
        Assert_True(MovedCm <= constants_foodboard_net_autotest::k_ServerToleranceCm, f"the slab is where it was placed ({MovedCm} cm off)");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Released), 0, "the server released nothing");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"refusals=[{Describe_Refusals()}] held={_Board.Get_HeldCount()} moved {MovedCm} cm");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Check = Check_AtReport();
        Assert_True(Get_IsRefusedNoRoomOnce(), f"the client raised the NoRoom refusal once (got [{Describe_Refusals()}])");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the client's count is 1");
        Assert_True(Get_IsAtReport(Check), f"the client's whole food stands at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"refusals=[{Describe_Refusals()}] held={_Board.Get_HeldCount()} {Describe_Check(Check)}");
        End_Client();
    }
}
