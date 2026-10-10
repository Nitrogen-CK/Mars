// A Place reach is the one reach a two-handed hold may make. The gloves hold a rock in both hands (a two-handed hold);
// a rock lying in the world is the subject. A Grab reach for it is refused (both gloves are busy): no reach is requested
// and the phase stays None. A Place reach for the same subject is accepted: OnReachRequested reports Place, both gloves
// take part, the reach sets the held rock's centre down at the subject's bounds-fit top plus the held rock's own half
// height (in the subject's frame), and the gloves run Reach -> Grip -> Return -> None, as a grab does. Isolated origin
// (28000, -25000, -30000).
class UMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_Origin = FVector(28000.0, -25000.0, -30000.0);

    private FCk_Handle_Inventory_DataOnly _Holder;
    private FCk_Handle_Item _Rock;
    private FCk_Handle _SubjectEntity;
    private FCk_Handle_WorldItem _Subject;
    private TArray<EMars_FPHands_ReachKind> _Requested;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Add_Hands(InHandle, Spec);
        Add_HandsSm();
        Log_Phases();
        _Hands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnReachRequested"));

        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        _Holder = utils_inventory_data_only::Add(HolderOwner, HolderParams, ECk_Replication::DoesNotReplicate);
        auto AddRequest = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        AddRequest.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        _Holder.Request_AddItemByDefinition(AddRequest, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());

        auto Owner = InHandle;
        _SubjectEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, k_Origin)));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step_WaitUntil("the rock item is seeded and the subject rock is a world item", n"Check_Ready", 0, 5.0f);
        Add_Step("the gloves hold the rock", n"Step_Hold");
        Add_Step_WaitUntil("the hold is two-handed", n"Check_TwoHanded", 0, 2.0f);
        Add_Step("request a Grab reach for the subject", n"Step_RequestGrab");
        Add_Step_WaitFrames("a grab would have started", 5);
        Add_Step("the grab was refused: no reach, no phase", n"Step_AssertGrabRefused");
        Add_Step("request a Place reach for the subject", n"Step_RequestPlace");
        Add_Step_WaitUntil("the gloves went Reach, Grip, Return and back to None", n"Check_BackToNone", 0, 5.0f);
        Add_Step("the place was accepted, both gloves took it and it sets the rock down above the subject", n"Step_AssertPlace");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        _Requested.Add(InKind);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = _Holder.Get_NumItems() == 1 && ck::IsValid(_SubjectEntity) && _SubjectEntity.Is_WorldItem();
        if (IsReady && ck::Is_NOT_Valid(_Rock))
        {
            _Rock = _Holder.Get_SoleItem();
            _Subject = _SubjectEntity.As_WorldItem();
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_Hold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Rock));
    }

    UFUNCTION()
    private void Check_TwoHanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded);
    }

    UFUNCTION()
    private void Step_RequestGrab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Make_Subject(), ECk_Interaction_CompletionPolicy::Instant));
    }

    UFUNCTION()
    private void Step_AssertGrabRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Requested.Num(), 0, "a grab with both gloves holding was not requested");
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::None, "the gloves stay at rest");
        Assert_Equals_Int(_Phases.Num(), 0, "no phase change");
    }

    UFUNCTION()
    private void Step_RequestPlace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Make_Subject(), ECk_Interaction_CompletionPolicy::Instant,
            EMars_FPHands_ReachKind::Place));
    }

    UFUNCTION()
    private void Check_BackToNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 4 && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertPlace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Requested.Num() == 1 && _Requested[0] == EMars_FPHands_ReachKind::Place, "one reach was requested, a Place");
        Assert_True(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded, "the gloves held the rock two-handed throughout");

        Assert_Equals_Int(_Phases.Num(), 4, "four phase changes");
        if (_Phases.Num() == 4)
        {
            Assert_True(_Phases[0] == EMars_FPHands_Phase::Reach, f"first Reach (got {_Phases[0] :n})");
            Assert_True(_Phases[1] == EMars_FPHands_Phase::Grip, f"then Grip (got {_Phases[1] :n})");
            Assert_True(_Phases[2] == EMars_FPHands_Phase::Return, f"then Return (got {_Phases[2] :n})");
            Assert_True(_Phases[3] == EMars_FPHands_Phase::None, f"then None (got {_Phases[3] :n})");
        }

        const auto MaybeTarget = _Hands.Get_Target();
        if (MaybeTarget.IsSet() == false)
        {
            FinishFailure("the place left no reach target");
            return;
        }

        const auto Target = MaybeTarget.GetValue();
        Assert_True(Target.Right.IsSet() && Target.Left.IsSet(), "both gloves take part in the place");
        Assert_True(Target.Layout == EMars_FPHands_GripLayout::Sides, "the gloves hold the rock by its sides");
        Assert_True(Target.PlaceAt.IsSet(), "the reach names where the rock is set down");

        FCk_Handle SubjectEntity = _Subject;
        Assert_True(Target.Get_LeadingGrip().Anchor == SubjectEntity.As_Transform(), "the reach anchors to the subject");

        const auto SubjectFit = _Subject.Get_BoundsFit();
        const auto HeldFit = _Hands.Get_Hold().Bounds;
        const auto Expected = SubjectFit.Centre + FVector(0.0, 0.0, SubjectFit.HalfExtents.Z + HeldFit.HalfExtents.Z);
        Assert_True(Target.PlaceAt.IsSet() && Target.PlaceAt.GetValue().Equals(Expected, 0.01),
            f"the rock's centre is set down on the subject's top ({Target.PlaceAt.GetValue()} vs {Expected})");
        Assert_True(HeldFit.HalfExtents.Z > 0.0, "the held rock has a height");
    }

    private FMars_FPHands_ReachSubject Make_Subject() const
    {
        FCk_Handle SubjectEntity = _Subject;
        return FMars_FPHands_ReachSubject(_Subject.Get_Pickup(), SubjectEntity);
    }
}
