class UMars_AutoTest_AttackCatalog_FrozenClipSurface : UMars_AutoTestRig_AttackCatalogPublicSurface
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-360000.0, -180000.0, 600.0);

    UPROPERTY()
    private UCk_ProceduralAction_Data _Source;

    UPROPERTY()
    private UCk_ProceduralAction_Data _Frozen;

    private FMars_TESTONLY_AttackCatalog_Stream _Stream;
    private float64 _OriginalDuration = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_ProbeCrawler(InHandle);
        Add_Step("copy the public draft into an independent frozen source", n"Step_CopyAndPlay");
        Add_Step_WaitUntil("the frozen pincer accepts real motion", n"Check_Accepted", k_SlowPolls, 0);
        Add_Step("edit only the test-owned mutable source", n"Step_EditSource");
        Add_Step_WaitUntil("the frozen pincer completes with its original duration", n"Check_Terminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("the acknowledged action and claw controls release", n"Check_Released", k_SlowPolls, 0);
        Add_Step("assert source isolation and unchanged accepted provenance", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private float64 Get_Duration(UCk_ProceduralAction_Data InClip) const
    {
        float64 Duration = 0.0;
        for (const auto& Phase : InClip.Get_Phases())
        { Duration += Phase.Get_Duration().Get_Seconds(); }
        return Duration;
    }

    private bool Get_AreReferenceFieldsEqual(UCk_ProceduralAction_Data InLeft, UCk_ProceduralAction_Data InRight) const
    {
        const auto Left = InLeft.Get_Phases();
        const auto Right = InRight.Get_Phases();
        if (Left.Num() != Right.Num() || InLeft.Get_Slots().Num() != InRight.Get_Slots().Num() ||
            InLeft.Get_Windows().Num() != InRight.Get_Windows().Num() || InLeft.Get_Markers().Num() != InRight.Get_Markers().Num() ||
            InLeft.Get_BodyChannel().Get_Enabled() != InRight.Get_BodyChannel().Get_Enabled())
        { return false; }
        for (int32 Index = 0; Index < Left.Num(); ++Index)
        {
            if (Left[Index].Get_Id() != Right[Index].Get_Id() ||
                Math::Abs(Left[Index].Get_Duration().Get_Seconds() - Right[Index].Get_Duration().Get_Seconds()) > 1.0e-6 ||
                Left[Index].Get_BodyKeys().Num() != Right[Index].Get_BodyKeys().Num() ||
                Left[Index].Get_LimbTracks().Num() != Right[Index].Get_LimbTracks().Num())
            { return false; }
        }
        return true;
    }

    UFUNCTION()
    private void Step_CopyAndPlay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OriginalDuration = Get_Duration(_ProbeClip);
        _Source = Build_DerivedClip(Make_DraftOf(_ProbeClip));
        _Frozen = Build_DerivedClip(Make_DraftOf(_Source));
        Assert_True(_Source != _ProbeClip && _Frozen != _Source && _Frozen != _ProbeClip,
            "draft/build creates distinct test-owned objects");
        Assert_True(Get_AreReferenceFieldsEqual(_Source, _ProbeClip) && Get_AreReferenceFieldsEqual(_Frozen, _Source),
            "copying preserves reference phases and channel structure without editing the source");
        Assert_True(utils_procedural_action::Validate_Data(_Source).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid &&
            utils_procedural_action::Validate_Data(_Frozen).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "both public source copies compile as valid clips");
        _Stream = Create_ProbeAction(InHandle, _Frozen);
    }

    UFUNCTION()
    private void Check_Accepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Stream.Accepted.Count > 0);
    }

    UFUNCTION()
    private void Step_EditSource(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Stream.TerminalSeen == false, "the source edit happens while the frozen action is active");
        auto Draft = Make_DraftOf(_Source);
        auto Phases = Draft.Get_Phases();
        for (auto& Phase : Phases)
        { Phase.Set_Duration(FCk_Time(Phase.Get_Duration().Get_Seconds() * 5.0)); }
        Draft.Set_Phases(Phases);
        const auto Report = utils_procedural_action_builder::Build_Into(Draft, _Source);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "the deliberate mutable-source edit remains valid");
    }

    UFUNCTION()
    private void Check_Terminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Stream.TerminalSeen);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsProbeReleased(_Stream) && Get_AreProbeControlsDefault());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Math::Abs(Get_Duration(_Source) - _OriginalDuration * 5.0) < 1.0e-6,
            "the test-owned source now has the deliberately edited duration");
        Assert_True(Math::Abs(Get_Duration(_Frozen) - _OriginalDuration) < 1.0e-6 &&
            Math::Abs(Get_Duration(_ProbeClip) - _OriginalDuration) < 1.0e-6,
            "the frozen copy and reference clip retained the original duration");
        Assert_True(Get_AreReferenceFieldsEqual(_Frozen, _ProbeClip), "the frozen and reference clip structures still match");
        Assert_True(_Stream.Accepted.ContentRevision > 0 && _Stream.Accepted.ContentChanged == false,
            "the active frozen clip's accepted content fingerprint stayed unchanged");
        Assert_True(Math::Abs(_Stream.Accepted.LastClipTime - _OriginalDuration) < 1.0e-4,
            "the actual accepted motion ended at the frozen clip's original time");
        Assert_True(_Stream.Result.Get_Outcome() == ECk_ProceduralAction_Outcome::Completed &&
            _Stream.Result.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded,
            f"the frozen pincer completed and returned: {_Stream.Result.Get_Outcome() :n}, {_Stream.Result.Get_Reason()}");
        Assert_ProbeDidNotEnterGameCombat();
    }
}
