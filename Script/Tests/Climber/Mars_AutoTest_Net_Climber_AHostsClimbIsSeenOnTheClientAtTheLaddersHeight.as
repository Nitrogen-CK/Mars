// A host's climb is seen on a client at the ladder's height: the host's own controller possesses the pawn (the owner
// and the authority in one) and the client's controller a viewer beside it. The host mounts its ladder and pushes up
// until the climb ends at the top, on the platform. The client's copy, which it does not control and whose Climber
// never climbs, rises with it without dropping on the way and, a second after it stopped rising, stands at the
// platform's height by the exit; its own ladder offered itself to that copy.
class UCk_AutoTest_Net_Climber_AHostsClimbIsSeenOnTheClientAtTheLaddersHeight : UMars_AutoTestRig_NetClimber
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(797000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsClimbIsSeenOnTheClientAtTheLaddersHeight";
    // A simulated copy follows its pawn's replicated place, which may lag a frame or two behind the line.
    private const float64 k_MaxCopyDropCm = 25.0;
    private const float64 k_CopyStandToleranceCm = 25.0;
    // The server holds this long after its own top-out before the controllers go back, so the client has asserted.
    private const float32 k_ServerWatchSeconds = 3.0f;
    // A rise smaller than this between two samples is not counted as rising.
    private const float64 k_RiseEpsilonCm = 0.5;

    // Off authority: the highest feet the copy reached and the course seconds since they last rose.
    private float64 _CopyHighestFeet = 0.0;
    private float32 _SecondsSinceCopyRose = 0.0f;
    // Whether the server's own controller took the pawn; without it the server moves a pawn nobody controls.
    private EMars_TESTONLY_ClimberNet_Possession _Possession = EMars_TESTONLY_ClimberNet_Possession::HostController;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Course(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
            return;
        }

        Mark_CourseClock();
        WaitUntil(n"Is_ClientCopySettledAtTheTop", n"OnClientCopySettled", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { _Possession = EMars_TESTONLY_ClimberNet_Possession::Nobody; }

        WaitUntil(n"Is_ServerReadyToMount", n"OnServerReady", k_SlowPolls);
    }

    // As the owner's readiness; a pawn nobody controls starts no state machine, so it is not waited Alive.
    UFUNCTION()
    private void Is_ServerReadyToMount(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Possession == EMars_TESTONLY_ClimberNet_Possession::HostController)
        {
            Is_OwnerReadyToMount(InHandle, OutResult, InPayload);
            return;
        }

        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsOnFloor() && ck::IsValid(_CourseLadder) && ck::IsValid(Get_CourseClimber()));
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_OwnerMount();
        WaitUntil(n"Is_OwnerClimbingFlying", n"OnServerClimbing", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerClimbing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastCourseDeadline())
        {
            Log_ClimberRow(k_Row, f"possession={_Possession :n} mounted=never");
            FinishFailure("the server's Climber was asked to mount and never climbed in MOVE_Flying");
            return;
        }

        WaitUntil(n"Is_OwnerClimbEnded", n"OnServerClimbEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerClimbEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, f"possession={_Possession :n}");
        const auto Climber = Get_CourseClimber();
        const auto IsTop = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Top;
        Assert_True(IsTop, "the server's climb ended at the top");
        Assert_True(Get_IsOnPlatform(), "the server's pawn stands on the platform");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerWatchSeconds, n"OnCourseServerClientAsserted");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The copy reached the top and has not risen for a settle since, or the course deadline passed.
    UFUNCTION()
    private void Is_ClientCopySettledAtTheTop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Samples = _CourseSamples.Num();
        Sample_Copy();
        if (_CourseSamples.Num() == Samples)
        {
            Result.Set(Get_IsPastCourseDeadline());
            return;
        }

        const auto& Sample = _CourseSamples[_CourseSamples.Num() - 1];
        if (Sample.FeetZ > _CopyHighestFeet + k_RiseEpsilonCm)
        {
            _CopyHighestFeet = Sample.FeetZ;
            _SecondsSinceCopyRose = 0.0f;
        }
        else
        { _SecondsSinceCopyRose += Sample.DeltaSeconds; }

        Result.Set(Get_IsPastCourseDeadline() || (Get_HasReachedTop() && _SecondsSinceCopyRose >= k_SettleSeconds));
    }

    UFUNCTION()
    private void OnClientCopySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, f"local={_Pawn.IsLocallyControlled()}");
        const auto Rise = Get_Rise();
        const auto Offset = _Pawn.GetActorLocation() - _Base;
        Assert_False(_Pawn.IsLocallyControlled(), "the client does not control the pawn it watches");
        Assert_True(Get_HasReachedTop(), f"the client's copy reached the top (highest feet {Rise.Highest :.1})");
        Assert_True(Rise.LargestDrop < k_MaxCopyDropCm, f"the client's copy never dropped on the way up (largest drop {Rise.LargestDrop :.2})");
        Assert_True(Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_CopyStandToleranceCm,
            f"the client's copy stands at the platform's height (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Math::Abs(Offset.X - k_ExitX) <= k_ExitToleranceCm && Math::Abs(Offset.Y) <= k_ExitToleranceCm,
            f"the client's copy stands by the exit ({Offset.X :.1}, {Offset.Y :.1})");
        Assert_False(_CourseEverClimbed, "the client's copy's Climber never climbed");
        Assert_True(_CourseEverCandidate, "the client's own ladder offered itself to the copy");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }
}
