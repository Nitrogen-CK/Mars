// The default spec validates; one detent, and a start off the ring on either side, are rejected.
class UMars_AutoTest_Dial_SpecValidation : UMars_AutoTestRig_Dial
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the default validates and each broken spec fails", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(FMars_Dial_Spec().Validate().IsValid(), "six detents from 0 validates");
        Assert_True(Make_Spec(2, 1).Validate().IsValid(), "two detents from the last validates");

        Assert_False(Make_Spec(1, 0).Validate().IsValid(), "one detent is rejected");
        Assert_False(Make_Spec(6, 6).Validate().IsValid(), "a start past the last detent is rejected");
        Assert_False(Make_Spec(6, -1).Validate().IsValid(), "a negative start is rejected");
    }
}
