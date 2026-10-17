class UMars_AutoTest_AttackCatalog_PublicPoseSurface : UMars_AutoTestRig_AttackCatalogPublicSurface
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-350000.0, -180000.0, 600.0);

    private FMars_TESTONLY_AttackCatalog_Stream _Stream;
    private bool _SawEndpointMotion = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_ProbeCrawler(InHandle);
        Add_Step("export the actual scheduler order and graph", n"Step_ExportScheduler");
        Add_Step("play a real claimed pincer through public APIs", n"Step_Play");
        Add_Step_WaitUntil("public previous and current poses name both moving claws", n"Check_Endpoints", k_SlowPolls, 0);
        Add_Step("cancel the observed action", n"Step_Cancel");
        Add_Step_WaitUntil("the cancelled action publishes its terminal", n"Check_Terminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("acknowledgement releases the stream and both claws", n"Check_Released", k_SlowPolls, 0);
        Add_Step("assert public accepted geometry and cleanup", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ExportScheduler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        System::ExecuteConsoleCommand("Ck.Ecs.Scheduler.ExportOrder Saved/CkEcs/AttackCatalog-P0-SchedulerOrder.txt");
        System::ExecuteConsoleCommand("Ck.Ecs.Scheduler.ExportGraph Saved/CkEcs/AttackCatalog-P0-SchedulerGraph.dot");
    }

    UFUNCTION()
    private void Step_Play(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Stream = Create_ProbeAction(InHandle, _ProbeClip);
    }

    UFUNCTION()
    private void Check_Endpoints(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        const auto Receipt = _Stream.Accepted.Latest;
        auto BothFound = false;
        if (_Stream.Accepted.Count > 0 && Receipt.Get_Interval().Get_Continuity() == ECk_ProceduralAction_Continuity::Continuous)
        {
            const auto Previous = Receipt.Get_PreviousPose().Get_Limbs();
            const auto Current = Receipt.Get_CurrentPose().Get_Limbs();
            BothFound = Previous.Num() == 2 && Current.Num() == 2;
            for (const auto Id : _ProbeLimbIds)
            {
                auto PreviousIndex = -1;
                auto CurrentIndex = -1;
                for (int32 Index = 0; Index < Previous.Num(); ++Index)
                {
                    if (Previous[Index].Get_Id() == Id)
                    { PreviousIndex = Index; }
                }
                for (int32 Index = 0; Index < Current.Num(); ++Index)
                {
                    if (Current[Index].Get_Id() == Id)
                    { CurrentIndex = Index; }
                }
                if (PreviousIndex < 0 || CurrentIndex < 0)
                { BothFound = false; continue; }
                const auto Before = Previous[PreviousIndex].Get_AcceptedEndpoint().GetLocation();
                const auto After = Current[CurrentIndex].Get_AcceptedEndpoint().GetLocation();
                if (utils_crawler::Get_IsFinite(Before) == false || utils_crawler::Get_IsFinite(After) == false)
                {
                    FinishFailure("a real claimed limb's accepted endpoint was not finite");
                    return;
                }
                _SawEndpointMotion = _SawEndpointMotion || (After - Before).Size() > 0.001;
            }
        }
        if (_Stream.TerminalSeen && (BothFound == false || _SawEndpointMotion == false))
        {
            FinishFailure("the pincer terminated without continuous previous/current claimed-limb evidence");
            return;
        }
        auto Res = OutResult;
        Res.Set(BothFound && _SawEndpointMotion);
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Stream.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
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
        Assert_True(_SawEndpointMotion && _Stream.Accepted.Count > 1, "real claimed endpoints moved between accepted poses");
        Assert_True(_Stream.Accepted.ContentRevision > 0 && _Stream.Accepted.ContentChanged == false,
            "accepted pincer receipts have stable positive content provenance");
        Assert_True(_Stream.Result.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded,
            f"the public pincer cancellation returned its claws: {_Stream.Result.Get_Outcome() :n}, {_Stream.Result.Get_Reason()}");
        Assert_ProbeDidNotEnterGameCombat();
    }
}
