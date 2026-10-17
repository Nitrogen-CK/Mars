// The pack-fit rule on the production pawn: crouched without a pack the capsule is 105 cm (half height 52.5); with a
// backpack in the hotbar's backpack slot it is 140 cm (70), over a 130 cm crawl gap's lintel, so the pack does not pass;
// taking the pack off brings the 105 cm crouch back. Isolated origin (-230000, 230000, 8000).
class UMars_AutoTest_PackFit_WornPackRaisesTheCrouch : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-230000.0, 230000.0, 8000.0);

    // The Warrens crawl gaps' lintel (Tools/LevelDesign/anchor_plans/build_warrens.py CRAWL_HEIGHT).
    private const float64 k_CrawlLintelCm = 130.0;

    private FCk_Handle _PackEntity;
    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_Hotbar _Hotbar;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("spawn a backpack on the floor beside the pawn", n"Step_SpawnPack");
        Add_Step_WaitUntil("the pack is constructed and its item linked", n"Check_PackReady", k_SlowPolls, 0);
        Add_Step("no pack: crouch", n"Step_Crouch");
        Add_Step_WaitUntil("crouched at 105 cm", n"Check_CrouchedWithoutPack", k_SlowPolls, 0);
        Add_Step("stand, then put the pack in the backpack slot", n"Step_StandAndWearPack");
        Add_Step_WaitUntil("standing and wearing the pack", n"Check_StandingAndWearing", k_SlowPolls, 0);
        Add_Step("wearing the pack: crouch", n"Step_Crouch");
        Add_Step_WaitUntil("crouched at 140 cm", n"Check_CrouchedWithPack", k_SlowPolls, 0);
        Add_Step("the crouch with a pack does not fit under a crawl gap's lintel; stand and take the pack off", n"Step_AssertTooTallAndTakeOff");
        Add_Step_WaitUntil("standing and not wearing the pack", n"Check_StandingAndNotWearing", k_SlowPolls, 0);
        Add_Step("no pack again: crouch", n"Step_Crouch");
        Add_Step_WaitUntil("crouched at 105 cm again", n"Check_CrouchedWithoutPack", k_SlowPolls, 0);
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    // After the pawn is linked: spawned in the same frame as the pawn, the pack's construction raced the pawn's bridge.
    UFUNCTION()
    private void Step_SpawnPack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(150.0, 0.0, 30.0));
        // A loose item lives under the world's transient entity, as the WorldItem tests spawn theirs; tracked for cleanup.
        _PackEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_Backpack_EntityScript, PackParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_PackEntity);
    }

    private bool Get_Crouched(float64 InHalfHeight)
    {
        return _Pawn.bIsCrouched && Math::IsNearlyEqual(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), InHalfHeight, 0.01);
    }

    private bool Get_Wearing()
    {
        return ck::IsValid(_Hotbar) && _Hotbar.Get_IsWearingBackpack();
    }

    private void Transfer(FCk_Handle_Inventory_DataOnly InFrom, FCk_Handle_Inventory_DataOnly InTo)
    {
        if (ck::Is_NOT_Valid(InFrom) || ck::Is_NOT_Valid(InTo) || ck::Is_NOT_Valid(_Pack))
        {
            FinishFailure("a pack transfer needs a source, a target and the pack");
            return;
        }

        auto From = InFrom;
        From.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Pack.Get_Item(), InTo),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferAnswered"));
    }

    UFUNCTION()
    private void OnTransferAnswered(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { FinishFailure(f"the pack transfer failed with [{InResult :n}]"); }
    }

    UFUNCTION()
    private void Check_PackReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = ck::IsValid(_PackEntity) && _PackEntity.Is_WorldItem() && ck::IsValid(_PackEntity.As_WorldItem().Get_Item());
        if (Ready && ck::Is_NOT_Valid(_Pack))
        {
            _Pack = _PackEntity.As_WorldItem();
            _Hotbar = _Player.As_Hotbar();
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_Crouch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Pawn.Crouch();
    }

    UFUNCTION()
    private void Check_CrouchedWithoutPack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Wearing() == false && Get_Crouched(mars::Mars_PlayerCharacter_Config.Body.CrouchedHalfHeight));
    }

    UFUNCTION()
    private void Step_StandAndWearPack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), 52.5, 0.01, "no pack: the crouched capsule is 105 cm");
        _Pawn.UnCrouch();
        Transfer(_Pack.Get_Holder(), _Hotbar.Get_BackpackSlot());
    }

    UFUNCTION()
    private void Check_StandingAndWearing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pawn.bIsCrouched == false && Get_Wearing());
    }

    UFUNCTION()
    private void Check_CrouchedWithPack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Wearing() && Get_Crouched(mars::Mars_PlayerCharacter_Config.Body.CrouchedHalfHeightWithPack));
    }

    UFUNCTION()
    private void Step_AssertTooTallAndTakeOff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto CrouchedTop = 2.0 * _Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight();
        Assert_Equals_Float(CrouchedTop, 140.0, 0.01, "wearing the pack: the crouched capsule is 140 cm");
        Assert_True(CrouchedTop > k_CrawlLintelCm, f"the crouch with a pack ({CrouchedTop} cm) is taller than a crawl gap ({k_CrawlLintelCm} cm)");
        Assert_True(2.0 * float64(mars::Mars_PlayerCharacter_Config.Body.CrouchedHalfHeight) < k_CrawlLintelCm,
            "the crouch without a pack fits under a crawl gap");

        _Pawn.UnCrouch();
        Transfer(_Hotbar.Get_BackpackSlot(), _Pack.Get_Holder());
    }

    UFUNCTION()
    private void Check_StandingAndNotWearing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pawn.bIsCrouched == false && Get_Wearing() == false);
    }
}

class AMars_AutoTest_PackFit_WornPackRaisesTheCrouch_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PackFit_WornPackRaisesTheCrouch;
}
