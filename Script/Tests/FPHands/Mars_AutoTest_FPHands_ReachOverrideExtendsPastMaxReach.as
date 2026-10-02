// MaxReachCm is a look cap, and a grip may carry its own: a grip 90 cm from the glove's rest stretches 60 under the spec's
// MaxReachCm 60, and all 90 under the grip's ReachOverrideCm 100. An authored grip matches the socket's rotation either
// way, even past the cap. Pure: Make_ReachedGrip on hand-built grip queries.
class UMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the cap holds without an override, the override extends it, the authored rotation is matched", n"Step_AssertReach");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_FPHands_ReachSpec();
        Spec.MaxReachCm = 60.0f;

        const auto SocketRotation = FQuat(FRotator(10.0, 20.0, 30.0));
        auto Grip = FMars_FPHands_GripQuery(FTransform::Identity, true, FTransform::Identity);
        Grip.WorldGrip = FTransform(SocketRotation, FVector(90.0, 0.0, 0.0), FVector::OneVector);
        Grip.IsAuthored = true;
        Grip.Standoff = 0.0;

        const auto Capped = utils_fphands::Make_ReachedGrip(Spec, Grip);
        const auto CappedLength = Capped.GetLocation().Size();
        Assert_True(Math::Abs(CappedLength - 60.0) <= 0.01, f"no override: the glove stretches MaxReachCm (got {CappedLength})");
        AssertRotationMatches(Capped, SocketRotation, "no override, past the cap");

        Grip.ReachOverrideCm = 100.0f;
        const auto Extended = utils_fphands::Make_ReachedGrip(Spec, Grip);
        const auto ExtendedLength = Extended.GetLocation().Size();
        Assert_True(Math::Abs(ExtendedLength - 90.0) <= 0.01, f"override 100: the glove reaches the grip (got {ExtendedLength})");
        AssertRotationMatches(Extended, SocketRotation, "override 100");
    }

    private void AssertRotationMatches(const FTransform& InReached, const FQuat& InExpected, const FString& InCase)
    {
        const auto Forward = InReached.GetRotation().GetForwardVector().Distance(InExpected.GetForwardVector());
        const auto Up = InReached.GetRotation().GetUpVector().Distance(InExpected.GetUpVector());
        Assert_True(Forward <= 0.001 && Up <= 0.001, f"{InCase}: the authored grip's rotation is matched (forward off {Forward}, up off {Up})");
    }
}
