// Focus and Unfocus queued in one frame apply in the order they were requested. A focused interactable that is unfocused
// and focused again in one frame (a player's focus sliding A -> B -> A) ends focused by its focuser, after an OnUnfocused
// then an OnFocused; an unfocused one focused and unfocused again in one frame ends unfocused, after an OnFocused then an
// OnUnfocused. The focuser is the test entity. Isolated Z band: -83000.
class UMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder : UCk_AutoTest_Base
{
    private FCk_Handle _Focuser;
    private FCk_Handle_Interactable _Interactable;
    private TArray<EMars_Interactable_FocusChange> _Events;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Focuser = InHandle;

        auto OwnerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto OwnerRoot = utils_transform::Add(OwnerEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -83000.0)),
            ECk_Replication::DoesNotReplicate);
        _Interactable = utils_interactable::Create(OwnerRoot, FMars_Interactable_Spec());
        _Interactable.BindTo_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnFocused"));
        _Interactable.BindTo_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnUnfocused"));

        Add_Step("focus the interactable", n"Step_Focus");
        Add_Step_WaitUntil("the interactable is focused", n"Check_OneEvent", 0, 5.0f);
        Add_Step("queue Unfocus then Focus in one frame", n"Step_UnfocusThenFocus");
        Add_Step_WaitUntil("both changes drained", n"Check_ThreeEvents", 0, 5.0f);
        Add_Step("the later Focus wins: focused by the focuser, unfocused then focused", n"Step_AssertFocused");
        Add_Step("unfocus the interactable", n"Step_Unfocus");
        Add_Step_WaitUntil("the interactable is unfocused", n"Check_FourEvents", 0, 5.0f);
        Add_Step("queue Focus then Unfocus in one frame", n"Step_FocusThenUnfocus");
        Add_Step_WaitUntil("both changes drained", n"Check_SixEvents", 0, 5.0f);
        Add_Step("the later Unfocus wins: unfocused, focused then unfocused", n"Step_AssertUnfocused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnFocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InFocusedBy)
    {
        _Events.Add(EMars_Interactable_FocusChange::Focus);
    }

    UFUNCTION()
    private void OnUnfocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InUnfocusedBy)
    {
        _Events.Add(EMars_Interactable_FocusChange::Unfocus);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Focuser));
    }

    UFUNCTION()
    private void Step_Unfocus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Focuser));
    }

    UFUNCTION()
    private void Step_UnfocusThenFocus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Focuser));
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Focuser));
    }

    UFUNCTION()
    private void Step_FocusThenUnfocus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Focuser));
        _Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Focuser));
    }

    UFUNCTION()
    private void Check_OneEvent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Events.Num() >= 1);
    }

    UFUNCTION()
    private void Check_ThreeEvents(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Events.Num() >= 3);
    }

    UFUNCTION()
    private void Check_FourEvents(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Events.Num() >= 4);
    }

    UFUNCTION()
    private void Check_SixEvents(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Events.Num() >= 6);
    }

    UFUNCTION()
    private void Step_AssertFocused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Interactable.Get_IsFocused(), "Unfocus then Focus in one frame leaves the interactable focused");
        Assert_True(_Interactable.Get_CurrentFocuser() == _Focuser, "the focuser is the one that focused last");

        Assert_Equals_Int(_Events.Num(), 3, "focus, then one event per queued change");
        if (_Events.Num() == 3)
        {
            Assert_True(_Events[1] == EMars_Interactable_FocusChange::Unfocus, "the queued Unfocus broadcast first");
            Assert_True(_Events[2] == EMars_Interactable_FocusChange::Focus, "the queued Focus broadcast second");
        }
    }

    UFUNCTION()
    private void Step_AssertUnfocused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Interactable.Get_IsFocused(), "Focus then Unfocus in one frame leaves the interactable unfocused");
        Assert_False(ck::IsValid(_Interactable.Get_CurrentFocuser()), "no focuser is left");

        Assert_Equals_Int(_Events.Num(), 6, "one event per change since the unfocus");
        if (_Events.Num() == 6)
        {
            Assert_True(_Events[4] == EMars_Interactable_FocusChange::Focus, "the queued Focus broadcast first");
            Assert_True(_Events[5] == EMars_Interactable_FocusChange::Unfocus, "the queued Unfocus broadcast second");
        }
    }
}
