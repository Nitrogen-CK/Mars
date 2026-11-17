// A client's top-out onto a mesh-part platform is seen on the host: with the pawn possessed by the client's
// controller, the client climbs its own ladder to the top of a platform built as a mesh part, which each machine
// builds for itself. On the client the pawn stands on the platform and, a second later, still does (no correction put
// it back). The host's copy ends on the platform by the exit in MOVE_Walking; how the host sees that copy's base is
// logged.
class UCk_AutoTest_Net_MovementBase_AClientsTopOutOntoAMeshPartIsSeenOnTheHost : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(813000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _MbRow = "AClientsTopOutOntoAMeshPartIsSeenOnTheHost";
        Begin_Course(k_Base);

        if (Get_IsServer())
        { Spawn_ServerPawn(); }

        WaitUntil(n"Is_PawnComposed", n"OnRowComposed", k_SlowPolls);
    }

    protected EMars_TESTONLY_ClimberNet_Platform Get_PlatformKind() const override
    {
        return EMars_TESTONLY_ClimberNet_Platform::MeshPart;
    }

    UFUNCTION()
    private void OnRowComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnRowServerComposeWaited");
            return;
        }

        WaitUntil(n"Is_OwnerReadyToMount", n"OnRowClientReady", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRowServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_MovementBaseRow("remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        Mark_CourseClock();
        WaitUntil(n"Is_RowServerCopyOnPlatform", n"OnRowServerCopyOnPlatform", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RowServerCopyOnPlatform(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsPastCourseDeadline() || (Get_HasReachedTop() && Get_IsOnPlatform()));
    }

    // Watches the copy for a settle more, so a copy that stood there only on its way elsewhere is caught.
    UFUNCTION()
    private void OnRowServerCopyOnPlatform(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnRowServerWatched", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRowServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_MovementBaseRow("");
        Assert_True(Get_HasReachedTop(), "the server's copy reached the top");
        Assert_True(Get_IsOnPlatform(), "the server's copy ends on the platform by the exit in MOVE_Walking");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnCourseServerClientAsserted");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRowClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_OwnerMount();
        WaitUntil(n"Is_OwnerClimbingFlying", n"OnRowClientClimbing", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRowClientClimbing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastCourseDeadline())
        {
            Log_MovementBaseRow("mounted=never");
            FinishFailure("the client's Climber was asked to mount and never climbed in MOVE_Flying");
            return;
        }

        WaitUntil(n"Is_OwnerClimbEnded", n"OnRowClientClimbEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRowClientClimbEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnRowClientSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRowClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Climber = Get_CourseClimber();
        const auto IsTop = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Top;
        Assert_True(IsTop, "the client's climb ended at the top");
        Assert_True(Get_IsOnPlatform(), "a second after its top-out the client's pawn stands on the platform");
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnRowClientStillThere", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRowClientStillThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_MovementBaseRow("");
        Assert_True(Get_IsOnPlatform(), "a second later the client's pawn still stands on the platform (not corrected back)");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }
}
