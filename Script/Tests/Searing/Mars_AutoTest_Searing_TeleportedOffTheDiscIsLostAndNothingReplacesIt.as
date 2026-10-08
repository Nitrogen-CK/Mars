// A piece teleported beyond the pan (pan-local (PanRadius + 2 HalfSize, 0, 20): outside the lip, over the void) is lost
// once: the summary counts it, its Id still answers Lost while its body lingers and falls, the body is destroyed after
// LingerSeconds and the Id is then gone; nothing is ever added in its place.
class UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    // Watched after the loss for a replacement (a respawn used to follow in 0.2 s).
    private const float32 k_NoReplacementSeconds = 1.5f;

    private FCk_Handle _FirstPiece;
    private float32 _LostTime = -1.0f;
    private float32 _LingeredSeconds = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("heat the pan", n"Step_Heat");
        Add_Steps_AddPieceAndLand();
        Add_Step("teleport the piece off the disc", n"Step_TeleportOff");
        Add_Step_WaitUntil("the piece was lost", n"Check_Lost1", 0, 1.0f);
        Add_Step("the piece is lost and its body lingers", n"Step_AssertLost");
        Add_Step_WaitUntil("the lost body was destroyed", n"Check_LostDestroyed", 0, 1.5f);
        Add_Step("the Id is gone with the body", n"Step_AssertDestroyed");
        Add_Step_WaitUntil("the no-replacement window passed", n"Check_WindowPassed", 0, 2.0f);
        Add_Step("nothing replaced the piece", n"Step_AssertNothingReplaced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportOff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstPiece = _Searing.Get_PieceEntity(Get_FirstId());
        Assert_True(ck::IsValid(_FirstPiece), "a piece rests on the pan");

        // On the pan implies the body exists in the simulation; a teleport before that does nothing.
        auto Body = _Searing.Get_PieceBody(Get_FirstId());
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the piece's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Location = PanBaseWorld.TransformPosition(FVector(_Spec.Loss.PanRadius + 2.0 * _Spec.Steak.HalfSize, 0.0, 20.0));
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, PanBaseWorld.Rotator()));
    }

    UFUNCTION()
    private void Step_AssertLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LostTime = Get_Now();
        const auto PieceId = Get_FirstId();

        Assert_Equals_Int(_Lost.Num(), 1, "OnPieceLost fired once");
        if (_Lost.Num() > 0)
        {
            Assert_True(_LostIds[0].Get_IsSame(PieceId), "OnPieceLost names the teleported piece");
            Assert_True(_Lost[0] == _FirstPiece, "the lost entity is the one that was teleported");
            Assert_True(ck::IsValid(_Lost[0]), "the lost piece is still live while it lingers");
        }

        Assert_True(_Searing.Get_HasPiece(PieceId), "the lingering piece is still on the books");
        const auto Status = _Searing.Get_PieceStatus(PieceId);
        Assert_True(Status == EMars_Searing_PieceStatus::Lost, f"its Id answers Lost (got {Status :n})");

        Assert_Equals_Int(_Searing.Get_Tally().Losses, 1, "one loss counted");
        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Lost, 1, "the summary counts one lost");
        Assert_Equals_Int(Summary.Cooking, 0, "nothing cooks");
        Assert_Equals_Int(Summary.Admitted, 1, "one piece admitted");
    }

    UFUNCTION()
    private void Step_AssertDestroyed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LingeredSeconds = Get_Now() - _LostTime;
        ck::Trace(f"[Searing] lost piece lingered {_LingeredSeconds :.3} s (LingerSeconds {_Spec.Loss.LingerSeconds})");
        Assert_True(_LingeredSeconds >= _Spec.Loss.LingerSeconds - 0.1f,
            f"the body lingered about LingerSeconds before it was destroyed ({_LingeredSeconds :.3} s)");

        Assert_False(_Searing.Get_HasPiece(Get_FirstId()), "the destroyed piece left the books");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "the pan is empty");
        Assert_Equals_Int(_Searing.Get_Summary().Lost, 1, "a destroyed lost piece stays counted");
    }

    UFUNCTION()
    private void Check_WindowPassed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Now() - _LostTime >= k_NoReplacementSeconds);
    }

    UFUNCTION()
    private void Step_AssertNothingReplaced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Added.Num(), 1, f"no second OnPieceAdded within {k_NoReplacementSeconds} s of the loss");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "the pan stays empty");
        Assert_Equals_Int(_Lost.Num(), 1, "no second loss");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Admitted, 1, "still one piece admitted");
        Assert_Equals_Int(Summary.Lost, 1, "still one lost");
    }
}

class AMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt;
}
