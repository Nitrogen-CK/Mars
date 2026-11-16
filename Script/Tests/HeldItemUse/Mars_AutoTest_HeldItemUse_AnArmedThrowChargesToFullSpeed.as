// An armed throw charges: a bare carrier (Hand node, a hotbar of two bag slots, HeldItem, HeldItemUse) holding a rock -
//   - unarmed, the charge is 0 and the Throw solution leaves at MinThrowPower of the rock's ThrowSpeed;
//   - armed, the charge climbs: part-way through it, the Throw solution's speed lies between the uncharged and the full
//     speed and matches Get_ThrowPower of ThrowSpeed;
//   - charged full, the power is 1 and the Throw solution leaves at the rock's whole ThrowSpeed;
//   - disarmed, the charge drops back to 0 and the Throw solution to MinThrowPower of ThrowSpeed.
// Nothing is thrown. Isolated origin (61200, -16000, -30000).
class UMars_AutoTest_HeldItemUse_AnArmedThrowChargesToFullSpeed : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(61200.0, -16000.0, -30000.0);

    private FCk_Handle_HeldItemUse _Use;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding", 0, 0);
        Add_Step("unarmed, the throw is uncharged; arm it", n"Step_AssertUnchargedAndArm");
        Add_Step_WaitUntil("the charge is part-way", n"Check_ChargePartWay", 0, 0);
        Add_Step("part-way, the throw's speed follows the power", n"Step_AssertPartWay");
        Add_Step_WaitUntil("the charge is full", n"Check_ChargeFull");
        Add_Step("full, the throw leaves at the whole ThrowSpeed; disarm", n"Step_AssertFullAndDisarm");
        Add_Step_WaitUntil("the charge is back to 0", n"Check_ChargeEmpty", 0, 0);
        Add_Step("disarmed, the throw is uncharged again", n"Step_AssertUncharged");
        Run_Steps(InHandle);
    }

    private const UMars_ItemTrait_Throwable Get_Throwable() const
    {
        return _Items[0].Get_Throwable();
    }

    private float64 Get_ThrowSolutionSpeed()
    {
        const auto Throw = _Use.Get_LaunchSolution(EMars_LaunchKind::Throw);
        Assert_True(Throw.IsSet(), "holding the rock, there is a Throw solution");
        return Throw.IsSet() ? Throw.GetValue().LinearVelocity.Size() : 0.0;
    }

    private void Assert_Uncharged(FString InWhen)
    {
        const auto Throwable = Get_Throwable();
        Assert_Equals_Float(_Use.Get_ThrowCharge(), 0.0f, 0.0001, f"{InWhen}, the charge is 0");
        Assert_Equals_Float(_Use.Get_ThrowPower(), Throwable.MinThrowPower, 0.0001, f"{InWhen}, the power is MinThrowPower");

        const auto Expected = Throwable.ThrowSpeed * Throwable.MinThrowPower;
        const auto Speed = Get_ThrowSolutionSpeed();
        Assert_True(Math::Abs(Speed - Expected) < 0.01, f"{InWhen}, the Throw solution leaves at {Expected} (got {Speed})");
    }

    UFUNCTION()
    private void Check_Holding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_AssertUnchargedAndArm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Throwable().ChargeSeconds > 0.0f, "the rock takes time to charge");
        Assert_Uncharged("unarmed");
        _Use.Request_SetThrowArmed(FMars_Request_HeldItemUse_SetThrowArmed(true));
    }

    UFUNCTION()
    private void Check_ChargePartWay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Charge = _Use.Get_ThrowCharge();
        Res.Set(Charge > 0.0f && Charge < 1.0f);
    }

    UFUNCTION()
    private void Step_AssertPartWay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Throwable = Get_Throwable();
        const auto Power = _Use.Get_ThrowPower();
        Assert_True(Power > Throwable.MinThrowPower && Power < 1.0f,
            f"part-way, the power lies between MinThrowPower {Throwable.MinThrowPower} and 1 (got {Power})");

        const auto Expected = Throwable.ThrowSpeed * Power;
        const auto Speed = Get_ThrowSolutionSpeed();
        Assert_True(Math::Abs(Speed - Expected) < 0.01, f"part-way, the Throw solution leaves at the power's speed {Expected} (got {Speed})");
    }

    UFUNCTION()
    private void Check_ChargeFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Use.Get_ThrowCharge() >= 1.0f);
    }

    UFUNCTION()
    private void Step_AssertFullAndDisarm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Throwable = Get_Throwable();
        Assert_Equals_Float(_Use.Get_ThrowPower(), 1.0f, 0.0001, "charged full, the power is 1");

        const auto Speed = Get_ThrowSolutionSpeed();
        Assert_True(Math::Abs(Speed - Throwable.ThrowSpeed) < 0.01,
            f"charged full, the Throw solution leaves at the rock's ThrowSpeed {Throwable.ThrowSpeed} (got {Speed})");

        _Use.Request_SetThrowArmed(FMars_Request_HeldItemUse_SetThrowArmed(false));
    }

    UFUNCTION()
    private void Check_ChargeEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Use.Get_ThrowArmed() == false && _Use.Get_ThrowCharge() == 0.0f);
    }

    UFUNCTION()
    private void Step_AssertUncharged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Uncharged("disarmed");
    }
}
