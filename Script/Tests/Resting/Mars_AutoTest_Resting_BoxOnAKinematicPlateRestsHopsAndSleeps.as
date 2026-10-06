// A dynamic box dropped onto a kinematic plate comes to rest on it; the plate jumping 15 uu over two frames and back
// throws the box clear (Apart), and it lands again: one hop, one OnLanded. Left alone it stays Resting, asleep or not
// (Jolt reports no contacts for a sleeping pair; the Resting keeps its verdict while the body sleeps).
class UMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps : UMars_AutoTestRig_Resting
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_HopRaise = 15.0f;

    private int32 _StatesBeforeHop = 0;
    private float32 _MaxPlateRaise = 0.0f;
    private float32 _WatchStart = -1.0f;
    private float32 _AsleepAfter = -1.0f;
    private bool _LeftRestingWhileWatched = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildRig(InHandle);

        Add_Step("the rig composed", n"Step_AssertComposed");
        Add_Step_WaitUntil("the box rests on the plate", n"Check_Resting", 0, 1.0f);
        Add_Step("the drop was no hop; raise the plate half way", n"Step_AssertRestedThenRaiseHalf");
        Add_Step_WaitFrames("the plate rises", 1);
        Add_Step("raise the plate the rest of the way", n"Step_RaiseFull");
        Add_Step_WaitFrames("the plate rises", 1);
        Add_Step("drop the plate back to rest", n"Step_Lower");
        Add_Step_WaitUntil("the box left the plate", n"Check_ApartAfterHop", 0, 1.0f);
        Add_Step_WaitUntil("the box landed again", n"Check_LandedAgain", 0, 3.0f);
        Add_Step("one hop, one landing", n"Step_AssertHop");
        Add_Step_WaitUntil("the box stayed on the plate (asleep or not)", n"Check_Watched", 0, 3.5f);
        Add_Step("the box is still resting", n"Step_AssertStillResting");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Resting), "the feature composed");
        const FCk_Handle PlateEntity = _PlateBody;
        Assert_True(_Resting.Get_Target() == PlateEntity, "the target is the plate body's entity");
        Assert_False(_Resting.Get_IsResting(), "the box starts Apart");
    }

    UFUNCTION()
    private void Step_AssertRestedThenRaiseHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resting.Get_Hops(), 0, "the 2 uu drop is no hop");
        Assert_Equals_Int(_Landings.Num(), 0, "no OnLanded for the drop");
        Assert_True(_States.Num() == 1 && _States[0] == EMars_Resting_State::Resting, "OnRestingChanged reported Resting once");

        _StatesBeforeHop = _States.Num();
        Set_PlateRaise(k_HopRaise * 0.5f);
    }

    UFUNCTION()
    private void Step_RaiseFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_PlateRaise();
        Set_PlateRaise(k_HopRaise);
    }

    UFUNCTION()
    private void Step_Lower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_PlateRaise();
        Set_PlateRaise(0.0f);
    }

    UFUNCTION()
    private void Check_ApartAfterHop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_PlateRaise();
        auto Apart = false;
        for (int32 Index = _StatesBeforeHop; Index < _States.Num(); ++Index)
        {
            if (_States[Index] == EMars_Resting_State::Apart)
            { Apart = true; }
        }

        auto Res = OutResult;
        Res.Set(Apart);
    }

    UFUNCTION()
    private void Check_LandedAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resting.Get_IsResting() && _Resting.Get_Hops() >= 1);
    }

    UFUNCTION()
    private void Step_AssertHop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resting.Get_Hops(), 1, "the throw was one hop");
        Assert_Equals_Int(_Landings.Num(), 1, "OnLanded fired once");
        if (_Landings.Num() > 0)
        {
            Assert_True(_Landings[0] >= _Resting.Get_Spec().HopMinSeconds,
                f"the landing came after at least HopMinSeconds apart (got {_Landings[0]})");
            ck::Trace(f"[Resting] hop: plate raise seen {_MaxPlateRaise :.2} uu, apart {_Landings[0] :.3} s");
        }

        _WatchStart = Get_Now();
    }

    // Samples the verdict every check: the box must stay Resting for 1.5 s, and the watch runs on to 3 s for the sleep.
    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Elapsed = Get_Now() - _WatchStart;
        if (_Resting.Get_IsResting() == false)
        { _LeftRestingWhileWatched = true; }

        if (_AsleepAfter < 0.0f && utils_jolt_body::Get_SleepState(_BoxBody) == ECk_Jolt_SleepState::Asleep)
        { _AsleepAfter = Elapsed; }

        auto Res = OutResult;
        Res.Set(Elapsed >= 1.5f && (_AsleepAfter >= 0.0f || Elapsed >= 3.0f));
    }

    UFUNCTION()
    private void Step_AssertStillResting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_LeftRestingWhileWatched, "the box never left Resting while it lay on the plate");
        Assert_True(_Resting.Get_IsResting(), "the box is still resting");
        Assert_Equals_Int(_Resting.Get_Hops(), 1, "no further hop");

        if (_AsleepAfter >= 0.0f)
        { ck::Trace(f"[Resting] sleep: asleep {_AsleepAfter :.3} s after the landing was asserted; still Resting"); }
        else
        { ck::Trace("[Resting] sleep: not reached within 3 s (the kinematic plate may keep the pair awake); still Resting"); }
    }

    private void Record_PlateRaise()
    {
        const auto PlateZ = utils_transform::Get_EntityCurrentTransform(_PlateBody.As_Transform()).GetLocation().Z;
        _MaxPlateRaise = Math::Max(_MaxPlateRaise, float32(PlateZ - (k_Origin.Z + k_PlateRestZ)));
    }
}
