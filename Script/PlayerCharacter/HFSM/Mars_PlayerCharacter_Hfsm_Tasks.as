namespace constants_player_sm
{
    // A candidate hit this far or less behind the nearest hit along the view ray is nested in it (an item lying in a tray):
    // among the nested ones the highest FocusPriority wins.
    const float64 k_NestingToleranceCm = 8.0;
}

// An interactable the view trace overlaps, and how far along the ray (from the viewpoint) the trace hit it. Unset until the
// trace reports the hit: an overlap already in progress when the focus task entered.
struct FMars_InteractionFocus_Candidate
{
    FCk_Handle_Interactable Interactable;
    TOptional<float64> HitDistanceCm;
}

// View trace -> focus. The nearest hit along the view ray wins (utils_player_viewpoint::Make_InteractionTraceSettings: every
// interactable probe on the ray, nearest first), so a slab lying behind a lever does not take the lever's focus. Priority
// only orders what is nested in that hit: among the candidates hit within k_NestingToleranceCm behind it, or hanging under its
// owner in the lifetime tree (a pocket of a pack), the highest FocusPriority wins, ties by distance. While the player has a
// live interaction on one of the focused interactable's targets the focus holds, whatever else enters the ray (a lever
// being pulled keeps it). The focused interactable's targets are offered to the player's resolver, it is told who focuses
// it (which drives its prompt) and the first-person gloves lean toward it. Only focusable candidates count: a claim that
// takes one out of focus (a mount, a ledger, a holder's hands) unfocuses it, one that keeps it focusable (a full hotbar, an
// operated station) leaves the focus alone. The hit distances come from the trace's overlap payloads (the hit point, seen
// from the viewpoint the trace is cast from, in the trace's own pass); the focus is recomputed from them every tick, so a
// view moving over two candidates in one frame focuses once. Unfocusing cancels nothing: the intent task cancels what lasts
// while held when its target leaves the resolver, and a WhileLive interaction is committed.
class UMars_SmTask_InteractionFocus : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Player;
    private FCk_Handle_ProbeTrace _Trace;
    private FCk_Handle_Transform _Viewpoint;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_FPHands _Hands;
    private TArray<FMars_InteractionFocus_Candidate> _Candidates;
    private FCk_Handle_Interactable _Focused;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        _Player = ck::Ctx(InHandle);
        auto ViewSource = _Player.As_PlayerViewpoint();
        _Trace = ViewSource.Get_InteractionTrace();
        _Viewpoint = ViewSource.Get_Viewpoint();
        _Resolver = _Player.As_InteractionResolver();
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);

        _Trace.BindTo_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
        _Trace.BindTo_OnOverlapUpdated(FCk_Delegate_ProbeTrace_OnOverlapUpdated(this, n"OnTraceOverlapUpdated"));
        _Trace.BindTo_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));

        auto CurrentOverlaps = _Trace.Get_CurrentOverlaps();
        for (auto Overlap : CurrentOverlaps)
        { Add_Candidate(Overlap.Get_OtherEntity()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Trace))
        {
            _Trace.UnbindFrom_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
            _Trace.UnbindFrom_OnOverlapUpdated(FCk_Delegate_ProbeTrace_OnOverlapUpdated(this, n"OnTraceOverlapUpdated"));
            _Trace.UnbindFrom_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));
        }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Candidates.Empty();
        _Focused = FCk_Handle_Interactable();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while its state is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Player))
        { Recompute_Focus(); }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION()
    private void OnTraceBeginOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        Record_Hit(InPayload.Get_OtherEntity(), InPayload.Get_ContactPoints());
    }

    UFUNCTION()
    private void OnTraceOverlapUpdated(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnOverlapUpdated InPayload)
    {
        Record_Hit(InPayload.Get_OtherEntity(), InPayload.Get_ContactPoints());
    }

    UFUNCTION()
    private void OnTraceEndOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnEndOverlap InPayload)
    {
        const auto Index = Find_Candidate(InPayload.Get_OtherEntity());
        if (Index >= 0)
        { _Candidates.RemoveAt(Index); }
    }

    // An overlapped probe that is no interactable is not a candidate.
    private void Add_Candidate(FCk_Handle InEntity)
    {
        auto Interactable = InEntity.As_Interactable(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Interactable) || Find_Candidate(InEntity) >= 0)
        { return; }

        auto Candidate = FMars_InteractionFocus_Candidate();
        Candidate.Interactable = Interactable;
        _Candidates.Add(Candidate);
    }

    // The trace's hit point on InEntity this pass; the trace is cast from the viewpoint, so its distance from there is the
    // hit's distance along the ray.
    private void Record_Hit(FCk_Handle InEntity, const TArray<FVector>& InContactPoints)
    {
        if (ck::Is_NOT_Valid(InEntity.As_Interactable(ECk_SanityCheck::UnChecked)))
        { return; }

        if (ck::EnsureIfNot(InContactPoints.Num() > 0, f"[InteractionFocus] the view trace reported [{InEntity.ToString()}] with no hit point"))
        { return; }

        Add_Candidate(InEntity);
        const auto Index = Find_Candidate(InEntity);
        const auto ViewLocation = utils_transform::Get_EntityCurrentTransform(_Viewpoint).GetLocation();
        _Candidates[Index].HitDistanceCm = TOptional<float64>((InContactPoints[0] - ViewLocation).Size());
    }

    // -1 when InEntity is no candidate.
    private int32 Find_Candidate(FCk_Handle InEntity) const
    {
        for (int32 Index = 0; Index < _Candidates.Num(); ++Index)
        {
            FCk_Handle CandidateEntity = _Candidates[Index].Interactable;
            if (CandidateEntity == InEntity)
            { return Index; }
        }

        return -1;
    }

    private void Recompute_Focus()
    {
        auto ViewSource = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(ViewSource) && ViewSource.Get_IsViewHeldBy(EMars_PlayerViewpoint_ViewHolder::CampMenu))
        {
            // The board owns input now. Releasing world focus removes its prompt, outline and resolver targets;
            // keep tracking candidates so Back can reacquire normally without rebuilding the trace.
            if (ck::IsValid(_Focused))
            { DoUnfocus(_Focused); }
            _Focused = FCk_Handle_Interactable();
            return;
        }

        for (int32 Index = _Candidates.Num() - 1; Index >= 0; --Index)
        {
            if (ck::Is_NOT_Valid(_Candidates[Index].Interactable))
            { _Candidates.RemoveAt(Index); }
        }

        if (Get_IsPinned())
        { return; }

        const auto Best = Get_Best();
        if (Best == _Focused)
        { return; }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Focused = Best;

        if (ck::IsValid(_Focused))
        { DoFocus(_Focused); }
    }

    // The player's own interaction on one of the focused interactable's targets is live, and it is still focusable.
    private bool Get_IsPinned() const
    {
        if (ck::Is_NOT_Valid(_Focused) || _Focused.Get_IsFocusable() == false)
        { return false; }

        for (auto Target : _Focused.Get_AllInteractTargets())
        {
            if (ck::IsValid(utils_interact_target::TryGet_Interaction(Target, _Player)))
            { return true; }
        }

        return false;
    }

    // The nearest focusable candidate with a known hit, unless a candidate nested in it ranks higher.
    private FCk_Handle_Interactable Get_Best() const
    {
        auto NearestIndex = -1;
        for (int32 Index = 0; Index < _Candidates.Num(); ++Index)
        {
            const auto Candidate = _Candidates[Index];
            if (Get_IsEligible(Candidate) == false)
            { continue; }

            if (NearestIndex < 0 || Candidate.HitDistanceCm.GetValue() < _Candidates[NearestIndex].HitDistanceCm.GetValue())
            { NearestIndex = Index; }
        }

        if (NearestIndex < 0)
        { return FCk_Handle_Interactable(); }

        const auto Nearest = _Candidates[NearestIndex];
        const auto NearestOwner = TryGet_Owner(Nearest.Interactable);

        auto BestIndex = NearestIndex;
        for (int32 Index = 0; Index < _Candidates.Num(); ++Index)
        {
            const auto Candidate = _Candidates[Index];
            if (Index == NearestIndex || Get_IsEligible(Candidate) == false)
            { continue; }

            const auto Distance = Candidate.HitDistanceCm.GetValue();
            const auto IsNested = Distance - Nearest.HitDistanceCm.GetValue() <= constants_player_sm::k_NestingToleranceCm
                || Get_IsUnder(Candidate.Interactable, NearestOwner);
            if (IsNested == false)
            { continue; }

            const auto Best = _Candidates[BestIndex];
            const auto Priority = Candidate.Interactable.Get_FocusPriority();
            const auto BestPriority = Best.Interactable.Get_FocusPriority();
            if (Priority > BestPriority || (Priority == BestPriority && Distance < Best.HitDistanceCm.GetValue()))
            { BestIndex = Index; }
        }

        return _Candidates[BestIndex].Interactable;
    }

    private bool Get_IsEligible(const FMars_InteractionFocus_Candidate& InCandidate) const
    {
        return InCandidate.HitDistanceCm.IsSet() && ck::IsValid(InCandidate.Interactable) && InCandidate.Interactable.Get_IsFocusable();
    }

    // InInteractable hangs under InOwner in the lifetime tree (the interactable of a pocket under its pack).
    private bool Get_IsUnder(const FCk_Handle_Interactable& InInteractable, const FCk_Handle& InOwner) const
    {
        if (ck::Is_NOT_Valid(InOwner))
        { return false; }

        auto Entity = utils_entity_lifetime::Get_LifetimeOwner(InInteractable);
        while (ck::IsValid(Entity) && utils_entity_lifetime::Get_IsTransientEntity(Entity) == false)
        {
            if (Entity == InOwner)
            { return true; }

            Entity = utils_entity_lifetime::Get_LifetimeOwner(Entity);
        }

        return false;
    }

    private void DoFocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Player));

        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Target)); }

        // An interactable the hands do not touch (every target ReachKind None) gets no lean.
        if (ck::IsValid(_Hands) && InInteractable.Get_WantsHandsLean())
        {
            _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(InInteractable, Get_InteractableOwner(InInteractable),
                InInteractable.Get_FocusReachHand()));
        }
    }

    private void DoUnfocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Player));

        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(Target)); }

        if (ck::IsValid(_Hands))
        { _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus()); }
    }

    // The entity an interactable belongs to (world item, lever root), via the context utils_interactable::Create stamps
    // on every target.
    private FCk_Handle Get_InteractableOwner(const FCk_Handle_Interactable& InInteractable) const
    {
        const auto Owner = TryGet_Owner(InInteractable);
        ck::EnsureIfNot(ck::IsValid(Owner), f"[InteractionFocus] [{InInteractable.ToString()}] has no target carrying its interaction context");
        return Owner;
    }

    // Invalid for an interactable without targets (one that only takes focus).
    private FCk_Handle TryGet_Owner(const FCk_Handle_Interactable& InInteractable) const
    {
        for (auto Target : InInteractable.Get_AllInteractTargets())
        {
            const auto Owner = Target.TryGet_InteractableOwner();
            if (ck::IsValid(Owner))
            { return Owner; }
        }

        return FCk_Handle();
    }
}

// When a held view is handed back: the moment the manipulation ends (the threshold, a cancel), or - the default - not
// before the Use row releases, so the drag that pulled the lever cannot turn the view the frame the lever lands.
enum EMars_ManipulateControl_ViewLock
{
    UntilManipulationEnds,
    UntilUseReleases
}

// Where a started interaction's reach stands while ManipulateControl waits for the gloves' grip.
enum EMars_ManipulateControl_ReachWait
{
    // No interaction is pending, or there are no gloves to wait for.
    None,
    // The gloves push (a drop's or a throw's follow-through): the reach is asked for once the push ends, or once it has run
    // k_PushEndGraceTicks ticks past its own seconds.
    PushEnd,
    // Asked for: the gloves take or refuse it in their next drain.
    Asked,
    // The gloves took it: the manipulation waits for their grip.
    Taken
}

// Resolver -> a gripped control. When the Use intent's best target is a ManuallyCompleted interact target whose owner is
// a Control, this task watches the target's OnNewInteraction. A new interaction asks the gloves for the reach to the target
// itself (the gesture its interaction context names; once a push in progress has ended, waiting no longer than the push's
// own seconds plus k_PushEndGraceTicks) and begins the control's
// manipulation once they grip the target (the control only moves while the hand is on it) - at once when they refuse that
// reach (busy with another target), or without gloves (headless). The gloves answer a reach in the drain after it is
// asked: one neither taken nor refused k_ReachAnswerTicks ticks after it was asked is a defect (an ensure), and the
// manipulation begins. It then feeds the control the look delta every tick (projected onto the control's on-screen pull
// direction) and ends it on OnInteractionFinished.
//
// The view holds still (the player viewpoint's ControlPull hold) from the interaction's START, not from the grip: a drag
// during the reach would otherwise turn the view off the lever and unfocus it. A pending interaction that ends before it
// began (cancelled, lost) hands the view back; once begun, the manipulation's end does - by default not before the Use row
// releases (ViewLock), since the drag that pulled a lever over its threshold would otherwise turn the view the frame the
// lever lands. The look delta drained before the grip is still not a pull (_SeenLookSequence is captured at begin).
// Stateful like UMars_SmTask_InteractionFocus; leaving Locomotion ends any manipulation and releases the hold at once.
class UMars_SmTask_ManipulateControl : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    // The gloves answer a reach in the drain after it is asked, so by this many ticks after the request it was taken or
    // refused.
    protected const int32 k_ReachAnswerTicks = 2;

    // The gloves' Push leaves for Rest one state-machine step after its seconds run out (utils_fphands::Get_PushSeconds),
    // and that phase edge reaches this task in the drain after: a PushEnd wait this many ticks past the push's seconds has
    // outlived the push (its phase frozen, the gloves' state machine torn down mid-push) and asks for the reach anyway.
    protected const int32 k_PushEndGraceTicks = 2;

    protected EMars_ManipulateControl_ViewLock ViewLock = EMars_ManipulateControl_ViewLock::UntilUseReleases;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InputIntents _Intents;
    // Invalid without gloves (headless tests): the manipulation then begins with the interaction.
    private FCk_Handle_FPHands _Hands;
    // Both invalid without a PlayerViewpoint (headless tests): no view hold, and the pull falls back to raw pitch.
    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FCk_Handle_Transform _View;
    // The watched ManuallyCompleted target and the Control that owns it.
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Control _Control;
    // The interaction that started on _Target, waiting for the gloves' grip before the manipulation begins.
    private FCk_Handle_Interaction _PendingInteraction;
    private EMars_ManipulateControl_ReachWait _ReachWait = EMars_ManipulateControl_ReachWait::None;
    // Ticks since the reach was asked for; unset unless the wait is Asked.
    private TOptional<int32> _TicksSinceAsked;
    // PushEnd only: how long the wait has run, and the ticks it has run past the push's seconds.
    private float32 _PushWaitSeconds = 0.0f;
    private int32 _TicksPastPush = 0;
    private bool _IsManipulating = false;
    // This task holds the viewpoint's ControlPull hold.
    private bool _HoldsView = false;
    // The view was handed back while Use was still held: it stays frozen until the row releases.
    private bool _ViewHeldForUseRelease = false;
    private int32 _SeenLookSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();
        _Intents = _Player.As_InputIntents(ECk_SanityCheck::UnChecked);
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);

        _Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Viewpoint))
        { _View = _Viewpoint.Get_Viewpoint(); }

        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));

        if (ck::IsValid(_Hands))
        {
            _Hands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnHandsReachRequested"));
            _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnHandsReachRefused"));
            _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnHandsPhaseChanged"));
        }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        EndManipulation();
        StopWatching();
        UnfreezeView();

        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        }

        if (ck::IsValid(_Hands))
        {
            _Hands.UnbindFrom_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnHandsReachRequested"));
            _Hands.UnbindFrom_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnHandsReachRefused"));
            _Hands.UnbindFrom_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnHandsPhaseChanged"));
        }

        _Player = FCk_Handle();
        _Resolver = FCk_Handle_InteractionResolver();
        _Intents = FCk_Handle_InputIntents();
        _Hands = FCk_Handle_FPHands();
        _Viewpoint = FCk_Handle_PlayerViewpoint();
        _View = FCk_Handle_Transform();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Locomotion is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_ViewHeldForUseRelease && Get_IsUseHeld() == false)
        { UnfreezeView(); }

        Tick_PendingInteraction();
        Tick_PushEnd(float32(InDeltaT.Get_Seconds()));

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
            if (ck::IsValid(_Target) && RemovedTarget == _Target)
            {
                EndManipulation();
                StopWatching();
            }
        }

        for (auto NewTarget : InNewTargets)
        {
            auto Control = NewTarget.TryGet_ManipulatedControl();
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
        if (InTarget != _Target || ck::Is_NOT_Valid(_Control))
        { return; }

        // Begins once the gloves grip the target (DoTick); the view holds still from here.
        _PendingInteraction = InInteraction;
        HoldView();

        if (ck::Is_NOT_Valid(_Hands))
        { return; }

        if (_Hands.Get_Phase() == EMars_FPHands_Phase::Push)
        {
            _ReachWait = EMars_ManipulateControl_ReachWait::PushEnd;
            _PushWaitSeconds = 0.0f;
            _TicksPastPush = 0;
            return;
        }

        Ask_Reach();
    }

    // After a threshold engage the Control has already ended the manipulation, so its EndManipulation is a no-op.
    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InTarget == _Target)
        {
            ClearPendingInteraction();
            EndManipulation();
        }
    }

    UFUNCTION()
    private void OnHandsReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        if (_ReachWait != EMars_ManipulateControl_ReachWait::Asked || _Hands.Get_IsReachTarget(_Target) == false)
        { return; }

        _ReachWait = EMars_ManipulateControl_ReachWait::Taken;
        _TicksSinceAsked.Reset();
    }

    // The gloves will not come, whatever the reason: the pull begins now.
    UFUNCTION()
    private void OnHandsReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                     EMars_FPHands_ReachRefusal InReason)
    {
        if (_ReachWait != EMars_ManipulateControl_ReachWait::Asked || InTarget != _Target || ck::Is_NOT_Valid(_PendingInteraction))
        { return; }

        BeginManipulation(_PendingInteraction);
    }

    UFUNCTION()
    private void OnHandsPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        if (_ReachWait == EMars_ManipulateControl_ReachWait::PushEnd && InNew != EMars_FPHands_Phase::Push)
        { Ask_Reach(); }
    }

    // The subject and the gesture the resolver's binds would ask for (UMars_SmTask_HandsResolverBinds), so a reach they
    // already started is the same reach.
    private void Ask_Reach()
    {
        _ReachWait = EMars_ManipulateControl_ReachWait::Asked;
        _TicksSinceAsked = TOptional<int32>(0);

        const auto& Context = _Target.Get_Fragment(FMars_Fragment_InteractionContext);
        _Hands.Request_StartReach(utils_fphands::Make_TargetReach(_Target));
    }

    // A push still running k_PushEndGraceTicks ticks past its own seconds: the reach is asked for now, and the gloves take or
    // refuse it.
    private void Tick_PushEnd(float32 InDeltaSeconds)
    {
        if (_ReachWait != EMars_ManipulateControl_ReachWait::PushEnd || ck::Is_NOT_Valid(_Hands))
        { return; }

        _PushWaitSeconds += InDeltaSeconds;
        if (_PushWaitSeconds < utils_fphands::Get_PushSeconds(_Hands.Get_Spec().Push))
        { return; }

        _TicksPastPush += 1;
        if (_TicksPastPush < k_PushEndGraceTicks)
        { return; }

        Ask_Reach();
    }

    // A started interaction begins once the gloves grip its target (no gloves: at once).
    private void Tick_PendingInteraction()
    {
        if (ck::Is_NOT_Valid(_PendingInteraction))
        {
            ClearPendingInteraction();
            return;
        }

        if (ck::Is_NOT_Valid(_Control))
        { return; }

        if (ck::Is_NOT_Valid(_Hands) || _Hands.Get_IsGrippingTarget(_Target))
        {
            BeginManipulation(_PendingInteraction);
            return;
        }

        if (_ReachWait != EMars_ManipulateControl_ReachWait::Asked)
        { return; }

        const auto Ticks = _TicksSinceAsked.GetValue() + 1;
        _TicksSinceAsked = TOptional<int32>(Ticks);
        if (Ticks < k_ReachAnswerTicks)
        { return; }

        if (ck::EnsureIfNot(false,
            f"[ManipulateControl] the gloves [{_Hands.ToString()}] neither took nor refused the reach for [{_Target.ToString()}] within {Ticks} ticks: manipulating without the grip"))
        { BeginManipulation(_PendingInteraction); }
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
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(Interaction));
        HoldView();
    }

    // A pending interaction that never began gives the view back; a begun manipulation keeps it until EndManipulation.
    private void ClearPendingInteraction()
    {
        _PendingInteraction = FCk_Handle_Interaction();
        _ReachWait = EMars_ManipulateControl_ReachWait::None;
        _TicksSinceAsked.Reset();
        _PushWaitSeconds = 0.0f;
        _TicksPastPush = 0;

        if (_IsManipulating == false)
        { ReleaseView(); }
    }

    private void EndManipulation()
    {
        if (_IsManipulating == false)
        { return; }

        _IsManipulating = false;

        if (ck::IsValid(_Control))
        { _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation()); }

        ReleaseView();
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

    // The view stops following the look input. A new hold owns the view: a pending hand-back is dropped.
    private void HoldView()
    {
        _ViewHeldForUseRelease = false;

        if (_HoldsView)
        { return; }

        _HoldsView = true;

        if (ck::IsValid(_Viewpoint))
        { _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::ControlPull)); }
    }

    // Hands the view back, unless ViewLock keeps it until the Use row releases (DoTick then unfreezes it).
    private void ReleaseView()
    {
        if (_HoldsView == false)
        { return; }

        if (ViewLock == EMars_ManipulateControl_ViewLock::UntilUseReleases && Get_IsUseHeld())
        {
            _ViewHeldForUseRelease = true;
            return;
        }

        UnfreezeView();
    }

    private void UnfreezeView()
    {
        _ViewHeldForUseRelease = false;

        if (_HoldsView == false)
        { return; }

        _HoldsView = false;

        if (ck::IsValid(_Viewpoint))
        { _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::ControlPull)); }
    }

    // False without operator intents (headless), so the view is handed back exactly when the manipulation ends.
    private bool Get_IsUseHeld() const
    {
        return ck::IsValid(_Intents) && _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use);
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

    // The frame the row's current hold began on; unset while it is not held or no matcher has arrived.
    protected TOptional<int32> TryGet_RowActivationFrame(FGameplayTag InIntent) const
    {
        if (ck::Is_NOT_Valid(_Intents))
        { return TOptional<int32>(); }

        return _Intents.TryGet_IntentActivationFrame(InIntent);
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

// A CkIntent level row -> a resolver intent and the press's interaction. A press opens the intent; the first best target it
// finds is the one the press is forwarded to, and the task starts the player's interaction on it (unless one from the
// player is already live there: the press joins it). One press is one interaction: the intent closes for the rest of the
// hold once that interaction from this player finishes or the target stops being best, so a held press never carries to the
// next best target (taking an item makes the platter under it best). A fresh press (a new activation frame) opens it again.
//
// Only a press opens it: a row already held when the task enters, or when a matcher swaps in, is not a press (a press held
// out of a station does not carry into free roam), and a swap closes it as a release would. A release closes it; one that
// comes before the forwarded target's interaction has started (a press and its release in one frame) waits for that start,
// or k_DeferredCloseFrames frames, so the resolver resolves the press at least once.
//
// The release, the forwarded target leaving the best targets, and the task's exit cancel the player's interaction only when
// it lasts while held (utils_interactable::Get_LastsWhileHeld: a Timed target, a pulled Control); an Instant one is done
// and a WhileLive one is committed from its start (its own work ends it).
class UMars_SmTask_IntentToResolver : UMars_SmTask_IntentEdges
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    // How long a release that came before its press's interaction started keeps the intent open.
    protected const int32 k_DeferredCloseFrames = 2;

    protected FGameplayTag InputIntent;
    protected FGameplayTag ResolverIntent;

    // Another intent row this one's key also drives, and the channel both resolve (Primary and Use share a key and Primary
    // resolves the Use channel): a target on DeferredChannel, reached by a press whose hold began on the same frame as
    // DeferToInputIntent's, is that intent's to start. This one joins it, so one press stays one interaction. Unset: never
    // defers.
    protected FGameplayTag DeferToInputIntent;
    protected FGameplayTag DeferredChannel;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;
    private bool _IntentOpen = false;

    // The activation frame of the hold the open intent was forwarded for; unset without a matcher.
    private TOptional<int32> _ForwardedFrame;
    // The hold whose interaction is spent: the intent stays closed until the row's activation frame differs.
    private TOptional<int32> _SpentFrame;
    // The best target the open intent was forwarded to; invalid until the resolver names one.
    private FCk_Handle_InteractTarget _ForwardedFor;
    // Set by a release that came before the forwarded interaction started: the frames the close has waited since.
    private TOptional<int32> _CloseWhenStarted;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();
        _IntentOpen = false;
        _ForwardedFrame.Reset();
        _SpentFrame.Reset();
        _ForwardedFor = FCk_Handle_InteractTarget();
        _CloseWhenStarted.Reset();
        _Resolver.BindTo_OnBestTargetsChanged(FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        Cancel_HeldInteraction();
        Close_Intent();
        if (ck::IsValid(_Resolver))
        { _Resolver.UnbindFrom_OnBestTargetsChanged(FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged")); }

        _Resolver = FCk_Handle_InteractionResolver();
        _Player = FCk_Handle();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while its state is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_CloseWhenStarted.IsSet() == false)
        { return ECk_SmTaskResult::Running; }

        const auto Waited = _CloseWhenStarted.GetValue() + 1;
        if (Waited < k_DeferredCloseFrames)
        {
            _CloseWhenStarted = TOptional<int32>(Waited);
            return ECk_SmTaskResult::Running;
        }

        Cancel_HeldInteraction();
        Close_Intent();
        return ECk_SmTaskResult::Running;
    }

    protected void OnMatcherRebound() override
    {
        Release_Hold();
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != InputIntent)
        { return; }

        _CloseWhenStarted.Reset();
        Open_Intent();
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == InputIntent)
        { Release_Hold(); }
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        if (InIntent != ResolverIntent || _IntentOpen == false)
        { return; }

        if (ck::IsValid(_ForwardedFor))
        {
            if (InRemovedTargets.Contains(_ForwardedFor))
            {
                Cancel_HeldInteraction();
                Spend_Hold();
            }

            return;
        }

        if (InNewTargets.Num() == 0 || ck::Is_NOT_Valid(InNewTargets[0]))
        { return; }

        Forward_To(InNewTargets[0]);
    }

    UFUNCTION()
    private void OnForwardedNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        if (utils_interaction::Get_InteractionSource(InInteraction) != _Player || _CloseWhenStarted.IsSet() == false)
        { return; }

        // The press was released before its interaction started: close now, as the release would have.
        _CloseWhenStarted.Reset();
        Cancel_HeldInteraction();
        Close_Intent();
    }

    UFUNCTION()
    private void OnForwardedInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        // Another source's interaction on the same target leaves this hold alone.
        if (ck::IsValid(InInteraction) && utils_interaction::Get_InteractionSource(InInteraction) != _Player)
        { return; }

        Spend_Hold();
    }

    private void Open_Intent()
    {
        const auto Frame = TryGet_RowActivationFrame(InputIntent);
        const auto IsSpent = Frame.IsSet() && _SpentFrame.IsSet() && _SpentFrame.GetValue() == Frame.GetValue();
        if (_IntentOpen || IsSpent)
        { return; }

        _IntentOpen = true;
        _ForwardedFrame = Frame;
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(ResolverIntent));
    }

    // The press ends: what lasts while held is cancelled and the intent closes - once the forwarded interaction has
    // started, so a release in the press's own frame still interacts.
    private void Release_Hold()
    {
        if (_IntentOpen == false)
        { return; }

        const auto HasStarted = ck::IsValid(_ForwardedFor)
            && ck::IsValid(utils_interact_target::TryGet_Interaction(_ForwardedFor, _Player));
        if (HasStarted == false)
        {
            _CloseWhenStarted = TOptional<int32>(0);
            return;
        }

        Cancel_HeldInteraction();
        Close_Intent();
    }

    // Starts the player's interaction on InTarget for this press, unless one from the player is live there already or the
    // same press starts it through the intent this one defers to (both would otherwise start one in the same frame, before
    // either is live, and the second would never end).
    private void Forward_To(FCk_Handle_InteractTarget InTarget)
    {
        _ForwardedFor = InTarget;
        _ForwardedFor.BindTo_OnNewInteraction(
            FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnForwardedNewInteraction"));
        _ForwardedFor.BindTo_OnInteractionFinished(
            FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnForwardedInteractionFinished"));

        if (ck::IsValid(utils_interact_target::TryGet_Interaction(_ForwardedFor, _Player)) || Get_DefersStart(_ForwardedFor))
        { return; }

        _ForwardedFor.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    // InTarget is on the deferred channel and the deferred-to row's hold began with this press.
    private bool Get_DefersStart(const FCk_Handle_InteractTarget& InTarget) const
    {
        if (DeferToInputIntent.IsValid() == false || utils_interact_target::Get_InteractionChannel(InTarget) != DeferredChannel)
        { return false; }

        const auto DeferredFrame = TryGet_RowActivationFrame(DeferToInputIntent);
        return DeferredFrame.IsSet() && _ForwardedFrame.IsSet() && DeferredFrame.GetValue() == _ForwardedFrame.GetValue();
    }

    // Cancels the player's live interaction on the forwarded target when it lasts while held.
    private void Cancel_HeldInteraction()
    {
        if (ck::Is_NOT_Valid(_ForwardedFor) || ck::Is_NOT_Valid(_Player) || utils_interactable::Get_LastsWhileHeld(_ForwardedFor) == false)
        { return; }

        if (ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_ForwardedFor, _Player)))
        { return; }

        _ForwardedFor.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
    }

    // The hold has had its interaction: closed until a fresh press.
    private void Spend_Hold()
    {
        _SpentFrame = _ForwardedFrame;
        Close_Intent();
    }

    private void Close_Intent()
    {
        _CloseWhenStarted.Reset();
        if (_IntentOpen == false)
        { return; }

        _IntentOpen = false;
        Forget_ForwardedTarget();

        // The exit of a player being torn down.
        if (ck::IsValid(_Resolver))
        { _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(ResolverIntent)); }
    }

    private void Forget_ForwardedTarget()
    {
        if (ck::IsValid(_ForwardedFor))
        {
            _ForwardedFor.UnbindFrom_OnNewInteraction(
                FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnForwardedNewInteraction"));
            _ForwardedFor.UnbindFrom_OnInteractionFinished(
                FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnForwardedInteractionFinished"));
        }

        _ForwardedFor = FCk_Handle_InteractTarget();
    }
}

class UMars_SmTask_UseIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Use;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Use;
}

// Primary resolves the Use channel first (a focused world prompt outranks the held item's use, and keeps the key while
// blocked: the config's ByOfferedTargets precedence resolves nothing then); where Use shares Primary's key, the press
// that starts a Use target is Use's, and Primary joins it.
class UMars_SmTask_PrimaryIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Primary;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Primary;
    default DeferToInputIntent = GameplayTags::Mars_Intent_Interact_Use;
    default DeferredChannel = GameplayTags::InteractionChannel_Mars_Use;
}
