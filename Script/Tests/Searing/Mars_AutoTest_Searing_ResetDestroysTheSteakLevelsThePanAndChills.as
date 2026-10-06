// A reset mid-session (hot, tilted, one face seared) destroys the steak, spawns a fresh raw one, levels and chills the
// pan and zeroes the tally.
class UMars_AutoTest_Searing_ResetDestroysTheSteakLevelsThePanAndChills : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    private FCk_Handle _OldSteak;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Spec, PanSpec);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the steak landed on the pan", n"Check_OnPan", 0, 3.0f);
        Add_Step("tilt the pan", n"Step_Tilt");
        Add_Step_WaitUntil("the face on the pan seared", n"Check_DownFaceSeared", 0, 2.0f);
        Add_Step("reset", n"Step_Reset");
        Add_Step_WaitUntil("the old steak is gone and a fresh one spawned", n"Check_ResetDone", 0, 2.0f);
        Add_Step("a fresh raw steak on a level, cold pan with a zero tally", n"Step_AssertReset");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Tilt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Look(FVector(15.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OldSteak = _Searing.Get_Steak();
        Assert_True(ck::IsValid(_OldSteak), "a steak is on the pan before the reset");
        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, 18.0, 0.01, "the pan is tilted before the reset");
        Assert_True(_Searing.Get_SearedFaceCount() >= 1, "a face is seared before the reset");
        Assert_True(_Searing.Get_IsHot(), "the pan is hot before the reset");

        _Searing.Request_Reset(FMars_Request_Searing_Reset());
    }

    UFUNCTION()
    private void Check_ResetDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Spawned.Num() >= 2 && ck::Is_NOT_Valid(_OldSteak));
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Spawned.Num(), 2, "OnSteakSpawned fired again after the reset");
        const auto Fresh = _Searing.Get_Steak();
        Assert_True(ck::IsValid(Fresh), "the fresh steak is live");
        Assert_True(Fresh != _OldSteak, "the fresh steak is a different entity");

        const auto Tilt = _Searing.Get_PanTilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "the reset levelled the roll");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "the reset levelled the pitch");
        Assert_Equals_Float(_Searing.Get_PanLift(), 0.0, 0.001, "no lift after the reset");

        Assert_False(_Searing.Get_IsHot(), "the reset chilled the pan");
        Assert_True(_Heats.Num() > 0 && _Heats.Last() == EMars_Searing_Heat::Cold, "OnHeatChanged reported the chill");

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            Assert_Equals_Float(_Searing.Get_FaceSear(Face), 0.0, 0.0001, f"face {utils_searing::Get_FaceName(Face)} is raw");
        }

        const auto Tally = _Searing.Get_Tally();
        Assert_Equals_Float(Tally.Seconds, 0.0, 0.0001, "the tally's seconds are zero");
        Assert_Equals_Int(Tally.Flips, 0, "the tally's flips are zero");
        Assert_Equals_Int(Tally.Losses, 0, "the tally's losses are zero");
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 0, "nothing lingers");
    }
}
