// The fry station's control layer on the operator's own keys. The operator rig's carrier holds Interact_Primary before it
// takes the real fry station through its Use interaction: taking it drives the skimmer from the first frame, and the hold
// from before the take is no press (the reader seeds on enter), so the skimmer, parked over the oil, still carries.
// Released and pressed again, the press dips it; released, it carries. The carrier's look then steers the skimmer over the
// drain basket; a press there pours and the release levels it again. No skim was refused. Isolated origin (202000,
// -82000, -30000).
class UMars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(202000.0, -82000.0, -30000.0);
    // Behind the stand, facing the vat.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    // A poll budget, not a ceiling: the station composes and the skimmer travels.
    private const int32 k_SlowPolls = 900;

    private TArray<EMars_Fry_Skim> _SkimRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Fry, k_Origin, k_CarrierLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Step("watch the kernel's skim refusals", n"Step_Watch");
        Add_Step("hold Interact_Primary before taking the station", n"Step_PressPrimary");
        Add_Step_WaitUntil("Interact_Primary is held", n"Check_PrimaryHeld", 0, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station is Operated and the skimmer is driven", n"Check_OperatedAndDriven", 0, 0);
        Add_Step("the hold from before the take asked nothing of the kernel", n"Step_AssertNoPressYet");
        Add_Step("release Interact_Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("Interact_Primary is released", n"Check_PrimaryReleased", 0, 0);
        Add_Step("press Interact_Primary at the park", n"Step_PressPrimary");
        Add_Step_WaitUntil("the skimmer dips", n"Check_Dipped", k_SlowPolls, 0);
        Add_Step("release Interact_Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the skimmer carries again and has risen clear of the rim", n"Check_CarryingClear", k_SlowPolls, 0);
        Add_Step("look the skimmer over the basket's centre", n"Step_LookToTheBasket");
        Add_Step_WaitUntil("the scoop is over the basket", n"Check_ScoopOverBasket", k_SlowPolls, 0);
        Add_Step("press Interact_Primary over the basket", n"Step_PressPrimary");
        Add_Step_WaitUntil("the skimmer pours", n"Check_Pouring", k_SlowPolls, 0);
        Add_Step("release Interact_Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the skimmer carries again", n"Check_Carrying", k_SlowPolls, 0);
        Add_Step("no skim was refused and the skimmer is still driven", n"Step_Assert");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_Watch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fry.BindTo_OnSkimRefused(FMars_Delegate_Fry_OnSkimRefused(this, n"OnSkimRefused"));
    }

    UFUNCTION()
    private void Step_PressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_ReleasePrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Check_PrimaryHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary));
    }

    UFUNCTION()
    private void Check_PrimaryReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary) == false);
    }

    UFUNCTION()
    private void Check_OperatedAndDriven(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated() && _Fry.Get_Drive() == EMars_Implement_Drive::Driven);
    }

    UFUNCTION()
    private void Step_AssertNoPressYet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary), "Interact_Primary is still held");
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Carry, "the skimmer carries");
        Assert_Equals_Int(_SkimRefusals.Num(), 0, "no skim reached the kernel");
        Assert_True(_Fry.Get_IsScoopInPot(), "the skimmer is parked over the oil (a press there dips)");
    }

    // One look, sized by the reach's CmPerLookDegree, from the skimmer's target to the basket's centre.
    UFUNCTION()
    private void Step_LookToTheBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Delta = _Fry.Get_Spec().Reach.BasketCentre - _Fry.Get_SkimmerTarget();
        const auto Step = float64(_Fry.Get_Spec().Reach.CmPerLookDegree);
        Add_LookDelta(FVector(Delta.Y / Step, -Delta.X / Step, 0.0));
    }

    UFUNCTION()
    private void Check_ScoopOverBasket(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_IsScoopOverBasket());
    }

    UFUNCTION()
    private void Check_Pouring(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Pour);
    }

    UFUNCTION()
    private void Check_CarryingClear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Carry && _Fry.Get_IsScoopClearOfRim());
    }

    UFUNCTION()
    private void Check_Dipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Dip);
    }

    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Carry);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SkimRefusals.Num(), 0, "no skim was refused: the park dips, the basket pours");
        Assert_True(_Fry.Get_Drive() == EMars_Implement_Drive::Driven, "the skimmer is still driven");
        Assert_True(_Station.Get_IsOperatedBy(_Carrier), "the carrier still operates the station");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnSkimRefused(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        _SkimRefusals.Add(InSkim);
    }
}
