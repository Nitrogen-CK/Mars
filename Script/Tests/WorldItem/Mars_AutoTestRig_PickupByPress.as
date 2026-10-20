// A carrier composed as the player is for a pickup: Hotbar (two bag slots), HeldItem, HeldItemUse
// (the drop / throw launch), the carrier's gloves, Use resolver, InputIntents and player tasks (Add_CarrierHands), and a
// private input stack with a real Use level row on F9 (UMars_AutoTestHelper_UseKey).
// It holds a rock (seeded, stowed to bag slot 0, held), launches it with the real HeldItemUse path onto a floor in front
// of it, focuses the rock's new world item from the frame it exists (the player looks where it throws), and once it lies
// still offers it to the resolver as the view trace would and taps Use (pressed, released two frames later). A test sets
// _LaunchKind and asserts the pickup lands. Add_Steps_TapWhileHolding instead keeps the held rock and taps on a second
// rock lying in front of the carrier (at _LooseRockLocal): the gloves, full with a two-handed rock, refuse the reach,
// and the pickup must land at once (within k_MaxRefusedStowFrames of the press).
// Add_Steps_UpToALooseRockOfferedWhileHolding is that sequence up to the offer, for a test that acts on the loose rock
// itself.
UCLASS(Abstract)
class UMars_AutoTestRig_PickupByPress : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    // A launched rock's roll and the gloves' return from a grab outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;
    // From the press (the tap's first poll comes four frames on): the matcher's pass, the resolver's, the target's
    // start of the interaction, the pickup state's entry, the gloves' drain that refuses the reach, the holder's
    // transfer drain and the poll after it. A reach and grip would add the gloves' Reach.Grab.OutSeconds.
    protected const int32 k_MaxRefusedStowFrames = 8;

    protected EMars_LaunchKind _LaunchKind = EMars_LaunchKind::Drop;
    // Where Add_Steps_TapWhileHolding's second rock is dropped from, from the origin.
    protected FVector _LooseRockLocal = FVector(100.0, 0.0, 20.0);

    protected FCk_Handle_HeldItemUse _Use;
    protected FCk_Handle_InputIntents _Intents;
    protected FCk_Handle_InteractionResolver _Resolver;
    private UMars_AutoTestHelper_UseKey _UseKey;

    private FVector _Origin;
    // The interact target of every reach the gloves refused (invalid for a reach that served no interaction).
    protected TArray<FCk_Handle_InteractTarget> _RefusedReaches;
    // The rock's Use target as it was offered (a picked-up transient rock's world item is destroyed with it).
    protected FCk_Handle_InteractTarget _OfferedTarget;
    protected FCk_Handle_WorldItem _Landed;
    private TOptional<FVector> _LastLandedLocation;
    private int32 _StillFrames = 0;
    // The frame Use was last pressed, and the frame a refused pickup was first seen stowed.
    private int64 _PressFrame = -1;
    private int64 _StowSeenFrame = -1;

    protected void Build_Rig(FCk_Handle InHandle, FVector InOrigin)
    {
        _Origin = InOrigin;
        Add_CarrierBodyWithBack(InHandle, InOrigin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        Add_CarrierHands();
        _Intents = _Carrier.As_InputIntents();
        _Resolver = _Carrier.As_InteractionResolver();
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnRigReachRefused"));

        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build(InHandle, EKeys::F9);
        Build_Floor(InHandle);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
    }

    // Up to the tap; the test adds its assertion steps after.
    protected void Add_Steps_LaunchAndTap()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step("hand the Use matcher to the carrier and stow the rock into bag slot 0", n"Step_ComposeAndStow");
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", 0, 0);
        Add_Step("launch the rock with the held item's drop / throw", n"Step_Launch");
        Add_Step_WaitUntil("the rock lies (nearly) still on the floor", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 0);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the rock is picked up", n"Check_Stowed", 0, 0);
        Add_Step("it is in a bag slot and its world item is gone", n"Step_AssertStowed");
    }

    // Up to a loose rock lying in front of the carrier, focused and offered to its resolver, while the carrier still holds its
    // own rock and its gloves rest.
    protected void Add_Steps_UpToALooseRockOfferedWhileHolding()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step("hand the Use matcher to the carrier and stow the rock into bag slot 0", n"Step_ComposeAndStow");
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", 0, 0);
        Add_Step("a second rock is dropped in front of the carrier", n"Step_SpawnLooseRock");
        Add_Step_WaitUntil("the second rock lies (nearly) still on the floor", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 0);
    }

    // Up to the tap on a loose rock while the carrier still holds its own; the test adds its assertion steps after.
    protected void Add_Steps_TapWhileHolding()
    {
        Add_Steps_UpToALooseRockOfferedWhileHolding();
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the second rock is picked up at once", n"Check_StowedAtOnce", 0, 0);
        Add_Step("the gloves refused its reach, and it is in the other bag slot", n"Step_AssertRefusedAndStowed");
    }

    // Two taps, each its own hold: empty-handed, the carrier taps on a loose rock (the first hold is spent by that pickup),
    // throws it, and taps on it again once it lies still; the test adds its assertion steps after.
    protected void Add_Steps_TapTwice()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step("hand the Use matcher to the carrier", n"Step_Compose");
        Add_Step_WaitUntil("the empty gloves rest, listening", n"Check_EmptyAndRest", 0, 0);
        Add_Step("a rock is dropped in front of the carrier", n"Step_SpawnLooseRock");
        Add_Step_WaitUntil("the rock lies (nearly) still on the floor", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 0);
        Add_Step("press Use (the first hold)", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the first tap picks the rock up", n"Check_Stowed", 0, 0);
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", k_SlowPolls, 0);
        Add_Step("forget the picked-up world item and throw the rock", n"Step_ForgetAndLaunch");
        Add_Step_WaitUntil("the thrown rock lies (nearly) still on the floor", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 0);
        Add_Step("press Use again (a fresh hold)", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the second tap picks the rock up again", n"Check_Stowed", 0, 0);
        Add_Step("it is in a bag slot and its world item is gone", n"Step_AssertStowed");
    }

    // A static slab under the carrier and in front of it (+X), its top at the carrier's feet, with a trough that stops a
    // rolling rock: a kerb 150 cm out (20 cm tall: a throw clears it, a drop or a roll-back stops at it) and a wall 320 cm out.
    private void Build_Floor(FCk_Handle InOwner)
    {
        Spawn_StaticSlab(InOwner, _Origin + FVector(150.0, 0.0, -1.0), FVector(400.0, 200.0, 1.0));
        Spawn_StaticSlab(InOwner, _Origin + FVector(150.0, 0.0, 10.0), FVector(2.0, 200.0, 10.0));
        Spawn_StaticSlab(InOwner, _Origin + FVector(320.0, 0.0, 50.0), FVector(2.0, 200.0, 50.0));
    }

    protected FCk_Handle_InteractTarget Get_UseTarget() const
    {
        auto Pickup = _Landed.Get_Pickup();
        return Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_Recording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsRecording());
    }

    UFUNCTION()
    private void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _UseKey.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    UFUNCTION()
    private void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsUseSetActive());
    }

    UFUNCTION()
    private void Step_ComposeAndStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Step_Compose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_intent_matcher::BindTo_OnIntentPhaseChanged(_UseKey.Get_Matcher(),
            FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnRigIntentPhaseChanged"), ECk_Signal_BindingPolicy::IgnorePayloadInFlight);
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
    }

    UFUNCTION()
    private void Check_EmptyAndRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _UseKey.Get_Matcher() && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_ForgetAndLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Landed = FCk_Handle_WorldItem();
        _LastLandedLocation.Reset();
        _StillFrames = 0;
        _LaunchKind = EMars_LaunchKind::Throw;
        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    UFUNCTION()
    private void Check_RockHeldAndRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_HeldItem.Get_CurrentItem()) && _Intents.Get_Matcher() == _UseKey.Get_Matcher()
            && _Hands.Get_Hold().Kind != EMars_FPHands_HoldKind::Empty && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_SpawnLooseRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()),
            FTransform(FRotator::ZeroRotator, _Origin + _LooseRockLocal));
        utils_world_item::Request_SpawnWorld(Owner, Spec);
    }

    UFUNCTION()
    private void Step_Launch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_LaunchKind == EMars_LaunchKind::Throw)
        { _Use.Request_Throw(FMars_Request_HeldItemUse_Throw()); }
        else
        { _Use.Request_Drop(FMars_Request_HeldItemUse_Drop()); }
    }

    // The launched rock is the World-mode world item near the carrier (the only one this rig spawns; found from the frame it
    // exists and focused then); it has moved less than 1.5 mm a frame for 10 frames (a sphere in the trough may still creep).
    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Landed))
        {
            _Landed = Find_LaunchedRock(InHandle);
            if (ck::Is_NOT_Valid(_Landed))
            {
                Res.Set(false);
                return;
            }

            FCk_Handle LandedEntity = _Landed;
            Track_ForCleanup(LandedEntity);

            // The player looks where it throws: the rock is focused from the frame it exists, in flight, before its
            // holder has even adopted the item.
            auto Pickup = _Landed.Get_Pickup();
            Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        }

        FCk_Handle Entity = _Landed;
        const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        const auto IsStill = _LastLandedLocation.IsSet() && _LastLandedLocation.GetValue().Equals(Location, 0.15);
        _StillFrames = IsStill ? _StillFrames + 1 : 0;
        _LastLandedLocation = TOptional<FVector>(Location);
        Res.Set(_StillFrames >= 10 && Location.Z < _Origin.Z + 30.0);
    }

    private FCk_Handle_WorldItem Find_LaunchedRock(FCk_Handle InHandle) const
    {
        const auto WorldItems = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem");
        for (const auto& Entity : WorldItems)
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(_Origin) < 1000.0)
            { return WorldItem; }
        }

        return FCk_Handle_WorldItem();
    }

    UFUNCTION()
    private void Step_FocusAndOffer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Landed;
        const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        Log(f"[PickupByPress] the {_LaunchKind :n} rock lies {(Location - _Origin).Size2D()} cm from the carrier");

        _OfferedTarget = Get_UseTarget();
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_OfferedTarget));
    }

    UFUNCTION()
    private void Check_Focused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(Get_UseTarget().As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    protected void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PressFrame = utils_time::Get_FrameCounter();
        _UseKey.Press();
    }

    // Logs the held row's activation frame first: the frame each hold is known by.
    UFUNCTION()
    protected void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
        auto FrameText = FString("unset");
        if (Frame.IsSet())
        { FrameText = f"{Frame.GetValue()}"; }

        Log(f"[PickupByPress] releasing Use: the row's activation frame is {FrameText}");
        _UseKey.Release();
    }

    // A transient rock's world item ends once its holder gives the item up.
    UFUNCTION()
    private void Check_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem()));
    }

    // Check_Stowed, marking the frame it first holds: the refused pickup's frame bound counts to it from the press.
    UFUNCTION()
    private void Check_StowedAtOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto IsStowed = ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem());
        if (IsStowed == false)
        {
            Res.Set(false);
            return;
        }

        _StowSeenFrame = utils_time::Get_FrameCounter();
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertRefusedAndStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RefusedReaches.Contains(_OfferedTarget), "the gloves, full with a two-handed rock, refused the reach for it");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(0)) && ck::IsValid(_Hotbar.Get_ItemAt(1)), "both bag slots hold a rock");
        Assert_True(_HeldItem.Get_CurrentItem() == _Hotbar.Get_ItemAt(0), "the first rock stays in the hands");

        const auto Frames = _StowSeenFrame - _PressFrame;
        Assert_True(Frames <= k_MaxRefusedStowFrames,
            f"the refused pickup landed within {k_MaxRefusedStowFrames} frames of the press (took {Frames})");
    }

    // The frames a press is known by, read in the matcher's own phase broadcast (where the player's intent task reads them).
    UFUNCTION()
    private void OnRigIntentPhaseChanged(FCk_Handle_IntentMatcher InMatcher, FName InIntentName, FGameplayTag InIntentTag,
                                         ECk_Intent_Phase InPreviousPhase, ECk_Intent_Phase InNewPhase, int32 InFrame)
    {
        if (InIntentTag != GameplayTags::Mars_Intent_Interact_Use || InNewPhase != ECk_Intent_Phase::Active || InPreviousPhase == ECk_Intent_Phase::Active)
        { return; }

        const auto Row = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
        auto RowText = FString("unset");
        if (Row.IsSet())
        { RowText = f"{Row.GetValue()}"; }

        Log(f"[PickupByPress] Use pressed: matcher frame {InFrame}, the row's activation frame then {RowText}");
    }

    UFUNCTION()
    private void OnRigReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                   EMars_FPHands_ReachRefusal InReason)
    {
        _RefusedReaches.Add(InTarget);
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto InABagSlot = ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1));
        Assert_True(InABagSlot, "the rock is in a bag slot");
        Assert_True(ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem()), "the world item gave its rock up");
    }
}
