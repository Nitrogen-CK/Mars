// Emote keys -> the first-person gloves. The intents are listed in EMars_FPEmote order.
class UMars_SmTask_EmoteIntents : UMars_SmTask_IntentEdges
{
    private AMars_PlayerCharacter _Character;
    private TArray<FGameplayTag> _EmoteIntents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Character = Cast<AMars_PlayerCharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));

        _EmoteIntents.Empty();
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Wave"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.ThumbsUp"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Point"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Clap"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.FlipOff"));

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Character = nullptr;
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        const auto Index = _EmoteIntents.FindIndex(InIntent);
        if (Index < 0 || ck::Is_NOT_Valid(_Character))
        { return; }

        _Character.Request_FPEmote(EMars_FPEmote(Index));
    }
}

// EmoteWheel held -> the wheel is open. The view holds still and the look input steers the wheel's pointer instead
// (one MovePointer per drained look delta, hence Tick); the release chooses the hovered emote, the centre cancels.
// Leaving Alive, or a matcher swap that reads the row Idle, cancels.
class UMars_SmTask_EmoteWheelIntent : UMars_SmTask_IntentEdges
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FGameplayTag _WheelIntent;
    private FCk_Handle_EmoteWheel _Wheel;
    private FCk_Handle_InputIntents _InputIntents;
    // Invalid without a PlayerViewpoint (headless tests): the view is not frozen.
    private FCk_Handle_Camera _Camera;
    private bool _IsOpen = false;
    private int32 _SeenLookSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _WheelIntent = GameplayTags::ResolveGameplayTag(n"Mars.Intent.EmoteWheel");
        _Wheel = Player.As_EmoteWheel(ECk_SanityCheck::UnChecked);
        _InputIntents = Player.As_InputIntents(ECk_SanityCheck::UnChecked);

        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        { _Camera = Viewpoint.Get_Camera(); }

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        Close(false);

        _Wheel = FCk_Handle_EmoteWheel();
        _InputIntents = FCk_Handle_InputIntents();
        _Camera = FCk_Handle_Camera();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Alive is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_IsOpen == false || ck::Is_NOT_Valid(_InputIntents) || ck::Is_NOT_Valid(_Wheel))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _InputIntents.Get_LookDeltaSequence();
        if (Sequence == _SeenLookSequence)
        { return ECk_SmTaskResult::Running; }

        _SeenLookSequence = Sequence;

        // The look delta is already screen-shaped: X yaw right+, Y pitch DOWN+.
        const auto LookDelta = _InputIntents.Get_LookDelta();
        _Wheel.Request_MovePointer(FMars_Request_EmoteWheel_MovePointer(FVector2D(LookDelta.X, LookDelta.Y)));
        return ECk_SmTaskResult::Running;
    }

    protected void OnMatcherRebound() override
    {
        if (_IsOpen && Get_IsRowActive(_WheelIntent) == false)
        { Close(false); }
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent == _WheelIntent)
        { Open(); }
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == _WheelIntent)
        { Close(true); }
    }

    private void Open()
    {
        if (_IsOpen || ck::Is_NOT_Valid(_Wheel))
        { return; }

        _IsOpen = true;
        // The delta drained before the press is not a pointer move.
        _SeenLookSequence = ck::IsValid(_InputIntents) ? _InputIntents.Get_LookDeltaSequence() : 0;
        _Wheel.Request_Open();

        if (ck::IsValid(_Camera))
        { _Camera.Request_Set_HasOrientationControl(false); }
    }

    private void Close(bool InConfirm)
    {
        if (_IsOpen == false)
        { return; }

        _IsOpen = false;

        if (ck::IsValid(_Wheel))
        { _Wheel.Request_Close(FMars_Request_EmoteWheel_Close(InConfirm)); }

        if (ck::IsValid(_Camera))
        { _Camera.Request_Set_HasOrientationControl(true); }
    }
}
