// AttachPoints resolves each published node by its tag, answers nothing for a tag it does not publish, and rejects a
// spec that repeats a tag without adding anything to the entity.
class UMars_AutoTest_AttachPoints_LookupByTag : UCk_AutoTest_Base
{
    private FCk_Handle_AttachPoints _AttachPoints;
    private FCk_Handle_Transform _HandNode;
    private FCk_Handle_Transform _BackNode;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _HandNode = MakeNode(InHandle);
        _BackNode = MakeNode(InHandle);

        auto Spec = FMars_AttachPoints_Spec();
        Spec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        Spec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, _BackNode));

        auto LocalHandle = InHandle;
        _AttachPoints = utils_attach_points::Add(LocalHandle, Spec);

        Add_Step("Hand and Back resolve to their own nodes", n"Step_AssertPublishedTags");
        Add_Step("an unpublished tag resolves to nothing", n"Step_AssertUnpublishedTag");
        Add_Step("a spec repeating a tag fails its own Validate()", n"Step_AssertDuplicateInvalid");
        Add_Step("a spec repeating a tag is rejected whole", n"Step_AssertDuplicateRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPublishedTags(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_AttachPoints, "Add with Hand + Back returns a valid handle");
        Assert_True(_AttachPoints.Get_AttachPoint(GameplayTags::AttachPoint_Mars_Hand) == _HandNode, "Get_AttachPoint(Hand) is the hand node");
        Assert_True(_AttachPoints.Get_AttachPoint(GameplayTags::AttachPoint_Mars_Back) == _BackNode, "Get_AttachPoint(Back) is the back node");
        Assert_True(_AttachPoints.Has_AttachPoint(GameplayTags::AttachPoint_Mars_Hand), "Has_AttachPoint(Hand)");
    }

    UFUNCTION()
    private void Step_AssertUnpublishedTag(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Unpublished = GameplayTags::ResolveGameplayTag(n"Inventory.Mars.Backpack");
        Assert_False(_AttachPoints.Has_AttachPoint(Unpublished), "Has_AttachPoint(Inventory.Mars.Backpack)");
        Assert_Invalid(_AttachPoints.Get_AttachPoint(Unpublished), "Get_AttachPoint(Inventory.Mars.Backpack)");
    }

    UFUNCTION()
    private void Step_AssertDuplicateInvalid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = MakeDuplicateSpec();
        const auto Validation = Spec.Validate();
        Assert_False(Validation.IsValid, "Validate() on a spec repeating a tag");
        Assert_True(Validation.Get_Error().Contains("repeats the tag"),
            f"Validate() names the repeated tag (got [{Validation.Get_Error()}])");
    }

    UFUNCTION()
    private void Step_AssertDuplicateRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        auto Spec = MakeDuplicateSpec();

        auto Rejected = utils_attach_points::Add(Owner, Spec);
        Assert_Invalid(Rejected, "Add with a repeated tag returns an invalid handle");
        Assert_False(Owner.Has_Fragment(FMars_Feature_AttachPoints), "a rejected spec adds no feature fragment");
        Assert_False(Owner.Has_Fragment(FMars_Fragment_AttachPoints_Params), "a rejected spec adds no params fragment");
    }

    private FMars_AttachPoints_Spec MakeDuplicateSpec() const
    {
        auto Spec = FMars_AttachPoints_Spec();
        Spec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        Spec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _BackNode));
        return Spec;
    }

    private FCk_Handle_Transform MakeNode(FCk_Handle InHandle)
    {
        auto Child = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_transform::Add(Child, FTransform::Identity, ECk_Replication::DoesNotReplicate);
    }
}

// Hand-authored so the deliberate duplicate-tag ensure is an expected error rather than a failure.
class AMars_AutoTest_AttachPoints_LookupByTag_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_AttachPoints_LookupByTag;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: entry [1] repeats the tag [AttachPoint.Mars.Hand] of entry [0]");
        return Out;
    }
}
