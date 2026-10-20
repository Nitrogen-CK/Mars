// A devourer destroyed while it holds a victim never releases it, but its victim is free again: the marker it left
// names a devourer that is gone, so another devourer can seize the victim and its marker takes over.
class UMars_AutoTest_Devour_ADestroyedDevourerFreesItsVictim : UCk_AutoTest_Base
{
    private FCk_Handle _Devourer;
    private FCk_Handle_Devour _Devour;
    private FCk_Handle_Devour _OtherDevour;
    private FCk_Handle _Victim;
    private int32 _Seizes = 0;
    private int32 _OtherSeizes = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Devourer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto OtherDevourer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Victim = utils_entity_lifetime::Request_CreateEntity(InHandle);

        // Long phases: both runs are still in Seize when the test ends.
        auto Spec = FMars_Devour_Spec();
        Spec.Timing.SeizeSeconds = 30.0f;
        _Devour = utils_devour::Add(_Devourer, Spec);
        _OtherDevour = utils_devour::Add(OtherDevourer, Spec);

        _Devour.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnPhaseChanged"));
        _OtherDevour.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnOtherPhaseChanged"));

        Add_Step("the first devourer's Begin", n"Step_Begin");
        Add_Step_WaitUntil("the victim is seized", n"Check_Seized", 0, 0);
        Add_Step("the held victim is closed to the other devourer; the first devourer is destroyed", n"Step_DestroyDevourer");
        Add_Step_WaitUntil("the first devourer is gone", n"Check_DevourerGone", 0, 0);
        Add_Step("the other devourer's Begin", n"Step_OtherBegin");
        Add_Step_WaitUntil("the other devourer seizes the victim", n"Check_OtherSeized", 0, 0);
        Add_Step("the victim is the other devourer's", n"Step_AssertTakenOver");
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
    private void Step_Begin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Devour.Request_Begin(FMars_Request_Devour_Begin(_Victim));
    }

    UFUNCTION()
    private void Check_Seized(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Seizes == 1);
    }

    UFUNCTION()
    private void Step_DestroyDevourer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_devour::TryGet_Devourer(_Victim) == _Devour, "the victim carries the first devourer's marker");
        Assert_False(_OtherDevour.Get_CanSeize(_Victim), "a victim held by a live devourer cannot be seized by another");

        utils_entity_lifetime::Request_DestroyEntity(_Devourer);
    }

    UFUNCTION()
    private void Check_DevourerGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Devour));
    }

    UFUNCTION()
    private void Step_OtherBegin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Victim.Has_Fragment(FMars_Fragment_Devour_Victim), "the destroyed devourer left its marker on the victim");
        Assert_False(ck::IsValid(utils_devour::TryGet_Devourer(_Victim)), "a marker naming a destroyed devourer names no devourer");
        Assert_True(_OtherDevour.Get_CanSeize(_Victim), "the victim of a destroyed devourer can be seized again");

        _OtherDevour.Request_Begin(FMars_Request_Devour_Begin(_Victim));
    }

    UFUNCTION()
    private void Check_OtherSeized(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OtherSeizes == 1);
    }

    UFUNCTION()
    private void Step_AssertTakenOver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_OtherSeizes, 1, "the other devourer seized once");
        Assert_True(_OtherDevour.Get_Victim() == _Victim, "the other devourer holds the victim");
        Assert_True(utils_devour::TryGet_Devourer(_Victim) == _OtherDevour, "the victim's marker names the other devourer");
        Assert_True(_OtherDevour.Get_Phase() == EMars_Devour_Phase::Seize, "the other devourer's run is in Seize");
    }
}
