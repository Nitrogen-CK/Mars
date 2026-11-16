// Lowered gloves (an armed throw) sink by the Pitch spec's Lower pose: with a level view, the pitch node eases to the
// Lower offset and pitch, so the hand node ends up where the view carries it through that pose - lower, pitched down by
// Lower.PitchDeg, still facing the view's yaw. Raised again, it eases back to where the view alone carries it.
class UMars_AutoTest_FPHands_LoweredGlovesSinkByTheLowerPoseAndComeBack : UCk_AutoTest_Base
{
    private FCk_Handle_Transform _HandNode;
    private FCk_Handle_FPHands _Hands;
    private FMars_FPHands_LowerSpec _Lower;

    private const FVector k_ViewOrigin = FVector(0.0, 4000.0, -40000.0);
    private const FVector k_HandOffset = FVector(60.0, 0.0, -20.0);
    private const float k_Yaw = -25.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto ViewEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto View = utils_transform::Add(ViewEntity, FTransform(FRotator(0.0, k_Yaw, 0.0), k_ViewOrigin), ECk_Replication::DoesNotReplicate);
        auto PitchNode = utils_scene_node::Create(View, FTransform::Identity);
        auto PitchTransform = PitchNode.As_Transform();
        _HandNode = utils_scene_node::Create(PitchTransform, FTransform(FRotator::ZeroRotator, k_HandOffset)).As_Transform();

        auto Spec = FMars_FPHands_Spec();
        Spec.Pitch.Node = PitchNode;
        Spec.Pitch.InterpSpeed.Reset();
        Spec.HandNode = _HandNode;
        _Lower = Spec.Pitch.Lower;
        auto Player = InHandle;
        _Hands = utils_fphands::Add(Player, Spec);

        Add_Step_WaitUntil("the gloves rest where the view carries them", n"Check_AtRest", 0, 0);
        Add_Step("lower the gloves", n"Step_Lower");
        Add_Step_WaitUntil("the gloves have eased fully into the Lower pose", n"Check_FullyLowered");
        Add_Step("the gloves sit where the Lower pose carries them", n"Step_AssertLowered");
        Add_Step("raise the gloves", n"Step_Raise");
        Add_Step_WaitUntil("the gloves have eased fully back", n"Check_FullyRaised");
        Add_Step("the gloves are back where the view alone carries them", n"Step_AssertRaised");
        Run_Steps(InHandle);
    }

    private FTransform Get_HandWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_HandNode);
    }

    private FTransform Get_ViewWorld() const
    {
        return FTransform(FRotator(0.0, k_Yaw, 0.0), k_ViewOrigin);
    }

    // Where the view carries the hand node through the pitch node's offset InPitchOffset.
    private FVector Get_CarriedLocation(FTransform InPitchOffset) const
    {
        return Get_ViewWorld().TransformPosition(InPitchOffset.TransformPosition(k_HandOffset));
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HandWorld().GetLocation().Distance(Get_CarriedLocation(FTransform::Identity)) < 0.5);
    }

    UFUNCTION()
    private void Step_Lower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hands.Get_IsLowered(), "the gloves start raised");
        _Hands.Request_SetLowered(FMars_Request_FPHands_SetLowered(true));
    }

    UFUNCTION()
    private void Check_FullyLowered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_LowerAlpha() >= 1.0f && Math::Abs(Get_HandWorld().Rotator().Pitch - _Lower.PitchDeg) < 0.1);
    }

    UFUNCTION()
    private void Step_AssertLowered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsLowered(), "the gloves are asked to be lowered");

        const auto Hand = Get_HandWorld();
        const auto Lowered = FTransform(FRotator(_Lower.PitchDeg, 0.0, 0.0), _Lower.Offset);
        const auto Error = Hand.GetLocation().Distance(Get_CarriedLocation(Lowered));
        Assert_True(Error < 0.5, f"the gloves sit where the Lower pose carries them (off by {Error} cm)");
        Assert_Equals_Float(Hand.Rotator().Pitch, _Lower.PitchDeg, 0.1, "the gloves pitch by Lower.PitchDeg");
        Assert_Equals_Float(Hand.Rotator().Yaw, k_Yaw, 0.1, "the gloves keep the view's yaw");

        const auto Rest = Get_CarriedLocation(FTransform::Identity);
        Assert_True(Hand.GetLocation().Z < Rest.Z - 5.0, f"lowered, the gloves sit lower (at {Hand.GetLocation().Z}, at rest {Rest.Z})");
    }

    UFUNCTION()
    private void Step_Raise(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetLowered(FMars_Request_FPHands_SetLowered(false));
    }

    UFUNCTION()
    private void Check_FullyRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_IsLowered() == false && _Hands.Get_LowerAlpha() <= 0.0f
            && Get_HandWorld().GetLocation().Distance(Get_CarriedLocation(FTransform::Identity)) < 0.5);
    }

    UFUNCTION()
    private void Step_AssertRaised(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandWorld();
        Assert_Equals_Float(Hand.Rotator().Pitch, 0.0f, 0.1, "raised, the gloves are level with the view again");
    }
}
