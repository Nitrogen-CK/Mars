// A client picks up a torch with the production pawn and holds it. The authority holds the same torch in the client
// body's hand (the server's report: its copy of the hand mount rides the body, the torch at HeldOffset on it, within
// k_GripCm of grip_r), and the torch's root pose replicates from there; on the client the torch stays in its first-person
// hand regardless: over k_WatchSeconds after the report arrives, every frame its hand mount is under its gloves and the
// torch's root is within k_HandToleranceCm of HeldOffset on it.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsHeldTorchStaysInItsFirstPersonHand
class UCk_AutoTest_Net_RealPawn_AClientsHeldTorchStaysInItsFirstPersonHand : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(924000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsHeldTorchStaysInItsFirstPersonHand";
    private const float64 k_HandToleranceCm = 5.0;
    private const float64 k_GripCm = 30.0;
    private const float64 k_WatchSeconds = 2.0;

    private FCk_Handle_WorldItem _Torch;
    private int32 _Watched = 0;
    private int32 _Strayed = 0;
    private float64 _MaxError = 0.0;
    private FString _FirstStray;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_Report();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
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
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        Spawn_ServerWorldItem(mars_items::Torch(), _Base + k_ItemFromBase);
        Mark_Deadline(16.0);
        WaitUntil(n"Is_ServerHoldsTheTorch", n"OnServerHoldsTheTorch", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldsTheTorch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Torch()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnServerHoldsTheTorch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Write_HandReport();
        const auto Report = Get_Report();
        Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Torch())} onBody={Report.IsMountOnBody} fromMount={Report.HeldFromHandMountCm :.2} fromGrip={Report.HeldFromBodyGripCm :.2}");
        Assert_True(Get_IsHolding(mars_items::Torch()), "the server's copy of the client's HeldItem holds the torch");
        WaitSeconds(k_ServerHoldSeconds + float32(k_WatchSeconds) + 2.0f, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientTorchFound", n"OnClientTorchFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientTorchFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Torch = Find_WorldItemNear(mars_items::Torch(), _Base + k_ItemFromBase, 150.0);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || ck::IsValid(_Torch));
    }

    UFUNCTION()
    private void OnClientTorchFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Torch))
        {
            Log_RealPawnRow(k_Row, "torch=missing");
            FinishFailure("the client never saw the torch the server spawned in front of its pawn");
            return;
        }

        utils_cue_generic::Request_ExecuteCue(_Torch, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(12.0);
        WaitUntil(n"Is_ClientHoldingWithReport", n"OnClientHoldingWithReport", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingWithReport(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Torch()) && Get_IsPresentationAtHand(k_HandToleranceCm)
            && Get_Report().Serial > 0));
    }

    UFUNCTION()
    private void OnClientHoldingWithReport(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Torch())} presentationError={Get_PresentationErrorCm() :.2} report={Get_Report().Serial}");
            FinishFailure("the client did not come to hold the torch at its first-person hand, or the server's report never arrived");
            return;
        }

        Mark_Deadline(k_WatchSeconds);
        WaitUntil(n"Is_ClientWatched", n"OnClientChecked", k_SlowPolls);
    }

    // Every frame of the watch: the mount is under the gloves and the torch at HeldOffset on it.
    UFUNCTION()
    private void Is_ClientWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Error = Get_PresentationErrorCm();
        const auto IsFirstPerson = Get_IsMountFirstPerson();
        _Watched += 1;
        _MaxError = Math::Max(_MaxError, Error);
        if (IsFirstPerson == false || Error < 0.0 || Error > k_HandToleranceCm)
        {
            if (_Strayed == 0)
            { _FirstStray = f"frame {_Watched}: firstPersonMount={IsFirstPerson} error={Error :.2}"; }

            _Strayed += 1;
        }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline());
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_Report();
        Log_RealPawnRow(k_Row, f"watched={_Watched} strayed={_Strayed} maxError={_MaxError :.2} first=[{_FirstStray}] serverOnBody={Report.IsMountOnBody} serverFromMount={Report.HeldFromHandMountCm :.2} serverFromGrip={Report.HeldFromBodyGripCm :.2}");
        Assert_True(Report.IsMountOnBody, "on the server the client's hand mount rides the body");
        Assert_True(Report.HeldFromHandMountCm >= 0.0 && Report.HeldFromHandMountCm <= k_HandToleranceCm,
            f"the server holds the torch at HeldOffset on the body's hand mount (error {Report.HeldFromHandMountCm :.2} cm)");
        Assert_True(Report.HeldFromBodyGripCm >= 0.0 && Report.HeldFromBodyGripCm <= k_GripCm,
            f"the server holds the torch in the client body's right hand ({Report.HeldFromBodyGripCm :.2} cm from grip_r)");
        Assert_True(_Watched > 10, f"the client watched its torch ({_Watched} frames)");
        Assert_True(_Strayed == 0,
            f"the client's torch stayed in its first-person hand every frame of {k_WatchSeconds} s ({_Strayed} of {_Watched} strayed, max error {_MaxError :.2} cm; first: {_FirstStray})");
        FinishSuccess();
    }
}
