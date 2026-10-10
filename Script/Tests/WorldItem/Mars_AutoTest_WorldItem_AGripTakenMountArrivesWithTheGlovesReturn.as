// A mount taken at the gloves' grip rides the gloves home. A carrier with gloves, a hotbar and HeldItem picks up a meat
// slab (a Persistent item) at the gloves' Grip: it is stowed into the empty hands' slot and selected, so it mounts Held
// with the ride the pickup asked for (Request_ArriveNextMount), yet it does not move from where it lay until the gloves
// start their Return, and it settles (OnMountSettled, Held by the carrier, at its HeldOffset under the Hand node) within a
// frame of the gloves coming to Rest. Isolated origin (24800, -15000, -30000).
class UMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(24800.0, -15000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);
    // A slab lying still moves less than this a frame; the arrival's first step is far more.
    private const float64 k_StillCm = 0.5;
    private const float64 k_AtOffsetCm = 0.5;
    private const int32 k_MaxFramesAfterRest = 1;
    // The slab's construction (its joint imports) and its fall onto its floor outrun the default poll budget at lane
    // frame rate.
    private const int32 k_SlowPolls = 900;
    // A body slower than this (cm/s) for k_RestPolls polls in a row lies still: one slow poll may be a bounce's top.
    private const float64 k_RestSpeed = 2.0;
    private const int32 k_RestPolls = 10;

    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FVector _SlabAtStart;
    private int32 _RestPolls = 0;
    private bool _SawReturn = false;
    private int32 _FramesBeforeReturn = 0;
    private int32 _MovedFramesBeforeReturn = 0;
    // Polls of Check_RideHome, one a frame: the clock the rest and the settle are read on.
    private int32 _Poll = 0;
    private TOptional<int32> _RestPoll;
    private TOptional<int32> _SettledPoll;
    private TOptional<EMars_WorldItem_Mount> _SettledMount;
    private FCk_Handle _SettledCarrier;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();

        _SlabEntity = Spawn_Slab(InHandle, k_Origin + k_SlabOffset);

        Add_Step_WaitUntil("the slab is constructed and its body added", n"Check_SlabReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the slab lies still on its floor", n"Check_SlabAtRest", k_SlowPolls, 0);
        Add_Step("the carrier focuses the slab's pickup", n"Step_Focus");
        Add_Step_WaitUntil("the pickup's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier reaches for the slab and picks it up", n"Step_ReachAndPickUp");
        Add_Step_WaitUntil("the gloves grip, return and rest; the slab rides them home and settles", n"Check_RideHome", 0, 0);
        Add_Step("still until the Return; settled at its HeldOffset within a frame of Rest", n"Step_AssertRodeHome");
        Run_Steps(InHandle);
    }

    // A meat slab lying on a static floor whose top is at InTop, under the world's transient entity, tracked for cleanup.
    private FCk_Handle Spawn_Slab(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InTop + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Entity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(Entity);
        return Entity;
    }

    UFUNCTION()
    private void Check_SlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Slab) && ck::IsValid(_SlabEntity) && _SlabEntity.Is_WorldItem()
            && ck::IsValid(_SlabEntity.As_WorldItem().Get_HeldItem()))
        {
            _Slab = _SlabEntity.As_WorldItem();
            _Slab.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnSlabMountSettled"));
        }

        auto Res = OutResult;
        Res.Set(ck::IsValid(_Slab) && utils_jolt_body::Get_IsBodyAdded(_Slab.Get_Body()));
    }

    UFUNCTION()
    private void Check_SlabAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsSlow = utils_jolt_body::Get_LinearVelocity(_Slab.Get_Body()).Size() < k_RestSpeed;
        _RestPolls = IsSlow ? _RestPolls + 1 : 0;

        auto Res = OutResult;
        Res.Set(_RestPolls >= k_RestPolls);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Pickup);
    }

    // What the player's resolver and interaction glue do on a press: the gloves reach for the pickup's target, and the
    // interaction starts.
    UFUNCTION()
    private void Step_ReachAndPickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SlabAtStart = Get_SlabWorld().GetLocation();

        auto Pickup = _Slab.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(Target, Pickup, _SlabEntity),
            ECk_Interaction_CompletionPolicy::Instant));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_RideHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        ++_Poll;
        if (_HandPhases.Contains(EMars_FPHands_Phase::Return))
        { _SawReturn = true; }

        if (_SawReturn == false)
        {
            ++_FramesBeforeReturn;
            const auto Moved = Get_SlabWorld().GetLocation() - _SlabAtStart;
            if (Moved.Size() > k_StillCm)
            {
                ++_MovedFramesBeforeReturn;
                Log(f"[RideHome test] moved {Moved.Size() :.3} cm ({Moved}) on frame {_FramesBeforeReturn} before the Return: phase {_Hands.Get_Phase() :n}, mount {_Slab.Get_Mount() :n}");
            }

            Res.Set(false);
            return;
        }

        if (_RestPoll.IsSet() == false && _Hands.Get_Phase() == EMars_FPHands_Phase::None)
        { _RestPoll = TOptional<int32>(_Poll); }

        Res.Set(_RestPoll.IsSet() && _SettledPoll.IsSet());
    }

    UFUNCTION()
    private void OnSlabMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        if (InMount != EMars_WorldItem_Mount::Held || _SettledPoll.IsSet())
        { return; }

        _SettledPoll = TOptional<int32>(_Poll);
        _SettledMount = TOptional<EMars_WorldItem_Mount>(InMount);
        _SettledCarrier = InCarrier;
    }

    UFUNCTION()
    private void Step_AssertRodeHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FramesBeforeReturn > 1, f"the gloves reached and gripped over frames ({_FramesBeforeReturn})");
        Assert_Equals_Int(_MovedFramesBeforeReturn, 0, "the slab stayed where it lay until the gloves started their Return");
        Assert_True(_SettledMount == EMars_WorldItem_Mount::Held && _SettledCarrier == _Carrier, "the slab settled Held by the carrier");
        Assert_True(Get_IsAtHeldOffset(), "it rests at its HeldOffset under the Hand node");

        const auto FramesAfterRest = _SettledPoll.GetValue() - _RestPoll.GetValue();
        Assert_True(FramesAfterRest <= k_MaxFramesAfterRest,
            f"the slab settled within a frame of the gloves' Rest ({FramesAfterRest} frame(s) after it)");
    }

    private FTransform Get_SlabWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_SlabEntity.As_Transform());
    }

    private bool Get_IsAtHeldOffset() const
    {
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(_Slab);
        if (ck::Is_NOT_Valid(Presentation))
        { return false; }

        const auto InHand = Get_SlabWorld().GetRelativeTransform(utils_transform::Get_EntityCurrentTransform(_HandNode));
        return InHand.GetLocation().Equals(Presentation.Mounting.HeldOffset.GetLocation(), k_AtOffsetCm);
    }
}
