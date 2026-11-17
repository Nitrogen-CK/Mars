// A jump off a ladder falls on both machines: with the pawn possessed by the client's controller, the client mounts
// its ladder, climbs until its feet are 150 above the floor and jumps off. On the client the climb ended Jump, the pawn
// fell and lands on the floor pushed away from the ladder's plane. The host's copy, whose Climber never climbs, rose
// past 120, then fell, and lands on the floor short of the climb line as well; its own ladder offered itself to that
// copy.
class UCk_AutoTest_Net_Climber_AJumpOffALadderFallsOnBothMachines : UMars_AutoTestRig_NetClimber
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(798000.0, 0.0, 5000.0);
    private const FString k_Row = "AJumpOffALadderFallsOnBothMachines";
    private const float64 k_JumpFeet = 150.0;
    // The other machine's copy counts as having climbed once its feet passed this.
    private const float64 k_CopyRiseFeet = 120.0;
    // Pushed away from the plane: landed at least this short of the climb line.
    private const float64 k_AwayCm = 20.0;

    // The frame counter when the client asked to jump, and when the server's copy first rose past k_CopyRiseFeet; -1
    // before.
    private int32 _JumpFrame = -1;
    private int32 _CopyRoseFrame = -1;

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

    private bool Get_IsAwayFromTheLine()
    {
        return ck::IsValid(_Pawn) && _Pawn.GetActorLocation().X - _Base.X <= k_LineX - k_AwayCm;
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
        WaitUntil(n"Is_ServerCopyLanded", n"OnServerCopyLanded", k_SlowPolls);
    }

    // The copy rose past k_CopyRiseFeet, a later sample fell and it stands on the floor; or the course deadline passed.
    UFUNCTION()
    private void Is_ServerCopyLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_CopyRoseFrame < 0 && ck::IsValid(_Pawn) && Get_FeetAboveFloor() >= k_CopyRiseFeet)
        { _CopyRoseFrame = int32(utils_time::Get_FrameCounter()); }

        const auto HasLanded = _CopyRoseFrame >= 0 && Get_HasFallingSampleFrom(_CopyRoseFrame) && Get_IsOnFloor();
        Result.Set(Get_IsPastCourseDeadline() || HasLanded);
    }

    UFUNCTION()
    private void OnServerCopyLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, f"roseFrame={_CopyRoseFrame}");
        const auto Rise = Get_Rise();
        Assert_True(_CopyRoseFrame >= 0, f"the server's copy rose 120 above the floor (highest feet {Rise.Highest :.1})");
        Assert_True(_CopyRoseFrame >= 0 && Get_HasFallingSampleFrom(_CopyRoseFrame), "the server's copy then read MOVE_Falling");
        Assert_True(Get_IsOnFloor(), "the server's copy lands on the floor");
        Assert_True(Get_IsAwayFromTheLine(), "the server's copy lands short of the climb line");
        Assert_False(_CourseEverClimbed, "the server's copy's Climber never climbed");
        Assert_True(_CourseEverCandidate, "the server's own ladder offered itself to the copy");
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

        WaitUntil(n"Is_ClientAtJumpHeight", n"OnClientAtJumpHeight", k_SlowPolls);
    }

    // Pushes up every poll until the feet are k_JumpFeet above the floor, the climb ended, or the deadline passed.
    UFUNCTION()
    private void Is_ClientAtJumpHeight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        auto Climber = Get_CourseClimber();
        if (ck::Is_NOT_Valid(Climber) || Climber.Get_IsClimbing() == false || Get_IsPastCourseDeadline()
            || Get_FeetAboveFloor() >= k_JumpFeet)
        {
            Result.Set(true);
            return;
        }

        Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Result.Set(false);
    }

    UFUNCTION()
    private void OnClientAtJumpHeight(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _JumpFrame = int32(utils_time::Get_FrameCounter());
        auto Climber = Get_CourseClimber();
        Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Jump));
        Mark_CourseClock();
        WaitUntil(n"Is_ClientLanded", n"OnClientLanded", k_SlowPolls);
    }

    // A sample after the jump fell and the pawn stands on the floor, or the course deadline passed.
    UFUNCTION()
    private void Is_ClientLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsPastCourseDeadline() || (Get_HasFallingSampleFrom(_JumpFrame) && Get_IsOnFloor()));
    }

    UFUNCTION()
    private void OnClientLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ClimberRow(k_Row, f"jumpFrame={_JumpFrame}");
        const auto Climber = Get_CourseClimber();
        const auto IsJump = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Jump;
        Assert_True(IsJump, "the client's climb ended Jump");
        Assert_True(Get_HasFallingSampleFrom(_JumpFrame), "a sample after the jump read MOVE_Falling");
        Assert_True(Get_IsOnFloor(), "the client's pawn lands on the floor");
        Assert_True(Get_IsAwayFromTheLine(), "the client's pawn lands short of the climb line (pushed away from the plane)");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }
}
