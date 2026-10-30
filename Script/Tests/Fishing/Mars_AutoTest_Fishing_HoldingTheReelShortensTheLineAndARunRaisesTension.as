// With runs every 0.1 s that last 10 s, the fish is soon running: a released reel loses line to the run and strains
// nothing; a held reel takes line in faster than the run gives it and strains the line (OnRun started); releasing lets the
// strain recover. The snap is set out of reach.
class UMars_AutoTest_Fishing_HoldingTheReelShortensTheLineAndARunRaisesTension : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 20.0f;

    private float32 _LengthAtReeling = 0.0f;
    private float32 _LengthAfterRun = 0.0f;
    private float32 _TensionAfterHold = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Run.MinGapSeconds = 0.1f;
        Spec.Run.MaxGapSeconds = 0.1f;
        Spec.Run.MinRunSeconds = 10.0f;
        Spec.Run.MaxRunSeconds = 10.0f;
        Spec.Run.PullCmPerS = 50.0f;
        Spec.Reel.ReelSpeedCmPerS = 400.0f;
        Spec.Reel.TensionGainPerS = 0.5f;
        Spec.Reel.RunTensionGainPerS = 2.0f;
        Spec.Reel.RecoveryPerS = 1.0f;
        Spec.Reel.SnapTension = 100.0f;
        Spec.Reel.HookTension = 0.0f;
        BuildFishing(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite");
        Add_Step("strike the hook", n"Step_Hook");
        Add_Step_WaitUntil("the fight is on", n"Check_Reeling");
        Add_Step("note the line out", n"Step_NoteLength");
        Add_Step_WaitUntil("the fish runs", n"Check_Running");
        Add_Step_WaitSeconds("the run pulls line with the reel released", 0.3f);
        Add_Step("the run took line and strained nothing", n"Step_AssertRunTookLine");
        Add_Step("hold the reel", n"Step_Hold");
        Add_Step_WaitSeconds("reel against the run", 0.3f);
        Add_Step("the held reel took line and strained it", n"Step_AssertHoldTookLine");
        Add_Step("release the reel", n"Step_Release");
        Add_Step_WaitSeconds("the strain recovers", 0.3f);
        Add_Step("the released reel let the strain recover", n"Step_AssertRecovered");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_NoteLength(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LengthAtReeling = _Fishing.Get_LineLengthCm();
        Assert_True(_LengthAtReeling > 100.0f, f"a line is out ({_LengthAtReeling} cm)");
    }

    UFUNCTION()
    private void Check_Running(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_IsRunning());
    }

    UFUNCTION()
    private void Step_AssertRunTookLine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LengthAfterRun = _Fishing.Get_LineLengthCm();
        Assert_True(_RunStarts >= 1, "OnRun started");
        Assert_True(_Fishing.Get_IsRunning(), "the fish is still running");
        Assert_True(_LengthAfterRun > _LengthAtReeling + 5.0f, f"the run pulled line out ({_LengthAtReeling} -> {_LengthAfterRun})");
        Assert_Equals_Float(_Fishing.Get_Tension(), 0.0f, 0.0f, "a released reel strains nothing");
    }

    UFUNCTION()
    private void Step_AssertHoldTookLine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Length = _Fishing.Get_LineLengthCm();
        _TensionAfterHold = _Fishing.Get_Tension();
        Assert_True(_Fishing.Get_Reel() == EMars_Fishing_Reel::Held, "the reel is held");
        Assert_True(Length < _LengthAfterRun - 50.0f, f"the held reel took line in against the run ({_LengthAfterRun} -> {Length})");
        Assert_True(_TensionAfterHold > 0.3f, f"the held reel strained the line through the run ({_TensionAfterHold})");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Reeling, "the line held");
    }

    UFUNCTION()
    private void Step_AssertRecovered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Reel() == EMars_Fishing_Reel::Released, "the reel is released");
        Assert_True(_Fishing.Get_Tension() < _TensionAfterHold - 0.1f, f"the strain recovered ({_TensionAfterHold} -> {_Fishing.Get_Tension()})");
        Assert_Equals_Int(_Snaps, 0, "the line never snapped");
    }
}
