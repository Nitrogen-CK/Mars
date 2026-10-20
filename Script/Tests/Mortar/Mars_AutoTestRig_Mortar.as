// The mortar rig: a Mortar kernel on a bare entity, nothing drawn. Its timing bar is slow and wide (a 2 s pass, the window
// half the bar, the marker in the middle), so a press timed by a poll lands deep inside or well outside the window
// whatever the frame rate. The handlers count the signals; the steps engage, press and release.
UCLASS(Abstract)
class UMars_AutoTestRig_Mortar : UCk_AutoTest_Base
{
    // A marker wait sees the window come round within one pass of the sweep, plus slack.
    protected const float32 k_MarkerWaitSeconds = 3.0f;

    protected FCk_Handle_Mortar _Mortar;

    protected int32 _StrikesStarted = 0;
    protected int32 _HitsLanded = 0;
    protected int32 _MissesLanded = 0;
    protected int32 _BatchChanges = 0;
    protected FMars_Mortar_Batch _LastBroadcastBatch;

    // The timing bar as the last press saw it.
    protected FMars_Mortar_Window _WindowAtPress;

    protected FMars_Mortar_Spec Make_Spec(int32 InCrushesNeeded) const
    {
        auto Spec = FMars_Mortar_Spec();
        Spec.Timing.SweepSeconds = 2.0f;
        Spec.Timing.WindowHalfWidth = 0.5f;
        Spec.Timing.Marker = 0.5f;
        Spec.CrushesNeeded = InCrushesNeeded;
        return Spec;
    }

    protected void BuildMortar(FCk_Handle InHandle, FMars_Mortar_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Mortar = utils_mortar::Add(Entity, InSpec);
        Assert_True(ck::IsValid(_Mortar), "the mortar composed");

        _Mortar.BindTo_OnStrikeStarted(FMars_Delegate_Mortar_OnStrikeStarted(this, n"OnStrikeStarted"));
        _Mortar.BindTo_OnStrikeLanded(FMars_Delegate_Mortar_OnStrikeLanded(this, n"OnStrikeLanded"));
        _Mortar.BindTo_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged"));
    }

    protected int32 Get_StrikesLanded() const
    {
        return _HitsLanded + _MissesLanded;
    }

    protected int32 Get_Tallied(EMars_Mortar_Seasoning InSeasoning) const
    {
        return _Mortar.Get_Tally().Get_Count(InSeasoning);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnStrikeStarted(FCk_Handle_Mortar InMortar)
    {
        ++_StrikesStarted;
    }

    UFUNCTION()
    protected void OnStrikeLanded(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike)
    {
        if (InStrike == EMars_Mortar_Strike::Hit)
        { ++_HitsLanded; }
        else
        { ++_MissesLanded; }
    }

    UFUNCTION()
    protected void OnBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        ++_BatchChanges;
        _LastBroadcastBatch = InBatch;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Engage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
    }

    UFUNCTION()
    protected void Step_Disengage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Disengage(FMars_Request_Mortar_Disengage());
    }

    UFUNCTION()
    protected void Step_Press(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WindowAtPress = _Mortar.Get_Window();
        _Mortar.Request_Press(FMars_Request_Mortar_Press());
    }

    UFUNCTION()
    protected void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Release(FMars_Request_Mortar_Release());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Predicates
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_IsEngaged());
    }

    UFUNCTION()
    protected void Check_Disengaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_IsEngaged() == false);
    }

    // The pestle is up and the window's middle is within half a window of the marker: a press now is a hit with a
    // margin of a quarter pass.
    UFUNCTION()
    protected void Check_WindowDeepOnMarker(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Window = _Mortar.Get_Window();
        auto Res = OutResult;
        Res.Set(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle
            && Math::Abs(Window.Centre - Window.Marker) <= 0.5f * Window.HalfWidth);
    }

    // The pestle is up and the window's middle is half a window past the edge that still hits: a press now is a miss.
    UFUNCTION()
    protected void Check_WindowWellOffMarker(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Window = _Mortar.Get_Window();
        auto Res = OutResult;
        Res.Set(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle
            && Math::Abs(Window.Centre - Window.Marker) >= 1.5f * Window.HalfWidth);
    }

    // Every strike started has landed and the pestle is back up.
    UFUNCTION()
    protected void Check_StrikeDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_StrikesStarted > 0 && Get_StrikesLanded() == _StrikesStarted
            && _Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle);
    }

    UFUNCTION()
    protected void Check_Done(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done);
    }
}
