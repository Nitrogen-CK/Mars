// Every entity tagged TAG_MarsMonster in the selected player's world: its body health, dead flag and parts, and for a
// crawler its gait, legs, navigator, attack (target, phase, samples, hit ledger), state machine (root and behaviour
// states) and brain (leaf and facts). Read-only: it never requests or writes anything.
class UMars_DebugPage_Monsters : UMars_DebugPage_Base
{
    FString GetPageName() override
    {
        return "Monsters";
    }

    void DrawPage(float DeltaTime) override
    {
        // Any live handle reaches the world's registry; the selected player's is the one the base page resolves.
        const auto AnyHandle = TryGet_PlayerEntity();
        if (ck::Is_NOT_Valid(AnyHandle))
        {
            DrawWarningBox("No Mars player entity to reach the world's monsters through (or it is not ready yet).");
            return;
        }

        const auto Monsters = utils_entity_tag::ForEach_Entity(AnyHandle, n"TAG_MarsMonster");

        BeginPageScrollBox();

        if (Monsters.Num() == 0)
        { DrawWarningBox("No monster in this world."); }

        // utils_monster::Add tags only what it composes as a monster.
        for (auto Entity : Monsters)
        {
            DrawMonster(Entity.As_Monster());
            mm::Spacer(0, 6);
        }

        EndPageScrollBox();
    }

    private void DrawMonster(FCk_Handle_Monster InMonster)
    {
        DrawSectionHeading(f"{utils_handle::Get_DebugName(InMonster)}  {InMonster.ToString()}");

        const auto IsDead = InMonster.Get_IsDead();
        DrawKvRow("Dead", BoolText(IsDead), IsDead ? FLinearColor(1.0f, 0.4f, 0.4f) : FLinearColor(0.5f, 1.0f, 0.5f));
        DrawKvRow("Body health", Get_HealthText(InMonster.Get_BodyHealth()));
        DrawKvRow("Parts attached", f"{InMonster.Get_AttachedPartCount()} / {InMonster.Get_Parts().Num()}");

        for (const auto& Part : InMonster.Get_Parts())
        {
            if (ck::Is_NOT_Valid(Part))
            { continue; }

            DrawKvRow(f"  {Part.Get_PartTag().ToString()}",
                f"{Part.Get_State() :n} | {Part.Get_Condition() :n} | {Get_HealthText(Part.Get_Health())}",
                Part.Get_State() == EMars_BodyPart_State::Attached ? FLinearColor::White : FLinearColor(0.6f, 0.6f, 0.6f));
        }

        const auto Crawler = InMonster.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Crawler))
        {
            DrawCrawler(Crawler);
            DrawCrawlerAttack(Crawler);
        }

        auto StateMachine = InMonster.As_StateMachine(ECk_SanityCheck::UnChecked);
        const FString RootState = ck::IsValid(StateMachine)
            ? Get_StateClassName(utils_state_machine::Get_CurrentStateClass(StateMachine))
            : "-";
        DrawKvRow("SM root state", RootState, FLinearColor(0.6f, 0.9f, 1.0f));

        if (ck::IsValid(Crawler))
        { DrawKvRow("SM behaviour state", Get_StateClassName(Crawler.Get_BehaviorStateClass()), FLinearColor(0.6f, 0.9f, 1.0f)); }

        const auto Brain = InMonster.As_Brain(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Brain))
        { DrawBrain(Brain); }
    }

    private void DrawBrain(FCk_Handle_Brain InBrain)
    {
        DrawKvRow("Brain", InBrain.Get_IsEnabled() ? "enabled" : "disabled");
        DrawKvRow("Leaf", utils_brain::Get_ClassName(InBrain.Get_LeafClass()), FLinearColor(1.0f, 0.85f, 0.4f));

        for (const auto& Fact : InBrain.Get_Spec().Facts)
        { DrawKvRow(f"  {Fact.Key.ToString()}", BoolText(InBrain.Get_Fact(Fact.Key))); }
    }

    private void DrawCrawler(FCk_Handle_Crawler InCrawler)
    {
        const auto Gait = InCrawler.Get_Gait();
        if (ck::IsValid(Gait))
        {
            DrawKvRow("Gait", f"{utils_procedural_gait::Get_Status(Gait) :n}");
            DrawKvRow("Legs enabled", f"{utils_procedural_gait::Get_EnabledLegCount(Gait)} / {utils_procedural_gait::Get_Legs(Gait).Num()}");
        }

        const auto Navigator = InCrawler.Get_Navigator();
        if (ck::Is_NOT_Valid(Navigator))
        {
            DrawKvRow("Navigator", "-");
            return;
        }

        const auto Status = Navigator.Get_Status();
        const auto StatusText = Status == EMars_SurfaceNavigator_Status::Failed
            ? f"{Status :n} ({Navigator.Get_FailReason() :n})"
            : f"{Status :n}";
        DrawKvRow("Navigator", StatusText);
        DrawKvRow("Path mode", f"{Navigator.Get_PathMode() :n}");
        DrawKvRow("Goal", Navigator.Get_Goal().ToString());
        DrawKvRow("Waypoint", f"{Navigator.Get_WaypointIndex()} / {Navigator.Get_Waypoints().Num()}");
    }

    private void DrawCrawlerAttack(FCk_Handle_Crawler InCrawler)
    {
        if (InCrawler.Get_IsCombatArmed() == false)
        { DrawKvRow("Attack", "unarmed"); return; }
        const auto Snapshot = InCrawler.Get_AttackDebugSnapshot();
        if (Snapshot.Frame == 0)
        { DrawKvRow("Attack", "tearing down"); return; }
        DrawSectionHeading("Attack catalogue");
        DrawKvRow("Read frame / attempt generation", f"{Snapshot.Frame} / {InCrawler.Get_AttackGeneration()}");
        DrawKvRow("Aggressive / Engage", f"{BoolText(InCrawler.Get_IsAggressive())} / {InCrawler.Get_EngageStage() :n}");
        const auto Target = InCrawler.Get_CombatTarget();
        const FString TargetText = ck::IsValid(Target) ? f"{utils_handle::Get_DebugName(Target)} {Target.ToString()}" : "-";
        DrawKvRow("Target", f"{TargetText} | generation {InCrawler.Get_CombatTargetGeneration()}");
        const auto Action = InCrawler.Get_AttackAction();
        const FString ActionState = ck::IsValid(Action) ? f"{Action.Get_State() :n}" : "released / absent";
        DrawKvRow("Phase / native action", f"{InCrawler.Get_AttackPhase() :n} / {ActionState}");
        if (ck::IsValid(Action))
        {
            DrawKvRow("Native result now", Get_NativeResultText(Action.Get_Result()));
            const auto Latest = Action.Get_LastReceipt();
            if (Latest.Get_HasAcceptedPose())
            {
                const auto Sampling = Latest.Get_Sampling();
                DrawKvRow("Native last receipt report", f"sample {Latest.Get_Stamp().Get_SampleSequence()} | evaluated {Sampling.Get_EvaluatedSamples()} / accepted {Sampling.Get_AcceptedSamples()} | backlog {Sampling.Get_Backlog().Get_Seconds() :.4} s");
                DrawKvRow("Native reported motion", f"endpoint {Sampling.Get_MaxEndpointTravelCm() :.3} cm | segment rotation {Sampling.Get_MaxSegmentAngularStepDegrees() :.3} deg (distinct from endpoint sphere geometry)");
            }
        }
        DrawKvRow("Pending request transport", BoolText(InCrawler.Get_HasPendingCombatRequests()));
        DrawKvRow("Live shared recovery", f"{InCrawler.Get_AttackCooldownRemaining() :.3} s (read frame {Snapshot.Frame})");
        DrawKvRow("Accepted start / event sequence", f"{Snapshot.Ledger.StartSequence} / {Snapshot.Ledger.EventSequence}");
        const auto Cancel = InCrawler.Get_AttackLastCancel();
        const auto Reject = InCrawler.Get_AttackLastReject();
        const FString CancelText = Cancel.IsSet() ? f"{Cancel.GetValue() :n}" : "-";
        const FString RejectText = Reject.IsSet() ? f"{Reject.GetValue() :n}" : "-";
        DrawKvRow("Last cancel / reject", f"{CancelText} / {RejectText}");
        DrawStoredSelection(InCrawler);
        DrawAttackPlan(InCrawler);
        DrawAttackStream(InCrawler, Snapshot);
        DrawAttackAnatomy(Snapshot.Anatomy);
        DrawAcceptedEmitters(InCrawler);
        DrawBlockers("Emitter failure", InCrawler.Get_AttackEmitterFailures());
        DrawAttackHistory(InCrawler.Get_AttackHistory());
    }

    private FString Get_NameText(FName InName) const
    { return InName.IsNone() ? "-" : InName.ToString(); }

    private FString Get_TagText(FGameplayTag InTag) const
    { return InTag.IsValid() ? InTag.ToString() : "-"; }

    private FString Get_ChoiceText(const TOptional<FGameplayTag>& InChoice) const
    { return InChoice.IsSet() ? Get_TagText(InChoice.GetValue()) : "-"; }

    private FString Get_NativeResultText(const FCk_ProceduralAction_Result& InResult) const
    { return f"{InResult.Get_Outcome() :n} / {InResult.Get_Recovery() :n} / {Get_NameText(InResult.Get_Reason())}"; }

    private FString Get_ClipText(UCk_ProceduralAction_Data InClip) const
    { return ck::IsValid(InClip) ? InClip.GetName().ToString() : "-"; }

    private void DrawBlockers(const FString& InLabel, const TArray<FMars_Attack_Blocker>& InBlockers)
    {
        for (const auto& Blocker : InBlockers)
        {
            DrawKvRow(InLabel, f"{Blocker.Code} | {Blocker.Field} | role {Get_TagText(Blocker.Role)} / slot {Get_NameText(Blocker.Slot)}",
                FLinearColor(1.0f, 0.65f, 0.3f));
            DrawKvRow("  Expected / actual", f"{Blocker.Expected} / {Blocker.Actual}");
        }
    }

    private void DrawStoredSelection(FCk_Handle_Crawler InCrawler)
    {
        const auto Decision = InCrawler.Get_AttackDecision();
        const auto Evaluation = Decision.Evaluation;
        DrawKvRow("Stored selection capture frame", f"{Evaluation.ObservationFrame}");
        DrawKvRow("Stored kernel selection", f"{Evaluation.Selection.Disposition :n} | reason {Get_NameText(Decision.LastReason)}");
        DrawKvRow("Preferred / ready / selected", f"{Get_ChoiceText(Evaluation.Selection.Preferred)} / {Get_ChoiceText(Evaluation.Selection.ReadyChoice)} / {Get_ChoiceText(Evaluation.Selection.Selected)}");
        DrawKvRow("Stored selection / target token", f"{Evaluation.SelectionGeneration} / {Evaluation.TargetIdentity}:{Evaluation.TargetGeneration}");
        const auto Preparation = InCrawler.Get_AttackPreparation();
        DrawKvRow("Preparation", f"{Get_TagText(Preparation.Preferred)} | active {BoolText(Preparation.Active)} | timeout {BoolText(Preparation.TimedOut)} | wait {Preparation.ElapsedReadinessWait :.3} s");
        DrawKvRow("Preparation target token", f"{Preparation.TargetIdentity}:{Preparation.TargetGeneration}");
        const auto Loadout = InCrawler.Get_Spec().ResolvedAttacks;
        DrawKvRow("Frozen loadout revision", f"{Loadout.GameRevision} | {Loadout.Entries.Num()} enabled entries");
        const auto Sampling = Loadout.Execution.Tuning.Get_Sampling();
        DrawKvRow("Copied native sampling policy", f"max steps {Sampling.Get_MaxSamples()} | advance {Sampling.Get_MaxAdvance().Get_Seconds() :.4} s | endpoint {Sampling.Get_MaxEndpointTravelCm() :.2} cm | segment angle {Sampling.Get_MaxSegmentAngularStepDegrees() :.2} deg");
        const auto Reuse = InCrawler.Get_AttackReuse();
        for (const auto& Entry : Loadout.Entries)
        {
            auto Remaining = 0.0f;
            int64 LastStart = 0;
            for (const auto& Clock : Reuse)
            {
                if (Clock.Id == Entry.Identity.Id)
                { Remaining = Clock.Remaining; LastStart = Clock.LastStartSequence; }
            }
            DrawKvRow(f"Entry {Entry.Identity.Id.ToString()}", f"priority {Entry.Identity.Priority} | reuse {Remaining :.3} s | last accepted start {LastStart}");
            auto Found = false;
            for (const auto& Candidate : Evaluation.Evaluations)
            {
                if (Candidate.AttackId != Entry.Identity.Id)
                { continue; }
                Found = true;
                DrawKvRow("  Stored evaluation", f"{Candidate.Availability :n} | capable {BoolText(Candidate.Capable)} | enabled / standing unclaimed {Candidate.EnabledSupport} / {Candidate.StandingSupport}");
                DrawBlockers("  Blocker", Candidate.Blockers);
            }
            if (Found == false)
            { DrawKvRow("  Stored evaluation", "not observed yet"); }
        }
    }

    private void DrawAttackPlan(FCk_Handle_Crawler InCrawler)
    {
        const auto Plan = InCrawler.Get_AttackPlan();
        const auto Admission = InCrawler.Get_AttackAdmission();
        const auto Result = InCrawler.Get_AttackResult();
        if (Plan.Entry.Identity.Id.IsValid() == false)
        { DrawKvRow("Pending / last admitted plan", "none admitted"); }
        else
        {
            DrawKvRow("Pending / last admitted plan", f"{Get_TagText(Plan.Entry.Identity.Id)} | revision {Plan.GameRevision} | selection {Plan.SelectionGeneration} | target generation {Plan.TargetGeneration}");
            DrawKvRow("Source / frozen played clip", f"{Get_ClipText(InCrawler.Get_AttackClip())} / {Get_ClipText(InCrawler.Get_AttackFrozenPlayedClip())}");
            DrawKvRow("Frozen damage / recovery / reuse", f"{Plan.Entry.Definition.Hit.Damage :.2} / {Plan.Entry.Definition.Cooldown.RecoverySeconds :.3} s / {Plan.Entry.Definition.Cooldown.ReuseSeconds :.3} s");
            for (const auto& Slot : Plan.Entry.Slots)
            { DrawKvRow("  Claimed slot", f"{Slot.Slot} -> {Slot.Binding.Role.ToString()} / {Slot.Binding.LimbId} | max condition {Slot.MaxCondition :n}"); }
            for (const auto& Part : Plan.Entry.Parts)
            { DrawKvRow("  Required part", f"{Part.Binding.Role.ToString()} / {Get_NameText(Part.Binding.LimbId)} | max condition {Part.MaxCondition :n}"); }
        }
        DrawKvRow("Admission", f"{Get_TagText(Admission.AttackId)} | accepted {BoolText(Admission.Accepted)} | action {Admission.ActionIdentity.Get_Value()} | sample {Admission.SampleId}");
        DrawKvRow("Admission tokens", f"attempt {Admission.AttemptGeneration} | selection {Admission.SelectionGeneration}");
        DrawKvRow("Damage ledger", f"committed {BoolText(InCrawler.Get_AttackDamageCommitted())} | sample {InCrawler.Get_AttackCommittedSampleId()} | emitter {Get_TagText(InCrawler.Get_AttackCommittedEmitterId())} | fraction {InCrawler.Get_AttackCommittedEmitterFraction() :.5}");
        DrawKvRow("Stored result", f"{Get_TagText(Result.AttackId)} | action {Result.ActionIdentity.Get_Value()} | accepted {BoolText(Result.Accepted)} | completed {BoolText(Result.Completed)}");
        DrawKvRow("Native terminal evidence", f"observed {BoolText(Result.Evidence.Observed)} | source {Get_NameText(Result.Evidence.Source)} | stream failure {Get_NameText(Result.Evidence.Failure)}");
        DrawKvRow("Stored native / game cleanup", f"{Get_NativeResultText(Result.Native)} / {Get_NameText(Result.CleanupOutcome)}");
        DrawBlockers("Result prerequisite failure", Result.RequiredPartFailures);
    }

    private void DrawAttackStream(FCk_Handle_Crawler InCrawler, const FMars_Crawler_AttackDebugSnapshot& InSnapshot)
    {
        const auto Stream = InSnapshot.Stream;
        DrawKvRow("Receipt identity / cursor", f"{Stream.Identity.Get_Value()} / {Stream.Cursor}");
        DrawKvRow("Acknowledged sample / subject revision", f"{Stream.AckSampleId} / {Stream.AckRevision}");
        DrawKvRow("Content fingerprint / topology revision", f"{Stream.ContentRevision} / {Stream.TopologyRevision}");
        const auto Interval = InCrawler.Get_AttackAcceptedInterval();
        DrawKvRow("Stored accepted interval", f"{Interval.Get_PhaseId()} | {Interval.Get_FromTime().Get_Seconds() :.4} - {Interval.Get_ToTime().Get_Seconds() :.4} s | {Interval.Get_Continuity() :n}");
        auto Windows = FString();
        for (const auto Window : Interval.Get_Windows())
        { Windows += f"{Window} "; }
        DrawKvRow("Stored interval windows", Windows == "" ? "-" : Windows);
        const auto Status = InSnapshot.Status;
        const FString Displaced = Status.Displaced.IsSet() ? f"{Status.Displaced.GetValue() :n}" : "-";
        DrawKvRow("Game window closed / offense ended", f"{BoolText(Status.WindowClosed)} / {BoolText(Status.OffenseEnded)}");
        DrawKvRow("Observed obstruction / displacement", f"{BoolText(Status.Obstructed)} / {Displaced}");
        DrawKvRow("Stream failure", f"{Get_NameText(Status.StreamFailure)} | failed {BoolText(Status.ActionStreamFailed)} | unavailable {BoolText(Status.StreamUnavailable)}");
        const auto Cleanup = InSnapshot.Cleanup;
        DrawKvRow("Survivor cleanup", f"requested {BoolText(Cleanup.Requested)} | released {BoolText(Cleanup.Released)} | elapsed {Cleanup.Elapsed :.3} s");
        auto Claims = FString();
        for (const auto Id : Cleanup.ClaimedIds)
        { Claims += f"{Id} "; }
        DrawKvRow("Saved cleanup claim IDs", Claims == "" ? "-" : Claims);
        if (InSnapshot.Candidate.IsSet())
        {
            const auto Candidate = InSnapshot.Candidate.GetValue();
            DrawKvRow("Pending candidate", f"sample {Candidate.SampleId} | generation {Candidate.Generation} | emitter {Candidate.EmitterContact.EmitterId.ToString()} | fraction {Candidate.EmitterContact.Fraction :.5}");
            DrawKvRow("  Contact", f"{Candidate.Location.ToString()} | zone {Candidate.Zone.ToString()} | target {Candidate.Target.ToString()}");
        }
        else
        { DrawKvRow("Pending candidate", "-"); }
    }

    private void DrawAttackAnatomy(const FMars_Crawler_AttackAnatomyCapture& InCapture)
    {
        DrawSectionHeading(f"Live anatomy capture (frame {InCapture.Frame}; independent of stored selection)");
        DrawKvRow("Articulation", InCapture.ArticulationValid ? f"{InCapture.Health :n} / {InCapture.Fault :n}" : "unavailable");
        for (const auto& Role : InCapture.Roles)
        {
            const auto Part = Role.Part;
            DrawKvRow(f"Role {Role.Role.ToString()}", f"{Role.Source :n} / {Get_NameText(Role.LimbId)} | live {BoolText(Part.Live)} | pending {BoolText(Part.PendingDestroy)} | owned {BoolText(Part.OwnerMatches)}");
            DrawKvRow("  Part", f"{Part.State :n} / {Part.Condition :n} | depleted {BoolText(Part.Depleted)}");
            if (Role.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            {
                const auto Limb = Role.Limb;
                DrawKvRow("  Limb", f"exists {BoolText(Limb.Exists)} | attached {BoolText(Limb.Attached)} | enabled {BoolText(Limb.Enabled)} | control {Limb.Control :n}");
                DrawKvRow("  Claimed-foot readiness", f"planted {BoolText(Limb.Planted)} | trusted {BoolText(Limb.Trusted)}");
            }
        }
    }

    private void DrawAcceptedEmitters(FCk_Handle_Crawler InCrawler)
    {
        DrawSectionHeading("Stored accepted emitter geometry");
        const auto Segments = InCrawler.Get_AttackAcceptedEmitters();
        if (Segments.Num() == 0)
        { DrawKvRow("Accepted emitters", "none acknowledged; pending geometry is not contact evidence"); }
        for (const auto& Segment : Segments)
        {
            const auto Stamp = Segment.Sample.Stamp;
            DrawKvRow(f"Emitter {Segment.Emitter.Id.ToString()}", f"{Segment.Emitter.Source :n} | slot {Get_NameText(Segment.Emitter.Slot)} | limb {Get_NameText(Segment.LimbId)} | radius {Segment.Emitter.Radius :.2} cm");
            DrawKvRow("  Provenance", f"action {Stamp.Get_Identity().Get_Value()} | native generation {Stamp.Get_Generation()} | attempt generation {Segment.Sample.Generation} | sample {Stamp.Get_SampleSequence()} | overlap frame {Segment.Sample.ObservationFrame}");
            DrawKvRow("  Source revisions", f"subject {Stamp.Get_SubjectPoseRevision()} | content {Stamp.Get_ContentRevision()} | topology {Stamp.Get_TopologyRevision()}");
            DrawKvRow("  Accepted segment", f"{Segment.Geometry.From.ToString()} -> {Segment.Geometry.To.ToString()} | travel {Segment.Geometry.Travel :.3} cm");
            const FString SweepWindow = Segment.Emitter.ObstructionWindow.IsNone() ? "inherits motion window" : Segment.Emitter.ObstructionWindow.ToString();
            DrawKvRow("  Stored activity", f"obstruction {BoolText(Segment.Activity.Obstruction)} / damage {BoolText(Segment.Activity.Damage)} | damage window {Segment.Emitter.DamageWindow} | sweep window {SweepWindow}");
            DrawKvRow("  Accepted frame rotations", f"{Segment.Geometry.PreviousFrame.GetRotation().Rotator().ToString()} -> {Segment.Geometry.CurrentFrame.GetRotation().Rotator().ToString()}");
        }
    }

    private void DrawAttackHistory(const TArray<FMars_Attack_HistoryEntry>& InHistory)
    {
        DrawSectionHeading(f"Stored attack history ({InHistory.Num()} / 16 events)");
        for (const auto& Entry : InHistory)
        {
            DrawKvRow(f"#{Entry.Sequence} {Entry.Event}", f"{Get_TagText(Entry.AttackId)} | action {Entry.ActionIdentity.Get_Value()} | {Get_NameText(Entry.Reason)}");
            DrawKvRow("  Historical generations", f"attempt {Entry.Context.AttemptGeneration} | selection {Entry.Context.SelectionGeneration} | target {Entry.Context.TargetGeneration}");
            const auto Evaluation = Entry.Context.Evaluation;
            DrawKvRow("  Historical evaluation capture frame", f"{Evaluation.ObservationFrame}");
            DrawKvRow("  Historical choices", f"{Evaluation.Selection.Disposition :n} | preferred {Get_ChoiceText(Evaluation.Selection.Preferred)} | ready {Get_ChoiceText(Evaluation.Selection.ReadyChoice)} | selected {Get_ChoiceText(Evaluation.Selection.Selected)}");
            for (const auto& Candidate : Evaluation.Evaluations)
            {
                DrawKvRow(f"  {Candidate.AttackId.ToString()}", f"{Candidate.Availability :n} | capable {BoolText(Candidate.Capable)}");
                DrawBlockers("    Historical blocker", Candidate.Blockers);
            }
            if (Entry.Result.Evidence.Observed || Entry.Result.Evidence.Failure.IsNone() == false)
            { DrawKvRow("  Historical native / cleanup", f"{Get_NativeResultText(Entry.Result.Native)} / {Get_NameText(Entry.Result.CleanupOutcome)} | evidence {Get_NameText(Entry.Result.Evidence.Source)} / {Get_NameText(Entry.Result.Evidence.Failure)}"); }
        }
    }

    private FString Get_HealthText(FCk_Handle_Health InHealth) const
    {
        if (ck::Is_NOT_Valid(InHealth))
        { return "-"; }

        return f"{InHealth.Get_Current() :.0} / {InHealth.Get_Max() :.0}";
    }
}
