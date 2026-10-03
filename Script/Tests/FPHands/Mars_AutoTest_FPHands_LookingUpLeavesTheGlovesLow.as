// The gloves take only part of an upward look: the pitch node between the view and the hand chain turns the chain back
// about the view's origin, so the hand node ends up pitched FollowUp of the way and lower than the view carries it, while
// it keeps the view's yaw. A downward look at FollowDown 1 is followed whole.
class UMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow : UCk_AutoTest_Base
{
    private FCk_Handle_Transform _View;
    private FCk_Handle_Transform _HandNode;
    private FCk_Handle_FPHands _Hands;

    private const FVector k_ViewOrigin = FVector(0.0, 0.0, -40000.0);
    private const FVector k_HandOffset = FVector(60.0, 0.0, -20.0);
    private const float k_Yaw = 30.0;
    private const float k_LookUp = 60.0;
    private const float k_LookDown = -40.0;
    private const float32 k_FollowUp = 0.4f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto ViewEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _View = utils_transform::Add(ViewEntity, FTransform(FRotator(k_LookUp, k_Yaw, 0.0), k_ViewOrigin), ECk_Replication::DoesNotReplicate);
        auto PitchNode = utils_scene_node::Create(_View, FTransform::Identity);
        auto PitchTransform = PitchNode.As_Transform();
        _HandNode = utils_scene_node::Create(PitchTransform, FTransform(FRotator::ZeroRotator, k_HandOffset)).As_Transform();

        auto Spec = FMars_FPHands_Spec();
        Spec.Pitch.Node = PitchNode;
        Spec.Pitch.FollowUp = k_FollowUp;
        Spec.Pitch.FollowDown = 1.0f;
        Spec.Pitch.InterpSpeed = 0.0f;
        auto Player = InHandle;
        _Hands = utils_fphands::Add(Player, Spec, _HandNode);

        Add_Step_WaitUntil("the hand node has settled at part of the upward look", n"Check_FollowsPartOfTheLookUp", 0, 5.0f);
        Add_Step("the gloves sit low and still face where the view turns", n"Step_AssertLow");
        Add_Step("look down", n"Step_LookDown");
        Add_Step_WaitUntil("the hand node has taken the whole downward look", n"Check_FollowsTheLookDown", 0, 5.0f);
        Add_Step("the gloves are where the view carries them", n"Step_AssertFollowsDown");
        Run_Steps(InHandle);
    }

    private FTransform Get_HandWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_HandNode);
    }

    // Where the view alone would carry the hand node for a look pitched InPitch.
    private FVector Get_CarriedLocation(float InPitch) const
    {
        return FTransform(FRotator(InPitch, k_Yaw, 0.0), k_ViewOrigin).TransformPosition(k_HandOffset);
    }

    UFUNCTION()
    private void Check_FollowsPartOfTheLookUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(Get_HandWorld().Rotator().Pitch - k_LookUp * k_FollowUp) < 0.1);
    }

    UFUNCTION()
    private void Step_AssertLow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandWorld();
        Assert_Equals_Float(Hand.Rotator().Pitch, k_LookUp * k_FollowUp, 0.1, "the gloves pitch up FollowUp of the look");
        Assert_Equals_Float(Hand.Rotator().Yaw, k_Yaw, 0.1, "the gloves keep the view's yaw");
        Assert_Equals_Float(_Hands.Get_ViewPitch(), k_LookUp, 0.1, "the feature read the view's pitch");

        const auto Expected = Get_CarriedLocation(k_LookUp * k_FollowUp);
        const auto Error = (Hand.GetLocation() - Expected).Size();
        Assert_True(Error < 0.5, f"the gloves are turned back about the view's origin (off by {Error} cm)");

        const auto Carried = Get_CarriedLocation(k_LookUp);
        Assert_True(Hand.GetLocation().Z < Carried.Z - 10.0,
            f"the gloves sit lower than the view carries them (at {Hand.GetLocation().Z}, carried {Carried.Z})");
    }

    UFUNCTION()
    private void Step_LookDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetRotation(_View, FCk_Request_Transform_SetRotation(FRotator(k_LookDown, k_Yaw, 0.0)));
    }

    UFUNCTION()
    private void Check_FollowsTheLookDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(Get_HandWorld().Rotator().Pitch - k_LookDown) < 0.1);
    }

    UFUNCTION()
    private void Step_AssertFollowsDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandWorld();
        const auto Error = (Hand.GetLocation() - Get_CarriedLocation(k_LookDown)).Size();
        Assert_True(Error < 0.5, f"a downward look at FollowDown 1 carries the gloves whole (off by {Error} cm)");
        Assert_Equals_Float(Hand.Rotator().Yaw, k_Yaw, 0.1, "the gloves keep the view's yaw looking down");
    }
}
