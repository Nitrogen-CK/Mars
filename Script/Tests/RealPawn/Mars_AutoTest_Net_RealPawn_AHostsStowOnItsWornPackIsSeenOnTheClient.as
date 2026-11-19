// The host's own production pawn (possessed by the server's local controller) picks up a backpack, which it then wears,
// picks up a rock and stows it in the pack's cargo slot 0 (the slot's Act, as its interaction asks). The client, standing
// beside it in a pawn of its own, sees its copy of the pack Carried on the host's Back, slot 0 holding the rock and the
// slot's cargo visual on the pack.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AHostsStowOnItsWornPackIsSeenOnTheClient
class UCk_AutoTest_Net_RealPawn_AHostsStowOnItsWornPackIsSeenOnTheClient : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(912000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsStowOnItsWornPackIsSeenOnTheClient";
    private const FVector k_RockFromBase = FVector(120.0, 150.0, 20.0);
    // The cargo visual sits on the pack: its root within this of the pack's.
    private const float64 k_OnPackCm = 100.0;

    private FCk_Handle_WorldItem _PackItem;
    private FCk_Handle_WorldItem _RockItem;
    private FCk_Handle_CargoSlot _Slot0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            Mark_Deadline(24.0);
            WaitUntil(n"Is_ClientSeesTheStow", n"OnClientChecked", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        Spawn_ServerJoltFloor(InHandle);
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one local player controller"); return; }

        Spawn_ServerWorldItem(mars_items::Backpack(), _Base + k_ItemFromBase);
        Spawn_ServerWorldItem(mars_items::Rock(), _Base + k_RockFromBase);
        Mark_Deadline(18.0);
        WaitUntil(n"Is_ServerReadyToPickUpThePack", n"OnServerReadyToPickUpThePack", k_SlowPolls);
    }

    // The host's copy is locally controlled and idle in Locomotion, its hotbar is ready, and the pack has adopted its slots.
    UFUNCTION()
    private void Is_ServerReadyToPickUpThePack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PackItem = Find_WorldItemNear(mars_items::Backpack(), _Base + k_ItemFromBase, 100.0);
        _RockItem = Find_WorldItemNear(mars_items::Rock(), _Base + k_RockFromBase, 100.0);
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        FCk_Handle PackEntity = _PackItem;
        const auto IsReady = _Pawn.IsLocallyControlled() && Get_IsStateActive(UMars_SmState_Loco_Idle) && ck::IsValid(Hotbar)
            && Hotbar.Get_IsReady() && ck::IsValid(_PackItem) && ck::IsValid(_RockItem) && PackEntity.As_Backpack().Get_IsReady();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsReady);
    }

    UFUNCTION()
    private void OnServerReadyToPickUpThePack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"pack={ck::IsValid(_PackItem)} rock={ck::IsValid(_RockItem)}");
            FinishFailure("the host's pawn, its hotbar, the pack or the rock was not ready on the server");
            return;
        }

        _PackItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        WaitUntil(n"Is_ServerWearingThePack", n"OnServerWearingThePack", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerWearingThePack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (_Player.As_Hotbar().Get_IsWearingBackpack() && _PackItem.Get_Mount() == EMars_WorldItem_Mount::Carried));
    }

    UFUNCTION()
    private void OnServerWearingThePack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"wearing={_Player.As_Hotbar().Get_IsWearingBackpack()} packMount={_PackItem.Get_Mount() :n}");
            FinishFailure("the host's pawn did not come to wear the pack it picked up");
            return;
        }

        _RockItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        WaitUntil(n"Is_ServerHoldingTheRock", n"OnServerHoldingTheRock", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldingTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsHolding(mars_items::Rock()));
    }

    UFUNCTION()
    private void OnServerHoldingTheRock(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, "holding=false");
            FinishFailure("the host's pawn did not come to hold the rock it picked up");
            return;
        }

        FCk_Handle PackEntity = _PackItem;
        _Slot0 = PackEntity.As_Backpack().Get_CargoSlot(0);
        utils_cargo_slot::Request_ActFor(_Slot0, _Player, EMars_CargoSlot_Action::Stow);
        WaitUntil(n"Is_ServerStowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsDefinition(_Slot0.Get_Item(), mars_items::Rock()));
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsStowed = Get_IsDefinition(_Slot0.Get_Item(), mars_items::Rock());
        Log_RealPawnRow(k_Row, f"stowed={IsStowed} refusal={_Slot0.Get_LastRefusal() :n}");
        Assert_True(IsStowed, f"the host's stow put the rock in the worn pack's slot 0 on the server (last refusal {_Slot0.Get_LastRefusal() :n})");
        WaitSeconds(k_ServerHoldSeconds + 3.0f, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientSeesTheStow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Find_ClientPack();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (ck::IsValid(_Slot0) && Get_IsDefinition(_Slot0.Get_Item(), mars_items::Rock())
            && ck::IsValid(_Slot0.Get_Visual())));
    }

    // The client's copy of the pack Carried by its copy of the host's player, and that pack's slot 0 once it is ready.
    private void Find_ClientPack()
    {
        if (Get_IsPawnComposed() == false)
        { return; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Candidate.Is_Backpack() == false || Candidate.Is_WorldItem() == false)
            { continue; }

            auto WorldItem = Candidate.As_WorldItem();
            if (WorldItem.Get_Carrier() != _Player)
            { continue; }

            _PackItem = WorldItem;
            const auto Pack = Candidate.As_Backpack();
            if (Pack.Get_IsReady())
            { _Slot0 = Pack.Get_CargoSlot(0); }

            return;
        }
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasPack = ck::IsValid(_PackItem);
        const auto IsOnBack = HasPack && _PackItem.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _PackItem.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Back;
        const auto HoldsRock = ck::IsValid(_Slot0) && Get_IsDefinition(_Slot0.Get_Item(), mars_items::Rock());
        const auto Visual = ck::IsValid(_Slot0) ? _Slot0.Get_Visual() : FCk_Handle();
        auto VisualFromPack = -1.0;
        if (ck::IsValid(Visual) && HasPack)
        { VisualFromPack = (Get_RootLocation(Visual) - Get_RootLocation(_PackItem)).Size(); }

        Log_RealPawnRow(k_Row, f"hostFound={ck::IsValid(_Player)} pack={HasPack} onBack={IsOnBack} slot={ck::IsValid(_Slot0)} holdsRock={HoldsRock} visualFromPack={VisualFromPack :.1}");
        Assert_True(HasPack, "the client has a copy of the pack Carried by its copy of the host's player");
        Assert_True(IsOnBack, "the client's copy of the pack is Carried on the host's Back");
        Assert_True(HoldsRock, "the client's copy of the pack's slot 0 holds the rock");
        Assert_True(VisualFromPack >= 0.0 && VisualFromPack <= k_OnPackCm,
            f"the client shows the stowed rock on the pack (cargo visual {VisualFromPack :.1} cm from the pack; -1: no visual)");
        FinishSuccess();
    }
}
