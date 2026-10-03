// A second Play while Live changes nothing: no second broadcast, still Live.
class UMars_AutoTest_CampSession_PlayWhileLiveIsIgnored : UCk_AutoTest_Base
{
    private FCk_Handle_CampSession _Session;
    private int32 _Count = 0;
    private TOptional<EMars_CampPhase> _Prev;
    private TOptional<EMars_CampPhase> _New;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Local = InHandle;
        auto Spec = FMars_CampSession_Spec();
        _Session = utils_camp_session::Add(Local, Spec);

        _Session.BindTo_OnPhaseChanged(FMars_Delegate_CampSession_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step("request Play", n"Step_RequestPlay");
        Add_Step_WaitUntil("OnPhaseChanged fired once", n"Check_BroadcastOnce", 0, 5.0f);
        Add_Step("the broadcast carried Lobby -> Live", n"Step_AssertLobbyToLive");
        Add_Step("request Play again while Live", n"Step_RequestPlay");
        Add_Step_WaitSeconds("second play window", 0.5f);
        Add_Step("still one broadcast and still Live", n"Step_AssertIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew)
    {
        _Count += 1;
        _Prev = TOptional<EMars_CampPhase>(InPrevious);
        _New = TOptional<EMars_CampPhase>(InNew);
    }

    UFUNCTION()
    private void Step_RequestPlay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Session.Request_Play();
    }

    UFUNCTION()
    private void Check_BroadcastOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Count == 1);
    }

    UFUNCTION()
    private void Step_AssertLobbyToLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PreviousPhase = _Prev.GetValue();
        const auto NewPhase = _New.GetValue();
        Assert_True(PreviousPhase == EMars_CampPhase::Lobby, f"previous phase is Lobby (got {PreviousPhase :n})");
        Assert_True(NewPhase == EMars_CampPhase::Live, f"new phase is Live (got {NewPhase :n})");
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Count, 1, "OnPhaseChanged broadcast count after the second Play");
        Assert_True(_Session.Get_IsLive(), "Get_IsLive after the second Play");
    }
}
