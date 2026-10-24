// The real chain bridge assembly: the windlass's FreeTurn pull scrubs the deck by hauled degrees over the whole haul (540
// of 1080 is half way), paying out lowers it again (back 180 is a third), and reaching the full haul latches it: the deck
// rests at the end pose, the Source asserts and later turns change nothing.
class UMars_AutoTest_ChainBridge_TheWindlassRatchetsTheDeckDownAndLatches : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 12.0f;

    private FCk_Handle _Bridge;
    private FCk_Handle_Control _Windlass;
    private FCk_Handle_Mover _Deck;
    private FCk_Handle_MechanismSource _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = UMars_ChainBridge_EntityScript::Params();
        Params.SpawnTransform = FTransform(FVector(-46000.0, 352000.0, -41000.0));
        Params.Bridge.TurnsToLower = 3.0f;
        Params.Source.OutputChannel = GameplayTags::Mechanism_Channel_M;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_ChainBridge_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBridgeConstructed"));

        Add_Step_WaitUntil("bridge assembled", n"Check_Ready", 900, 0);
        Add_Step("raised; grip the windlass", n"Step_Grip");
        Add_Step_WaitUntil("gripped", n"Check_Gripped", 0, 0);
        Add_Step("haul 540", n"Step_HaulHalf");
        Add_Step_WaitUntil("deck moved", n"Check_DeckLeftRest", 0, 0);
        Add_Step("half way, not down; pay out 180", n"Step_AssertHalfThenPayOut");
        Add_Step_WaitUntil("deck rose", n"Check_DeckBelowHalf", 0, 0);
        Add_Step("a third; haul the rest and past it", n"Step_AssertThirdThenHaulRest");
        Add_Step_WaitUntil("down and asserted", n"Check_Down", 0, 0);
        Add_Step("latched; pay out", n"Step_AssertDownThenPayOut");
        Add_Step_WaitFrames("let a pay-out drain", 5);
        Add_Step("still down", n"Step_AssertStillDown");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBridgeConstructed(FCk_Handle_EntityScript InBridge)
    {
        _Bridge = InBridge;
    }

    private FCk_Handle Find_OwnedTagged(FCk_Handle InAny, FName InTag) const
    {
        for (auto Entity : utils_entity_tag::ForEach_Entity(InAny, InTag))
        {
            if (ck::IsValid(Entity) && utils_entity_lifetime::Get_LifetimeOwner(Entity) == _Bridge)
            { return Entity; }
        }
        return FCk_Handle();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Bridge))
        {
            Res.Set(false);
            return;
        }

        _Windlass = Find_OwnedTagged(InHandle, n"TAG_MarsChainBridgeWindlass").As_Control(ECk_SanityCheck::UnChecked);
        _Deck = Find_OwnedTagged(InHandle, n"TAG_MarsChainBridgeDeck").As_Mover(ECk_SanityCheck::UnChecked);
        _Source = _Bridge.As_MechanismSource(ECk_SanityCheck::UnChecked);
        Res.Set(ck::IsValid(_Windlass) && ck::IsValid(_Deck) && ck::IsValid(_Source)
            && _Windlass.Has_Fragment(FMars_Tag_Control_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_Grip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Windlass.Get_IsFreeTurn(), "the windlass is a FreeTurn control");
        Assert_Equals_Float(_Deck.Get_Alpha(), 0.0f, 0.0001f, "the deck starts raised");
        Assert_False(_Source.Get_IsAsserted(), "the source starts deasserted");

        _Windlass.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(FCk_Handle_Interaction()));
    }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Windlass.Get_IsManipulating());
    }

    UFUNCTION()
    private void Step_HaulHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(540.0f));
    }

    UFUNCTION()
    private void Check_DeckLeftRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Deck.Get_Alpha() > 0.0f);
    }

    UFUNCTION()
    private void Step_AssertHalfThenPayOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 0.5f, 0.0001f, "540 of 1080 hauled is half way");
        Assert_True(_Deck.Get_Target() == EMars_Mover_Pose::Start, "a part haul leaves the target raised");
        Assert_False(_Source.Get_IsAsserted(), "not down, not asserted");

        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(-180.0f));
    }

    UFUNCTION()
    private void Check_DeckBelowHalf(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Deck.Get_Alpha() < 0.5f);
    }

    UFUNCTION()
    private void Step_AssertThirdThenHaulRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 1.0f / 3.0f, 0.0001f, "paying out 180 leaves 360 of 1080");

        // 360 + 900 overshoots the full haul: the ratchet clamps at 1080.
        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(900.0f));
    }

    UFUNCTION()
    private void Check_Down(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Deck.Get_Alpha() >= 1.0f && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_AssertDownThenPayOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Deck.Get_Target() == EMars_Mover_Pose::End, "the full haul makes the end pose the target");
        Assert_True(_Deck.Get_IsResting(), "the deck rests down");

        _Windlass.Request_Nudge(FMars_Request_Control_Nudge(-720.0f));
    }

    UFUNCTION()
    private void Step_AssertStillDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Deck.Get_Alpha(), 1.0f, 0.0001f, "paying out after the latch moves nothing");
        Assert_True(_Deck.Get_Target() == EMars_Mover_Pose::End, "still targeting the end pose");
        Assert_True(_Source.Get_IsAsserted(), "the source stays asserted");
        Assert_True(_Windlass.Get_IsManipulating(), "the grip outlasts the latch until the operator lets go");
    }
}
