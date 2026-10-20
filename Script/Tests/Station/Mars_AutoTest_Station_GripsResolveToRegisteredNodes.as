// A station's grips name nodes by role tag; the placeable station's entity script resolves each through the nodes it
// registered and declares the gloves' grip table on the station root: a test station (UMars_TESTONLY_GripStation) with two
// grips over its two registered nodes gets a two-row table whose nodes are those nodes (the root's children at their
// offsets), and the grip interactable lives on the root (the owner the gloves read the table from). A grip naming a tag
// nothing registers rejects the station whole (ensure, nothing composed: no grip table, no Station); Validate() rejects
// two grips for one hand and a grip without a node tag.
class UMars_AutoTest_Station_GripsResolveToRegisteredNodes : UMars_AutoTestRig_Station
{
    private FCk_Handle _StationEntity;
    private FCk_Handle_Station _Station;
    private FCk_Handle _RejectedEntity;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Station_Spec();
        Spec.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        Spec.Grips.Add(FMars_Station_Grip(EMars_Hand::Left, Get_SurfaceTag(), NAME_None, EMars_HandGripPose::Open, TOptional<float32>(80.0f), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        auto Pending = Spawn_TestStation(InHandle, UMars_TESTONLY_GripStation_EntityScript, FMars_TESTONLY_StationSpawnParams(FTransform::Identity, Spec));
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto RejectedSpec = FMars_Station_Spec();
        RejectedSpec.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        auto RejectedPending = Spawn_TestStation(InHandle, UMars_TESTONLY_SurfaceOnlyStation_EntityScript, FMars_TESTONLY_StationSpawnParams(FTransform::Identity, RejectedSpec));
        utils_pending_entity_script::Promise_OnConstructed(RejectedPending, FCk_Delegate_EntityScript_Constructed(this, n"OnRejectedConstructed"));

        Add_Step_WaitUntil("both test stations are constructed", n"Check_Constructed", 0, 0);
        Add_Step("the root carries a two-row grip table on the registered nodes", n"Step_AssertGripTable");
        Add_Step_WaitUntil("the grip target exists", n"Check_HasGripTarget", 0, 0);
        Add_Step("the grip interactable belongs to the station root", n"Step_AssertGripOwner");
        Add_Step("Validate() rejects two grips for one hand and a grip without a node tag", n"Step_AssertValidate");
        Add_Step("a grip naming an unregistered node rejects the station whole", n"Step_AssertUnregisteredRejected");
        Run_Steps(InHandle);
    }

    private FGameplayTag Get_ToolTag() const
    {
        return GameplayTags::Station_Node_Tool;
    }

    private FGameplayTag Get_SurfaceTag() const
    {
        return GameplayTags::Station_Node_Surface;
    }

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        Track_ForCleanup(InEntityScriptHandle);
        _StationEntity = InEntityScriptHandle;
        _Station = _StationEntity.As_Station(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnRejectedConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        Track_ForCleanup(InEntityScriptHandle);
        _RejectedEntity = InEntityScriptHandle;
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_StationEntity) && ck::IsValid(_RejectedEntity));
    }

    UFUNCTION()
    private void Step_AssertGripTable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "a station whose grips name its two registered nodes is composed");
        Assert_True(_StationEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the station root carries the grip table");
        if (_StationEntity.Has_Fragment(FMars_Fragment_FPHands_Grips) == false)
        { return; }

        const auto Entries = _StationEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries;
        Assert_Equals_Int(Entries.Num(), 2, "the table has two rows");
        if (Entries.Num() != 2)
        { return; }

        Assert_True(Entries[0].Hand == EMars_Hand::Right && Get_IsRootChildAt(Entries[0].Node, constants_station_autotest::k_ToolLocal),
            "row 0: the right glove on the node registered under Station.Node.Tool");
        Assert_True(Entries[0].Pose == EMars_HandGripPose::Power && Entries[0].Socket.IsSet() == false, "row 0 keeps its pose and its unset socket");
        Assert_True(Entries[1].Hand == EMars_Hand::Left && Get_IsRootChildAt(Entries[1].Node, constants_station_autotest::k_SurfaceLocal),
            "row 1: the left glove on the node registered under Station.Node.Surface");
        Assert_True(Entries[1].Pose == EMars_HandGripPose::Open && Entries[1].ReachOverrideCm.IsSet() &&
            Math::Abs(Entries[1].ReachOverrideCm.GetValue() - 80.0f) < 0.001f,
            "row 1 keeps its pose and reach override");
    }

    // InNode is a scene node directly under the station root at InLocal: the node the test station registered there.
    private bool Get_IsRootChildAt(const FCk_Handle_Transform& InNode, FVector InLocal)
    {
        FCk_Handle Entity = InNode;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return false; }

        return utils_scene_node::Get_Parent(Node) == _StationEntity.As_Transform()
            && utils_scene_node::Get_Offset(Node).GetLocation().Equals(InLocal, 0.001);
    }

    UFUNCTION()
    private void Check_HasGripTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Station) && ck::IsValid(_Station.Get_GripTarget()));
    }

    UFUNCTION()
    private void Step_AssertGripOwner(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Station.Get_GripTarget();
        Assert_True(Target.Has_Fragment(FMars_Fragment_InteractionContext), "the grip target carries its interaction context");
        if (Target.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return; }

        const auto Owner = Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        Assert_True(Owner == _StationEntity, "the grip interactable's owner is the station root");
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto TwoRight = FMars_Station_Spec();
        TwoRight.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        TwoRight.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_SurfaceTag(), NAME_None, EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        const auto TwoRightResult = TwoRight.Validate();
        Assert_False(TwoRightResult.IsValid(), "Validate() rejects two grips for the right hand");
        Assert_True(TwoRightResult.Get_Error().Contains("repeats the hand"), f"Validate() names the repeated hand (got [{TwoRightResult.Get_Error()}])");

        auto NoTag = FMars_Station_Spec();
        NoTag.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, FGameplayTag(), NAME_None, EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        const auto NoTagResult = NoTag.Validate();
        Assert_False(NoTagResult.IsValid(), "Validate() rejects a grip without a node tag");
        Assert_True(NoTagResult.Get_Error().Contains("has no node tag"), f"Validate() names the missing tag (got [{NoTagResult.Get_Error()}])");
    }

    // The surface-only test station was constructed (its transform and nodes exist) but composed nothing past the grips.
    UFUNCTION()
    private void Step_AssertUnregisteredRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RejectedEntity.Is_Transform(), "the rejected station's entity script ran (its root has a transform)");
        Assert_False(_RejectedEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "a rejected station declares no grip table");
        Assert_False(_RejectedEntity.Has_Fragment(FMars_Feature_Station), "a rejected station adds no feature fragment");
        Assert_False(_RejectedEntity.Has_Fragment(FMars_Fragment_Station), "a rejected station adds no state fragment");
    }
}

// Hand-authored so the deliberate unregistered-node ensure is an expected error rather than a failure.
class AMars_AutoTest_Station_GripsResolveToRegisteredNodes_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Station_GripsResolveToRegisteredNodes;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the grips: grip [0] names the node [Station.Node.Tool] that no grip node registers");
        return Out;
    }
}
