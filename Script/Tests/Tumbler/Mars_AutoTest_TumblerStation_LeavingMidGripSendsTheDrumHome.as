// Leaving the tumbler station mid-grip lets the lever go. The operator rig's carrier takes the real tumbler station through
// its Use interaction, looks its hand onto the lever and grips it with a Use press, then rocks the drum off home with its
// look while still holding Use. Back leaves the station with Use still held: the station goes Idle, leaving cancels the
// grip, the hand is free and the drum returns home. Isolated origin (205000, -82000, -30000).
class UMars_AutoTest_TumblerStation_LeavingMidGripSendsTheDrumHome : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(205000.0, -82000.0, -30000.0);
    // Behind the stand, facing the counter.
    private const FVector k_CarrierLocal = FVector(-115.0, 0.0, 0.0);
    // Degrees of look pitch per rocking frame (down is +).
    private const float32 k_RockDegrees = 4.0f;
    // A poll budget, not a ceiling: the station composes, the hand reaches and the drum returns over seconds.
    private const int32 k_SlowPolls = 900;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Tumbler, k_Origin, k_CarrierLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Tumbler, feed and docks and its shell is in the simulation", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 0);
        Add_Step("look at the lever", n"Step_LookToLever");
        Add_Step_WaitUntil("the lever is hovered", n"Check_HoveredLever", k_SlowPolls, 0);
        Add_Step("press Use on the lever", n"Step_PressUse");
        Add_Step_WaitUntil("the lever is gripped", n"Check_Gripped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the look rocks the drum off home", n"Check_RockedOffHome", k_SlowPolls, 0);
        Add_Step("leave with Back, Use still held", n"Step_PressBack");
        Add_Step_WaitUntil("the station is Idle, the hand free and the drum home", n"Check_IdleFreeAndHome", k_SlowPolls, 0);
        Add_Step("release Use and Back", n"Step_ReleaseKeys");
        Add_Step("the grip ended with the operator", n"Step_Assert");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_Operated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated());
    }

    // One look on the carrier's intents that puts the kernel's cursor on the lever grip's projection on the reach plane.
    UFUNCTION()
    private void Step_LookToLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Tumbler.Get_Spec();
        const auto AnchorLocal = _Tumbler.Get_RootWorld().InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(Spec.Nodes.LeverGrip));
        const auto Centre = Spec.Hand.WorkspaceCentreLocal;
        const auto Delta = FVector2D(AnchorLocal.Y - Centre.Y, AnchorLocal.Z - Centre.Z) - _Tumbler.Get_Cursor();
        const auto Step = float64(Spec.Hand.CmPerLookDegree);
        Add_LookDelta(FVector(Delta.X / Step, -Delta.Y / Step, 0.0));
    }

    UFUNCTION()
    private void Check_HoveredLever(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Hovered() == EMars_Tumbler_Target::Lever);
    }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped);
    }

    UFUNCTION()
    private void Check_RockedOffHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Math::Abs(_Tumbler.Get_DrumDegrees()) > 1.0f)
        {
            Res.Set(true);
            return;
        }

        Add_LookDelta(FVector(0.0, float64(k_RockDegrees), 0.0));
        Res.Set(false);
    }

    UFUNCTION()
    private void Step_PressBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Use), "Use is still held");
        Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped, "the drum is gripped");
        Press_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_IdleFreeAndHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationIdle() && _Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Free && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home);
    }

    UFUNCTION()
    private void Step_ReleaseKeys(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Use);
        Release_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Free, "the hand is free");
        Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home, "the drum is home");
        Assert_False(_Station.Get_IsOperated(), "nobody operates the station");
    }
}
