// Three pawns stand by the base on the server: one nobody controls, the viewer the client's controller possesses and
// the host pawn the server's local controller possesses. On the server the host pawn carries both TAG_MarsCombatTarget
// and TAG_MarsSharedCombatTarget, the viewer only the shared tag, the pawn neither: a scan of TAG_MarsCombatTarget near
// the base yields the host pawn alone, a scan of the shared tag the host pawn and the viewer. On the client every copy
// carries neither tag and both scans yield nothing.
// Surface: Ck.Prey.Net.AS_Prey_OnlyTheHostsPawnCarriesTheLocalTag
class UCk_AutoTest_Net_Prey_OnlyTheHostsPawnCarriesTheLocalTag : UMars_AutoTestRig_NetPrey
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(593000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const FString k_Row = "OnlyTheHostsPawnCarriesTheLocalTag";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        Spawn_ServerHostPawn();
        WaitUntil(n"Is_ServerReadyWithThreePawns", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReadyWithThreePawns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        auto Viewer = Get_Viewer();
        auto ViewerController = ck::IsValid(Viewer) ? Cast<APlayerController>(Viewer.GetController()) : nullptr;
        const auto IsViewerPossessed = ck::IsValid(ViewerController) && ViewerController.IsLocalController() == false;
        Result.Set(Get_IsPawnComposed() && IsViewerPossessed && Get_IsServerHostPawnReady());
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(Get_IsServer() ? k_ServerWatchSeconds : k_SettleSeconds, n"OnWatched");
    }

    private FString Describe_Tags(FCk_Handle InEntity)
    {
        return f"shared {Get_HasSharedTag(InEntity)} local {Get_HasLocalTag(InEntity)}";
    }

    UFUNCTION()
    private void OnWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Machine = Get_MachineName();
        auto ViewerEntity = Get_PawnEntity(Get_Viewer());
        auto HostEntity = Get_PawnEntity(Get_HostPawn());
        const auto LocalScan = Find_TaggedNearBase(n"TAG_MarsCombatTarget");
        const auto SharedScan = Find_TaggedNearBase(n"TAG_MarsSharedCombatTarget");
        Log_PreyRow(k_Row, f"viewer=[{Describe_Tags(ViewerEntity)}] host=[{Describe_Tags(HostEntity)}] localScan={LocalScan.Num()} sharedScan={SharedScan.Num()}");

        Assert_Valid(_Player, f"the {Machine}'s copy of the pawn composed");
        Assert_Valid(ViewerEntity, f"the {Machine}'s copy of the viewer composed");
        Assert_Valid(HostEntity, f"the {Machine}'s copy of the host pawn composed");
        Assert_False(Get_HasSharedTag(_Player) || Get_HasLocalTag(_Player), f"the {Machine}'s copy of the pawn carries neither tag");
        if (Get_IsServer())
        {
            Assert_True(Get_HasSharedTag(HostEntity) && Get_HasLocalTag(HostEntity), "the server's host pawn carries both tags");
            Assert_True(Get_HasSharedTag(ViewerEntity), "the server's viewer carries TAG_MarsSharedCombatTarget");
            Assert_False(Get_HasLocalTag(ViewerEntity), "the server's viewer carries no TAG_MarsCombatTarget");
            Assert_True(LocalScan.Num() == 1 && LocalScan[0] == HostEntity,
                f"a scan of TAG_MarsCombatTarget near the base yields the host pawn alone (yields {LocalScan.Num()})");
            Assert_True(SharedScan.Num() == 2 && SharedScan.Contains(HostEntity) && SharedScan.Contains(ViewerEntity),
                f"a scan of TAG_MarsSharedCombatTarget near the base yields the host pawn and the viewer (yields {SharedScan.Num()})");
        }
        else
        {
            Assert_False(Get_HasSharedTag(ViewerEntity) || Get_HasLocalTag(ViewerEntity), "the client's viewer carries neither tag");
            Assert_False(Get_HasSharedTag(HostEntity) || Get_HasLocalTag(HostEntity), "the client's host pawn carries neither tag");
            Assert_Equals_Int(LocalScan.Num(), 0, "a scan of TAG_MarsCombatTarget near the base yields nothing on the client");
            Assert_Equals_Int(SharedScan.Num(), 0, "a scan of TAG_MarsSharedCombatTarget near the base yields nothing on the client");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Machine}");
        // The server's watch is its hold: it wrote nothing after the spawns.
        TearDown();
        FinishSuccess();
    }
}
