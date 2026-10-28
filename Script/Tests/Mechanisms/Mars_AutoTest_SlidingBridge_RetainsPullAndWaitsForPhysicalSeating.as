// Exercises the real composition, including actual Jolt support. Removing the deck through the public component API
// simulates absent collision without weakening the production safety gate; the same real deck is restored at its end pose.
class UMars_AutoTest_SlidingBridge_RetainsPullAndWaitsForPhysicalSeating : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FCk_Handle _Bridge;
    private FCk_Handle_Control _Windlass;
    private FCk_Handle_Mover _Deck;
    private FCk_Handle_UnrealComponent _DeckPart;
    private FCk_Handle_Gate _NearGuard;
    private FCk_Handle_Gate _FarGuard;
    private FCk_Handle_MechanismSource _Source;
    private FTransform _BridgeWorld;
    private int32 _SourceEdges = 0;
    private bool _PrematureSource = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = UMars_SlidingBridge_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator(0.0, 90.0, 0.0), FVector(-52000.0, 352000.0, -41000.0));
        Params.Bridge.WheelOffset = FTransform(FRotator(0.0, 37.0, 0.0), FVector(600.0, -1700.0, -30.0));
        Params.Source.OutputChannel = GameplayTags::Mechanism_Channel_M;
        // Even a misconfigured source must never announce an unavailable crossing.
        Params.Source.StartAsserted = true;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_SlidingBridge_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBridgeConstructed"));

        Add_Step_WaitUntil("actual assembly and collision component ready", n"Check_Ready", 900, 0);
        Add_Step("retracted guards closed; grip", n"Step_Initial");
        Add_Step_WaitUntil("first grip accepted", n"Check_Gripped");
        Add_Step("haul half", n"Step_HaulHalf");
        Add_Step_WaitUntil("half pull reaches actual deck offset", n"Check_Half");
        Add_Step("release half way", n"Step_Release");
        Add_Step_WaitUntil("release accepted", n"Check_Released");
        Add_Step_WaitSeconds("no drift after release", 0.2f);
        Add_Step("half retained; regrip", n"Step_Regrip");
        Add_Step_WaitUntil("second grip accepted", n"Check_Gripped");
        Add_Step("pay out one sixth", n"Step_PayOut");
        Add_Step_WaitUntil("one third retained after payout", n"Check_Third");
        Add_Step("remove Jolt deck; request full haul", n"Step_FullWithoutSupport");
        Add_Step_WaitUntil("mover and native deck at end without support", n"Check_EndWithoutSupport");
        Add_Step_WaitSeconds("outlast multiple physical-seat polls", 0.3f);
        Add_Step("missing support holds guards and source; try payout", n"Step_AssertMissingThenPayOut");
        Add_Step_WaitFrames("drain ignored terminal payout", 5);
        Add_Step("terminal request retained; restore real Jolt deck", n"Step_RestoreSupport");
        Add_Step_WaitUntil("guards start clearing after support exists", n"Check_GuardsMoving");
        Add_Step("source stays closed while guards travel", n"Step_AssertGuardsMoving");
        Add_Step_WaitUntil("both guards at settled open poses and source asserted", n"Check_Available");
        Add_Step("one availability edge; try payout again", n"Step_AvailableThenPayOut");
        Add_Step_WaitFrames("drain later terminal payout", 5);
        Add_Step("bridge remains available", n"Step_Final");
        Add_Step("destroy real assembly before completing fixture", n"Step_Destroy");
        Add_Step_WaitUntil("bridge descendants and Jolt deck removed", n"Check_Gone");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Source))
        { _Source.UnbindFrom_OnAssertedChanged(FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceChanged")); }
    }

    UFUNCTION()
    private void OnBridgeConstructed(FCk_Handle_EntityScript InBridge)
    { _Bridge = InBridge; }

    private FCk_Handle Find_OwnedTagged(FCk_Handle InContext, FName InTag) const
    {
        for (auto Entity : utils_entity_tag::ForEach_Entity(InContext, InTag))
        {
            // Add_MeshPart returns a component entity owned by its mesh node, beneath the deck node. Walk the
            // lifetime subtree rather than assuming every tagged descendant is directly owned by the bridge.
            auto Owner = Entity;
            while (ck::IsValid(Owner))
            {
                if (Owner == _Bridge)
                { return Entity; }
                const auto NextOwner = utils_entity_lifetime::Get_LifetimeOwner(Owner);
                // Other test assemblies can terminate at a self-owned world/fixture entity.
                if (NextOwner == Owner)
                { break; }
                Owner = NextOwner;
            }
        }
        return FCk_Handle();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Bridge))
        { Result.Set(false); return; }
        _Windlass = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeWindlass").As_Control(ECk_SanityCheck::UnChecked);
        _Deck = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeDeck").As_Mover(ECk_SanityCheck::UnChecked);
        _DeckPart = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeDeckCollision").As_UnrealComponent(ECk_SanityCheck::UnChecked);
        _NearGuard = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeNearGuard").As_Gate(ECk_SanityCheck::UnChecked);
        _FarGuard = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeFarGuard").As_Gate(ECk_SanityCheck::UnChecked);
        _Source = _Bridge.As_MechanismSource(ECk_SanityCheck::UnChecked);
        Result.Set(ck::IsValid(_Windlass) && ck::IsValid(_Deck) && ck::IsValid(_DeckPart)
            && ck::IsValid(_NearGuard) && ck::IsValid(_FarGuard) && ck::IsValid(_Source)
            && ck::IsValid(utils_unreal_component::Get_Component(_DeckPart))
            && _Windlass.Has_Fragment(FMars_Tag_Control_NeedsSetup) == false
            && _NearGuard.Has_Fragment(FMars_Tag_Gate_NeedsSetup) == false
            && _FarGuard.Has_Fragment(FMars_Tag_Gate_NeedsSetup) == false);
    }

    private FVector Get_DeckLocalPosition() const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Bridge.As_Transform());
        return Root.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(_Deck.As_Transform()));
    }

    private bool Get_HasSeatedSupport() const
    {
        for (int32 Along = 1; Along <= 3; ++Along)
        {
            for (int32 Across = -1; Across <= 1; ++Across)
            {
                const auto Top = _BridgeWorld.TransformPosition(FVector(Across * 103.5, Along * 262.5, 0.0));
                const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(Top + FVector(0.0, 0.0, 10.0), Top - FVector(0.0, 0.0, 40.0));
                if (Hit.Get_HasHit() == false || Math::Abs(Hit.Get_Position().Z - Top.Z) > 2.0)
                { return false; }
            }
        }
        return true;
    }

    private bool Get_GuardCleared(FCk_Handle_Gate InGate, FVector InOffset) const
    {
        const auto Mover = InGate.Get_MovingNode().As_Mover();
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Bridge.As_Transform());
        const auto At = Root.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(Mover.As_Transform()));
        return InGate.Get_IsOpen() && Mover.Get_Target() == EMars_Mover_Pose::End
            && Mover.Get_IsResting() && Mover.Get_Alpha() == 1.0f && At.Distance(InOffset + FVector(0.0, 0.0, 220.0)) < 0.1;
    }

    private void Assert_Closed()
    {
        Assert_False(_NearGuard.Get_IsOpen(), "near guard stays closed");
        Assert_False(_FarGuard.Get_IsOpen(), "far guard stays closed");
        Assert_Equals_Float(_NearGuard.Get_MovingNode().As_Mover().Get_Alpha(), 0.0f, 0.0001f, "near leaf stays down");
        Assert_Equals_Float(_FarGuard.Get_MovingNode().As_Mover().Get_Alpha(), 0.0f, 0.0001f, "far leaf stays down");
        Assert_False(_Source.Get_IsAsserted(), "crossing is unavailable");
    }

    UFUNCTION()
    private void Step_Initial(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BridgeWorld = utils_transform::Get_EntityCurrentTransform(_Bridge.As_Transform());
        Assert_True(_Windlass.Get_IsFreeTurn(), "windlass uses the existing continuous grip control");
        Assert_Equals_Float(_Deck.Get_Alpha(), 0.0f, 0.0001f, "initially retracted");
        Assert_True(Get_DeckLocalPosition().Distance(FVector(0.0, -1050.0, 0.0)) < 0.1, "actual retracted offset");
        Assert_Closed();
        _Source.BindTo_OnAssertedChanged(FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceChanged"));
        _Windlass.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(FCk_Handle_Interaction()));
    }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(_Windlass.Get_IsManipulating()); }

    UFUNCTION()
    private void Step_HaulHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Windlass.Request_Nudge(FMars_Request_Control_Nudge(540.0f)); }

    UFUNCTION()
    private void Check_Half(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(_Deck.Get_Alpha() - 0.5f) < 0.0001f
            && Get_DeckLocalPosition().Distance(FVector(0.0, -525.0, 0.0)) < 0.1);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Closed();
        _Windlass.Request_EndManipulation(FMars_Request_Control_EndManipulation());
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(_Windlass.Get_IsManipulating() == false); }

    UFUNCTION()
    private void Step_Regrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 0.5f, 0.0001f, "release retained the half haul");
        Assert_True(Get_DeckLocalPosition().Distance(FVector(0.0, -525.0, 0.0)) < 0.1, "release retained actual offset");
        Assert_Closed();
        _Windlass.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(FCk_Handle_Interaction()));
    }

    UFUNCTION()
    private void Step_PayOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Windlass.Request_Nudge(FMars_Request_Control_Nudge(-180.0f)); }

    UFUNCTION()
    private void Check_Third(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(_Deck.Get_Alpha() - 1.0f / 3.0f) < 0.0001f
            && Get_DeckLocalPosition().Distance(FVector(0.0, -700.0, 0.0)) < 0.1);
    }

    UFUNCTION()
    private void Step_FullWithoutSupport(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Closed();
        utils_unreal_component::Request_RemoveFromJoltStaticWorld(_DeckPart);
        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(900.0f));
    }

    UFUNCTION()
    private void Check_EndWithoutSupport(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        auto Component = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_DeckPart));
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Bridge.As_Transform());
        Result.Set(_Deck.Get_Target() == EMars_Mover_Pose::End && _Deck.Get_IsResting() && _Deck.Get_Alpha() == 1.0f
            && Get_DeckLocalPosition().IsNearlyZero(0.1) && ck::IsValid(Component)
            && Component.GetWorldLocation().Distance(Root.TransformPosition(FVector(0.0, 525.0, -10.0))) < 0.1
            && Get_HasSeatedSupport() == false);
    }

    UFUNCTION()
    private void Step_AssertMissingThenPayOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_HasSeatedSupport(), "end/rest without Jolt support is not a seated crossing");
        Assert_Closed();
        Assert_Equals_Int(_SourceEdges, 0, "full requested alpha emits no availability edge");
        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(-720.0f));
    }

    UFUNCTION()
    private void Step_RestoreSupport(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 1.0f, 0.0001f, "full request refuses payout even while support is missing");
        Assert_Closed();
        utils_unreal_component::Request_BakeIntoJoltStaticWorld(_DeckPart);
        Assert_True(Get_HasSeatedSupport(), "restored actual deck supplies all nine support witnesses");
    }

    UFUNCTION()
    private void Check_GuardsMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_NearGuard.Get_IsOpen() && _FarGuard.Get_IsOpen()
            && (_NearGuard.Get_MovingNode().As_Mover().Get_IsResting() == false
                || _FarGuard.Get_MovingNode().As_Mover().Get_IsResting() == false));
    }

    UFUNCTION()
    private void Step_AssertGuardsMoving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Source.Get_IsAsserted(), "logical gate-open state does not assert availability during leaf travel");
        Assert_Equals_Int(_SourceEdges, 0, "no early edge during guard travel");
    }

    UFUNCTION()
    private void Check_Available(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_GuardCleared(_NearGuard, FVector(0.0, -1100.0, -30.0))
            && Get_GuardCleared(_FarGuard, FVector(0.0, 1085.0, -30.0)) && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_AvailableThenPayOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasSeatedSupport(), "available crossing has actual support");
        Assert_Equals_Int(_SourceEdges, 1, "one terminal assertion");
        Assert_False(_PrematureSource, "source observer never saw an unsupported deck or uncleared guard");
        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(-1080.0f));
    }

    UFUNCTION()
    private void Step_Final(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 1.0f, 0.0001f, "terminal latch ignores later payout");
        Assert_True(Get_DeckLocalPosition().IsNearlyZero(0.1), "actual deck remains seated");
        Assert_True(_Source.Get_IsAsserted(), "source remains asserted");
        Assert_Equals_Int(_SourceEdges, 1, "no repeated assertion");
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Source.UnbindFrom_OnAssertedChanged(FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceChanged"));
        utils_entity_lifetime::Request_DestroyEntity(_Bridge);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_Bridge) && ck::Is_NOT_Valid(_Windlass) && ck::Is_NOT_Valid(_Deck)
            && ck::Is_NOT_Valid(_DeckPart) && ck::Is_NOT_Valid(_NearGuard) && ck::Is_NOT_Valid(_FarGuard)
            && ck::Is_NOT_Valid(_Source) && Get_HasSeatedSupport() == false);
    }

    UFUNCTION()
    private void OnSourceChanged(FCk_Handle_MechanismSource InSource, EMars_MechanismSource_Output InOutput)
    {
        ++_SourceEdges;
        if (InOutput == EMars_MechanismSource_Output::Asserted
            && (Get_HasSeatedSupport() == false
                || Get_GuardCleared(_NearGuard, FVector(0.0, -1100.0, -30.0)) == false
                || Get_GuardCleared(_FarGuard, FVector(0.0, 1085.0, -30.0)) == false))
        { _PrematureSource = true; }
    }
}
