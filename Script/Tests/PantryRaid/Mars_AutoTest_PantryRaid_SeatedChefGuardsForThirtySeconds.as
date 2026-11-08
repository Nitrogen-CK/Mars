// R05 (player guards backpack). A chef sits 150 cm from the grounded cheese pack for 30 s of the raid's own clock (the
// fixture clock: global time dilation 4, so about 7.5 s of wall time). Both residents emerge and stay out, but no lease is
// granted, no claim transfer is ever issued, both low pockets keep their items, and no rat ever comes within the avoidance
// radius (300 cm) of the chef: they watch from outside it.
class UMars_AutoTest_PantryRaid_SeatedChefGuardsForThirtySeconds : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private const float32 k_Dilation = 4.0f;
    private const float32 k_GuardSeconds = 30.0f;
    private float32 _OriginalDilation = 1.0f;
    private float32 _GuardStartedAt = 0.0f;
    private float64 _NearestRatToChef = 1.0e9;
    private bool _Watching = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(640000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("both residents are out", n"Check_TwoRats", k_LongPolls, 0);
        Add_Step("start the 30 s guard on the fixture clock", n"Step_StartGuard");
        Add_Step_WaitUntil("30 s of raid clock passed", n"Check_GuardDone", k_LongPolls, 50.0f);
        Add_Step("no lease, no claim, nothing moved, no rat inside the chef's avoidance", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Watching == false)
        { return; }

        for (auto Rat : Get_Rats())
        { _NearestRatToChef = Math::Min(_NearestRatToChef, utils_pantry_raid::Get_PlanarDistance(Rat.Get_Location(), Get_ChefLocation(0))); }
    }

    UFUNCTION()
    private void Check_TwoRats(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Raid) && Get_Rats().Num() == 2);
    }

    UFUNCTION()
    private void Step_StartGuard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _GuardStartedAt = _Raid.Get_Clock();
        _OriginalDilation = Gameplay::GetGlobalTimeDilation();
        Gameplay::SetGlobalTimeDilation(k_Dilation);
        _Watching = true;
    }

    UFUNCTION()
    private void Check_GuardDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_Clock() - _GuardStartedAt >= k_GuardSeconds);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Gameplay::SetGlobalTimeDilation(_OriginalDilation);
        _Watching = false;

        Assert_Equals_Int(_Raid.Get_LeasesGranted(), 0, "no lease in 30 s of guard");
        auto Issued = 0;
        for (auto Rat : Get_Rats())
        {
            Issued += Rat.Get_ClaimTransfersIssued();
            Assert_False(Rat.Get_IsLoaded(), "no rat holds anything");
        }
        Assert_Equals_Int(Issued, 0, "no claim transfer was ever issued");
        Assert_True(Get_Slot(1).Get_Item() == _CheeseItem && Get_Slot(2).Get_Item() == _FoodItem, "both low pockets keep their items");
        Assert_True(_NearestRatToChef >= float64(_Spec.Guard.AvoidEnterCm),
            f"no rat came within the chef's avoidance radius (nearest {_NearestRatToChef} cm)");
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        Assert_True(Record.IsSet() && Record.GetValue().Guarded, "the pack is still Guarded");
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (_Watching)
        { Gameplay::SetGlobalTimeDilation(_OriginalDilation); }

        Super::DoEndPlay(InHandle);
    }
}
