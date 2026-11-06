// The held item's offset from the hand has one owner at a time (utils_fphands::Get_HeldOffsetOwner). A carrier with gloves
// picks up a one-handed tallow lying on a floor in front of it; polled every frame of the grab, the owner runs None, then
// Arrival for the one pass the spawned visual is anchored where the tallow lay (when a poll sees it), then Carry while it
// rides in, then None once it rests at its hold offset - and the hold reads one-handed through the whole carry, so the
// glove's follow never takes the ride over. Then the right glove carries the tallow to a plain interactable left of the
// hand (a Holding reach): the owner is Follow while it is there, None again back at rest. Isolated origin
// (23600, -19000, -30000).
class UMars_AutoTest_FPHands_TheHeldOffsetHasOneOwnerAtATime : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(23600.0, -19000.0, -30000.0);
    private const FVector k_ItemOffset = FVector(60.0, 0.0, 0.0);
    // The point the Holding reach goes to, from the hand mount (Build_CarrierBody's (40, 20, 60)): ahead and to the left.
    private const FVector k_PointFromHand = FVector(60.0, -40.0, 0.0);
    private const FVector k_HandMount = FVector(40.0, 20.0, 60.0);
    // The item's construction, its fall onto the floor and the gloves' grab outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    // A body slower than this (cm/s) for k_RestPolls polls in a row lies still.
    private const float64 k_RestSpeed = 2.0;
    private const int32 k_RestPolls = 10;
    // The visual's hold offset is reached when its node offset is within this (cm) of HeldOffset.
    private const float64 k_SettleCm = 0.5;
    // Polls the gloves stay at rest with the visual settled before the pickup's ledger closes, so a late owner shows.
    private const int32 k_SettledPolls = 10;

    private FCk_Handle _ItemEntity;
    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _Item;
    private FCk_Handle _PointOwner;
    private FCk_Handle_Interactable _Point;
    private int32 _RestPolls = 0;

    // The pickup's ledger: the distinct consecutive owners and the poll each began on.
    private int32 _Polls = 0;
    private int32 _SettledFor = 0;
    private TArray<EMars_FPHands_HeldOffsetOwner> _Owners;
    private TArray<int32> _OwnerPolls;
    private int32 _CarryPolls = 0;
    private int32 _CarryPollsNotOneHanded = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
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

        // A plain interactable (no probe, no targets): a point grip, one glove.
        _PointOwner = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto PointRoot = utils_transform::Add(_PointOwner, FTransform(FRotator::ZeroRotator, k_Origin + k_HandMount + k_PointFromHand),
            ECk_Replication::DoesNotReplicate);
        _Point = utils_interactable::Create(PointRoot, FMars_Interactable_Spec());

        Add_Step_WaitUntil("the tallow is a world item with its body added", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the tallow lies still on the floor", n"Check_ItemAtRest", k_SlowPolls, 0);
        Add_Step("the carrier focuses the tallow's pickup", n"Step_Focus");
        Add_Step_WaitUntil("the pickup's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier reaches for the tallow and picks it up", n"Step_PickUp");
        Add_Step_WaitUntil("the grab ran its course and the visual rests at its hold offset (sampling the owner every poll)",
            n"Check_PickupDone", k_SlowPolls, 0);
        Add_Step("the owner ran None, Arrival (maybe), Carry, None; one-handed through the carry", n"Step_AssertPickupOwners");
        Add_Step("the right glove carries the tallow to the point", n"Step_ReachHolding");
        Add_Step_WaitUntil("the gloves grip the point", n"Check_Gripping", k_SlowPolls, 0);
        Add_Step("the tallow follows its glove", n"Step_AssertFollow");
        Add_Step_WaitUntil("the gloves are back at rest", n"Check_CarrierHandsRest", k_SlowPolls, 0);
        Add_Step_WaitFrames("the tallow is back at its hold offset", 10);
        Add_Step("nobody writes the offset at rest", n"Step_AssertNoneAtRest");
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
        Assert_True(ck::IsValid(_Item) && _Item.Get_Presentation().Grip.Handedness == EMars_ItemPresentation_Handedness::OneHanded,
            "the tallow is a one-handed item");
        Assert_True(_Hands.Get_HeldOffsetOwner() == EMars_FPHands_HeldOffsetOwner::None, "nothing in the hand, nobody owns the offset");

        auto Target = _WorldItem.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_PickupDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_Polls;
        const auto Owner = _Hands.Get_HeldOffsetOwner();
        if (_Owners.Num() == 0 || _Owners.Last() != Owner)
        {
            _Owners.Add(Owner);
            _OwnerPolls.Add(_Polls);
        }

        if (Owner == EMars_FPHands_HeldOffsetOwner::Carry)
        {
            ++_CarryPolls;
            if (_Hands.Get_Hold().Kind != EMars_FPHands_HoldKind::OneHanded)
            { ++_CarryPollsNotOneHanded; }
        }

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

        _SettledFor = Gripped && AtRest && Held && Settled ? _SettledFor + 1 : 0;

        auto Res = OutResult;
        Res.Set(_SettledFor >= k_SettledPolls);
    }

    UFUNCTION()
    private void Step_AssertPickupOwners(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Observed = Describe_Owners();
        auto Expected = TArray<EMars_FPHands_HeldOffsetOwner>();
        Expected.Add(EMars_FPHands_HeldOffsetOwner::None);
        if (_Owners.Num() > 1 && _Owners[1] == EMars_FPHands_HeldOffsetOwner::Arrival)
        { Expected.Add(EMars_FPHands_HeldOffsetOwner::Arrival); }

        Expected.Add(EMars_FPHands_HeldOffsetOwner::Carry);
        Expected.Add(EMars_FPHands_HeldOffsetOwner::None);

        auto Matches = _Owners.Num() == Expected.Num();
        for (int32 Index = 0; Matches && Index < Expected.Num(); ++Index)
        { Matches = _Owners[Index] == Expected[Index]; }

        Assert_True(Matches, f"the owner ran None, Arrival (maybe), Carry, None - one at a time (got {Observed}over {_Polls} polls)");
        Assert_True(_CarryPolls > 1, f"the carry owned the offset over several polls (got {_CarryPolls})");
        Assert_Equals_Int(_CarryPollsNotOneHanded, 0, "the hold read one-handed through the whole carry");
    }

    UFUNCTION()
    private void Step_ReachHolding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::OneHanded, "the gloves hold the tallow one-handed");

        auto Request = FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_Point, _PointOwner),
            ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::Grab);
        Request.ReachHand = EMars_FPHands_ReachHand::Holding;
        _Hands.Request_StartReach(Request);
    }

    UFUNCTION()
    private void Check_Gripping(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Grip);
    }

    UFUNCTION()
    private void Step_AssertFollow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Right), "a Holding reach goes to the right glove, which holds the tallow");
        const auto Owner = _Hands.Get_HeldOffsetOwner();
        Assert_True(Owner == EMars_FPHands_HeldOffsetOwner::Follow, f"the tallow follows its glove (got {Owner :n})");
    }

    UFUNCTION()
    private void Step_AssertNoneAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Owner = _Hands.Get_HeldOffsetOwner();
        Assert_True(Owner == EMars_FPHands_HeldOffsetOwner::None, f"nobody owns the offset at rest (got {Owner :n})");

        auto Node = _HeldItem.Get_PresentationEntity().As_SceneNode(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(Node) && utils_scene_node::Get_Offset(Node).Equals(_Hands.Get_Hold().HeldOffset),
            "the tallow is back at its hold offset");
    }

    // "Owner@poll " per entry of the ledger.
    private FString Describe_Owners() const
    {
        auto Text = FString();
        for (int32 Index = 0; Index < _Owners.Num(); ++Index)
        { Text += f"{_Owners[Index] :n}@{_OwnerPolls[Index]} "; }

        return Text;
    }
}
