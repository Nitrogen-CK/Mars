// A station's grips name nodes by role tag; Add resolves each through the nodes the placing script registered and declares
// the gloves' grip table on the station root: two grips over two registered nodes give a two-row table whose nodes are
// those handles, and the grip interactable lives on the root (the owner the gloves read the table from). A grip naming a
// tag nothing registers rejects the station whole (ensure, invalid handle, nothing composed); Validate() rejects two grips
// for one hand and a grip without a node tag.
class UMars_AutoTest_Station_GripsResolveToRegisteredNodes : UCk_AutoTest_Base
{
    private FCk_Handle _StationEntity;
    private FCk_Handle_Station _Station;
    private FCk_Handle_Transform _ToolNode;
    private FCk_Handle_Transform _SurfaceNode;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _ToolNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(10.0, 20.0, 90.0))).As_Transform();
        _SurfaceNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(10.0, -20.0, 90.0))).As_Transform();

        auto Spec = FMars_Station_Spec();
        Spec.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, 0.0f));
        Spec.Grips.Add(FMars_Station_Grip(EMars_Hand::Left, Get_SurfaceTag(), NAME_None, EMars_HandGripPose::Open, 80.0f));

        auto Setup = FMars_Station_Setup();
        Setup.GripNodes.Add(FMars_Station_GripNode(Get_SurfaceTag(), _SurfaceNode));
        Setup.GripNodes.Add(FMars_Station_GripNode(Get_ToolTag(), _ToolNode));
        _Station = utils_station::Add(Root, Spec, Setup);

        Add_Step("the root carries a two-row grip table on the registered nodes", n"Step_AssertGripTable");
        Add_Step_WaitUntil("the grip target exists", n"Check_HasGripTarget", 0, 2.0f);
        Add_Step("the grip interactable belongs to the station root", n"Step_AssertGripOwner");
        Add_Step("Validate() rejects two grips for one hand and a grip without a node tag", n"Step_AssertValidate");
        Add_Step("a grip naming an unregistered node rejects the station whole", n"Step_AssertUnregisteredRejected");
        Run_Steps(InHandle);
    }

    private FGameplayTag Get_ToolTag() const
    {
        return GameplayTags::ResolveGameplayTag(n"Station.Node.Tool");
    }

    private FGameplayTag Get_SurfaceTag() const
    {
        return GameplayTags::ResolveGameplayTag(n"Station.Node.Surface");
    }

    UFUNCTION()
    private void Step_AssertGripTable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "Add with two registered grip nodes returns a valid station");
        Assert_True(_StationEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the station root carries the grip table");
        if (_StationEntity.Has_Fragment(FMars_Fragment_FPHands_Grips) == false)
        { return; }

        const auto Entries = _StationEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries;
        Assert_True(Entries.Num() == 2, f"the table has two rows (got {Entries.Num()})");
        if (Entries.Num() != 2)
        { return; }

        Assert_True(Entries[0].Hand == EMars_Hand::Right && FCk_Handle(Entries[0].Node) == FCk_Handle(_ToolNode),
            "row 0: the right glove on the node registered under Station.Node.Tool");
        Assert_True(Entries[0].Pose == EMars_HandGripPose::Power && Entries[0].Socket == NAME_None, "row 0 keeps its pose and socket");
        Assert_True(Entries[1].Hand == EMars_Hand::Left && FCk_Handle(Entries[1].Node) == FCk_Handle(_SurfaceNode),
            "row 1: the left glove on the node registered under Station.Node.Surface");
        Assert_True(Entries[1].Pose == EMars_HandGripPose::Open && Math::Abs(Entries[1].ReachOverrideCm - 80.0f) < 0.001f,
            "row 1 keeps its pose and reach override");
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
        TwoRight.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, 0.0f));
        TwoRight.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_SurfaceTag(), NAME_None, EMars_HandGripPose::Open, 0.0f));
        const auto TwoRightResult = TwoRight.Validate();
        Assert_False(TwoRightResult.IsValid, "Validate() on two grips for the right hand");
        Assert_True(TwoRightResult.Get_Error().Contains("repeats the hand"), f"Validate() names the repeated hand (got [{TwoRightResult.Get_Error()}])");

        auto NoTag = FMars_Station_Spec();
        NoTag.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, FGameplayTag(), NAME_None, EMars_HandGripPose::Power, 0.0f));
        const auto NoTagResult = NoTag.Validate();
        Assert_False(NoTagResult.IsValid, "Validate() on a grip without a node tag");
        Assert_True(NoTagResult.Get_Error().Contains("has no node tag"), f"Validate() names the missing tag (got [{NoTagResult.Get_Error()}])");
    }

    UFUNCTION()
    private void Step_AssertUnregisteredRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto RejectedEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RejectedEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto SurfaceNode = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();

        auto Spec = FMars_Station_Spec();
        Spec.Grips.Add(FMars_Station_Grip(EMars_Hand::Right, Get_ToolTag(), NAME_None, EMars_HandGripPose::Power, 0.0f));
        auto Setup = FMars_Station_Setup();
        Setup.GripNodes.Add(FMars_Station_GripNode(Get_SurfaceTag(), SurfaceNode));

        auto Rejected = utils_station::Add(Root, Spec, Setup);
        Assert_Invalid(Rejected, "Add with a grip naming an unregistered node returns an invalid station");
        Assert_False(RejectedEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "a rejected station declares no grip table");
        Assert_False(RejectedEntity.Has_Fragment(FMars_Feature_Station), "a rejected station adds no feature fragment");
        Assert_False(RejectedEntity.Has_Fragment(FMars_Fragment_Station), "a rejected station adds no state fragment");
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
