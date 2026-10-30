// A hook struck inside the window sets (OnBiteEnded Hooked, the float un-dips, the tension starts at HookTension) and
// the fight begins (Reeling after HookSetSeconds). After a reset and a second cast, a bite left alone closes its 0.5 s
// window Missed (OnBiteEnded Missed) and the spot is Waiting again; a hook struck then is ignored.
class UMars_AutoTest_Fishing_HookInsideTheWindowHooksAndOutsideMisses : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Bite.HookWindowSeconds = 0.5f;
        BuildFishing(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite");
        Add_Step("strike the hook", n"Step_Hook");
        Add_Step_WaitUntil("the fight is on", n"Check_Reeling");
        Add_Step("the bite ended hooked", n"Step_AssertHooked");
        Add_Step("reset and cast again", n"Step_ResetAndCast");
        Add_Step_WaitUntil("a second fish bites", n"Check_SecondBite");
        Add_Step_WaitUntil("the window closes unhooked", n"Check_Waiting");
        Add_Step("the bite ended missed", n"Step_AssertMissed");
        Add_Step("strike the hook with no bite", n"Step_Hook");
        Add_Step_WaitSeconds("a beat", 0.15f);
        Add_Step("the late hook was ignored", n"Step_AssertLateHookIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertHooked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Fishing.Get_Spec();
        Assert_Equals_Int(_BitesHooked, 1, "one OnBiteEnded Hooked");
        Assert_Equals_Int(_BitesMissed, 0, "no OnBiteEnded Missed");
        Assert_Equals_Int(Count_PhaseSeen(EMars_Fishing_Phase::Hooked), 1, "Hooked was broadcast once");
        Assert_Equals_Float(_Fishing.Get_Bait().DipCm, 0.0f, 0.0f, "the float un-dipped");
        Assert_True(_Fishing.Get_Tension() >= Spec.Reel.HookTension - 0.01f, f"the tension started at HookTension ({_Fishing.Get_Tension()})");
        Assert_True(_Fishing.Get_Catch().Item.IsNull() == false, "a fish is on the line");
    }

    UFUNCTION()
    private void Step_ResetAndCast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Reset(FMars_Request_Fishing_Reset());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
    }

    UFUNCTION()
    private void Check_SecondBite(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bites >= 2);
    }

    UFUNCTION()
    private void Step_AssertMissed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Casts, 2, "the reset let a second cast through in the same drain");
        Assert_Equals_Int(_BitesMissed, 1, "one OnBiteEnded Missed");
        Assert_Equals_Int(_BitesHooked, 1, "still one hooked");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Waiting, "the spot is Waiting again");
        Assert_Equals_Float(_Fishing.Get_Bait().DipCm, 0.0f, 0.0f, "the float un-dipped on the miss");
    }

    UFUNCTION()
    private void Step_AssertLateHookIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_BitesHooked, 1, "a hook struck while Waiting hooked nothing");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Waiting || _Fishing.Get_Phase() == EMars_Fishing_Phase::Bite,
            f"the spot is Waiting or on a fresh bite ({_Fishing.Get_Phase() :n})");
    }
}
