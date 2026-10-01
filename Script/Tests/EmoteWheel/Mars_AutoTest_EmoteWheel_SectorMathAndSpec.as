// Sector 0 is centred on the top and indices run clockwise in screen space (Y down); the dead zone hovers nothing; the
// layout point of a sector lies on the same centre line the hit test uses. The spec needs a definition, a positive
// travel and a dead zone inside the wheel.
class UMars_AutoTest_EmoteWheel_SectorMathAndSpec : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("check the sector math", n"Step_SectorMath");
        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SectorMath(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(0.0, -1.0), 8, 0.25f) == 0, "up is sector 0");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(1.0, 0.0), 8, 0.25f) == 2, "right is sector 2 of 8");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(0.0, 1.0), 8, 0.25f) == 4, "down is sector 4 of 8");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(-1.0, 0.0), 8, 0.25f) == 6, "left is sector 6 of 8");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(-0.1, -1.0), 8, 0.25f) == 0, "just left of up wraps to sector 0");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(1.0, 0.0), 4, 0.25f) == 1, "right is sector 1 of 4");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(0.1, -0.1), 8, 0.25f) == -1, "inside the dead zone hovers nothing");
        Assert_True(utils_emote_wheel::Get_SectorAt(FVector2D(0.0, -1.0), 0, 0.25f) == -1, "an empty wheel hovers nothing");

        // 30 degrees clockwise from the top: past the 22.5 boundary of 8 sectors, inside sector 0 of 4 (45 wide).
        const auto ThirtyDegrees = FVector2D(Math::Sin(Math::DegreesToRadians(30.0)), -Math::Cos(Math::DegreesToRadians(30.0)));
        Assert_True(utils_emote_wheel::Get_SectorAt(ThirtyDegrees, 8, 0.25f) == 1, "30 degrees is sector 1 of 8");
        Assert_True(utils_emote_wheel::Get_SectorAt(ThirtyDegrees, 4, 0.25f) == 0, "30 degrees is sector 0 of 4");

        for (int32 Index = 0; Index < 8; ++Index)
        {
            const auto Point = utils_emote_wheel::Get_SectorPoint(Index, 8, 1.0f);
            Assert_True(utils_emote_wheel::Get_SectorAt(Point, 8, 0.25f) == Index, f"the layout point of sector {Index} hits sector {Index}");
        }
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Configured = mars::Mars_PlayerCharacter_Config.EmoteWheel.Validate();
        Assert_True(Configured.IsValid, f"the player's configured spec is valid ({Configured.Get_Error()})");

        const auto NoDefinition = FMars_EmoteWheel_Spec().Validate();
        Assert_False(NoDefinition.IsValid, f"a spec without a definition is rejected ({NoDefinition.Get_Error()})");

        auto NoTravel = mars::Mars_PlayerCharacter_Config.EmoteWheel;
        NoTravel.PointerTravel = 0.0f;
        Assert_False(NoTravel.Validate().IsValid, "a zero pointer travel is rejected");

        auto FullDeadZone = mars::Mars_PlayerCharacter_Config.EmoteWheel;
        FullDeadZone.DeadZoneRatio = 1.0f;
        Assert_False(FullDeadZone.Validate().IsValid, "a dead zone covering the whole wheel is rejected");
    }
}
