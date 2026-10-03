// A Play request broadcasts OnPhaseChanged exactly once, Lobby -> Live.
class UMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive : UCk_AutoTest_Base
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
        Add_Step_WaitUntil("OnPhaseChanged fired", n"Check_Broadcast", 0, 5.0f);
        Add_Step_WaitSeconds("a second broadcast would land in this window", 0.5f);
        Add_Step("one broadcast, carrying Lobby -> Live", n"Step_AssertOnceLobbyToLive");
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
    private void Check_Broadcast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Count >= 1);
    }

    UFUNCTION()
    private void Step_AssertOnceLobbyToLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Count, 1, "OnPhaseChanged broadcast count for one Play");

        const auto PreviousPhase = _Prev.GetValue();
        const auto NewPhase = _New.GetValue();
        Assert_True(PreviousPhase == EMars_CampPhase::Lobby, f"previous phase is Lobby (got {PreviousPhase :n})");
        Assert_True(NewPhase == EMars_CampPhase::Live, f"new phase is Live (got {NewPhase :n})");
        Assert_True(_Session.Get_IsLive(), "the session is Live after the Play");
    }
}
