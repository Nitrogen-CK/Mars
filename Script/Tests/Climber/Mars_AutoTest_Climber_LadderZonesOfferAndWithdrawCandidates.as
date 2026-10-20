// The ladder's zones feed the climber through the player's body probe: the production AMars_PlayerCharacter (unpossessed,
// so no locomotion acts on its own) is teleported into a ladder's Front zone, which adds a (ladder, Front) candidate and
// broadcasts OnCandidatesChanged once; teleported out, the candidate is withdrawn with one more broadcast; back in, the
// candidate it offers mounts the climber. The climber is the player's own.
class UMars_AutoTest_Climber_LadderZonesOfferAndWithdrawCandidates : UMars_AutoTestRig_PlayerCombat
{
    private const FVector k_LadderOffset = FVector(300.0, 0.0, 0.0);

    private FCk_Handle_Ladder _Ladder;
    private FCk_Handle_Climber _Climber;
    private int32 _CandidateChanges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(56000.0, 330000.0, -41000.0);
        SpawnFloorAndUnpossessedPawn(InHandle);

        auto LadderEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto LadderRoot = utils_transform::Add(LadderEntity, FTransform(FRotator::ZeroRotator, _Origin + k_LadderOffset), ECk_Replication::DoesNotReplicate);
        _Ladder = utils_ladder::Add(LadderRoot, FMars_Ladder_Spec());

        Add_Step_WaitUntil("the player entity is composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step("bind the player's climber; it starts with no candidate", n"Step_BindClimber");
        Add_Step("teleport the player into the Front zone", n"Step_IntoFront");
        Add_Step_WaitUntil("the zone offers a candidate", n"Check_HasCandidate", k_SlowPolls, 0);
        Add_Step("one (ladder, Front) candidate, one broadcast", n"Step_AssertCandidate");
        Add_Step("teleport the player away", n"Step_Away");
        Add_Step_WaitUntil("the candidate is withdrawn", n"Check_NoCandidate", k_SlowPolls, 0);
        Add_Step("a second broadcast", n"Step_AssertWithdrawn");
        Add_Step("teleport the player into the Front zone again", n"Step_IntoFront");
        Add_Step_WaitUntil("the zone offers the candidate again", n"Check_HasCandidate", k_SlowPolls, 0);
        Add_Step("mount from the candidate", n"Step_MountFromCandidate");
        Add_Step_WaitUntil("the player climbs the offered ladder", n"Check_Climbing", k_SlowPolls, 0);
        Add_Step("leave the ladder", n"Step_Dismount");
        Add_Step_WaitUntil("off the ladder", n"Check_NotClimbing", k_SlowPolls, 0);
        Add_Step("tear down", n"Step_TearDown");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BindClimber(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Ladder, "the ladder composed");
        _Climber = _Player.As_Climber(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Climber))
        {
            FinishFailure("the player entity has no climber");
            return;
        }

        Assert_False(_Climber.Get_HasCandidate(), "the player starts away from every ladder");
        _Climber.BindTo_OnCandidatesChanged(FMars_Delegate_Climber_OnCandidatesChanged(this, n"OnCandidatesChanged"));
    }

    UFUNCTION()
    private void Step_IntoFront(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        _Pawn.SetActorLocation(_Origin + k_LadderOffset + FVector(45.0, 0.0, HalfHeight + 2.0));
    }

    UFUNCTION()
    private void Step_Away(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        _Pawn.SetActorLocation(_Origin + FVector(-300.0, 0.0, HalfHeight + 2.0));
    }

    UFUNCTION()
    private void Check_HasCandidate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_HasCandidate());
    }

    UFUNCTION()
    private void Step_AssertCandidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Candidates = _Climber.Get_Candidates();
        Assert_Equals_Int(Candidates.Num(), 1, "one candidate");
        if (Candidates.Num() == 1)
        {
            Assert_True(Candidates[0].Ladder == _Ladder, "the candidate is the ladder whose zone the player stands in");
            Assert_True(Candidates[0].Zone == EMars_Ladder_Zone::Front, "the candidate is its Front zone");
        }

        Assert_Equals_Int(_CandidateChanges, 1, "OnCandidatesChanged fired once for the offer");
    }

    UFUNCTION()
    private void Check_NoCandidate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_HasCandidate() == false);
    }

    UFUNCTION()
    private void Step_AssertWithdrawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CandidateChanges, 2, "OnCandidatesChanged fired once more for the withdrawal");
    }

    UFUNCTION()
    private void Step_MountFromCandidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Candidates = _Climber.Get_Candidates();
        if (Candidates.Num() == 0)
        {
            FinishFailure("the candidate vanished before the mount");
            return;
        }

        _Climber.Request_Mount(FMars_Request_Climber_Mount(Candidates[0].Ladder, Candidates[0].Zone));
    }

    UFUNCTION()
    private void Check_Climbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing() && _Climber.Get_Ladder() == _Ladder);
    }

    UFUNCTION()
    private void Step_Dismount(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
    }

    UFUNCTION()
    private void Check_NotClimbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing() == false);
    }

    UFUNCTION()
    private void OnCandidatesChanged(FCk_Handle_Climber InClimber)
    {
        ++_CandidateChanges;
    }
}

// The PlayerCombat runner base lists the production pawn's known spawn-time log noise.
class AMars_AutoTest_Climber_LadderZonesOfferAndWithdrawCandidates_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TestEntityScriptClass = UMars_AutoTest_Climber_LadderZonesOfferAndWithdrawCandidates;
}
