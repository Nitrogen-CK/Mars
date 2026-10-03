// A FaceViewer grip keeps only its bar: the glove takes it the way it would from where the player stands. Pure:
// utils_fphands::Make_ViewerFacingGrip on a vertical bar authored palm-forward, seen with the rest palm facing left, then
// from the other side (rest palm facing right), then authored upside down (the bar's X pointing down).
class UMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the bar is kept, the palm turns to the player's side, an upside-down bar is taken thumb-up", n"Step_AssertRoll");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRoll(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Authored: bar up (X), palm forward (Z) - the hand would sit behind the bar from a player looking along +X.
        const auto Authored = FQuat(FRotator::MakeFromXZ(FVector::UpVector, FVector::ForwardVector));

        // Rest seen from the player: thumb side up (X), palm facing left (Z = -Y).
        const auto RestLeft = FQuat(FRotator::MakeFromXZ(FVector::UpVector, -FVector::RightVector));
        const auto FromFront = utils_fphands::Make_ViewerFacingGrip(Authored, RestLeft);
        AssertAxes(FromFront, FQuat(FRotator::MakeFromXZ(FVector::UpVector, -FVector::RightVector)), "seen from the front");

        // The player walks around: the rest palm now faces +Y in world; the grip follows the player, not the lever.
        const auto RestRight = FQuat(FRotator::MakeFromXZ(FVector::UpVector, FVector::RightVector));
        const auto FromBehind = utils_fphands::Make_ViewerFacingGrip(Authored, RestRight);
        AssertAxes(FromBehind, FQuat(FRotator::MakeFromXZ(FVector::UpVector, FVector::RightVector)), "seen from the other side");

        // A bar authored pointing down is still taken thumb-up: the index end is chosen, not inherited.
        const auto UpsideDown = FQuat(FRotator::MakeFromXZ(-FVector::UpVector, FVector::ForwardVector));
        const auto Flipped = utils_fphands::Make_ViewerFacingGrip(UpsideDown, RestLeft);
        AssertAxes(Flipped, FQuat(FRotator::MakeFromXZ(FVector::UpVector, -FVector::RightVector)), "authored upside down");
    }

    // InExpected's X is the bar, its Z the palm normal.
    private void AssertAxes(const FQuat& InGrip, const FQuat& InExpected, const FString& InCase)
    {
        const auto Bar = InExpected.GetForwardVector();
        const auto Palm = InExpected.GetUpVector();
        const auto BarOff = InGrip.GetForwardVector().Distance(Bar);
        const auto PalmOff = InGrip.GetUpVector().Distance(Palm);
        Assert_True(BarOff <= 0.001, f"{InCase}: the grip's bar runs {Bar} (off {BarOff})");
        Assert_True(PalmOff <= 0.001, f"{InCase}: the palm faces {Palm} (off {PalmOff})");
    }
}
