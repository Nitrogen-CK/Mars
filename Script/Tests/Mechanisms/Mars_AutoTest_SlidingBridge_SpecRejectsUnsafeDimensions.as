// Validation is exercised without constructing malformed entities or suppressing production ensures.
class UMars_AutoTest_SlidingBridge_SpecRejectsUnsafeDimensions : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("reject invalid storage, cage, guards and drive values", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Good = FMars_SlidingBridge_Spec();
        Assert_True(Good.Validate().IsValid(), "approved default dimensions validate");

        auto Invalid = Good;
        Invalid.DeckWidth = 0.0;
        Assert_False(Invalid.Validate().IsValid(), "zero width is rejected");
        Invalid = Good;
        Invalid.DeckThickness = -20.0;
        Assert_False(Invalid.Validate().IsValid(), "negative deck thickness is rejected");
        Invalid = Good;
        Invalid.Travel = Good.DeckLength - 1.0;
        Assert_False(Invalid.Validate().IsValid(), "leaf must fully store off the gap");
        Invalid = Good;
        Invalid.TurnsToExtend = 0.0f;
        Assert_False(Invalid.Validate().IsValid(), "a zero-turn haul is rejected");
        Invalid = Good;
        Invalid.MoveDuration = -1.0f;
        Assert_False(Invalid.Validate().IsValid(), "negative movement duration is rejected");
        Invalid = Good;
        Invalid.CageWallThickness = Good.DeckWidth * 0.5;
        Assert_False(Invalid.Validate().IsValid(), "walls cannot consume the clear passage");
        Invalid = Good;
        Invalid.CanopyThickness = Good.CageHeight;
        Assert_False(Invalid.Validate().IsValid(), "canopy cannot consume headroom");
        Invalid = Good;
        Invalid.GuardWidth = 200.0;
        Assert_False(Invalid.Validate().IsValid(), "guards must seal the full clear width");
        Invalid = Good;
        Invalid.NearGuardOffset.Y = -500.0;
        Assert_False(Invalid.Validate().IsValid(), "guard cannot admit boarding the stored leaf");
        Invalid = Good;
        Invalid.FarGuardOffset.Y = 1000.0;
        Assert_False(Invalid.Validate().IsValid(), "far guard cannot intersect the moving leaf");
        Invalid = Good;
        Invalid.GuardRaise = 100.0;
        Assert_False(Invalid.Validate().IsValid(), "guard must rise clear of its full opening");
        Invalid = Good;
        Invalid.DeckLength = Math::Sqrt(-1.0);
        Assert_False(Invalid.Validate().IsValid(), "non-finite dimensions are rejected");
        Invalid = Good;
        Invalid.DrivePath.Add(FVector(0.0, Math::Sqrt(-1.0), 0.0));
        Assert_False(Invalid.Validate().IsValid(), "non-finite drive path points are rejected");
    }
}
