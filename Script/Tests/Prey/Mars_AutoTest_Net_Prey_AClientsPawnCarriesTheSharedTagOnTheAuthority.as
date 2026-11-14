// A pawn a joined player controls is prey on the machine with authority: with the viewer possessed by the client's
// controller, the server's copy of the viewer carries TAG_MarsSharedCombatTarget and not TAG_MarsCombatTarget (it is
// player controlled, not locally controlled), and the server's copy of the pawn nobody controls carries neither. The
// client's copies carry neither tag: it has authority over neither.
// Surface: Ck.Prey.Net.AS_Prey_AClientsPawnCarriesTheSharedTagOnTheAuthority
class UCk_AutoTest_Net_Prey_AClientsPawnCarriesTheSharedTagOnTheAuthority : UMars_AutoTestRig_NetPrey
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(590000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const FString k_Row = "AClientsPawnCarriesTheSharedTagOnTheAuthority";

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
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(Get_IsServer() ? k_ServerWatchSeconds : k_SettleSeconds, n"OnWatched");
    }

    UFUNCTION()
    private void OnWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Machine = Get_MachineName();
        auto Viewer = Get_Viewer();
        auto ViewerEntity = Get_PawnEntity(Viewer);
        const auto ViewerShared = Get_HasSharedTag(ViewerEntity);
        const auto ViewerLocalTag = Get_HasLocalTag(ViewerEntity);
        const auto ViewerAuthority = ck::IsValid(ViewerEntity) && utils_net::Get_HasAuthority(ViewerEntity);
        const auto ViewerLocal = ck::IsValid(Viewer) && Viewer.IsLocallyControlled();
        const auto ViewerPlayer = Get_IsPlayerControlled(ViewerEntity);
        Log_PreyRow(k_Row, f"viewer=[shared {ViewerShared} local {ViewerLocalTag} authority {ViewerAuthority} locallyControlled {ViewerLocal} playerControlled {ViewerPlayer}]");

        Assert_Valid(_Player, f"the {Machine}'s copy of the pawn composed");
        Assert_Valid(ViewerEntity, f"the {Machine}'s copy of the viewer composed");
        Assert_False(Get_HasSharedTag(_Player), f"the {Machine}'s copy of the pawn carries no TAG_MarsSharedCombatTarget");
        Assert_False(Get_HasLocalTag(_Player), f"the {Machine}'s copy of the pawn carries no TAG_MarsCombatTarget");
        Assert_False(ViewerLocalTag, f"the {Machine}'s copy of the viewer carries no TAG_MarsCombatTarget");
        if (Get_IsServer())
        {
            Assert_True(ViewerShared, "the server's copy of the viewer carries TAG_MarsSharedCombatTarget");
            Assert_True(ViewerPlayer, "the server reads the viewer player controlled");
            Assert_False(ViewerLocal, "the server does not control the viewer locally");
        }
        else
        {
            Assert_True(ViewerLocal, "the client controls the viewer locally");
            Assert_False(ViewerShared, "the client's copy of the viewer carries no TAG_MarsSharedCombatTarget");
            Assert_False(ck::IsValid(_Player) && utils_net::Get_HasAuthority(_Player), "the client has no authority over the pawn's entity");
            Assert_False(ViewerAuthority, "the client has no authority over the viewer's entity");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Machine}");
        // The server's watch is its hold: it wrote nothing after the spawn.
        TearDown();
        FinishSuccess();
    }
}
