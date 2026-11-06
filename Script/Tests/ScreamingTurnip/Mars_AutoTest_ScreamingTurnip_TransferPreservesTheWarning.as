// A settled root picked up mid-warning keeps its warning across the transfer: from the pickup until it is Held,
// WarningElapsed never drops below what it was (frozen while the mount is in flight, never zeroed), nothing commits on the
// way, and the scream comes earlier after it is Held than a fresh warning would allow.
class UMars_AutoTest_ScreamingTurnip_TransferPreservesTheWarning : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 6000.0, -30000.0);

    private FMars_ScreamingTurnip_Vocal _Vocal;
    private float32 _ElapsedAtPickup = 0.0f;
    private float32 _MinElapsedInTransfer = 1000.0f;
    private bool _SawTransfer = false;
    private float32 _HeldAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A long Inhale so the pickup lands inside the warning.
        _Vocal = Make_ShortVocal();
        _Vocal.AnticipateSeconds = 0.2f;
        _Vocal.InhaleSeconds = 1.5f;

        Build_Floor(InHandle);
        Build_Carrier(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 10.0), _Vocal);

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step_WaitUntil("it settles on the slab", n"Check_FirstSettled", k_SlowPolls);
        Add_Step_WaitUntil("its warning is into the Inhale", n"Check_IntoInhale", k_SlowPolls);
        Add_Step("pick it up mid-warning", n"Step_PickUp");
        Add_Step_WaitUntil("it is Held, the warning tracked through the transfer", n"Check_HeldTracking", k_SlowPolls);
        Add_Step("the warning survived the transfer", n"Step_AssertPreserved");
        Add_Step_WaitUntil("it screams in the hands", n"Check_OneScream", k_SlowPolls);
        Add_Step("sooner than a fresh warning", n"Step_AssertEarly");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_IntoInhale(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        const auto Turnip = _Turnips[0];
        auto Res = OutResult;
        Res.Set(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Inhale && Turnip.Get_WarningElapsed() >= _Vocal.AnticipateSeconds + 0.1f);
    }

    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ElapsedAtPickup = _Turnips[0].Get_WarningElapsed();
        Stow(_WorldItems[0]);
    }

    UFUNCTION()
    private void Check_HeldTracking(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        const auto Turnip = _Turnips[0];
        const auto Placement = Turnip.Get_Placement();
        if (Placement == EMars_ScreamingTurnip_Placement::Transfer)
        { _SawTransfer = true; }

        if (Placement != EMars_ScreamingTurnip_Placement::Held)
        { _MinElapsedInTransfer = Math::Min(_MinElapsedInTransfer, Turnip.Get_WarningElapsed()); }

        auto Res = OutResult;
        Res.Set(Placement == EMars_ScreamingTurnip_Placement::Held);
    }

    UFUNCTION()
    private void Step_AssertPreserved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_True(_SawTransfer, "the pickup passed through Transfer");
        Assert_True(_MinElapsedInTransfer >= _ElapsedAtPickup - 0.001f,
            f"the warning was never reset on the way ({_MinElapsedInTransfer :.3} s >= {_ElapsedAtPickup :.3} s at the pickup)");
        Assert_Equals_Int(_Commits.Num(), 0, "nothing committed on the way");
        _HeldAt = TryGet_EnteredAt(Turnip, EMars_ScreamingTurnip_Placement::Held, 0.0f).Get(Turnip.Get_Clock());
    }

    UFUNCTION()
    private void Check_OneScream(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Commits.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertEarly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Warning = _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds;
        const auto FromHeld = _Commits[0].At - _HeldAt;
        const auto Expected = Warning - _ElapsedAtPickup;
        Assert_True(FromHeld < Warning - 0.05f, f"the scream came {FromHeld :.3} s after the hold, sooner than a fresh {Warning :.3} s warning");
        Assert_True(FromHeld <= Expected + _MaxTick + 0.001f,
            f"the warning resumed where the pickup left it ({FromHeld :.3} s <= the {Expected :.3} s it had left)");
    }
}
