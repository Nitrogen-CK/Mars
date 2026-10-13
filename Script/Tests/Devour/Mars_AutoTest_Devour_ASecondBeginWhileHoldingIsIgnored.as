// One victim at a time: while a devourer holds a victim it cannot seize another, a Begin for a second victim changes
// nothing, and a victim held by one devourer cannot be seized by another.
class UMars_AutoTest_Devour_ASecondBeginWhileHoldingIsIgnored : UCk_AutoTest_Base
{
    private FCk_Handle_Devour _Devour;
    private FCk_Handle_Devour _OtherDevour;
    private FCk_Handle _First;
    private FCk_Handle _Second;
    private int32 _Seizes = 0;
    private int32 _OtherSeizes = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Devourer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto OtherDevourer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _First = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Second = utils_entity_lifetime::Request_CreateEntity(InHandle);

        // Long phases: the first victim is still held when the test ends.
        auto Spec = FMars_Devour_Spec();
        Spec.Timing.SeizeSeconds = 30.0f;
        _Devour = utils_devour::Add(Devourer, Spec);
        _OtherDevour = utils_devour::Add(OtherDevourer, Spec);

        _Devour.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnPhaseChanged"));
        _OtherDevour.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnOtherPhaseChanged"));

        Add_Step("the first Begin", n"Step_BeginFirst");
        Add_Step_WaitUntil("the first victim is seized", n"Check_Seized", 0, 0);
        Add_Step("a second Begin, and another devourer's Begin for the held victim", n"Step_BeginAgain");
        Add_Step_WaitSeconds("either would be taken in this window", 0.5f);
        Add_Step("nothing changed", n"Step_AssertUnchanged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        if (InPhase == EMars_Devour_Phase::Seize)
        { _Seizes += 1; }
    }

    UFUNCTION()
    private void OnOtherPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        if (InPhase == EMars_Devour_Phase::Seize)
        { _OtherSeizes += 1; }
    }

    UFUNCTION()
    private void Step_BeginFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Devour.Request_Begin(FMars_Request_Devour_Begin(_First));
    }

    UFUNCTION()
    private void Check_Seized(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Seizes >= 1);
    }

    UFUNCTION()
    private void Step_BeginAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Devour.Get_CanSeize(_Second), "a devourer holding a victim cannot seize another");
        Assert_False(_OtherDevour.Get_CanSeize(_First), "a held victim cannot be seized by another devourer");

        _Devour.Request_Begin(FMars_Request_Devour_Begin(_Second));
        _OtherDevour.Request_Begin(FMars_Request_Devour_Begin(_First));
    }

    UFUNCTION()
    private void Step_AssertUnchanged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Seizes, 1, "the devourer seized once");
        Assert_Equals_Int(_OtherSeizes, 0, "the other devourer seized nothing");
        Assert_True(_Devour.Get_Victim() == _First, "the devourer still holds its first victim");
        Assert_True(utils_devour::TryGet_Devourer(_First) == _Devour, "the first victim is still this devourer's");
        Assert_False(ck::IsValid(utils_devour::TryGet_Devourer(_Second)), "the second victim was never marked");
        Assert_False(_OtherDevour.Get_IsActive(), "the other devourer is still Idle");
    }
}
