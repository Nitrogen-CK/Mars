// A new session starts in Lobby; a Play request moves it to Live.
class UMars_AutoTest_CampSession_PlayTransitionsToLive : UCk_AutoTest_Base
{
    private FCk_Handle_CampSession _Session;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Local = InHandle;
        auto Spec = FMars_CampSession_Spec();
        _Session = utils_camp_session::Add(Local, Spec);

        Add_Step("the session starts in Lobby", n"Step_AssertLobby");
        Add_Step("request Play", n"Step_RequestPlay");
        Add_Step_WaitUntil("the session is Live", n"Check_IsLive", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLobby(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Session.Get_Phase() == EMars_CampPhase::Lobby, "Phase is Lobby at Add");
        Assert_False(_Session.Get_IsLive(), "Get_IsLive is false at Add");
    }

    UFUNCTION()
    private void Step_RequestPlay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Session.Request_Play();
    }

    UFUNCTION()
    private void Check_IsLive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Session.Get_IsLive());
    }
}
