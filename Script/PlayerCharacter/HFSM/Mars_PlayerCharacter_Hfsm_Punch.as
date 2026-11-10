// Primary with empty hands and nothing to use it on -> a jab of the bare fists (the Punch feature). Every press asks for
// one throw; the feature alternates the hands, keeps the rhythm and deals the blow on its own clock, so this task only
// decides whether a press is a jab at all. It is one when:
//   - the hands are empty (no held item, the selected slot included: an item being launched is still held);
//   - the gloves rest (they are not reaching, gripping, holding or following a throw through);
//   - nothing holds the view (a gripped control, the emote wheel, a camp board);
//   - the player is not on a ladder;
//   - and no interactable under the view is focused by the player. A focused prompt owns the press, usable or blocked, as
//     it does over a held item's use (the Primary intent's ByOfferedTargets precedence): the world Use and Primary intent
//     tasks run it, and this one stays out.
// A jab takes the gloves back from a playing emote, as a reach does. Only the owner reads input, so no owning-copy gate;
// a carrier without the Punch feature (a test rig) throws nothing.
class UMars_SmTask_PunchIntent : UMars_SmTask_IntentEdges
{
    private FCk_Handle _Player;
    private FCk_Handle_Punch _Punch;
    // Each optional on a test carrier; without it its rule does not apply.
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FCk_Handle_Climber _Climber;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Punch = _Player.As_Punch(ECk_SanityCheck::UnChecked);
        _HeldItem = _Player.As_HeldItem(ECk_SanityCheck::UnChecked);
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);
        _Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        _Climber = _Player.As_Climber(ECk_SanityCheck::UnChecked);

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Player = FCk_Handle();
        _Punch = FCk_Handle_Punch();
        _HeldItem = FCk_Handle_HeldItem();
        _Hands = FCk_Handle_FPHands();
        _Viewpoint = FCk_Handle_PlayerViewpoint();
        _Climber = FCk_Handle_Climber();
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != GameplayTags::Mars_Intent_Interact_Primary || Get_CanPunch() == false)
        { return; }

        if (ck::IsValid(_Hands))
        { utils_fphands::Stop_Emote(_Hands); }

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    private bool Get_CanPunch() const
    {
        if (ck::Is_NOT_Valid(_Punch))
        { return false; }

        if (ck::IsValid(_HeldItem) && ck::IsValid(_HeldItem.Get_CurrentItem()))
        { return false; }

        if (ck::IsValid(_Hands) && _Hands.Get_Phase() != EMars_FPHands_Phase::None)
        { return false; }

        if (ck::IsValid(_Viewpoint) && _Viewpoint.Get_IsViewHeld())
        { return false; }

        if (ck::IsValid(_Climber) && _Climber.Get_IsClimbing())
        { return false; }

        return Get_IsFocusingAnInteractable() == false;
    }

    // An interactable under the view trace is focused by this player (UMars_SmTask_InteractionFocus focuses only what the
    // trace overlaps, and each interactable knows who focuses it).
    private bool Get_IsFocusingAnInteractable() const
    {
        if (ck::Is_NOT_Valid(_Viewpoint))
        { return false; }

        const auto Overlaps = _Viewpoint.Get_InteractionTrace().Get_CurrentOverlaps();
        for (auto Overlap : Overlaps)
        {
            FCk_Handle Other = Overlap.Get_OtherEntity();
            const auto Interactable = Other.As_Interactable(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Interactable) && Interactable.Get_CurrentFocuser() == _Player)
            { return true; }
        }

        return false;
    }
}
