// What the host's pawn does on the course in a row whose owner is the host.
enum EMars_TESTONLY_MovementBaseNet_HostCourse
{
    // Climbs to the top and stands on the platform.
    ClimbToTheTop,
    // Climbs to the top, then walks toward the platform's centre for a moment.
    ClimbToTheTopAndWalk,
    // Climbs until its feet are k_MbJumpFeet above the floor, jumps off and lands on the floor.
    JumpOffAtHeight
}

// Samples of a copy counted by how its machine sees the pawn's base.
struct FMars_TESTONLY_MovementBaseNet_NetBases
{
    UPROPERTY()
    int32 None = 0;

    UPROPERTY()
    int32 Crossing = 0;

    UPROPERTY()
    int32 PerMachine = 0;

    UPROPERTY()
    int32 Unresolved = 0;
}

// The movement-base net tests' steps, on the climber course: what a copy of a pawn does while the pawn stands on a
// surface each machine built for itself. In a host-owned row the host's own controller possesses the pawn and moves it
// over the course; the client samples its copy until it settled (one second of course clock with its place still, once
// the row's course reached its end on the copy) and asserts over that second. Each machine logs one line per row.
UCLASS(Abstract)
class UMars_AutoTestRig_NetMovementBase : UMars_AutoTestRig_NetClimber
{
    default _TimeoutSeconds = 30.0f;

    // The jump dismount's height.
    protected const float64 k_MbJumpFeet = 150.0;
    // A copy's place that moved less than this between two samples is still.
    protected const float64 k_MbStillEpsilonCm = 0.5;
    // The host walks this long, in course seconds.
    protected const float32 k_MbWalkSeconds = 0.3f;
    // The copy's walk counts as seen once it is this far along +X past the exit.
    protected const float64 k_MbWalkSeenCm = 25.0;
    // The server holds this long after its own end before the controllers go back, so the client has asserted.
    protected const float32 k_MbServerWatchSeconds = 3.0f;

    protected FString _MbRow;
    protected EMars_TESTONLY_MovementBaseNet_HostCourse _MbCourse = EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTop;
    // Where the copy's settled second starts in the samples; -1 before.
    protected int32 _MbSettleStartIndex = -1;
    // Server: the pawn's X relative to the base when the walk started.
    protected float64 _MbWalkStartX = 0.0;
    // The frame counter when the jump was asked for, and when the copy's feet first passed k_MbJumpFeet; -1 before.
    protected int32 _MbJumpFrame = -1;
    protected int32 _MbPassedJumpFeetFrame = -1;

    private bool _MbIsReadyToSettle = false;
    private FVector _MbStillPlace = FVector::ZeroVector;
    private float32 _MbStillSeconds = 0.0f;

    // A host-owned row: the server spawns the pawn and the viewer, the host's controller moves the pawn over InCourse;
    // the client waits for its copy and samples it.
    protected void Begin_HostOwnedRow(FString InRow, FVector InBase, EMars_TESTONLY_MovementBaseNet_HostCourse InCourse)
    {
        _MbRow = InRow;
        _MbCourse = InCourse;
        Begin_Course(InBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnMbComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnMbComposed", k_SlowPolls);
    }

    // The row's checks on each machine, once its course ended there.
    protected void Assert_ServerRow() {}
    protected void Assert_ClientRow() {}

    //------------------------------------------------------------------------------------------------------------------
    // Reads
    //------------------------------------------------------------------------------------------------------------------

    protected FMars_TESTONLY_MovementBaseNet_NetBases Get_NetBases()
    {
        auto Counts = FMars_TESTONLY_MovementBaseNet_NetBases();
        const auto From = Math::Max(Get_ClimbStartIndex(), 0);
        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            const auto NetBase = _CourseSamples[Index].NetBase;
            if (NetBase == EMars_Character_NetBase::None)
            { Counts.None += 1; }
            else if (NetBase == EMars_Character_NetBase::Crossing)
            { Counts.Crossing += 1; }
            else if (NetBase == EMars_Character_NetBase::PerMachine)
            { Counts.PerMachine += 1; }
            else
            { Counts.Unresolved += 1; }
        }

        return Counts;
    }

    // The largest distance in the plane between two consecutive samples from InFrom.
    protected float64 Get_LargestPlanarStep(int32 InFrom)
    {
        auto Largest = 0.0;
        for (int32 Index = Math::Max(InFrom, 0) + 1; Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Previous = _CourseSamples[Index - 1];
            const auto& Sample = _CourseSamples[Index];
            const auto DX = Sample.X - Previous.X;
            const auto DY = Sample.Y - Previous.Y;
            Largest = Math::Max(Largest, Math::Sqrt(DX * DX + DY * DY));
        }

        return Largest;
    }

    // The first sample from the climb's start that reads MOVE_Walking; -1 without one.
    protected int32 Get_FirstWalkingIndexAfterClimb()
    {
        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return -1; }

        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Mode == EMovementMode::MOVE_Walking)
            { return Index; }
        }

        return -1;
    }

    // The first sample at or after InFrame; the sample count without one.
    protected int32 Get_IndexAtFrame(int32 InFrame)
    {
        for (int32 Index = 0; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Frame >= InFrame)
            { return Index; }
        }

        return _CourseSamples.Num();
    }

    // Samples of the settled second that read another mode than InMode or another base than InNetBase.
    protected int32 Get_SettledSamplesNotReading(EMovementMode InMode, EMars_Character_NetBase InNetBase)
    {
        if (_MbSettleStartIndex < 0)
        { return -1; }

        auto Count = 0;
        for (int32 Index = _MbSettleStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Sample.Mode != InMode || Sample.NetBase != InNetBase)
            { Count += 1; }
        }

        return Count;
    }

    protected bool Get_HasSettledSampleWithABase()
    {
        if (_MbSettleStartIndex < 0)
        { return false; }

        for (int32 Index = _MbSettleStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].HasMovementBase)
            { return true; }
        }

        return false;
    }

    protected int32 Get_SettledSampleCount()
    {
        return _MbSettleStartIndex < 0 ? 0 : _CourseSamples.Num() - _MbSettleStartIndex;
    }

    protected FString Describe_Samples(int32 InFrom, int32 InCount)
    {
        auto Text = "";
        const auto From = Math::Max(InFrom, 0);
        const auto To = Math::Min(From + InCount, _CourseSamples.Num());
        for (int32 Index = From; Index < To; ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            const auto Mode = Sample.Mode == EMovementMode::MOVE_Flying ? "F"
                : (Sample.Mode == EMovementMode::MOVE_Falling ? "D" : (Sample.Mode == EMovementMode::MOVE_Walking ? "W" : "O"));
            const auto NetBase = Sample.NetBase == EMars_Character_NetBase::None ? "n"
                : (Sample.NetBase == EMars_Character_NetBase::Crossing ? "c"
                : (Sample.NetBase == EMars_Character_NetBase::PerMachine ? "p" : "u"));
            const auto HasBase = Sample.HasMovementBase ? "b" : "";
            Text += f"{Sample.Frame}:({Sample.X :.1},{Sample.FeetZ :.1}){Mode}{NetBase}{HasBase} ";
        }

        return Text;
    }

    // The row's one line on this machine: the climber course's fields, then how this machine saw the base.
    protected void Log_MovementBaseRow(FString InExtra)
    {
        if (ck::Is_NOT_Valid(_Pawn))
        {
            const auto Missing = f"[MovementBaseNetTest] {_MbRow} {Get_MachineName()} pawn=missing samples={_CourseSamples.Num()} ensures={Get_NewEnsures()} {InExtra}";
            Log(Missing);
            return;
        }

        const auto Rise = Get_Rise();
        const auto Modes = Get_Modes();
        const auto NetBases = Get_NetBases();
        const auto Offset = _Pawn.GetActorLocation() - _Base;
        const auto Climber = Get_CourseClimber();
        auto Dismount = "none";
        if (ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet())
        { Dismount = f"{Climber.Get_LastDismount().GetValue() :n}"; }

        const auto Start = Get_ClimbStartIndex();
        auto ModeBefore = "none";
        if (_CourseSamples.Num() > 0)
        { ModeBefore = f"{_CourseSamples[Math::Max(Start - 1, 0)].Mode :n}"; }

        auto LastNetBase = "none";
        auto LastHasBase = false;
        if (_CourseSamples.Num() > 0)
        {
            LastNetBase = f"{_CourseSamples[_CourseSamples.Num() - 1].NetBase :n}";
            LastHasBase = _CourseSamples[_CourseSamples.Num() - 1].HasMovementBase;
        }

        const auto FirstWalking = Get_FirstWalkingIndexAfterClimb();
        const auto FirstWalkingFrame = FirstWalking >= 0 ? _CourseSamples[FirstWalking].Frame : -1;
        const auto FeetZ = Get_FeetAboveFloor();
        const auto Mode = _Pawn.CharacterMovement.MovementMode;
        const auto NowNetBase = _Pawn.Get_NetBase();
        const auto Step = Get_LargestPlanarStep(Start);
        const auto First = Describe_Samples(Start, 20);
        const auto Last = Describe_Samples(_CourseSamples.Num() - 10, 10);
        const auto Line = f"[MovementBaseNetTest] {_MbRow} {Get_MachineName()} highest={Rise.Highest :.2} drop={Rise.LargestDrop :.2} "
            + f"flying={Modes.Flying} falling={Modes.Falling} walking={Modes.Walking} "
            + f"final=({Offset.X :.1},{Offset.Y :.1},{FeetZ :.1}) mode={Mode :n} netBase={NowNetBase :n} "
            + f"lastSample=[netBase={LastNetBase} hasBase={LastHasBase}] climbed={_CourseEverClimbed} "
            + f"lastDismount={Dismount} ensures={Get_NewEnsures()} samples={_CourseSamples.Num()} "
            + f"bases=[none {NetBases.None} crossing {NetBases.Crossing} perMachine {NetBases.PerMachine} "
            + f"unresolved {NetBases.Unresolved}] largestStep={Step :.2} modeBeforeMount={ModeBefore} "
            + f"settled={Get_SettledSampleCount()} frames=[mount {_CourseMountFrame} flying {_CourseFirstFlyingFrame} "
            + f"top {_CourseFirstTopFrame} climbEnd {_CourseClimbEndFrame} platform {_CourseFirstPlatformFrame} "
            + f"jump {_MbJumpFrame} passedJumpFeet {_MbPassedJumpFeetFrame} firstWalking {FirstWalkingFrame}] {InExtra} "
            + f"first=[{First}] last=[{Last}]";
        Log(Line);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Both machines
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnMbComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnMbServerComposeWaited");
            return;
        }

        Mark_CourseClock();
        WaitUntil(n"Is_MbCopySettled", n"OnMbClientCopySettled", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnMbServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        {
            Log_MovementBaseRow("possession=none");
            FinishFailure("the server's world has not exactly one local player controller to move the pawn");
            return;
        }

        WaitUntil(n"Is_OwnerReadyToMount", n"OnMbServerReady", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_OwnerMount();
        WaitUntil(n"Is_OwnerClimbingFlying", n"OnMbServerClimbing", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerClimbing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastCourseDeadline())
        {
            Log_MovementBaseRow("mounted=never");
            FinishFailure("the server's Climber was asked to mount and never climbed in MOVE_Flying");
            return;
        }

        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::JumpOffAtHeight)
        {
            WaitUntil(n"Is_MbServerAtJumpHeight", n"OnMbServerAtJumpHeight", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_OwnerClimbEnded", n"OnMbServerClimbEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerClimbEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTopAndWalk)
        {
            WaitUntil(n"Is_CourseSettled", n"OnMbServerReadyToWalk", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerReadyToWalk(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _MbWalkStartX = _Pawn.GetActorLocation().X - _Base.X;
        Mark_CourseClock();
        WaitUntil(n"Is_MbServerWalked", n"OnMbServerWalked", k_SlowPolls);
    }

    // Walks toward the platform's centre every poll for k_MbWalkSeconds of course clock.
    UFUNCTION()
    protected void Is_MbServerWalked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_CourseClockSeconds >= k_MbWalkSeconds)
        {
            Result.Set(true);
            return;
        }

        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0f);
        Result.Set(false);
    }

    UFUNCTION()
    protected void OnMbServerWalked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    // Pushes up every poll until the feet are k_MbJumpFeet above the floor, the climb ended, or the deadline passed.
    UFUNCTION()
    protected void Is_MbServerAtJumpHeight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        auto Climber = Get_CourseClimber();
        if (ck::Is_NOT_Valid(Climber) || Climber.Get_IsClimbing() == false || Get_IsPastCourseDeadline()
            || Get_FeetAboveFloor() >= k_MbJumpFeet)
        {
            Result.Set(true);
            return;
        }

        Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Result.Set(false);
    }

    UFUNCTION()
    protected void OnMbServerAtJumpHeight(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _MbJumpFrame = int32(utils_time::Get_FrameCounter());
        auto Climber = Get_CourseClimber();
        Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Jump));
        Mark_CourseClock();
        WaitUntil(n"Is_MbServerLanded", n"OnMbServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MbServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsPastCourseDeadline() || (Get_HasFallingSampleFrom(_MbJumpFrame) && Get_IsOnFloor()));
    }

    UFUNCTION()
    protected void OnMbServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_MovementBaseRow(f"walkStartX={_MbWalkStartX :.1}");
        Assert_ServerRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_MbServerWatchSeconds, n"OnCourseServerClientAsserted");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // Whether the row's course has reached its end on this copy, so its place may settle; notes when the copy's feet
    // first passed the jump's height.
    protected bool Track_IsCopyCourseAtItsEnd()
    {
        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::JumpOffAtHeight)
        {
            if (_MbPassedJumpFeetFrame < 0 && Get_FeetAboveFloor() >= k_MbJumpFeet)
            { _MbPassedJumpFeetFrame = int32(utils_time::Get_FrameCounter()); }

            return _MbPassedJumpFeetFrame >= 0 && Math::Abs(Get_FeetAboveFloor()) <= k_StandToleranceCm;
        }

        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTopAndWalk)
        { return Get_HasReachedTop() && _Pawn.GetActorLocation().X - _Base.X >= k_ExitX + k_MbWalkSeenCm; }

        return Get_HasReachedTop();
    }

    // The copy's course reached its end and its place has been still for k_SettleSeconds since, or the deadline passed.
    UFUNCTION()
    protected void Is_MbCopySettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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
        const auto Place = FVector(Sample.X, Sample.Y, Sample.FeetZ);
        if (_MbIsReadyToSettle == false)
        {
            _MbIsReadyToSettle = Track_IsCopyCourseAtItsEnd();
            if (_MbIsReadyToSettle)
            { Restart_Settle(Place); }
        }
        else if ((Place - _MbStillPlace).Size() > k_MbStillEpsilonCm)
        { Restart_Settle(Place); }
        else
        { _MbStillSeconds += Sample.DeltaSeconds; }

        Result.Set(Get_IsPastCourseDeadline() || (_MbIsReadyToSettle && _MbStillSeconds >= k_SettleSeconds));
    }

    private void Restart_Settle(FVector InPlace)
    {
        _MbStillPlace = InPlace;
        _MbStillSeconds = 0.0f;
        _MbSettleStartIndex = _CourseSamples.Num() - 1;
    }

    UFUNCTION()
    protected void OnMbClientCopySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        Log_MovementBaseRow(f"local={IsLocal}");
        Assert_True(ck::IsValid(_Pawn) && IsLocal == false, "the client does not control the pawn it watches");
        Assert_True(_MbSettleStartIndex >= 0, "the client's copy reached the course's end and settled");
        Assert_ClientRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }
}
