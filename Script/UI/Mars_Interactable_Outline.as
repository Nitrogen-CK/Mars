// The focus outline drawn on whatever the player is looking at. Mapped to Outline.Gameplay.Interaction in
// Config/DefaultCkFoundation.ini; otherwise CkFoundation's DA_Outline_Interactable, with a thinner ring.
namespace mars
{
    asset Outline_Interactable_Mars_DA of UCkUsf_OutlinePreset
    {
        _OutlineType       = ECk_Usf_OutlineType::Normal;
        _OutlineColor      = FLinearColor(0.10, 0.60, 1.00, 1.0);
        _OutlineBrightness = 1.5;
        _ThicknessScale    = 0.3;
    }
}

// Claims an outline on the interactable's owner and its live entity subtree while focused (a task of the Interactable's
// Focused state). The source is the owning state machine, so concurrent focus tasks clear only the claim they own. Only
// components hosted by the entity (utils_unreal_component) are outlined - see AMars_TestLamp.
class UMars_SmTask_Interactable_Outline : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    // Valid while this task holds a claim.
    private FCk_Handle _OutlineTarget;
    private FCk_Handle _OutlineSource;
    private FGameplayTag _OutlineTag;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Release_Outline();

        const auto& InteractableCtx = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext);
        auto Interactable = InteractableCtx.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), "InteractionContext is missing the Interactable handle"))
        { return; }

        auto Focuser = Interactable.Get_CurrentFocuser();
        if (ck::Is_NOT_Valid(Focuser))
        { return; }

        // Interactables hosted on the player are not world objects; outlining their owner would outline the player.
        if (InteractableCtx.InteractableOwner == Focuser)
        { return; }

        Claim_Outline(InteractableCtx.InteractableOwner);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Release_Outline();
    }

    private void Claim_Outline(FCk_Handle InTarget)
    {
        FCk_Handle Source = Get_OwningStateMachine();
        const auto Tag = utils_usf_outline_settings::Get_GameplayInteractionOutlineTag();
        if (ck::Is_NOT_Valid(InTarget) || ck::Is_NOT_Valid(Source))
        { return; }

        utils_usf_outline::Set_OutlineClaim(InTarget, Source, Tag, ECk_Usf_OutlineScope::EntityAndDependents);
        if (utils_usf_outline::Has_OutlineClaim(InTarget, Source, Tag) == false)
        { return; }

        _OutlineTarget = InTarget;
        _OutlineSource = Source;
        _OutlineTag = Tag;
    }

    // The claim goes with its target: nothing to clear once the target is gone.
    private void Release_Outline()
    {
        if (ck::IsValid(_OutlineTarget) && ck::IsValid(_OutlineSource) &&
            utils_usf_outline::Has_OutlineClaim(_OutlineTarget, _OutlineSource, _OutlineTag))
        { utils_usf_outline::Clear_OutlineClaim(_OutlineTarget, _OutlineSource, _OutlineTag); }

        _OutlineTarget = FCk_Handle();
        _OutlineSource = FCk_Handle();
        _OutlineTag = FGameplayTag();
    }
}
