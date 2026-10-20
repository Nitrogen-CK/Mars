// A mount taken at the gloves' grip rides the gloves home. A carrier with gloves, a hotbar and HeldItem picks up a meat
// slab (a Persistent item) at the gloves' Grip: it is stowed into the empty hands' slot and selected, so it mounts Held
// with the ride the pickup asked for (Request_ArriveNextMount), yet it does not move from where it lay until the gloves
// start their Return, and it settles (OnMountSettled, Held by the carrier, at its HeldOffset under the Hand node) as the
// gloves come to Rest: during the Return, no more than k_MaxFramesBeforeRest frames before Rest and no more than a frame
// after it. Isolated origin (24800, -15000, -30000).
class UMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(24800.0, -15000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);
    // A slab lying still moves less than this a frame; the arrival's first step is far more.
    private const float64 k_StillCm = 0.5;
    private const float64 k_AtOffsetCm = 0.5;
    // The arrival runs on the Return's own clock (GripSeconds left + BackSeconds); the gloves' phase reads None only after the
    // Hands sub-SM leaves Return and its SetPhase request drains, about two frames later.
    private const int64 k_MaxFramesBeforeRest = 3;
    private const int64 k_MaxFramesAfterRest = 1;
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
    // The frames the gloves were first seen in Return and at Rest after it, and the frame the slab settled Held.
    private TOptional<int64> _ReturnFrame;
    private TOptional<int64> _RestFrame;
    private TOptional<int64> _SettledFrame;
    private TOptional<EMars_WorldItem_Mount> _SettledMount;
    private FCk_Handle _SettledCarrier;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();

        _SlabEntity = Spawn_FoodItemOnFloor(InHandle, mars_items::Food_MeatSlab(), k_Origin + k_SlabOffset);

        Add_Step_WaitUntil("the slab is constructed and its body added", n"Check_SlabReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the slab lies still on its floor", n"Check_SlabAtRest", k_SlowPolls, 0);
        Add_Step("the carrier focuses the slab's pickup", n"Step_Focus");
        Add_Step_WaitUntil("the pickup's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier reaches for the slab and picks it up", n"Step_ReachAndPickUp");
        Add_Step_WaitUntil("the gloves grip, return and rest; the slab rides them home and settles", n"Check_RideHome", 0, 0);
        Add_Step("still until the Return; settled at its HeldOffset as the gloves rest", n"Step_AssertRodeHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Slab = TryGet_ConstructedWorldItem(_SlabEntity);
        if (ck::Is_NOT_Valid(_Slab) && ck::IsValid(Slab))
        {
            _Slab = Slab;
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

    // What the player's resolver does on a press: the interaction starts, and its pickup task asks the gloves for the reach.
    UFUNCTION()
    private void Step_ReachAndPickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SlabAtStart = Get_SlabWorld().GetLocation();

        auto Target = _Slab.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_RideHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_HandPhases.Contains(EMars_FPHands_Phase::Return) && _SawReturn == false)
        {
            _SawReturn = true;
            _ReturnFrame = TOptional<int64>(utils_time::Get_FrameCounter());
        }

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

        if (_RestFrame.IsSet() == false && _Hands.Get_Phase() == EMars_FPHands_Phase::None)
        { _RestFrame = TOptional<int64>(utils_time::Get_FrameCounter()); }

        Res.Set(_RestFrame.IsSet() && _SettledFrame.IsSet());
    }

    UFUNCTION()
    private void OnSlabMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        if (InMount != EMars_WorldItem_Mount::Held || _SettledFrame.IsSet())
        { return; }

        _SettledFrame = TOptional<int64>(utils_time::Get_FrameCounter());
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

        // Two-sided: a slab that lands early in the Return outran the gloves as surely as a late one lagged them.
        Assert_True(_SettledFrame.GetValue() >= _ReturnFrame.GetValue(),
            f"the slab settled during the Return, not before it (frame {_SettledFrame.GetValue()}, Return from {_ReturnFrame.GetValue()})");
        const auto FramesAfterRest = _SettledFrame.GetValue() - _RestFrame.GetValue();
        Assert_True(FramesAfterRest >= -k_MaxFramesBeforeRest && FramesAfterRest <= k_MaxFramesAfterRest,
            f"the slab settled as the gloves came to Rest ({FramesAfterRest} frame(s) after it; allowed {-k_MaxFramesBeforeRest}..{k_MaxFramesAfterRest})");
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
