// The lit-lantern rows' shared steps on the real-pawn rig: the server spawns the production pawn, a lantern in front of
// it and, in the row's order, hands the pawn to the client's controller and picks the lantern up for it and lights it.
// The client watches its copy of the lantern (UMars_AutoTestHelper_HeldFlameDepth): the order its mount and its pawn's
// first-person flip came in, the deepest scene node under the lantern while it is held, and where the flame node and
// its light sit, before and after the client turns its view. Each machine asserts no ensure in this PIE process (both
// machines share the counter).
UCLASS(Abstract)
class UMars_AutoTestRig_NetRealPawnLitLantern : UMars_AutoTestRig_NetRealPawn
{
    default _TimeoutSeconds = 28.0f;

    // A held lit lantern on its owner's first-person view: hand mount 5, lantern root 6, bail 7, flame node and light
    // 8.
    protected const int32 k_DeepestDepth = 8;
    protected const float64 k_LightToleranceCm = 0.1;
    protected const float64 k_FlameNodeToleranceCm = 0.5;
    protected const float64 k_TurnDegrees = 90.0;
    // After the turn the light has moved with the hand (k_TurnLeastMoveCm in the world) and stays within
    // k_TurnMountDriftCm of where it hung in the hand mount's frame (the bail may swing).
    protected const float64 k_TurnLeastMoveCm = 20.0;
    protected const float64 k_TurnMountDriftCm = 10.0;
    protected const float64 k_LanternSettleSeconds = 1.0;
    protected const float64 k_RestWithinSeconds = 4.0;
    protected const float64 k_TurnSeconds = 0.5;
    protected const float64 k_AfterTurnSeconds = 1.0;
    protected const float32 k_ServerStepSeconds = 1.0f;
    protected const float32 k_ServerHoldWholeSeconds = 9.0f;

    // Set by each row before Run_LitLantern: possession before the pickup (or after it), the base, the row's name.
    protected bool _PossessFirst = true;
    protected FString _Row = "";

    protected UMars_AutoTestHelper_HeldFlameDepth _Watch;
    private FCk_Handle _Lantern;

    private float64 _HeldSeconds = 0.0;
    private float64 _LightErrorBefore = -1.0;
    private float64 _LightErrorAfter = -1.0;
    private float64 _FlameNodeErrorBefore = -1.0;
    private FVector _LightWorldBefore = FVector::ZeroVector;
    private FVector _LightInMountBefore = FVector::ZeroVector;
    private float64 _LightMoved = -1.0;
    private float64 _LightMountDrift = -1.0;

    protected void Run_LitLantern(FCk_Handle InHandle, FVector InBase)
    {
        Begin_Rig(InBase);
        _Watch = Cast<UMars_AutoTestHelper_HeldFlameDepth>(NewObject(this, UMars_AutoTestHelper_HeldFlameDepth));

        if (Get_IsServer() == false)
        {
            Mark_Deadline(22.0);
            WaitUntil(n"Is_ClientLanternHeldFirstPerson", n"OnClientLanternHeld", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerJoltFloor(InHandle);
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_PossessFirst == false)
        {
            OnServerLanternDue(InTimer, InChrono, InDeltaT);
            return;
        }

        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        WaitSeconds(k_ServerStepSeconds, n"OnServerLanternDue");
    }

    UFUNCTION()
    private void OnServerLanternDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Lantern = Spawn_ServerWorldItem(mars_items::Lantern(), _Base + k_ItemFromBase);
        Mark_Deadline(6.0);
        WaitUntil(n"Is_ServerLanternReady", n"OnServerLanternReady", k_SlowPolls);
    }

    private bool Get_IsServerLanternReady()
    {
        const auto WorldItem = _Lantern.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        return ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() && ck::IsValid(WorldItem.Get_HeldItem())
            && ck::IsValid(_Lantern.As_Flame(ECk_SanityCheck::UnChecked)) && ck::IsValid(Hotbar) && Hotbar.Get_IsReady();
    }

    UFUNCTION()
    private void Is_ServerLanternReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsServerLanternReady());
    }

    // The client sees the lantern on the floor before it is picked up.
    UFUNCTION()
    private void OnServerLanternReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServerLanternReady() == false)
        { FinishFailure("the server's lantern did not link its item, compose its flame or find the pawn's hotbar ready"); return; }

        WaitSeconds(k_ServerStepSeconds, n"OnServerRaiseDue");
    }

    // What a client's pickup cue becomes on the host, and the lantern lit.
    UFUNCTION()
    private void OnServerRaiseDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto WorldItem = _Lantern.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        auto Flame = _Lantern.As_Flame();
        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
        Mark_Deadline(6.0);
        WaitUntil(n"Is_ServerHoldingTheLitLantern", n"OnServerHoldingTheLitLantern", k_SlowPolls);
    }

    private bool Get_IsServerHoldingTheLitLantern()
    {
        const auto Flame = _Lantern.As_Flame(ECk_SanityCheck::UnChecked);
        return Get_IsHolding(mars_items::Lantern()) && ck::IsValid(Flame) && Flame.Get_IsLit();
    }

    UFUNCTION()
    private void Is_ServerHoldingTheLitLantern(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsServerHoldingTheLitLantern());
    }

    UFUNCTION()
    private void OnServerHoldingTheLitLantern(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServerHoldingTheLitLantern() == false)
        { FinishFailure("the server's pawn did not come to hold the lit lantern"); return; }

        if (_PossessFirst)
        {
            OnServerPossessed(InTimer, InChrono, InDeltaT);
            return;
        }

        WaitSeconds(k_ServerStepSeconds, n"OnServerPossessDue");
    }

    UFUNCTION()
    private void OnServerPossessDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        OnServerPossessed(InTimer, InChrono, InDeltaT);
    }

    // The server holds the row open while the client asserts.
    UFUNCTION()
    private void OnServerPossessed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldWholeSeconds, n"OnServerHoldDone");
    }

    UFUNCTION()
    private void OnServerHoldDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_RealPawnRow(_Row, f"holding={Get_IsServerHoldingTheLitLantern()}");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure in this PIE process (both machines share the counter), on the server");
        OnServerHeld(InTimer, InChrono, InDeltaT);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The pawn's copy and the flame item near the lantern's spot, watched from the first sample both are found.
    private void Sample_Watch()
    {
        if (Get_IsPawnComposed() == false)
        { return; }

        if (_Watch.Get_IsWatching() == false)
        {
            const auto Spot = _Base + k_ItemFromBase;
            for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
            {
                auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
                if (ck::Is_NOT_Valid(WorldItem) || ck::Is_NOT_Valid(Candidate.As_Flame(ECk_SanityCheck::UnChecked)))
                { continue; }

                if ((Get_RootLocation(Candidate) - Spot).Size() < 300.0)
                {
                    _Watch.Watch(_Pawn, WorldItem);
                    break;
                }
            }
        }

        _Watch.Sample();
    }

    private bool Get_IsClientLanternHeldFirstPerson()
    {
        if (_Watch.Get_IsWatching() == false || _Watch.Item.Get_Mount() != EMars_WorldItem_Mount::Held
            || _Watch.Get_HandMountParent() != "firstPerson")
        { return false; }

        const auto Flame = _Watch.Item.H().As_Flame(ECk_SanityCheck::UnChecked);
        const auto HeldItem = Get_HeldItem();
        return ck::IsValid(Flame) && Flame.Get_IsLit() && ck::IsValid(HeldItem) && HeldItem.Get_IsPresentationInHand()
            && HeldItem.Get_IsPresentationSettled();
    }

    UFUNCTION()
    private void Is_ClientLanternHeldFirstPerson(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Watch();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsClientLanternHeldFirstPerson());
    }

    // The arrival had k_LanternSettleSeconds and the flame node stands over the root (the bail rests), or the deadline.
    UFUNCTION()
    private void Is_ClientBailAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Watch();
        const auto Error = _Watch.Get_FlameNodeErrorCm();
        const auto Settled = Get_WorldSecondsNow() - _HeldSeconds >= k_LanternSettleSeconds;
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Settled && Error >= 0.0 && Error <= k_FlameNodeToleranceCm));
    }

    private float64 Get_WorldSecondsNow()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        return System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Is_ClientSampledToDeadline(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Watch();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline());
    }

    UFUNCTION()
    private void OnClientLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsClientLanternHeldFirstPerson() == false)
        {
            Log_LitLanternRow();
            FinishFailure("the client's lantern never came to rest lit in its first-person hand");
            return;
        }

        _HeldSeconds = Get_WorldSecondsNow();
        Mark_Deadline(k_RestWithinSeconds);
        WaitUntil(n"Is_ClientBailAtRest", n"OnClientSettled", k_SlowPolls);
    }

    // The arrival settled: the flame node and the light where the lantern puts them; then the view turns.
    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LightErrorBefore = _Watch.Get_LightErrorCm();
        _FlameNodeErrorBefore = _Watch.Get_FlameNodeErrorCm();
        _LightWorldBefore = _Watch.Get_LightLocation();
        _LightInMountBefore = Get_LightInMount();
        Request_ServerTurnView(FRotator(0.0, _Pawn.GetActorRotation().Yaw + k_TurnDegrees, 0.0));
        Mark_Deadline(k_TurnSeconds);
        WaitUntil(n"Is_ClientSampledToDeadline", n"OnClientTurned", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LightErrorAfter = _Watch.Get_LightErrorCm();
        _LightMoved = (_Watch.Get_LightLocation() - _LightWorldBefore).Size();
        _LightMountDrift = (Get_LightInMount() - _LightInMountBefore).Size();
        Mark_Deadline(k_AfterTurnSeconds);
        WaitUntil(n"Is_ClientSampledToDeadline", n"OnClientWatched", k_SlowPolls);
    }

    // The light in the hand mount's frame.
    private FVector Get_LightInMount()
    {
        const auto Mount = utils_transform::Get_EntityCurrentTransform(_Pawn.Get_HandMount());
        return Mount.InverseTransformPosition(_Watch.Get_LightLocation());
    }

    protected void Log_LitLanternRow()
    {
        Log_RealPawnRow(_Row, f"{_Watch.Describe()} lightErrorBefore={_LightErrorBefore :.3} lightErrorAfter={_LightErrorAfter :.3} "
            + f"flameNodeErrorBefore={_FlameNodeErrorBefore :.3} lightMoved={_LightMoved :.2} lightMountDrift={_LightMountDrift :.2} ensures={Get_NewEnsures()}");
    }

    // The row's order assert (each row names the order it expects).
    protected void Assert_Order()
    {
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_LitLanternRow();
        Assert_Order();
        Assert_True(_Watch.HeldSamples > 0 && _Watch.Deepest >= 0 && _Watch.Deepest <= k_DeepestDepth,
            f"the deepest scene node under the client's held lantern is at most {k_DeepestDepth} (deepest {_Watch.Deepest} over {_Watch.HeldSamples} samples)");
        Assert_True(_LightErrorBefore >= 0.0 && _LightErrorBefore <= k_LightToleranceCm,
            f"the client's light sits half the flame over the flame node once the lantern settled ({_LightErrorBefore} cm off)");
        Assert_True(_LightErrorAfter >= 0.0 && _LightErrorAfter <= k_LightToleranceCm,
            f"the client's light sits half the flame over the flame node after the view turned ({_LightErrorAfter} cm off)");
        Assert_True(_FlameNodeErrorBefore >= 0.0 && _FlameNodeErrorBefore <= k_FlameNodeToleranceCm,
            f"the client's flame node stands the flame height over the lantern's root while the bail rests ({_FlameNodeErrorBefore} cm off)");
        Assert_True(_LightMoved >= k_TurnLeastMoveCm && _LightMountDrift >= 0.0 && _LightMountDrift <= k_TurnMountDriftCm,
            f"the client's light went with the hand as the view turned (moved {_LightMoved} cm, {_LightMountDrift} cm off its place in the hand mount)");
        const auto Flame = _Watch.Item.H().As_Flame(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(Flame) && Flame.Get_IsLit(), "the lantern is lit on the client");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure in this PIE process (both machines share the counter), on the client");
        FinishSuccess();
    }
}

// The server hands the production pawn to the client's controller, waits a second, then picks a lantern up for it and
// lights it. On the client the lantern's mount commits with its hand mount already under the gloves' swing node; while
// it is held no scene node under it is deeper than 8; once its arrival settled, and again after the client turns its
// view 90 degrees, the light sits half the flame over the flame node within 0.1 cm and went with the hand; the flame
// node stands the flame height over the lantern's root within 0.5 cm while the bail rests; the lantern is lit; no
// ensure.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsLitLanternStaysWholeInItsFirstPersonHand
class UCk_AutoTest_Net_RealPawn_AClientsLitLanternStaysWholeInItsFirstPersonHand : UMars_AutoTestRig_NetRealPawnLitLantern
{
    private const FVector k_Base = FVector(942000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _PossessFirst = true;
        _Row = "AClientsLitLanternStaysWholeInItsFirstPersonHand";
        Run_LitLantern(InHandle, k_Base);
    }

    protected void Assert_Order() override
    {
        Assert_True(_Watch.ParentAtMount == "firstPerson",
            f"the client's lantern mounted after its pawn's first-person flip (hand mount under [{_Watch.ParentAtMount}] at the mount)");
    }
}
