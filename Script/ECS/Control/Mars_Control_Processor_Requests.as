// Drains WatchInteractable (on every machine) -> SetActive -> grip requests and pull reports in arrival order -> the
// drain's engages -> EndManipulation -> BeginManipulation ->
// Nudges (see FMars_Fragment_Control_Requests). SetActive and Engage apply on the authority only: a client's are dropped (its engage
// arrives as Cue.Mars.Control.Engage). The manipulation requests apply wherever a grip may begin (Get_MayGripHere: the
// authority, or a client whose control's entity replicates) and are dropped elsewhere. A pending engage on a client begins
// no grip until it clears.
//
// The grip arbiter, on the authority of an arbitrated control only (Get_IsGripArbitrated; anywhere else a grip claim is
// dropped and the grip ledger never moves), one request at a time in the order they arrived. Begin: a Released ledger
// grants (Gripped, the gripper, GripSerial + 1) and watches the gripper's destruction through
// FMars_Fragment_Control_HeldGrips on it; the holder asking again changes nothing; anyone else is refused (RefusalSerial +
// 1, LastRefused), never with an ensure (two players reaching for one lever is legitimate), and this machine's grip mirror
// runs for it. LetGo: only the holder releases (Ended). Cross: only the holder releases (Ended), and the control engages
// once for it (Crossed); from anyone else it is dropped. The holder's destruction releases (GripperLost). A grant seeds
// the ledger's Pull where the handle stands; a pull report moves it only from the current gripper and is read in arrival
// order with the grip requests. A drain may apply more
// than one engage (its Engage request and each accepted Cross): each toggles or re-arms as an engage does and raises
// OnEngaged. Every ledger change marks it dirty. This machine's own grip reports itself: a grip begun by an interaction
// claims for the interaction's source, and its end reports exactly one of LetGo or Cross (utils_control::Request_GripFor).
class UMars_Processor_Control_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Control_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Control_Requests& InRequests,
                       FMars_Fragment_Control& InState)
    {
        auto Self = InHandle.As_Control();

        // Every machine keeps the watched interactable, whether or not a grip may begin here.
        const auto WatchRequest = InRequests.WatchInteractableRequest;

        if (Self.Get_MayGripHere() == false)
        {
            InHandle.Request_TryRemove(FMars_Fragment_Control_Requests);
            ApplyWatch(Self, WatchRequest);
            return;
        }

        // Off authority only the grip applies; the ledger is the authority's.
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        const auto HasEngage = HasAuthority && InRequests.EngageRequest.IsSet();

        // A claim anywhere but an arbitrated control's authority is dropped: the grip ledger is that authority's alone.
        const auto Arbitrates = HasAuthority && Self.Get_IsGripArbitrated();
        TArray<FMars_Request_Control_Grip> GripRequests;
        TArray<FMars_Control_QueuedPullReport> PullReports;
        if (Arbitrates)
        {
            GripRequests = InRequests.GripRequests;
            PullReports = InRequests.PullReports;
        }

        const auto HasSetActive = HasAuthority && InRequests.SetActiveRequest.IsSet();
        auto SetActiveValue = false;
        if (HasSetActive)
        { SetActiveValue = InRequests.SetActiveRequest.GetValue().Activation == EMars_Control_Activation::Active; }

        const auto HasEndManipulation = InRequests.EndManipulationRequest.IsSet();
        const auto HasBeginManipulation = InRequests.BeginManipulationRequest.IsSet();
        auto BeginManipulationRequest = FMars_Request_Control_BeginManipulation();
        if (HasBeginManipulation)
        { BeginManipulationRequest = InRequests.BeginManipulationRequest.GetValue(); }

        TArray<FMars_Request_Control_Nudge> NudgeRequests = InRequests.NudgeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Control_Requests);

        const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
        auto& Local = Self.Get_Fragment(FMars_Fragment_Control_Local);
        const auto WasActive = InState.IsActive;
        auto NewActive = WasActive;

        ApplyWatch(Self, WatchRequest);

        if (HasSetActive)
        {
            if (SetActiveValue == false)
            { DestroyReleaseTimer(Local); }
            else if (Params.Behavior == EMars_Control_Behavior::Momentary)
            { ArmReleaseTimer(Self, Local, Params.ActiveSeconds); }

            NewActive = SetActiveValue;
        }

        // Strictly in arrival order: a claim, its reports and its end that land together are read as they were sent.
        auto EngageCount = HasEngage ? 1 : 0;
        auto NextReport = 0;
        for (int32 GripIndex = 0; GripIndex < GripRequests.Num(); ++GripIndex)
        {
            for (; NextReport < PullReports.Num() && PullReports[NextReport].AfterGripRequests <= GripIndex; ++NextReport)
            { ApplyPullReport(Self, PullReports[NextReport].Report); }

            const auto& Request = GripRequests[GripIndex];
            if (Request.Verb == EMars_Control_GripVerb::Begin)
            {
                HandleGripBegin(Self, Request.Gripper);
                continue;
            }

            const auto Released = HandleGripEnd(Self, Request.Gripper, Request.Verb);
            if (Released && Request.Verb == EMars_Control_GripVerb::Cross)
            { EngageCount += 1; }
        }

        for (; NextReport < PullReports.Num(); ++NextReport)
        { ApplyPullReport(Self, PullReports[NextReport].Report); }

        for (int32 Engage = 0; Engage < EngageCount; ++Engage)
        {
            if (Params.Behavior == EMars_Control_Behavior::Toggle)
            { NewActive = NewActive == false; }
            else
            {
                NewActive = true;
                ArmReleaseTimer(Self, Local, Params.ActiveSeconds);
            }

            InState.Engagements += 1;
        }

        const auto Changed = NewActive != WasActive;
        if (Changed)
        {
            InState.IsActive = NewActive;

            // A returns-to-rest handle is not a state display: it springs back after every pull.
            // The engage's MoveTo takes the handle from a mirrored grip, which would scrub it back.
            auto Mover = Local.Mover;
            if (ck::IsValid(Mover) && Self.Get_ReturnsToRest() == false)
            {
                Local.MirroredGrip.Reset();
                Self.Request_TryRemove(FMars_Tag_Control_MirroringGrip);
                Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(NewActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));
            }
        }

        if (Changed || EngageCount > 0)
        { InHandle.Request_MarkReplicationDirty(FMars_Fragment_Control); }

        // Not manipulating: the threshold already ended it, and a Settle here would fight the Engage's MoveTo.
        const auto Ended = HasEndManipulation && Local.Manipulation.IsSet();
        if (Ended)
        { EndManipulation(Self, Local); }

        auto Began = false;
        if (HasBeginManipulation)
        { Began = BeginManipulation(Self, Local, BeginManipulationRequest); }

        // FreeTurn: the drain's pull degrees, broadcast after the grip edges below.
        auto TurnDegrees = 0.0f;
        if (Local.Manipulation.IsSet())
        { TurnDegrees = ApplyNudges(Self, Local, NudgeRequests); }

        for (int32 Engage = 0; Engage < EngageCount; ++Engage)
        {
            if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
            { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Broadcast(Self); }
        }

        if (Changed && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        {
            const auto Activation = NewActive ? EMars_Control_Activation::Active : EMars_Control_Activation::Inactive;
            Self.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Broadcast(Self, Activation);
        }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Released); }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, 0.0f); }

        if (Began && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Gripped); }

        if (TurnDegrees != 0.0f && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnTurned.Broadcast(Self, TurnDegrees); }
    }

    // Lets go before the threshold: the handle settles back to the current target pose from wherever it is.
    private void EndManipulation(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState)
    {
        const auto Gripper = InState.Manipulation.GetValue().Gripper;
        InState.Manipulation.Reset();
        InControl.Request_TryRemove(FMars_Tag_Control_Manipulating);

        auto Mover = InState.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }

        utils_control::Request_GripFor(InControl, Gripper, EMars_Control_GripVerb::LetGo);
    }

    // Returns false while a pending engage stands (not an error: the grip is asked again once it clears), when the control
    // is not ManuallyCompleted, or is a Walk control without a valid Puller (both ensure). The
    // grip starts where the handle stands (without a Mover: at the end the pull runs from), and the scrub stops an in-flight
    // engage tween so the hand owns the handle. A Walk grip records the puller's horizontal distance now: the pull is what
    // it gains from here.
    private bool BeginManipulation(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control_Local& InState,
        const FMars_Request_Control_BeginManipulation& InRequest)
    {
        // A grip now would seed at the threshold and read the direction the engage is about to change.
        if (InState.PendingEngage.IsSet())
        { return false; }

        const auto IsManuallyCompleted =
            InControl.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        if (ck::EnsureIfNot(IsManuallyCompleted, f"[Control] [{InControl.ToString()}] is not ManuallyCompleted; BeginManipulation ignored"))
        { return false; }

        const auto IsWalk = InControl.Get_PullSource() == EMars_Control_PullSource::Walk;
        if (IsWalk && ck::EnsureIfNot(ck::IsValid(InRequest.Puller) && ck::IsValid(InControl.H().As_Transform(ECk_SanityCheck::UnChecked)),
            f"[Control] [{InControl.ToString()}] is a Walk control: BeginManipulation needs a valid Puller and a control with a transform; ignored"))
        { return false; }

        auto Mover = InState.Mover;
        const auto HasMover = ck::IsValid(Mover);

        // A FreeTurn grip has no threshold to cross, whatever the request asked.
        const auto IsFreeTurn = InControl.Get_IsFreeTurn();

        auto Gripper = FCk_Handle();
        if (ck::IsValid(InRequest.Interaction))
        { Gripper = utils_interaction::Get_InteractionSource(InRequest.Interaction); }

        // A grip that replaces another's without an end lets the other's claim go first.
        if (InState.Manipulation.IsSet() && InState.Manipulation.GetValue().Gripper != Gripper)
        { utils_control::Request_GripFor(InControl, InState.Manipulation.GetValue().Gripper, EMars_Control_GripVerb::LetGo); }

        auto Manipulation = FMars_Control_Manipulation();
        Manipulation.Interaction = InRequest.Interaction;
        Manipulation.Gripper = Gripper;
        Manipulation.Completion = IsFreeTurn ? EMars_Control_ManipulationCompletion::OnRelease : InRequest.Completion;
        Manipulation.Alpha = InControl.Get_GripStartAlpha();
        Manipulation.Pull = Manipulation.Alpha;
        if (IsWalk)
        {
            Manipulation.Puller = InRequest.Puller;
            Manipulation.WalkStartCm = InControl.Get_HorizontalDistanceTo(InRequest.Puller);
        }
        InState.Manipulation = Manipulation;

        // A ledger grip naming this gripper is this machine's own from now on: never mirrored or claimed here.
        if (ck::IsValid(Gripper))
        { InState.LastLocalGripper = Gripper; }

        if (InControl.Has_Fragment(FMars_Tag_Control_Manipulating) == false)
        { InControl.Add_Fragment(FMars_Tag_Control_Manipulating()); }

        if (HasMover)
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Manipulation.Alpha)); }

        // The local grip does not wait for the answer: a refusal ends it once it is mirrored.
        utils_control::Request_GripFor(InControl, Gripper, EMars_Control_GripVerb::Begin);
        return true;
    }

    // The arbiter's Begin (see the class comment). A gripper destroyed while its claim was in flight claims nothing.
    private void HandleGripBegin(FCk_Handle_Control& InControl, FCk_Handle InGripper)
    {
        if (ck::Is_NOT_Valid(InGripper))
        { return; }

        auto& Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        if (Ledger.Grip == EMars_Control_Grip::Gripped)
        {
            if (Ledger.Gripper == InGripper)
            { return; }

            Ledger.RefusalSerial += 1;
            Ledger.LastRefused = InGripper;
            InControl.H().Request_MarkReplicationDirty(FMars_Fragment_Control_Grip);

            // The authority mirrors its own ledger: a grip of this machine's that was refused lets go.
            Mark_GripMirror(InControl);
            return;
        }

        // The pull starts where the handle stands, as the gripping machine's own grip does.
        Ledger.Grip = EMars_Control_Grip::Gripped;
        Ledger.Gripper = InGripper;
        Ledger.GripSerial += 1;
        Ledger.Pull = InControl.Get_GripStartAlpha();
        InControl.H().Request_MarkReplicationDirty(FMars_Fragment_Control_Grip);

        // The authority mirrors its own ledger: another machine's grip is shown and claimed here too.
        Mark_GripMirror(InControl);

        auto Gripper = InGripper;
        auto& Held = Gripper.AddOrGet_Fragment(FMars_Fragment_Control_HeldGrips);
        if (Held.Controls.Contains(InControl) == false)
        { Held.Controls.Add(InControl); }

        // Unbind first keeps the watch single across the controls one gripper holds.
        Gripper.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnGripperBeginDestroy"));
        Gripper.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnGripperBeginDestroy"));
    }

    // The arbiter's LetGo and Cross: scoped, so an end naming anyone but the holder changes nothing. Returns whether the
    // grip was released (Ended for a LetGo, Crossed for a Cross).
    private bool HandleGripEnd(FCk_Handle_Control& InControl, FCk_Handle InGripper, EMars_Control_GripVerb InVerb)
    {
        auto& Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        if (Ledger.Grip == EMars_Control_Grip::Released || ck::Is_NOT_Valid(InGripper) || Ledger.Gripper != InGripper)
        { return false; }

        Ledger.Grip = EMars_Control_Grip::Released;
        Ledger.LastRelease = InVerb == EMars_Control_GripVerb::Cross ? EMars_Control_GripRelease::Crossed : EMars_Control_GripRelease::Ended;
        InControl.H().Request_MarkReplicationDirty(FMars_Fragment_Control_Grip);
        Mark_GripMirror(InControl);

        auto Gripper = InGripper;
        if (Gripper.Has_Fragment(FMars_Fragment_Control_HeldGrips) == false)
        { return true; }

        auto& Held = Gripper.Get_Fragment(FMars_Fragment_Control_HeldGrips);
        Held.Controls.Remove(InControl);
        if (Held.Controls.IsEmpty())
        { Gripper.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnGripperBeginDestroy")); }

        return true;
    }

    // A gripper going away releases every grip it still holds.
    UFUNCTION()
    private void OnGripperBeginDestroy(FCk_Handle InGripper)
    {
        if (InGripper.Has_Fragment(FMars_Fragment_Control_HeldGrips) == false)
        { return; }

        auto Gripper = InGripper;
        auto Controls = Gripper.Get_Fragment(FMars_Fragment_Control_HeldGrips).Controls;
        for (int32 Index = 0; Index < Controls.Num(); ++Index)
        {
            auto Control = Controls[Index];
            if (ck::Is_NOT_Valid(Control) || Control.Has_Fragment(FMars_Fragment_Control_Grip) == false)
            { continue; }

            auto& Ledger = Control.Get_Fragment(FMars_Fragment_Control_Grip);
            if (Ledger.Grip == EMars_Control_Grip::Released || Ledger.Gripper != InGripper)
            { continue; }

            Ledger.Grip = EMars_Control_Grip::Released;
            Ledger.LastRelease = EMars_Control_GripRelease::GripperLost;
            Control.H().Request_MarkReplicationDirty(FMars_Fragment_Control_Grip);
            Mark_GripMirror(Control);
        }
    }

    // The authority's grip mirror runs for a ledger change its own drain made.
    private void Mark_GripMirror(FCk_Handle_Control& InControl)
    {
        if (InControl.Has_Fragment(FMars_Tag_Control_NeedsGripMirror) == false)
        { InControl.Add_Fragment(FMars_Tag_Control_NeedsGripMirror()); }
    }

    // Only the current gripper's report moves the ledger's pull, clamped; anything else is dropped without an ensure (a
    // report can trail its grip's end or lead its grant). A value that did not change marks nothing.
    private void ApplyPullReport(FCk_Handle_Control& InControl, const FMars_Request_Control_ReportPull& InReport)
    {
        auto& Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        if (Ledger.Grip == EMars_Control_Grip::Released || ck::Is_NOT_Valid(InReport.Gripper) || Ledger.Gripper != InReport.Gripper)
        { return; }

        const auto Pull = Math::Clamp(InReport.Pull, 0.0f, 1.0f);
        if (Ledger.Pull == Pull)
        { return; }

        Ledger.Pull = Pull;
        InControl.H().Request_MarkReplicationDirty(FMars_Fragment_Control_Grip);
    }

    // Keeps the watched interactable. While another machine holds the grip the claim moves with the watch: the one watched
    // before gives it back and the one watched now takes it at once (an invalid one watches nothing).
    private void ApplyWatch(FCk_Handle_Control& InControl, const TOptional<FMars_Request_Control_WatchInteractable>& InWatch)
    {
        if (InWatch.IsSet() == false)
        { return; }

        auto& Local = InControl.Get_Fragment(FMars_Fragment_Control_Local);
        auto Previous = Local.Interactable;
        auto Interactable = InWatch.GetValue().Interactable;
        Local.Interactable = Interactable;

        if (Local.GripHolder != EMars_Control_GripHolder::AnotherMachine || Previous == Interactable)
        { return; }

        if (ck::IsValid(Previous))
        { Previous.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Operated)); }

        if (ck::IsValid(Interactable))
        { Interactable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Operated)); }
    }

    // Returns the drain's degrees for a FreeTurn control (its pull is not integrated), 0 for Travel. A Walk control's pull is
    // the puller's distance (UMars_Processor_Control_Tick): its nudges change nothing. Not an error: the player's task just
    // sends none.
    private float32 ApplyNudges(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control_Local& InState,
        const TArray<FMars_Request_Control_Nudge>& InNudges)
    {
        if (InNudges.IsEmpty())
        { return 0.0f; }

        auto PullDegrees = 0.0f;
        for (const auto& Nudge : InNudges)
        { PullDegrees += Nudge.PullDegrees; }

        if (InControl.Get_IsFreeTurn())
        { return PullDegrees; }

        if (InControl.Get_PullSource() == EMars_Control_PullSource::Walk)
        { return 0.0f; }

        const auto AlphaPerDegree = InControl.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.AlphaPerDegree;
        auto Manipulation = InState.Manipulation.GetValue();
        Manipulation.Pull = Math::Clamp(Manipulation.Pull + PullDegrees * AlphaPerDegree, 0.0f, 1.0f);
        InState.Manipulation = Manipulation;
        return 0.0f;
    }

    private void ArmReleaseTimer(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState, float32 InActiveSeconds)
    {
        DestroyReleaseTimer(InState);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InActiveSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InControl, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnReleaseTimerDone")); }
        InState.ReleaseTimer = Timer;
    }

    private void DestroyReleaseTimer(FMars_Fragment_Control_Local& InState)
    {
        if (ck::IsValid(InState.ReleaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(InState.ReleaseTimer); }

        InState.ReleaseTimer = FCk_Handle_Timer();
    }

    UFUNCTION()
    private void OnReleaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The control is going away with its timer.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Control = Owner.As_Control();

        // A timer replaced by a re-engage can still finish in the frame it was destroyed.
        const auto& State = Control.Get_Fragment(FMars_Fragment_Control_Local);
        if (State.ReleaseTimer != InTimer)
        { return; }

        Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Inactive));
    }
}
