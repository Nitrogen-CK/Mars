// A registered presentation with automatic component ticking disabled: drive its real clock at precise boundaries,
// including rapid cover reversal, zero time, busy-page rejection, queued close and immediate cancellation.
class UMars_AutoTest_Cookbook_TransitionsReverseAndPageBoundsHold : UCk_AutoTest_Base
{
    private UMars_CookbookPresentationComponent _Book;
    private float32 _PausedOpeningPosition = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, FVector(131000.0, -52000.0, -30000.0)), ECk_Replication::DoesNotReplicate);
        const auto Params = utils_unreal_component::Make_Params(UMars_CookbookPresentationComponent,
            ECk_UnrealComponent_TickPolicy::DoNotTick, n"Cookbook_ClockTest");
        auto Component = utils_unreal_component::Add(Entity, Params);
        utils_unreal_component::BindTo_OnAdded(Component, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPresentationAdded"));

        Add_Step_WaitUntil("the real skeletal component is registered", n"Check_Ready", 0, 0);
        Add_Step("start opening on the explicit presentation clock", n"Step_BeginOpening");
        Add_Step_WaitFrames("engine ticks do not own the presentation clock", 4);
        Add_Step("cover reversals preserve the animation time and zero time does not advance it", n"Step_CoverReversal");
        Add_Step("both completed turns retain the exact last pose instead of restarting the idle leaf", n"Step_TurnEndpoints");
        Add_Step("busy turns and both page boundaries reject extra input", n"Step_PageBounds");
        Add_Step("a close during a turn waits for the leaf", n"Step_QueuedClose");
        Add_Step("immediate close cancels a turn without committing it", n"Step_ImmediateClose");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPresentationAdded(FCk_Handle_UnrealComponent InHandle)
    { _Book = Cast<UMars_CookbookPresentationComponent>(utils_unreal_component::Get_Component(InHandle)); }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Book));
    }

    UFUNCTION()
    private void Step_BeginOpening(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Book.Request_Close();
        _Book.Request_Turn(1);
        Assert_False(_Book.Get_IsTransitioning(), "paging while fully closed does nothing");
        _Book.Request_Toggle();
        _Book.Request_AdvancePresentation(0.2);
        Assert_Equals_Float(_Book.GlobalAnimRateScale, 1.5, 0.0001, "the native animation speed tuner defaults to 50 percent faster");
        Assert_Equals_Float(_Book.GetPosition(), 0.3, 0.0001, "the explicit clock honors the native animation speed tuner exactly once");
        _PausedOpeningPosition = _Book.GetPosition();
        Assert_False(_Book.IsComponentTickEnabled(), "the engine never schedules a second book clock");
    }

    UFUNCTION()
    private void Step_CoverReversal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Book.GetPosition(), _PausedOpeningPosition, 0.001,
            "four world frames without an explicit clock step leave the opening pose unchanged");
        const auto OpeningPosition = _Book.GetPosition();
        _Book.Request_Toggle();
        const auto ClosingPosition = _Book.GetPosition();
        auto Opening = System::LoadAsset_Blocking(TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(
            "/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Animations/Cookbook_Opening_AS.Cookbook_Opening_AS")));
        Assert_Equals_Float(OpeningPosition + ClosingPosition, Opening.GetPlayLength(), 0.001,
            "reversing the symmetric cover clips mirrors time without jumping pose");
        _Book.Request_AdvancePresentation(0.0);
        Assert_Equals_Float(_Book.GetPosition(), ClosingPosition, 0.001, "zero DeltaT preserves the animation position");
        _Book.Request_Toggle();
        Assert_Equals_Float(_Book.GetPosition(), OpeningPosition, 0.001, "a second rapid reversal restores the same opening pose");
        _Book.Request_AdvancePresentation(10.0);
        Assert_True(_Book.Get_IsOpen() && _Book.Get_IsTransitioning() == false, "opening settles into the open hold");
    }

    UFUNCTION()
    private void Step_TurnEndpoints(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Forward = System::LoadAsset_Blocking(TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(
            "/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Animations/Cookbook_TurnForward_AS.Cookbook_TurnForward_AS")));
        const auto Duration = Forward.GetPlayLength();
        _Book.Request_Turn(1);
        _Book.Request_AdvancePresentation((Duration - 0.001f) / _Book.GlobalAnimRateScale);
        Assert_True(_Book.Get_IsTransitioning(), "forward is still turning just before its final frame");
        _Book.Request_AdvancePresentation(0.002f / _Book.GlobalAnimRateScale);
        Assert_False(_Book.Get_IsTransitioning(), "forward settles on its last frame");
        Assert_Equals_Float(_Book.GetPosition(), Duration, 0.0001, "forward keeps its terminal pose; the idle leaf differs by 180 degrees");
        _Book.Request_Turn(-1);
        _Book.Request_AdvancePresentation((Duration - 0.001f) / _Book.GlobalAnimRateScale);
        _Book.Request_AdvancePresentation(0.002f / _Book.GlobalAnimRateScale);
        Assert_False(_Book.Get_IsTransitioning(), "reverse also settles on its last frame");
        Assert_Equals_Float(_Book.GetPosition(), Duration, 0.0001, "reverse retains its terminal pose as well");
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 0, "the endpoint checks return to the first spread");
    }

    UFUNCTION()
    private void Step_PageBounds(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Book.Get_PageSectionCount(), 3, "index, sample recipe and notes form three page sections");
        _Book.Request_Turn(-1);
        Assert_False(_Book.Get_IsTransitioning(), "previous at the first section is rejected");
        _Book.Request_Turn(1);
        _Book.Request_Turn(1);
        _Book.Request_AdvancePresentation(10.0);
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 1, "a repeated press while turning does not queue a second turn");
        _Book.Request_Turn(1);
        _Book.Request_AdvancePresentation(10.0);
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 2, "a second settled turn reaches the final section");
        _Book.Request_Turn(1);
        Assert_False(_Book.Get_IsTransitioning(), "next at the final section is rejected");
    }

    UFUNCTION()
    private void Step_QueuedClose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Book.Request_Turn(-1);
        _Book.Request_Toggle();
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 2, "closing during a turn waits for its commit");
        _Book.Request_AdvancePresentation(10.0);
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 1, "the active leaf settles before closing");
        Assert_True(_Book.Get_IsOpen() && _Book.Get_IsTransitioning(), "closing still consumes book paging and shared Q");
        _Book.Request_Turn(-1);
        _Book.Request_AdvancePresentation(10.0);
        Assert_False(_Book.Get_IsOpen(), "the queued close finishes with the cover shut");
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 1, "paging during closing never changes the section");
    }

    UFUNCTION()
    private void Step_ImmediateClose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Book.Request_Toggle();
        _Book.Request_AdvancePresentation(10.0);
        _Book.Request_Turn(1);
        _Book.Request_Close();
        _Book.Request_AdvancePresentation(10.0);
        Assert_False(_Book.Get_IsOpen() || _Book.Get_IsTransitioning(), "forced close cancels the in-flight leaf immediately");
        Assert_Equals_Int(_Book.Get_PageSectionIndex(), 1, "the cancelled turn never commits after later ticks");
    }
}
