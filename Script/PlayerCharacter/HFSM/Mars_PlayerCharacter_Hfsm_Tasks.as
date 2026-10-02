// View trace -> focus. The nearest overlapped interactable wins; its targets are offered to the
// player's resolver, it is told who focuses it (which drives its prompt) and the first-person gloves lean toward it.
class UMars_SmTask_InteractionFocus : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Player;
    private FCk_Handle_ProbeTrace _Trace;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_FPHands _Hands;
    private TArray<FCk_Handle_Interactable> _Candidates;
    private FCk_Handle_Interactable _Focused;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Trace = _Player.As_PlayerViewpoint().Get_InteractionTrace();
        _Resolver = _Player.As_InteractionResolver();
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);

        _Trace.BindTo_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
        _Trace.BindTo_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));

        auto CurrentOverlaps = _Trace.Get_CurrentOverlaps();
        for (auto Overlap : CurrentOverlaps)
        { DoAddCandidate(Overlap.Get_OtherEntity()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Trace))
        {
            _Trace.UnbindFrom_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
            _Trace.UnbindFrom_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));
        }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Candidates.Empty();
        _Focused = FCk_Handle_Interactable();
        mars_interaction_focus::Set(_Player, _Focused);
    }

    UFUNCTION()
    private void OnTraceBeginOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        DoAddCandidate(InPayload.Get_OtherEntity());
    }

    UFUNCTION()
    private void OnTraceEndOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnEndOverlap InPayload)
    {
        auto Interactable = InPayload.Get_OtherEntity().As_Interactable(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        _Candidates.Remove(Interactable);
        Recompute_Focus();
    }

    private void DoAddCandidate(FCk_Handle InEntity)
    {
        auto Interactable = InEntity.As_Interactable(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        _Candidates.AddUnique(Interactable);
        Recompute_Focus();
    }

    // The highest FocusPriority wins; ties use the same distance metric the resolver sorts by, so the prompt and the
    // interaction agree.
    private void Recompute_Focus()
    {
        const auto PlayerLocation = Get_Location(_Player);

        auto Best = FCk_Handle_Interactable();
        int32 BestPriority = 0;
        float64 BestDistSq = 0.0;
        for (int32 Index = _Candidates.Num() - 1; Index >= 0; --Index)
        {
            auto Candidate = _Candidates[Index];
            if (ck::Is_NOT_Valid(Candidate))
            {
                _Candidates.RemoveAt(Index);
                continue;
            }

            if (Candidate.Get_EnableDisable() == ECk_EnableDisable::Disable)
            { continue; }

            const auto Priority = Candidate.Get_FocusPriority();
            const auto DistSq = (Get_Location(Candidate) - PlayerLocation).SizeSquared();
            const auto Wins = ck::Is_NOT_Valid(Best)
                || Priority > BestPriority
                || (Priority == BestPriority && DistSq < BestDistSq);
            if (Wins)
            {
                Best = Candidate;
                BestPriority = Priority;
                BestDistSq = DistSq;
            }
        }

        if (Best == _Focused)
        { return; }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Focused = Best;
        mars_interaction_focus::Set(_Player, _Focused);

        if (ck::IsValid(_Focused))
        { DoFocus(_Focused); }
    }

    private void DoFocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Player));

        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Target)); }

        if (ck::IsValid(_Hands))
        { _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(InInteractable, Get_InteractableOwner(InInteractable))); }
    }

    private void DoUnfocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Player));

        auto Targets = InInteractable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
            _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(Target));
        }

        if (ck::IsValid(_Hands))
        { _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus()); }
    }

    // The entity an interactable belongs to (world item, lever root), via the context stamped on its targets.
    private FCk_Handle Get_InteractableOwner(const FCk_Handle_Interactable& InInteractable) const
    {
        for (auto Target : InInteractable.Get_AllInteractTargets())
        {
            if (ck::IsValid(Target) && Target.Has_Fragment(FMars_Fragment_InteractionContext))
            { return Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner; }
        }

        return FCk_Handle();
    }

    private FVector Get_Location(FCk_Handle InEntity) const
    {
        auto AsTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(AsTransform))
        { return FVector::ZeroVector; }

        return utils_transform::Get_EntityCurrentTransform(AsTransform).GetLocation();
    }
}

// Resolver -> interaction start. Every newly-best target starts an interaction from the player; a target that stops being
// best has the player's interaction cancelled.
//
// Exit cancels the player's interaction on every current best Use / Primary target: the intent tasks that leave with it
// close those intents by request, so the resolver's removal broadcast lands after this task has unbound (a held item's
// timed use would otherwise run on into Operating or Downed).
class UMars_SmTask_InteractionResolverBinds : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();
        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));

            CancelBestTargets(GameplayTags::InteractionIntent_Mars_Use);
            CancelBestTargets(GameplayTags::InteractionIntent_Mars_Primary);
        }

        _Player = FCk_Handle();
        _Resolver = FCk_Handle_InteractionResolver();
    }

    private void CancelBestTargets(FGameplayTag InIntent)
    {
        auto BestTargets = _Resolver.Get_BestInteractTargets(InIntent);
        for (auto Target : BestTargets)
        {
            if (ck::Is_NOT_Valid(Target))
            { continue; }

            auto MutableTarget = Target;
            MutableTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
        }
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        for (auto RemovedTarget : InRemovedTargets)
        {
            if (ck::Is_NOT_Valid(RemovedTarget))
            { continue; }

            auto MutableTarget = RemovedTarget;
            MutableTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
        }

        for (auto NewTarget : InNewTargets)
        {
            if (ck::Is_NOT_Valid(NewTarget))
            { continue; }

            auto MutableTarget = NewTarget;
            MutableTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
        }
    }
}

// Resolver -> a gripped control. When the Use intent's best target is a ManuallyCompleted interact target whose owner is
// a Control, this task watches the target's OnNewInteraction and begins the control's manipulation once the gloves grip
// the target (the control only moves while the hand is on it) - or straight away without gloves (headless), or after
// GripWaitSeconds if the gloves never get there (an unreachable target must not deadlock the lever). It then feeds the
// control the look delta every tick (projected onto the control's on-screen pull direction) and ends it on
// OnInteractionFinished.
//
// The camera's orientation holds still from the interaction's START, not from the grip: a drag during the reach would
// otherwise turn the view off the lever and unfocus it. A pending interaction that ends before it began (cancelled, lost)
// hands the view back; once begun, the manipulation's end does. The look delta drained before the grip is still not a
// pull (_SeenLookSequence is captured at begin). Stateful like UMars_SmTask_InteractionFocus; leaving Locomotion ends any
// manipulation and restores the camera.
class UMars_SmTask_ManipulateControl : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    // Longest the manipulation waits for the gloves to grip after the interaction started (seconds).
    protected float32 GripWaitSeconds = 1.0f;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InputIntents _Intents;
    // Invalid without gloves (headless tests): the manipulation then begins with the interaction.
    private FCk_Handle_FPHands _Hands;
    // Both invalid without a PlayerViewpoint (headless tests): no camera freeze, and the pull falls back to raw pitch.
    private FCk_Handle_Camera _Camera;
    private FCk_Handle_Transform _View;
    // The watched ManuallyCompleted target and the Control that owns it.
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Control _Control;
    // The interaction that started on _Target, waiting for the gloves' grip before the manipulation begins.
    private FCk_Handle_Interaction _PendingInteraction;
    private float32 _PendingSeconds = 0.0f;
    private bool _IsManipulating = false;
    private bool _CameraFrozen = false;
    private int32 _SeenLookSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();
        _Intents = _Player.As_InputIntents(ECk_SanityCheck::UnChecked);
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);

        auto Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        {
            _Camera = Viewpoint.Get_Camera();
            _View = Viewpoint.Get_Viewpoint();
        }

        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        EndManipulation();
        StopWatching();

        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        }

        _Player = FCk_Handle();
        _Resolver = FCk_Handle_InteractionResolver();
        _Intents = FCk_Handle_InputIntents();
        _Hands = FCk_Handle_FPHands();
        _Camera = FCk_Handle_Camera();
        _View = FCk_Handle_Transform();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Locomotion is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        Tick_PendingInteraction(float32(InDeltaT.Get_Seconds()));

        if (_IsManipulating == false)
        { return ECk_SmTaskResult::Running; }

        // The lever died under the hand.
        if (ck::Is_NOT_Valid(_Control))
        {
            EndManipulation();
            return ECk_SmTaskResult::Running;
        }

        if (ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        // One nudge per drained delta, whatever the processor order; a still frame advances nothing.
        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence == _SeenLookSequence)
        { return ECk_SmTaskResult::Running; }

        _SeenLookSequence = Sequence;

        // No view: a zero pull axis makes Get_PullDegrees fall back to raw pitch.
        auto View = FTransform::Identity;
        auto PullWorld = FVector::ZeroVector;
        if (ck::IsValid(_View))
        {
            View = utils_transform::Get_EntityCurrentTransform(_View);
            PullWorld = _Control.Get_PullDirectionWorld();
        }

        const auto PullDegrees = utils_control::Get_PullDegrees(PullWorld, View, _Intents.Get_LookDelta());
        _Control.Request_Nudge(FMars_Request_Control_Nudge(PullDegrees));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        if (InIntent != GameplayTags::InteractionIntent_Mars_Use)
        { return; }

        for (auto RemovedTarget : InRemovedTargets)
        {
            if (ck::IsValid(_Target) && FCk_Handle(RemovedTarget) == FCk_Handle(_Target))
            {
                EndManipulation();
                StopWatching();
            }
        }

        for (auto NewTarget : InNewTargets)
        {
            auto Control = Get_ManipulatedControl(NewTarget);
            if (ck::Is_NOT_Valid(Control))
            { continue; }

            EndManipulation();
            StopWatching();
            _Target = NewTarget;
            _Control = Control;
            _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
            _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
            return;
        }
    }

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        if ((FCk_Handle(InTarget) == FCk_Handle(_Target)) == false || ck::Is_NOT_Valid(_Control))
        { return; }

        // Begins in DoTick once the gloves grip the target; the view holds still from here.
        _PendingInteraction = InInteraction;
        _PendingSeconds = 0.0f;
        SetCameraFrozen(true);
    }

    // After a threshold engage the Control has already ended the manipulation, so its EndManipulation is a no-op.
    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (FCk_Handle(InTarget) == FCk_Handle(_Target))
        {
            ClearPendingInteraction();
            EndManipulation();
        }
    }

    // A started interaction waits for the gloves' grip (none = no wait), capped at GripWaitSeconds.
    private void Tick_PendingInteraction(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_PendingInteraction))
        {
            ClearPendingInteraction();
            return;
        }

        if (ck::Is_NOT_Valid(_Control))
        { return; }

        _PendingSeconds += InDeltaSeconds;
        const auto Gripping = ck::Is_NOT_Valid(_Hands) || _Hands.Get_IsGrippingTarget(_Target);
        if (Gripping == false && _PendingSeconds < GripWaitSeconds)
        { return; }

        if (Gripping == false)
        { ck::Trace(f"[ManipulateControl] gloves never gripped [{_Target.ToString()}] within {GripWaitSeconds}s; manipulating anyway"); }

        BeginManipulation(_PendingInteraction);
    }

    private void BeginManipulation(FCk_Handle_Interaction InInteraction)
    {
        // Copied before the pending slot is cleared: the caller passes that very member.
        const auto Interaction = InInteraction;
        // Manipulating before the pending slot clears, so the clear keeps the view held.
        _IsManipulating = true;
        ClearPendingInteraction();

        // The delta that was drained before the grip is not a pull.
        _SeenLookSequence = ck::IsValid(_Intents) ? _Intents.Get_LookDeltaSequence() : 0;
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(Interaction, _Player));
        SetCameraFrozen(true);
    }

    // A pending interaction that never began gives the view back; a begun manipulation keeps it until EndManipulation.
    private void ClearPendingInteraction()
    {
        _PendingInteraction = FCk_Handle_Interaction();
        _PendingSeconds = 0.0f;

        if (_IsManipulating == false)
        { SetCameraFrozen(false); }
    }

    // The Control behind a ManuallyCompleted interact target; invalid for any other target.
    private FCk_Handle_Control Get_ManipulatedControl(FCk_Handle_InteractTarget InTarget) const
    {
        if (ck::Is_NOT_Valid(InTarget) || InTarget.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return FCk_Handle_Control(); }

        if (InTarget.Get_InteractionCompletionPolicy() != ECk_Interaction_CompletionPolicy::ManuallyCompleted)
        { return FCk_Handle_Control(); }

        auto Control = InTarget.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner.As_Control(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Control) || Control.Get_CompletionPolicy() != ECk_Interaction_CompletionPolicy::ManuallyCompleted)
        { return FCk_Handle_Control(); }

        return Control;
    }

    private void EndManipulation()
    {
        if (_IsManipulating == false)
        { return; }

        _IsManipulating = false;

        if (ck::IsValid(_Control))
        { _Control.Request_EndManipulation(); }

        SetCameraFrozen(false);
    }

    private void StopWatching()
    {
        ClearPendingInteraction();

        if (ck::IsValid(_Target))
        {
            _Target.UnbindFrom_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
            _Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        }

        _Target = FCk_Handle_InteractTarget();
        _Control = FCk_Handle_Control();
    }

    private void SetCameraFrozen(bool InFrozen)
    {
        if (InFrozen == _CameraFrozen)
        { return; }

        _CameraFrozen = InFrozen;

        if (ck::IsValid(_Camera))
        { _Camera.Request_Set_HasOrientationControl(InFrozen == false); }
    }
}

// Owns the player's intent-matcher subscription: binds on enter, follows every matcher swap (the matcher usually arrives
// after enter, and Deactivate/Repoint swap it to INVALID), unbinds on exit. Subclasses override the hooks and filter on
// their own intent tags; they cache their handles BEFORE Super::DoEnterTask, because the first OnMatcherRebound runs
// inside it.
//
// Phase changes already in flight when binding are ignored, so a row held on enter is not a press.
class UMars_SmTask_IntentEdges : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_IntentMatcher _Matcher;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Intents = Player.As_InputIntents();
        _Intents.BindTo_OnMatcherChanged(FMars_Delegate_InputIntents_OnMatcherChanged(this, n"OnMatcherChanged"));

        Rebind(_Intents.Get_Matcher());
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Intents))
        { _Intents.UnbindFrom_OnMatcherChanged(FMars_Delegate_InputIntents_OnMatcherChanged(this, n"OnMatcherChanged")); }

        if (ck::IsValid(_Matcher))
        { utils_intent_matcher::UnbindFrom_OnIntentPhaseChanged(_Matcher, FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnIntentPhaseChanged")); }

        _Intents = FCk_Handle_InputIntents();
        _Matcher = FCk_Handle_IntentMatcher();
    }

    protected void OnMatcherRebound()
    {
    }

    protected void OnIntentPressed(FGameplayTag InIntent)
    {
    }

    protected void OnIntentReleased(FGameplayTag InIntent)
    {
    }

    protected bool Get_IsRowActive(FGameplayTag InIntent) const
    {
        if (ck::Is_NOT_Valid(_Intents))
        { return false; }

        return _Intents.Get_IsIntentActive(InIntent);
    }

    private void Rebind(FCk_Handle_IntentMatcher InNewMatcher)
    {
        if (ck::IsValid(_Matcher))
        { utils_intent_matcher::UnbindFrom_OnIntentPhaseChanged(_Matcher, FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnIntentPhaseChanged")); }

        _Matcher = InNewMatcher;

        if (ck::IsValid(_Matcher))
        {
            utils_intent_matcher::BindTo_OnIntentPhaseChanged(_Matcher,
                FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnIntentPhaseChanged"), ECk_Signal_BindingPolicy::IgnorePayloadInFlight);
        }

        OnMatcherRebound();
    }

    UFUNCTION()
    private void OnMatcherChanged(FCk_Handle_InputIntents InIntents, FCk_Handle_IntentMatcher InPrev, FCk_Handle_IntentMatcher InNew)
    {
        Rebind(InNew);
    }

    UFUNCTION()
    private void OnIntentPhaseChanged(FCk_Handle_IntentMatcher InMatcher, FName InIntentName, FGameplayTag InIntentTag,
                                      ECk_Intent_Phase InPreviousPhase, ECk_Intent_Phase InNewPhase, int32 InFrame)
    {
        const auto IsPressed = InNewPhase == ECk_Intent_Phase::Active && InPreviousPhase != ECk_Intent_Phase::Active;
        const auto IsReleased = InPreviousPhase == ECk_Intent_Phase::Active && InNewPhase != ECk_Intent_Phase::Active;

        if (IsPressed)
        { OnIntentPressed(InIntentTag); }
        else if (IsReleased)
        { OnIntentReleased(InIntentTag); }
    }
}

// Mirrors a CkIntent level row onto a resolver intent: a press opens it, a release closes it. A matcher swap re-syncs to
// the new matcher's level (a key held across the compose opens; the swap to INVALID closes).
class UMars_SmTask_IntentToResolver : UMars_SmTask_IntentEdges
{
    protected FGameplayTag InputIntent;
    protected FGameplayTag ResolverIntent;

    private FCk_Handle_InteractionResolver _Resolver;
    private bool _IntentOpen = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Resolver = Player.As_InteractionResolver();
        _IntentOpen = false;

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        Set_IntentOpen(false);
        _IntentOpen = false;
        _Resolver = FCk_Handle_InteractionResolver();
    }

    protected void OnMatcherRebound() override
    {
        Set_IntentOpen(Get_IsRowActive(InputIntent));
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent == InputIntent)
        { Set_IntentOpen(true); }
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == InputIntent)
        { Set_IntentOpen(false); }
    }

    private void Set_IntentOpen(bool InOpen)
    {
        if (InOpen == _IntentOpen || ck::Is_NOT_Valid(_Resolver))
        { return; }

        _IntentOpen = InOpen;
        if (InOpen)
        { _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(ResolverIntent)); }
        else
        { _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(ResolverIntent)); }
    }
}

class UMars_SmTask_UseIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Use;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Use;
}

class UMars_SmTask_PrimaryIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Primary;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Primary;
}
