// A client's climb is seen on the host at the ladder's height: with the pawn possessed by the client's controller, the
// client mounts its own ladder and pushes up until the climb ends at the top. On the client the climb reads MOVE_Flying
// throughout, its pawn never drops back down the ladder (its movement component did not put it back), and a second
// later it stands on the platform. The host's copy, which never climbs, rises with it: it reaches the top with no
// MOVE_Falling sample and no drop on the way, reads MOVE_Flying for at least ten samples and ends on the platform.
class UCk_AutoTest_Net_Climber_AClientsClimbIsSeenOnTheHostAtTheLaddersHeight : UMars_AutoTestRig_NetClimber
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(796000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsClimbIsSeenOnTheHostAtTheLaddersHeight";
    // A drop under this is a frame's worth of a held move put back; past it the copy was moved down the ladder.
    private const float64 k_MaxDropCm = 10.0;
    private const int32 k_MinFlyingSamples = 10;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Course(k_Base);

        if (Get_IsServer())
        { Spawn_ServerPawn(); }

        WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
            return;
        }

        WaitUntil(n"Is_OwnerReadyToMount", n"OnClientReady", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_ClimberRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        Mark_CourseClock();
        WaitUntil(n"Is_ServerCopyOnPlatform", n"OnServerCopyDone", k_SlowPolls);
    }

    // The copy reached the top and stands on the platform, or the course deadline passed.
    UFUNCTION()
    private void Is_ServerCopyOnPlatform(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsPastCourseDeadline() || (Get_HasReachedTop() && Get_IsOnPlatform()));
    }

    UFUNCTION()
    private void OnServerCopyDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, "");
        const auto Rise = Get_Rise();
        const auto Modes = Get_Modes();
        const auto Climber = Get_CourseClimber();
        Assert_True(Get_HasReachedTop(), f"the server's copy reached the top (highest feet {Rise.Highest :.1})");
        Assert_Equals_Int(Get_FallingSamplesBeforeTop(), 0, "no sample of the server's copy read MOVE_Falling on the way up");
        Assert_True(Rise.LargestDrop < k_MaxDropCm, f"the server's copy never dropped on the way up (largest drop {Rise.LargestDrop :.2})");
        Assert_True(Modes.Flying >= k_MinFlyingSamples, f"the server's copy read MOVE_Flying for ten samples or more ({Modes.Flying})");
        Assert_True(Get_IsOnPlatform(), "the server's copy ends on the platform");
        Assert_False(_CourseEverClimbed, "the server's copy's Climber never climbed");
        Assert_False(ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet(), "the server's copy's Climber has no last dismount");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnCourseServerClientAsserted");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_OwnerMount();
        WaitUntil(n"Is_OwnerClimbingFlying", n"OnClientClimbing", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientClimbing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastCourseDeadline())
        {
            Log_ClimberRow(k_Row, "mounted=never");
            FinishFailure("the client's Climber was asked to mount and never climbed in MOVE_Flying");
            return;
        }

        WaitUntil(n"Is_OwnerClimbEnded", n"OnClientClimbEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientClimbEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnClientSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, "");
        const auto Rise = Get_Rise();
        const auto Climber = Get_CourseClimber();
        const auto IsTop = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Top;
        Assert_True(IsTop, "the client's climb ended at the top");
        Assert_Equals_Int(Get_ClimbingSamplesNotFlying(), 0, "every sample of the client's climb read MOVE_Flying");
        Assert_True(Rise.LargestDrop < k_MaxDropCm, f"the client's own pawn never dropped back down the ladder (largest drop {Rise.LargestDrop :.2})");
        Assert_True(Get_IsOnPlatform(), "a second after its top-out the client's pawn stands on the platform");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }
}
