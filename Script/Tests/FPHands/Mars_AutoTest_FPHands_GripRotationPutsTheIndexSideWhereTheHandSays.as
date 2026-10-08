// A grip authored by intent (fingers, palm) puts each glove's index side where that hand has it: a palm-down right
// hand's on its left, a left hand's on its right. Pure: utils_fphands::Make_GripRotation and its inverse Get_GripFingers.
class UMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // Palm down, fingers forward: the feed rest and the free hand.
        const auto RightFlat = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::UpVector);
        const auto LeftFlat = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        AssertNear(RightFlat.GetForwardVector(), -FVector::RightVector, "right hand flat: the index side is on the left");
        AssertNear(LeftFlat.GetForwardVector(), FVector::RightVector, "left hand flat: the index side is on the right");
        AssertNear(RightFlat.GetUpVector(), -FVector::UpVector, "right hand flat: the palm faces down");
        AssertNear(LeftFlat.GetUpVector(), -FVector::UpVector, "left hand flat: the palm faces down");
        AssertNear(utils_fphands::Get_GripFingers(EMars_Hand::Right, RightFlat), FVector::ForwardVector,
            "right hand flat: the fingers read back forward");
        AssertNear(utils_fphands::Get_GripFingers(EMars_Hand::Left, LeftFlat), FVector::ForwardVector,
            "left hand flat: the fingers read back forward");

        // A handshake grip on a bar running away from the operator (the cleaver, the lever): the hand leads along it.
        const auto Handshake = utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::UpVector, -FVector::RightVector);
        AssertNear(Handshake.GetForwardVector(), FVector::ForwardVector, "right handshake: the index side leads along the bar");

        // Fingers that lean into the palm are flattened onto it, so they give the same frame as fingers laid flat.
        const auto Leaning = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector(1.0, 0.0, -0.5), -FVector::UpVector);
        AssertNear(Leaning.GetForwardVector(), RightFlat.GetForwardVector(), "right hand, leaning fingers: the same index side");
        AssertNear(Leaning.GetUpVector(), RightFlat.GetUpVector(), "right hand, leaning fingers: the same palm");

        TArray<FVector> Palms;
        Palms.Add(FVector(0.3, -0.8, 0.5));
        Palms.Add(FVector(-1.0, 0.2, 0.1));
        Palms.Add(FVector(0.2, 0.3, -0.9));
        TArray<FVector> Fingers;
        Fingers.Add(FVector(0.6, 0.4, 0.2));
        Fingers.Add(FVector(0.1, 0.9, -0.4));
        Fingers.Add(FVector(-0.7, 0.5, 0.1));
        for (int32 Index = 0; Index < Palms.Num(); ++Index)
        {
            const auto Palm = Palms[Index].GetSafeNormal();
            const auto Flattened = (Fingers[Index] - Palm * Fingers[Index].DotProduct(Palm)).GetSafeNormal();

            const auto Right = utils_fphands::Make_GripRotation(EMars_Hand::Right, Fingers[Index], Palms[Index]);
            AssertNear(utils_fphands::Get_GripFingers(EMars_Hand::Right, Right), Flattened,
                f"right hand, case {Index}: the fingers round-trip");
            AssertNear(Right.GetUpVector(), Palm, f"right hand, case {Index}: the palm round-trips");

            const auto Left = utils_fphands::Make_GripRotation(EMars_Hand::Left, Fingers[Index], Palms[Index]);
            AssertNear(utils_fphands::Get_GripFingers(EMars_Hand::Left, Left), Flattened,
                f"left hand, case {Index}: the fingers round-trip");
            AssertNear(Left.GetUpVector(), Palm, f"left hand, case {Index}: the palm round-trips");
        }

        FinishSuccess();
    }

    private void AssertNear(FVector InActual, FVector InExpected, const FString& InCase)
    {
        const auto Off = InActual.Distance(InExpected);
        Assert_True(Off <= 0.001, f"{InCase}: expected {InExpected}, got {InActual} (off {Off})");
    }
}
