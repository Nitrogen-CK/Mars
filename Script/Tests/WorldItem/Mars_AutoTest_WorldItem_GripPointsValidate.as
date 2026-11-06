// An item's declared grip points (FMars_ItemPresentation_Grip::Points) validate against its handedness: none or both on a
// TwoHanded item, no Left on a OneHanded one, never a Left without a Right, every point unit scale. The Presentation's
// own Validate carries the points' verdict, and the Screaming Turnip's definition (the first item to declare points)
// validates.
class UMars_AutoTest_WorldItem_GripPointsValidate : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the points' rules", n"Step_AssertPointRules");
        Add_Step("the Presentation's Validate carries them", n"Step_AssertPresentation");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPointRules(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Point = FTransform(FRotator(10.0, 20.0, 30.0), FVector(1.0, 2.0, 3.0));
        const auto Scaled = FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(2.0, 2.0, 2.0));
        const auto Two = EMars_ItemPresentation_Handedness::TwoHanded;
        const auto One = EMars_ItemPresentation_Handedness::OneHanded;

        AssertValid(Make_Points(TOptional<FTransform>(), TOptional<FTransform>()), Two, "no points, two-handed");
        AssertValid(Make_Points(TOptional<FTransform>(Point), TOptional<FTransform>(Point)), Two, "both points, two-handed");
        AssertInvalid(Make_Points(TOptional<FTransform>(Point), TOptional<FTransform>()), Two, "a right point alone, two-handed");
        AssertInvalid(Make_Points(TOptional<FTransform>(), TOptional<FTransform>(Point)), Two, "a left point without a right");
        AssertInvalid(Make_Points(TOptional<FTransform>(), TOptional<FTransform>(Point)), One, "a left point without a right, one-handed");
        AssertValid(Make_Points(TOptional<FTransform>(Point), TOptional<FTransform>()), One, "a right point, one-handed");
        AssertInvalid(Make_Points(TOptional<FTransform>(Point), TOptional<FTransform>(Point)), One, "a left point on a one-handed item");
        AssertInvalid(Make_Points(TOptional<FTransform>(Scaled), TOptional<FTransform>(Point)), Two, "a scaled right point");
        AssertInvalid(Make_Points(TOptional<FTransform>(Point), TOptional<FTransform>(Scaled)), Two, "a scaled left point");
    }

    UFUNCTION()
    private void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
        Presentation.Grip.Points.Right = TOptional<FTransform>(FTransform::Identity);
        Assert_False(Presentation.Validate().IsValid(), "a two-handed Presentation declaring one point fails Validate");

        Presentation.Grip.Points.Left = TOptional<FTransform>(FTransform::Identity);
        Assert_True(Presentation.Validate().IsValid(), f"with both points it validates [{Presentation.Validate().Get_Error()}]");

        const UMars_ItemTrait_Presentation Turnip = mars_items::ScreamingTurnip().Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        Assert_True(Turnip.Validate().IsValid(), f"the Screaming Turnip's Presentation validates [{Turnip.Validate().Get_Error()}]");
        Assert_True(Turnip.Grip.Points.Right.IsSet() && Turnip.Grip.Points.Left.IsSet(), "the Screaming Turnip declares both points");
    }

    private FMars_ItemPresentation_GripPoints Make_Points(TOptional<FTransform> InRight, TOptional<FTransform> InLeft) const
    {
        auto Points = FMars_ItemPresentation_GripPoints();
        Points.Right = InRight;
        Points.Left = InLeft;
        return Points;
    }

    private void AssertValid(const FMars_ItemPresentation_GripPoints& InPoints, EMars_ItemPresentation_Handedness InHandedness, const FString& InCase)
    {
        const auto Validation = InPoints.Validate(InHandedness);
        Assert_True(Validation.IsValid(), f"{InCase}: valid ({Validation.Get_Error()})");
    }

    private void AssertInvalid(const FMars_ItemPresentation_GripPoints& InPoints, EMars_ItemPresentation_Handedness InHandedness, const FString& InCase)
    {
        Assert_False(InPoints.Validate(InHandedness).IsValid(), f"{InCase}: invalid");
    }
}
