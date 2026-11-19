// The steward seizes a joined player who has turned away from it: the client, in the production pawn, turns its view to
// k_Yaw and looks down k_Pitch (its own camera director), and the server waits until its copy of the pawn's view
// follows (UMars_Processor_PlayerViewpoint_FollowAim) before raising the channel. The server's steward starts the
// seize from its copy of the victim's view (Get_VictimView): on the first frame the server reads Seize, the steward's
// View node points within k_SeizeToleranceDeg of where the client looks (Seize has barely begun to turn it to the
// face). The client rides the run through to Alive.
// Surface: Ck.Steward.Net.AS_Steward_TheHostsSeizeStartsAtTheJoinedVictimsOwnView
class UCk_AutoTest_Net_Steward_TheHostsSeizeStartsAtTheJoinedVictimsOwnView : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(647000.0, 0.0, 5000.0);
    private const FString k_Row = "TheHostsSeizeStartsAtTheJoinedVictimsOwnView";
    // Away from the steward (it stands on +X, facing the base), and away from its root's own yaw (180).
    private const float64 k_Yaw = 135.0;
    private const float64 k_Pitch = -30.0;
    // The server's copy of the view follows the replicated control rotation within this.
    private const float64 k_FollowToleranceDeg = 3.0;
    // Seize turns the node toward the face over SeizeSeconds (SmoothStep): its first frame has turned it a degree or two.
    private const float64 k_SeizeToleranceDeg = 10.0;

    private bool _SeizeSampled = false;
    private float64 _SeizeAngleDeg = -1.0;
    private float32 _SeizeAlpha = -1.0f;
    private FVector _SeizeForward = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::None);

        if (Get_IsServer())
        {
            Spawn_ServerPawn();
            WaitUntil(n"Is_ServerReadyForSteward", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ClientReady", n"OnClientReady", k_SlowPolls);
    }

    private FVector Get_TargetForward() const
    {
        return FRotator(k_Pitch, k_Yaw, 0.0).Quaternion().GetForwardVector();
    }

    private float64 Get_AngleToTargetDeg(FVector InForward)
    {
        return Math::RadiansToDegrees(Math::Acos(Math::Clamp(InForward.GetSafeNormal().DotProduct(Get_TargetForward()), -1.0, 1.0)));
    }

    // This machine's copy of the pawn's view forward.
    private FVector Get_PawnViewForward()
    {
        return utils_transform::Get_EntityCurrentTransform(_Player.As_PlayerViewpoint().Get_Viewpoint()).GetRotation().GetForwardVector();
    }

    UFUNCTION()
    private void Is_InAliveSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsPawnComposedForDevour();
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1 && Get_IsInState(UMars_SmState_Alive));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ServerReadyForSteward(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsPawnComposedForDevour()
            && Get_IsReceiverFound());
    }

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        Spawn_ServerSteward();
        WaitUntil(n"Is_StewardSinkEvaluated", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_StewardRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_ServerSeesTheTurnedPrey", n"OnServerSeesTheTurnedPrey", k_SlowPolls);
    }

    // The pawn's entity is prey here and the server's copy of its view points where the client looks.
    UFUNCTION()
    private void Is_ServerSeesTheTurnedPrey(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Alive) && utils_entity_tag::Has(_Player, n"TAG_MarsSharedCombatTarget")
            && Get_AngleToTargetDeg(Get_PawnViewForward()) <= k_FollowToleranceDeg);
    }

    UFUNCTION()
    private void OnServerSeesTheTurnedPrey(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Deasserted);
        WaitSampling(k_RiseDelaySeconds, n"OnServerReadyToRise");
    }

    UFUNCTION()
    private void OnServerReadyToRise(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitUntil(n"Is_ServerSeizeSampled", n"OnServerSeizeSampled", k_SlowPolls);
    }

    // The first frame this machine reads Seize: where the steward's View node points.
    UFUNCTION()
    private void Is_ServerSeizeSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        if (_SeizeSampled == false && ck::IsValid(_Devourer) && _Devourer.Get_Phase() == EMars_Devour_Phase::Seize)
        {
            const auto View = _Devourer.Get_View();
            if (ck::IsValid(View))
            {
                _SeizeForward = utils_transform::Get_EntityCurrentTransform(View).GetRotation().GetForwardVector();
                _SeizeAngleDeg = Get_AngleToTargetDeg(_SeizeForward);
                _SeizeAlpha = _Devourer.Get_PhaseAlpha();
                _SeizeSampled = true;
            }
        }

        auto Result = OutResult;
        Result.Set(_SeizeSampled);
    }

    UFUNCTION()
    private void OnServerSeizeSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_StewardRow(k_Row, f"seizeAngle={_SeizeAngleDeg :.2} seizeAlpha={_SeizeAlpha :.3} seizeForward={_SeizeForward} target={Get_TargetForward()} pawnView={Get_PawnViewForward()}");
        Assert_True(Get_DevourVictim() == _Player, "the server's steward names the pawn's entity as its victim");
        Assert_True(_SeizeAngleDeg >= 0.0 && _SeizeAngleDeg <= k_SeizeToleranceDeg,
            f"the server's steward starts the seize at the client's own view: its View node points {_SeizeAngleDeg :.2} deg from where the client looks (alpha {_SeizeAlpha :.3}, forward {_SeizeForward}, target {Get_TargetForward()})");
        WaitUntil(n"Is_InAliveSampling", n"OnServerSeesEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ServerHoldSeconds, n"OnServerEndWaited");
    }

    UFUNCTION()
    private void OnServerEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserted first: handing the pawn back makes its copy a non-owning one, which replays the history.
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposedForDevour() && _Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive)
            && Get_AreDevourCopiesFound());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        auto Camera = _Player.As_PlayerViewpoint().Get_Camera();
        utils_camera::Request_SnapBoomRotation(Camera, FRotator(k_Pitch, k_Yaw, 0.0));
        WaitUntil(n"Is_InAliveSampling", n"OnClientAliveAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAliveAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_StewardRow(k_Row, "");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _Player, "the client's run ended with its pawn's entity");
        Finish_DevourRow();
    }
}
