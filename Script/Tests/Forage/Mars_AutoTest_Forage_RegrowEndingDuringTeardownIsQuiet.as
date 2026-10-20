// A source torn down with its regrow about to end tears down quietly: a one-charge source regrowing after 0.01 s is
// exhausted (regrow timer pending) and destroyed from the same poll that sees the timer, so the timer finishes in the
// frames its owner is going away. The source and its timer both end invalid, nothing replenishes, and no ensure fires
// (an ensure would fail this test: it has no expected errors). Whether a run lands the timer's finish exactly in the
// owner-gone window depends on frame timing; the guard in OnRegrowDone covers it either way.
class UMars_AutoTest_Forage_RegrowEndingDuringTeardownIsQuiet : UMars_AutoTestRig_Forage
{
    private const FVector k_Origin = FVector(-60000.0, 60000.0, -60000.0);

    private FCk_Handle_Timer _RegrowTimer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddSource(InHandle, k_Origin);
        AddForage(Make_RockSpec(1, FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, 0.01f)));

        Add_Step("request a release", n"Step_Release");
        Add_Step_WaitUntil("exhausted with a regrow pending; destroy the source at once", n"Check_PendingThenDestroy", k_SlowPolls, 0);
        Add_Step_WaitUntil("the source and its regrow timer are gone", n"Check_Gone", k_SlowPolls, 0);
        Add_Step("it never replenished", n"Step_AssertQuiet");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestRelease(EMars_Forage_ReleaseReason::Depleted);
    }

    UFUNCTION()
    private void Check_PendingThenDestroy(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pending = _Forage.Get_IsExhausted() && _Forage.Get_IsRegrowPending();
        if (Pending)
        {
            _RegrowTimer = _Forage.Get_Fragment(FMars_Fragment_Forage).RegrowTimer;
            utils_entity_lifetime::Request_DestroyEntity(_Source);
        }

        auto Res = OutResult;
        Res.Set(Pending);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Source) && ck::Is_NOT_Valid(_RegrowTimer));
    }

    UFUNCTION()
    private void Step_AssertQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "the one charge was released");
        Assert_Equals_Int(_ExhaustedCount, 1, "exhausted once");
        Assert_Equals_Int(_ReplenishedCount, 0, "a torn-down source never replenishes");
    }
}
