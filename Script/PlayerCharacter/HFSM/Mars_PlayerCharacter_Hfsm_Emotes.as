// Emote keys -> the character's emote, gloves and body (AMars_PlayerCharacter::Request_Emote). A press plays its emote
// while the gloves are at rest with empty hands. Only the first five emotes have keys; the rest are wheel-only.
class UMars_SmTask_EmoteIntents : UMars_SmTask_IntentEdges
{
    private AMars_PlayerCharacter _Character;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Character = Cast<AMars_PlayerCharacter>(ck::ToActor(ck::Ctx(InHandle), ECk_SanityCheck::UnChecked));

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Character = nullptr;
    }

    // No character (headless): nothing to play on.
    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        const auto Emote = TryGet_Emote(InIntent);
        if (Emote.IsSet() == false || ck::Is_NOT_Valid(_Character))
        { return; }

        _Character.Request_Emote(Emote.GetValue());
    }

    private TOptional<EMars_FPEmote> TryGet_Emote(FGameplayTag InIntent) const
    {
        if (InIntent == GameplayTags::Mars_Intent_Emote_Wave)
        { return TOptional<EMars_FPEmote>(EMars_FPEmote::Wave); }

        if (InIntent == GameplayTags::Mars_Intent_Emote_ThumbsUp)
        { return TOptional<EMars_FPEmote>(EMars_FPEmote::ThumbsUp); }

        if (InIntent == GameplayTags::Mars_Intent_Emote_Point)
        { return TOptional<EMars_FPEmote>(EMars_FPEmote::Point); }

        if (InIntent == GameplayTags::Mars_Intent_Emote_Clap)
        { return TOptional<EMars_FPEmote>(EMars_FPEmote::Clap); }

        if (InIntent == GameplayTags::Mars_Intent_Emote_FlipOff)
        { return TOptional<EMars_FPEmote>(EMars_FPEmote::FlipOff); }

        return TOptional<EMars_FPEmote>();
    }
}

// EmoteWheel held -> the wheel is open. The view holds still and the look input steers the wheel's pointer instead
// (one MovePointer per drained look delta, hence Tick); the release chooses the hovered emote, the centre cancels.
// Leaving Alive, or a matcher swap that reads the row Idle, cancels. A chosen entry's Mars.Emote.* tag plays that
// emote on the character (utils_fphands::TryGet_Emote, AMars_PlayerCharacter::Request_Emote); an entity without a
// character (tests) plays nothing.
//
// The wheel does not open while a gripped control holds the view (UMars_SmTask_ManipulateControl freezes it from the
// interaction's start): both toggle the camera's orientation control and both read the look delta, so closing the
// wheel would hand the view back mid-pull. A control gripped while the wheel is open keeps the view on close.
class UMars_SmTask_EmoteWheelIntent : UMars_SmTask_IntentEdges
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Player;
    private AMars_PlayerCharacter _Character;
    private FCk_Handle_EmoteWheel _Wheel;
    private FCk_Handle_InputIntents _InputIntents;
    private FCk_Handle_InteractionResolver _Resolver;
    // Invalid without a PlayerViewpoint (headless tests): the view is not frozen.
    private FCk_Handle_Camera _Camera;
    private bool _IsOpen = false;
    private int32 _SeenLookSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Character = Cast<AMars_PlayerCharacter>(ck::ToActor(_Player, ECk_SanityCheck::UnChecked));
        _Wheel = _Player.As_EmoteWheel();
        _InputIntents = _Player.As_InputIntents();
        _Resolver = _Player.As_InteractionResolver();
        _Wheel.BindTo_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));

        auto Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        { _Camera = Viewpoint.Get_Camera(); }

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        Close(EMars_EmoteWheel_CloseAction::Cancel);

        if (ck::IsValid(_Wheel))
        { _Wheel.UnbindFrom_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen")); }

        _Player = FCk_Handle();
        _Character = nullptr;
        _Wheel = FCk_Handle_EmoteWheel();
        _InputIntents = FCk_Handle_InputIntents();
        _Resolver = FCk_Handle_InteractionResolver();
        _Camera = FCk_Handle_Camera();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Alive is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_IsOpen == false)
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

    UFUNCTION()
    private void OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote)
    {
        auto Emote = EMars_FPEmote::Wave;
        if (ck::Is_NOT_Valid(_Character) || utils_fphands::TryGet_Emote(InEmote, Emote) == false)
        { return; }

        _Character.Request_Emote(Emote);
    }

    protected void OnMatcherRebound() override
    {
        if (_IsOpen && Get_IsRowActive(GameplayTags::Mars_Intent_EmoteWheel) == false)
        { Close(EMars_EmoteWheel_CloseAction::Cancel); }
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent == GameplayTags::Mars_Intent_EmoteWheel)
        { Open(); }
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == GameplayTags::Mars_Intent_EmoteWheel)
        { Close(EMars_EmoteWheel_CloseAction::Choose); }
    }

    private void Open()
    {
        if (_IsOpen || Get_IsControlEngaged())
        { return; }

        _IsOpen = true;
        // The delta drained before the press is not a pointer move.
        _SeenLookSequence = _InputIntents.Get_LookDeltaSequence();
        _Wheel.Request_Open();

        if (ck::IsValid(_Camera))
        { _Camera.Request_Set_HasOrientationControl(false); }
    }

    private void Close(EMars_EmoteWheel_CloseAction InAction)
    {
        if (_IsOpen == false)
        { return; }

        _IsOpen = false;

        // The exit of a player being torn down.
        if (ck::IsValid(_Wheel))
        { _Wheel.Request_Close(FMars_Request_EmoteWheel_Close(InAction)); }

        if (ck::IsValid(_Camera) && Get_IsControlEngaged() == false)
        { _Camera.Request_Set_HasOrientationControl(true); }
    }

    // A ManuallyCompleted interaction from this player is live on a best Use target: a control is gripped, or about to
    // be, and UMars_SmTask_ManipulateControl holds the view for it.
    private bool Get_IsControlEngaged()
    {
        if (ck::Is_NOT_Valid(_Resolver))
        { return false; }

        auto BestTargets = _Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Use);
        for (auto Target : BestTargets)
        {
            if (ck::Is_NOT_Valid(Target))
            { continue; }

            if (Target.Get_InteractionCompletionPolicy() != ECk_Interaction_CompletionPolicy::ManuallyCompleted)
            { continue; }

            if (ck::IsValid(utils_interact_target::TryGet_Interaction(Target, _Player)))
            { return true; }
        }

        return false;
    }
}
