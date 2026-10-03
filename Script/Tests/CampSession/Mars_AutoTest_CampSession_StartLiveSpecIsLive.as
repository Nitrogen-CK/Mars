// A session whose spec starts Live is Live from Add, stays Live once its state machine starts, and never broadcasts a phase change.
class UMars_AutoTest_CampSession_StartLiveSpecIsLive : UCk_AutoTest_Base
{
    private FCk_Handle_CampSession _Session;
    private int32 _Count = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Local = InHandle;
        auto Spec = FMars_CampSession_Spec();
        Spec.StartPhase = EMars_CampPhase::Live;
        _Session = utils_camp_session::Add(Local, Spec);

        _Session.BindTo_OnPhaseChanged(FMars_Delegate_CampSession_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step("the session is Live at Add", n"Step_AssertLive");
        Add_Step_WaitSeconds("SM start window", 0.5f);
        Add_Step("the session is still Live and never broadcast", n"Step_AssertStillLiveNoBroadcast");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew)
    {
        _Count += 1;
    }

    UFUNCTION()
    private void Step_AssertLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Session.Get_IsLive(), "Get_IsLive is true at Add");
    }

    UFUNCTION()
    private void Step_AssertStillLiveNoBroadcast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Session.Get_IsLive(), "Get_IsLive is still true after the SM start window");
        Assert_Equals_Int(_Count, 0, "OnPhaseChanged broadcast count");
    }
}
