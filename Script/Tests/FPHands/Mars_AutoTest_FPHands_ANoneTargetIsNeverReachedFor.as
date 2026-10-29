// A target the hands do not touch (ReachKind None: a conversation, a board that opens a screen) gets no gesture and no
// lean: its interactable wants no hands lean, the resolver binds leave the gloves at rest when it becomes the best Use
// target, and a StartReach that names it anyway is refused Malformed (an ensure the runner at the bottom expects). A Timed
// lever beside it still wants the lean. Beside the hands rig: a resolver on the test entity and the two interactables.
// Isolated origin (160000, -78000, -30000).
class UMars_AutoTest_FPHands_ANoneTargetIsNeverReachedFor : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(160000.0, -78000.0, -30000.0);

    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle _BoardOwner;
    private FCk_Handle_Interactable _Board;
    private FCk_Handle_InteractTarget _BoardTarget;
    private FMars_AutoTestRig_Hands_Lever _Lever;

    private TArray<EMars_FPHands_ReachKind> _RefusedKinds;
    private TArray<EMars_FPHands_ReachRefusal> _RefusedReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        auto Root = Add_Hands(InHandle, Spec);
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(k_Origin));
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        Add_HandsSm();
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnReachRefused"));

        Build_Board(InHandle);
        _Lever = Add_TimedLever(InHandle, k_Origin + FVector(60.0, 40.0, 0.0), 5.0f);

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_RestListening", 0, 0);
        Add_Step("the board wants no lean, the lever does; the board becomes the best Use target", n"Step_BoardBecomesBest");
        Add_Step_WaitUntil("the resolver holds the board as its best Use target", n"Check_BoardIsBest", 0, 0);
        Add_Step_WaitFrames("the resolver binds had their drain", 10);
        Add_Step("the gloves stayed at rest and nothing was refused: the binds never asked", n"Step_AssertAtRest");
        Add_Step("ask the gloves for the None reach anyway", n"Step_ReachForBoard");
        Add_Step_WaitUntil("the reach was refused", n"Check_Refused", 0, 0);
        Add_Step("it was refused Malformed, naming None, and the gloves stayed at rest", n"Step_AssertRefusedMalformed");
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec()
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // The test entity has no transform: no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // A transform-only interactable with one Instant Use target the hands do not touch. Its interaction never starts here,
    // so its state class only has to load.
    private void Build_Board(FCk_Handle InHandle)
    {
        auto Parent = InHandle;
        _BoardOwner = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(_BoardOwner, FTransform(FRotator::ZeroRotator, k_Origin + FVector(60.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        Target.InteractionStateClass = UMars_AutoTestState_WhileLiveWork;
        Target.ReachKind = EMars_FPHands_ReachKind::None;

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Target);
        _Board = utils_interactable::Create(Root, Spec);
        _BoardTarget = _Board.Get_AllInteractTargets()[0];
    }

    UFUNCTION()
    private void OnReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                EMars_FPHands_ReachRefusal InReason)
    {
        _RefusedKinds.Add(InKind);
        _RefusedReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_BoardBecomesBest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Board.Get_WantsHandsLean(), "an interactable whose only target is None wants no hands lean");
        Assert_True(_Lever.Interactable.Get_WantsHandsLean(), "a lever's interactable wants the lean");

        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_BoardTarget));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
    }

    UFUNCTION()
    private void Check_BoardIsBest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Use).Contains(_BoardTarget));
    }

    UFUNCTION()
    private void Step_AssertAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::None, "the gloves stayed at rest with a None target best");
        Assert_False(_Hands.Get_Target().IsSet(), "the gloves have no reach target");
        Assert_Equals_Int(_RefusedReasons.Num(), 0, "the resolver binds never asked for the reach, so nothing was refused");
    }

    UFUNCTION()
    private void Step_ReachForBoard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_BoardTarget, _Board, _BoardOwner),
            ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::None));
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RefusedReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefusedMalformed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RefusedReasons.Num(), 1, "the None reach was refused once");
        Assert_True(_RefusedReasons[0] == EMars_FPHands_ReachRefusal::Malformed, f"refused Malformed (got {_RefusedReasons[0] :n})");
        Assert_True(_RefusedKinds[0] == EMars_FPHands_ReachKind::None, f"the refusal names the None it asked for (got {_RefusedKinds[0] :n})");
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::None, "the gloves stayed at rest");
    }
}

// Hand-authored so the gloves' ensure on the None reach is an expected error rather than a failure. Pinned to that ensure's
// own wording so an unrelated FPHands ensure still fails the test.
class AMars_AutoTest_FPHands_ANoneTargetIsNeverReachedFor_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_FPHands_ANoneTargetIsNeverReachedFor;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("asks for no gesture: a None target is never reached for");
        return Out;
    }
}
