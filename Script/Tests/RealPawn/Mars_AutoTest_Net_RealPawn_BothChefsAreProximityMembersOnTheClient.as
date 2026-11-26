// Two chefs, one nobody plays and one the client plays, join the proximity channel by name with no join code (each
// talker's Spec lists the channel, the channel's Spec enables auto-join; the server joins them). The client learns the
// membership from the channel's replicated control plane: on the client, its copies of both chefs are members that can
// talk and hear. The channel is the production Spec on the test subject (see Mars_AutoTestRig_NetRealPawnVoice.as).
// Surface: Ck.RealPawn.Net.AS_RealPawn_BothChefsAreProximityMembersOnTheClient
class UCk_AutoTest_Net_RealPawn_BothChefsAreProximityMembersOnTheClient : UMars_AutoTestRig_NetRealPawnVoice
{
    private const FVector k_Base = FVector(958000.0, 0.0, 5000.0);
    private const FString k_Row = "BothChefsAreProximityMembersOnTheClient";
    // The server holds this long once the client runs its own chef, so the client's check lands before the chefs go.
    private const float32 k_ClientCheckSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_VoiceRig();

        if (Get_IsServer() == false)
        {
            Mark_Deadline(20.0);
            WaitUntil(n"Is_ClientSeesMembers", n"OnClientChecked", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        Mark_Deadline(15.0);
        WaitUntil(n"Is_ServerSeesMembers", n"OnServerChecked", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    // Both chefs joined on the server, and the client runs its own chef (the server's copy entered the client's Alive).
    UFUNCTION()
    private void Is_ServerSeesMembers(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsPawnComposed() && Get_IsMember(_Pawn) && Get_IsMember(_Viewer) && Get_IsViewerAlive()));
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_VoiceRow(k_Row, f"members={Get_MemberCount()} unplayed=[{Describe_Talker(_Pawn)}] clientChef=[{Describe_Talker(_Viewer)}] viewerAlive={Get_IsViewerAlive()}");
        Assert_True(Get_IsMember(_Pawn), f"the chef nobody plays joined the proximity channel on the server ([{Describe_Talker(_Pawn)}])");
        Assert_True(Get_IsMember(_Viewer), f"the client's chef joined the proximity channel on the server ([{Describe_Talker(_Viewer)}])");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        WaitSeconds(k_ClientCheckSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientSeesMembers(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsPawnComposed() && ck::IsValid(Get_Viewer()) && Get_IsMember(_Pawn) && Get_IsMember(Get_Viewer())));
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_VoiceRow(k_Row, f"members={Get_MemberCount()} unplayed=[{Describe_Talker(_Pawn)}] ownChef=[{Describe_Talker(Get_Viewer())}]");
        Assert_True(Get_IsMember(_Pawn), f"the client sees the chef nobody plays in the proximity channel ([{Describe_Talker(_Pawn)}])");
        Assert_True(Get_IsMember(Get_Viewer()), f"the client sees its own chef in the proximity channel ([{Describe_Talker(Get_Viewer())}])");
        Assert_True(Get_CanTalkAndHear(_Pawn), "the chef nobody plays can talk and hear in the channel on the client");
        Assert_True(Get_CanTalkAndHear(Get_Viewer()), "the client's own chef can talk and hear in the channel on the client");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        FinishSuccess();
    }

    private bool Get_CanTalkAndHear(AMars_PlayerCharacter InPawn)
    {
        if (Get_IsMember(InPawn) == false)
        { return false; }

        const auto Flags = utils_voice_channel::Get_MemberFlags(_Channel, Get_TalkerOf(InPawn));
        return Flags.Get_CanTalk() == ECk_EnableDisable::Enable && Flags.Get_CanHear() == ECk_EnableDisable::Enable;
    }

    private int32 Get_MemberCount()
    {
        return ck::IsValid(_Channel) ? utils_voice_channel::Get_Members(_Channel).Num() : -1;
    }
}
