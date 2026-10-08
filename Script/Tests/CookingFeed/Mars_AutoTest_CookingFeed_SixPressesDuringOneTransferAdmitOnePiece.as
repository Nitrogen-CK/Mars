// Six add-food presses inside one transfer (three in the drain that starts it, three a frame later) start ONE transfer: the
// other five are refused Busy, never deferred. One release follows; accepted, the hand returns and the platter has spent
// exactly one piece.
class UMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece : UMars_AutoTestRig_CookingFeed
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());

        Add_Step("press add food three times in one drain", n"Step_PressThrice");
        Add_Step("press three more times while the hand reaches", n"Step_PressThrice");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("five refusals, one release; accept it", n"Step_AssertOneTransferAndAccept");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 2.0f);
        Add_Step("one piece admitted, five left", n"Step_AssertOnePieceAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PressThrice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin();
        Begin();
        Begin();
    }

    UFUNCTION()
    private void Step_AssertOneTransferAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Refusals.Num(), 5, "five presses were refused");
        Assert_Equals_Int(Get_RefusalCount(EMars_CookingFeed_Refusal::Busy), 5, "every refusal was Busy");
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Reach), 1, "one reach");
        Assert_Ledger(k_Stock - 1, 0, "awaiting admission");

        Step_AcceptPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertOnePieceAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 1, "after the return");
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "it settled Admitted");
        Assert_Equals_Int(_Releases.Num(), 1, "still one release");
        Assert_Equals_Int(_Refusals.Num(), 5, "no press was replayed once idle");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");
    }
}
