// A spot that starts closed is Arriving with a partial presence, refuses a cast, and opens after ArriveSeconds
// (OnPresenceChanged Open, presence 1). Leave sends it Leaving: a cast in the same drain is refused, the presence fades,
// and after LeaveSeconds it is Gone (OnPresenceChanged Gone, presence 0). A second Leave is ignored.
class UMars_AutoTest_Fishing_LeaveFadesToGoneAndRefusesACast : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Presence.StartOpen = false;
        Spec.Presence.ArriveSeconds = 0.3f;
        Spec.Presence.LeaveSeconds = 0.3f;
        BuildFishing(InHandle, Spec);

        Add_Step("engage and cast while arriving", n"Step_EngageAndCast");
        Add_Step("the spot is arriving and refused the cast", n"Step_AssertArriving");
        Add_Step_WaitUntil("the spot opens", n"Check_Open");
        Add_Step("the opening broadcast", n"Step_AssertOpen");
        Add_Step("leave and cast in one drain", n"Step_LeaveAndCast");
        Add_Step("the cast was refused and the spot is leaving", n"Step_AssertLeaving");
        Add_Step_WaitUntil("the spot is gone", n"Check_Gone");
        Add_Step("leave again", n"Step_Leave");
        Add_Step_WaitSeconds("a beat", 0.15f);
        Add_Step("the spot is gone and the second leave was ignored", n"Step_AssertGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_EngageAndCast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
    }

    UFUNCTION()
    private void Step_AssertArriving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Presence() == EMars_Fishing_Presence::Arriving, "the spot is Arriving");
        Assert_True(_Fishing.Get_PresenceAlpha() < 1.0f, f"the presence is partial ({_Fishing.Get_PresenceAlpha()})");
        Assert_Equals_Int(_Casts, 0, "no OnCast while arriving");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "Idle");
    }

    UFUNCTION()
    private void Step_AssertOpen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PresenceChanges, 1, "one OnPresenceChanged");
        Assert_True(_LastPresence == EMars_Fishing_Presence::Open, "it broadcast Open");
        Assert_Equals_Float(_Fishing.Get_PresenceAlpha(), 1.0f, 0.0f, "the presence is full");
        Assert_True(_Fishing.Get_IsEngaged(), "the operator stayed through the arrival");
    }

    UFUNCTION()
    private void Step_LeaveAndCast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Leave(FMars_Request_Fishing_Leave());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
    }

    UFUNCTION()
    private void Step_AssertLeaving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Presence() == EMars_Fishing_Presence::Leaving, "the spot is Leaving");
        Assert_Equals_Int(_PresenceChanges, 2, "Leaving broadcast");
        Assert_Equals_Int(_Casts, 0, "the cast in the leave's drain was refused");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "Idle");
    }

    UFUNCTION()
    private void Step_AssertGone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Presence() == EMars_Fishing_Presence::Gone, "the spot is Gone");
        Assert_Equals_Int(_PresenceChanges, 3, "Gone broadcast once; the second Leave changed nothing");
        Assert_Equals_Float(_Fishing.Get_PresenceAlpha(), 0.0f, 0.0f, "the presence is empty");
    }
}
