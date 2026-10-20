// The view stays held while any holder holds it: hold A and B, release A, still held; release B, free. A hold and a
// release of one holder in one drain apply in arrival order: hold-then-release ends free, release-then-hold ends held.
// The viewpoint has no camera (hand-made fragments, as the player-path rig builds it), so only the holder set is read.
class UMars_AutoTest_PlayerViewpoint_EachHolderKeepsItsOwnHold : UCk_AutoTest_Base
{
    private FCk_Handle_PlayerViewpoint _Viewpoint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        Entity.Add_Fragment(FMars_Feature_PlayerViewpoint());
        Entity.Add_Fragment(FMars_Fragment_PlayerViewpoint());
        _Viewpoint = Entity.As_PlayerViewpoint();

        Add_Step("the control pull and the emote wheel hold the view", n"Step_HoldBoth");
        Add_Step_WaitUntil("the holds are drained", n"Check_Drained", 0, 0);
        Add_Step("both hold: the view is held", n"Step_AssertHeld");
        Add_Step("the control pull releases", n"Step_ReleaseControlPull");
        Add_Step_WaitUntil("the release is drained", n"Check_Drained", 0, 0);
        Add_Step("the emote wheel still holds the view", n"Step_AssertHeld");
        Add_Step("the emote wheel releases", n"Step_ReleaseEmoteWheel");
        Add_Step_WaitUntil("the release is drained", n"Check_Drained", 0, 0);
        Add_Step("no holder is left: the view is free", n"Step_AssertFree");
        Add_Step("the station holds and releases in one drain", n"Step_HoldThenRelease");
        Add_Step_WaitUntil("the batch is drained", n"Check_Drained", 0, 0);
        Add_Step("hold-then-release ends free", n"Step_AssertFree");
        Add_Step("the station releases and holds in one drain", n"Step_ReleaseThenHold");
        Add_Step_WaitUntil("the batch is drained", n"Check_Drained", 0, 0);
        Add_Step("release-then-hold ends held", n"Step_AssertHeld");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Viewpoint.Has_Fragment(FMars_Fragment_PlayerViewpoint_Requests) == false);
    }

    UFUNCTION()
    private void Step_HoldBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Viewpoint.Get_IsViewHeld(), "the view starts free");
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::ControlPull));
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::EmoteWheel));
    }

    UFUNCTION()
    private void Step_ReleaseControlPull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::ControlPull));
    }

    UFUNCTION()
    private void Step_ReleaseEmoteWheel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::EmoteWheel));
    }

    UFUNCTION()
    private void Step_HoldThenRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::Station));
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::Station));
    }

    UFUNCTION()
    private void Step_ReleaseThenHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::Station));
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::Station));
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Viewpoint.Get_IsViewHeld(), "the view is held");
    }

    UFUNCTION()
    private void Step_AssertFree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Viewpoint.Get_IsViewHeld(), "the view is free");
    }
}
