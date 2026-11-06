// A one-handed item the gloves pick up is drawn on every frame of the hand-off and travels, never jumps: from the frame
// its world item's mesh goes (the holder gave the item up at the Grip) its held visual's mesh is there, starting where the
// item lay, and the visual moves to its hold offset in steps no larger than a fraction of the way (the gloves' carry,
// UMars_Processor_FPHands_Tick). Samples every poll of the grab: a poll with neither mesh is a blink, one with both a
// double, a large step a teleport. A carrier with gloves and a World-mode tallow (one-handed, no grip sockets) on a floor
// in front of it. Isolated origin (23600, -17000, -30000).
class UMars_AutoTest_WorldItem_AOneHandedPickupIsDrawnEveryFrameOfTheGrab : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(23600.0, -17000.0, -30000.0);
    private const FVector k_ItemOffset = FVector(60.0, 0.0, 0.0);
    // The item's construction, its fall onto the floor and the gloves' grab outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    // A body slower than this (cm/s) for k_RestPolls polls in a row lies still.
    private const float64 k_RestSpeed = 2.0;
    private const int32 k_RestPolls = 10;
    // The visual's hold offset is reached when its node offset is within this (cm) of HeldOffset.
    private const float64 k_SettleCm = 0.5;
    // A single poll's travel beyond this fraction of the whole floor-to-hold distance is a jump, not a carry.
    private const float64 k_MaxStepFraction = 0.5;

    private FCk_Handle _ItemEntity;
    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _Item;
    private int32 _RestPolls = 0;

    // The sampler's ledger from the pickup's start to the carry's end.
    private int32 _Polls = 0;
    private int32 _BlinkPolls = 0;
    private int32 _DoublePolls = 0;
    private int32 _VisualPolls = 0;
    private FVector _LayWorld = FVector::ZeroVector;
    private TOptional<FVector> _FirstVisualWorld;
    private TOptional<FVector> _LastVisualWorld;
    private float64 _MaxStepCm = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.3f;
        Spec.Reach.Grab.GripSeconds = 0.3f;
        Spec.Reach.Grab.BackSeconds = 0.3f;
        Add_CarrierHands(Spec);

        const auto FloorTop = k_Origin + k_ItemOffset;
        Spawn_FloorSlab(InHandle, FloorTop);
        auto Owner = InHandle;
        _ItemEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Tallow()), FTransform(FRotator::ZeroRotator, FloorTop + FVector(0.0, 0.0, 10.0))));

        Add_Step_WaitUntil("the tallow is a world item with its body added", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the tallow lies still on the floor", n"Check_ItemAtRest", k_SlowPolls, 0);
        Add_Step("the carrier focuses the tallow's pickup", n"Step_Focus");
        Add_Step_WaitUntil("the pickup's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier reaches for the tallow and picks it up", n"Step_PickUp");
        Add_Step_WaitUntil("the grab ran its course and the visual settled at its hold offset (sampling every poll)", n"Check_GrabDone", k_SlowPolls, 0);
        Add_Step("no poll without a mesh, none with two, no jump", n"Step_AssertDrawnEveryFrame");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ItemReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = TryGet_ConstructedWorldItem(_ItemEntity); }

        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) && utils_jolt_body::Get_IsBodyAdded(_WorldItem.Get_Body()));
    }

    UFUNCTION()
    private void Check_ItemAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsSlow = utils_jolt_body::Get_LinearVelocity(_WorldItem.Get_Body()).Size() < k_RestSpeed;
        _RestPolls = IsSlow ? _RestPolls + 1 : 0;

        auto Res = OutResult;
        Res.Set(_RestPolls >= k_RestPolls);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _WorldItem.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Pickup);
    }

    // What the player's resolver does on a press: the interaction starts, and its pickup task asks the gloves for the reach.
    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _WorldItem.Get_HeldItem();
        _LayWorld = utils_transform::Get_EntityCurrentTransform(_ItemEntity.As_Transform()).GetLocation();
        Assert_True(ck::IsValid(_Item) && _Item.Get_Presentation().Grip.Handedness == EMars_ItemPresentation_Handedness::OneHanded,
            "the tallow is a one-handed item");

        auto Target = _WorldItem.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_GrabDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();

        const auto Gripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        const auto AtRest = _Hands.Get_Phase() == EMars_FPHands_Phase::None;
        const auto Held = ck::IsValid(_Item) && _HeldItem.Get_CurrentItem() == _Item;

        auto Settled = false;
        auto Node = _HeldItem.Get_PresentationEntity().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (Held && ck::IsValid(Node))
        {
            const auto HeldOffset = _Item.Get_Presentation().Mounting.HeldOffset.GetLocation();
            Settled = utils_scene_node::Get_Offset(Node).GetLocation().Equals(HeldOffset, k_SettleCm);
        }

        auto Res = OutResult;
        Res.Set(Gripped && AtRest && Held && Settled);
    }

    // One poll of the ledger: which of the two meshes is drawn, and where the held visual is.
    private void Sample()
    {
        ++_Polls;
        const auto WorldDrawn = Get_HasDrawnMesh(_ItemEntity);
        const auto VisualEntity = _HeldItem.Get_PresentationEntity();
        const auto VisualDrawn = Get_HasDrawnMesh(VisualEntity);

        if (WorldDrawn == false && VisualDrawn == false)
        { ++_BlinkPolls; }

        if (WorldDrawn && VisualDrawn)
        { ++_DoublePolls; }

        if (VisualDrawn == false)
        { return; }

        ++_VisualPolls;
        const auto VisualWorld = utils_transform::Get_EntityCurrentTransform(VisualEntity.As_Transform()).GetLocation();
        if (_FirstVisualWorld.IsSet() == false)
        { _FirstVisualWorld = TOptional<FVector>(VisualWorld); }

        if (_LastVisualWorld.IsSet())
        { _MaxStepCm = Math::Max(_MaxStepCm, _LastVisualWorld.GetValue().Distance(VisualWorld)); }

        _LastVisualWorld = TOptional<FVector>(VisualWorld);
    }

    UFUNCTION()
    private void Step_AssertDrawnEveryFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_VisualPolls > 1, f"the held visual was sampled over several polls (got {_VisualPolls} of {_Polls})");
        Assert_Equals_Int(_BlinkPolls, 0, "no poll of the grab drew neither the world item's mesh nor the held visual's");
        Assert_Equals_Int(_DoublePolls, 0, "no poll of the grab drew both");

        const auto FirstVisual = _FirstVisualWorld.IsSet() ? _FirstVisualWorld.GetValue() : FVector::ZeroVector;
        Assert_True(FirstVisual.Equals(_LayWorld, 5.0), f"the held visual started where the tallow lay {_LayWorld} (got {FirstVisual})");

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        const auto HoldWorld = (_Item.Get_Presentation().Mounting.HeldOffset * HandWorld).GetLocation();
        const auto Travel = _LayWorld.Distance(HoldWorld);
        Assert_True(_MaxStepCm < Travel * k_MaxStepFraction,
            f"the visual's largest single-poll step ({_MaxStepCm} cm) is a fraction of the {Travel} cm from the floor to the hold: a carry, not a jump");
    }
}
