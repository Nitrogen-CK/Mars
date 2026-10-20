// The held visual's two one-shot start poses: with both a NextArrival for the item and a NextSpawnFrom waiting, the
// SpawnFrom wins - the visual spawns at that pose and keeps its offset from the hand (no arrival lerp toward HeldOffset).
// A ClearNextSpawnFrom queued in the same frame as a SetNextSpawnFrom drops it whatever the drain order: the next
// visual spawns at HeldOffset. A bare carrier (Hand node, a hotbar of two bag slots, HeldItem); rock items.
// Isolated origin (54800, -14000, -30000).
class UMars_AutoTest_HeldItem_SpawnFromWinsOverArrivalAndClearDropsIt : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -14000.0, -30000.0);

    // Hand space: where the pickup pose sits relative to the hand when the visual spawns, and where the arrival would
    // have started (far from both it and HeldOffset).
    private const FVector k_SpawnFromInHand = FVector(15.0, -8.0, 4.0);
    private const FVector k_ArrivalInHand = FVector(-60.0, 40.0, -30.0);

    private FCk_Handle _FirstVisual;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("ask for an arrival and a spawn-from pose, then stow the rock", n"Step_PosesThenStow");
        Add_Step_WaitUntil("the rock's held visual is composed", n"Check_VisualComposed", 0, 0);
        Add_Step("the visual sits at the spawn-from pose, not lerping from the arrival", n"Step_AssertSpawnFrom");
        Add_Step("deselect", n"Step_Deselect");
        Add_Step_WaitUntil("the hands are empty", n"Check_HandsEmptied", 0, 0);
        Add_Step("ask for a spawn-from pose and clear it in one frame, then select again", n"Step_SetClearThenSelect");
        Add_Step_WaitUntil("a new held visual is composed", n"Check_SecondVisualComposed", 0, 0);
        Add_Step("the visual sits at HeldOffset", n"Step_AssertHeldOffset");
        Run_Steps(InHandle);
    }

    private FTransform Get_HandWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_HandNode);
    }

    private FTransform Get_HeldOffset() const
    {
        const UMars_ItemTrait_Presentation Presentation = _Items[0].Get_Presentation();
        return Presentation.Mounting.HeldOffset;
    }

    // The held visual's node offset from the hand; unset while the visual is not composed.
    private TOptional<FTransform> TryGet_VisualOffset() const
    {
        auto Node = _HeldItem.Get_PresentationEntity().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return TOptional<FTransform>(); }

        return TOptional<FTransform>(utils_scene_node::Get_Offset(Node));
    }

    UFUNCTION()
    private void Step_PosesThenStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HandWorld = Get_HandWorld();
        const auto ArrivalWorld = FTransform(FRotator::ZeroRotator, k_ArrivalInHand) * HandWorld;
        const auto SpawnFromWorld = FTransform(FRotator::ZeroRotator, k_SpawnFromInHand) * HandWorld;
        _HeldItem.Request_SetNextArrival(FMars_Request_HeldItem_SetNextArrival(_Items[0], ArrivalWorld));
        _HeldItem.Request_SetNextSpawnFrom(FMars_Request_HeldItem_SetNextSpawnFrom(SpawnFromWorld));
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_VisualComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0] && TryGet_VisualOffset().IsSet());
    }

    UFUNCTION()
    private void Step_AssertSpawnFrom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstVisual = _HeldItem.Get_PresentationEntity();
        const auto Offset = TryGet_VisualOffset().GetValue().GetLocation();
        Assert_True(Offset.Equals(k_SpawnFromInHand, 0.5), f"the visual keeps the spawn-from pose's offset {k_SpawnFromInHand} (got {Offset})");
        Assert_False(Offset.Equals(Get_HeldOffset().GetLocation(), 0.5), "the visual is not at HeldOffset: the spawn-from pose won");
        Assert_False(Offset.Equals(k_ArrivalInHand, 0.5), "the visual is not at the arrival pose: the arrival lost");
    }

    UFUNCTION()
    private void Step_Deselect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Deselect(FMars_Request_Hotbar_Deselect());
    }

    UFUNCTION()
    private void Check_HandsEmptied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void Step_SetClearThenSelect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto SpawnFromWorld = FTransform(FRotator::ZeroRotator, k_SpawnFromInHand) * Get_HandWorld();
        _HeldItem.Request_SetNextSpawnFrom(FMars_Request_HeldItem_SetNextSpawnFrom(SpawnFromWorld));
        _HeldItem.Request_ClearNextSpawnFrom(FMars_Request_HeldItem_ClearNextSpawnFrom());
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Check_SecondVisualComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0] && _HeldItem.Get_PresentationEntity() != _FirstVisual
            && TryGet_VisualOffset().IsSet());
    }

    UFUNCTION()
    private void Step_AssertHeldOffset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Offset = TryGet_VisualOffset().GetValue().GetLocation();
        const auto Held = Get_HeldOffset().GetLocation();
        Assert_True(Offset.Equals(Held, 0.5), f"the cleared spawn-from pose left the visual at HeldOffset {Held} (got {Offset})");
    }
}
