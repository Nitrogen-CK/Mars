// A one-handed hold moves the hand node to the right glove (Rest.OneHandedHandOffset, through the side node) and lays the
// gloves out around the moved node, so neither glove's place changes when empty hands take a one-handed item without grip
// sockets: the lateral the hold asks of the hand node (utils_fphands::Get_HandLateral) exactly undoes each glove's change
// of rest target, and the targets carry that lateral (FMars_FPHands_HandTargets.Lateral) for the anim instance to take
// out. Empty hands and two-handed holds ask for no lateral, and the spec rejects a one-handed rest that also turns the
// node (the lateral is a translation). Pure: Get_HandLateral, Get_RestTargets and the spec's Validate.
class UMars_AutoTest_FPHands_AOneHandedHoldKeepsBothGlovesWhereTheyRested : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Rest = FMars_FPHands_RestSpec();
        const auto Frame = FMars_FPHands_TargetFrame();

        auto Empty = FMars_FPHands_Hold();
        auto OneHanded = FMars_FPHands_Hold();
        OneHanded.Kind = EMars_FPHands_HoldKind::OneHanded;
        auto TwoHanded = FMars_FPHands_Hold();
        TwoHanded.Kind = EMars_FPHands_HoldKind::TwoHanded;

        Assert_True(utils_fphands::Get_HandLateral(Rest, Empty).IsNearlyZero(), "empty hands leave the hand node centred");
        Assert_True(utils_fphands::Get_HandLateral(Rest, TwoHanded).IsNearlyZero(), "a two-handed hold leaves the hand node centred");
        const auto Lateral = utils_fphands::Get_HandLateral(Rest, OneHanded);
        AssertNear(Lateral, Rest.OneHandedHandOffset.GetLocation() - Rest.CenteredHandOffset.GetLocation(),
            "a one-handed hold moves the hand node from the centred rest to the one-handed one");
        Assert_True(Lateral.IsNearlyZero() == false, "the one-handed rest is off centre");

        const auto EmptyTargets = utils_fphands::Get_RestTargets(Rest, Empty, Frame);
        const auto HeldTargets = utils_fphands::Get_RestTargets(Rest, OneHanded, Frame);
        Assert_True(EmptyTargets.Lateral.IsNearlyZero(), "empty hands' targets are laid out at the centred node");
        AssertNear(HeldTargets.Lateral, Lateral, "a one-handed hold's targets carry the lateral they are laid out for");
        AssertNear(HeldTargets.Right.GripInHand.GetLocation() + Lateral, EmptyTargets.Right.GripInHand.GetLocation(),
            "the right glove, which takes the item, stays where it rested");
        AssertNear(HeldTargets.Left.GripInHand.GetLocation() + Lateral, EmptyTargets.Left.GripInHand.GetLocation(),
            "the free left glove stays where it rested");

        auto Root = utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto Spec = FMars_FPHands_Spec();
        Spec.HandNode = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();
        Assert_True(Spec.Validate().IsValid(), f"the default spec is valid: {Spec.Validate().Get_Error()}");
        Spec.Rest.OneHandedHandOffset.SetRotation(FQuat(FVector::UpVector, Math::DegreesToRadians(10.0)));
        Assert_True(Spec.Validate().IsValid() == false, "a one-handed rest that turns the hand node is rejected");

        FinishSuccess();
    }

    private void AssertNear(FVector InActual, FVector InExpected, const FString& InCase)
    {
        const auto Off = InActual.Distance(InExpected);
        Assert_True(Off <= 0.001, f"{InCase}: expected {InExpected}, got {InActual} (off {Off})");
    }
}
