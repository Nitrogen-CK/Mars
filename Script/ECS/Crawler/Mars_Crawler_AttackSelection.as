// Runtime adapters own live observations; utils_attack consumes only copied values.
struct FMars_Crawler_AttackConstruction
{
    UPROPERTY() FMars_Attack_ResolvedLoadout Resolved;
    UPROPERTY() UMars_AttackLoadout_Data Loadout;
    UPROPERTY() TArray<UMars_AttackDefinition_Data> Definitions;
    UPROPERTY() TArray<UCk_ProceduralAction_Data> Clips;
}

struct FMars_Attack_LoadoutEvaluation
{
    UPROPERTY() TArray<FMars_Attack_Evaluation> Evaluations;
    UPROPERTY() FMars_Attack_Selection Selection;
    UPROPERTY() int32 SelectionGeneration = 0;
    UPROPERTY() int64 ObservationFrame = 0;
    UPROPERTY() int64 TargetIdentity = 0;
    UPROPERTY() int32 TargetGeneration = 0;
}

struct FMars_Attack_ResolvedPlan
{
    UPROPERTY() FMars_Attack_ResolvedEntry Entry;
    UPROPERTY() FMars_Attack_ExecutionPolicy Execution;
    UPROPERTY() FCk_Handle Target;
    UPROPERTY() int32 TargetGeneration = 0;
    UPROPERTY() int32 SelectionGeneration = 0;
    UPROPERTY() int32 GameRevision = 0;
}

struct FMars_Attack_Admission
{
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FCk_ProceduralAction_Identity ActionIdentity;
    UPROPERTY() int32 AttemptGeneration = 0;
    UPROPERTY() int32 SelectionGeneration = 0;
    UPROPERTY() bool Accepted = false;
    UPROPERTY() int64 SampleId = 0;
}

struct FMars_Attack_TerminalEvidence
{
    UPROPERTY() bool Observed = false;
    UPROPERTY() FName Failure;
    UPROPERTY() FName Source;
}

struct FMars_Attack_Result
{
    UPROPERTY() FMars_Attack_TerminalEvidence Evidence;
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FCk_ProceduralAction_Identity ActionIdentity;
    UPROPERTY() FCk_ProceduralAction_Result Native;
    UPROPERTY() FName CleanupOutcome;
    UPROPERTY() bool Accepted = false;
    UPROPERTY() bool Completed = false;
    UPROPERTY() TArray<FMars_Attack_Blocker> RequiredPartFailures;
}

struct FMars_Attack_Decision
{
    UPROPERTY() FMars_Attack_LoadoutEvaluation Evaluation;
    // Every evaluation and blocker: a change is a decision event (OnAttackDecisionChanged, the history).
    UPROPERTY() FString Signature;
    // The target and the choice alone: a change bumps the selection generation an explicit start must match.
    UPROPERTY() FString SelectionSignature;
    UPROPERTY() FName LastReason;
}

struct FMars_Attack_HistoryContext
{
    UPROPERTY() int32 AttemptGeneration = 0;
    UPROPERTY() int32 SelectionGeneration = 0;
    UPROPERTY() int32 TargetGeneration = 0;
    UPROPERTY() FMars_Attack_LoadoutEvaluation Evaluation;
}

struct FMars_Attack_HistoryEntry
{
    UPROPERTY() FMars_Attack_HistoryContext Context;
    UPROPERTY() int64 Sequence = 0;
    UPROPERTY() FName Event;
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FCk_ProceduralAction_Identity ActionIdentity;
    UPROPERTY() FName Reason;
    UPROPERTY() FMars_Attack_Result Result;
}

struct FMars_Crawler_AttackReuse
{
    UPROPERTY() FGameplayTag Id;
    UPROPERTY() float32 Remaining = 0.0f;
    UPROPERTY() int64 LastStartSequence = 0;
}

struct FMars_Crawler_AttackLedger
{
    UPROPERTY() int64 StartSequence = 0;
    UPROPERTY() int64 EventSequence = 0;
    UPROPERTY() TArray<FMars_Attack_HistoryEntry> History;
}

struct FMars_Fragment_Crawler_AttackSelection
{
    UPROPERTY() FMars_Attack_Preparation Preparation;
    UPROPERTY() TArray<FMars_Crawler_AttackReuse> Reuse;
    UPROPERTY() FMars_Attack_Decision Decision;
    UPROPERTY() int32 Generation = 1;
    UPROPERTY() FMars_Crawler_AttackLedger Ledger;
}

struct FMars_Crawler_AttackCleanup
{
    UPROPERTY() TArray<FName> ClaimedIds;
    UPROPERTY() bool Released = false;
    UPROPERTY() bool Requested = false;
    UPROPERTY() float32 Elapsed = 0.0f;
}

delegate void FMars_Delegate_Crawler_OnAttackDecisionChanged(FCk_Handle_Crawler InSelf, FMars_Attack_Decision InDecision);
event void FMars_Delegate_Crawler_OnAttackDecisionChanged_MC(FCk_Handle_Crawler InSelf, FMars_Attack_Decision InDecision);
delegate void FMars_Delegate_Crawler_OnAttackAdmitted(FCk_Handle_Crawler InSelf, FMars_Attack_Admission InAdmission);
event void FMars_Delegate_Crawler_OnAttackAdmitted_MC(FCk_Handle_Crawler InSelf, FMars_Attack_Admission InAdmission);
delegate void FMars_Delegate_Crawler_OnAttackCompleted(FCk_Handle_Crawler InSelf, FMars_Attack_Result InResult);
event void FMars_Delegate_Crawler_OnAttackCompleted_MC(FCk_Handle_Crawler InSelf, FMars_Attack_Result InResult);

namespace utils_crawler
{
    EMars_Crawler_AttackReject Get_LegacyAttackReject(FName InCode)
    {
        if (InCode == n"OutOfRange" || InCode == n"TooClose") { return EMars_Crawler_AttackReject::OutOfRange; }
        if (InCode == n"Facing") { return EMars_Crawler_AttackReject::Facing; }
        if (InCode == n"Moving") { return EMars_Crawler_AttackReject::Moving; }
        if (InCode == n"Height") { return EMars_Crawler_AttackReject::Height; }
        if (InCode == n"Ungrounded") { return EMars_Crawler_AttackReject::Ungrounded; }
        if (InCode == n"Slope") { return EMars_Crawler_AttackReject::Slope; }
        if (InCode == n"SupportStance") { return EMars_Crawler_AttackReject::Stance; }
        if (InCode == n"WindupBlocked") { return EMars_Crawler_AttackReject::WindupBlocked; }
        if (InCode == n"Dead") { return EMars_Crawler_AttackReject::Dead; }
        if (InCode == n"SupportCapacity") { return EMars_Crawler_AttackReject::Legs; }
        if (InCode == n"PartMissing" || InCode == n"PartSevered" || InCode == n"PartBroken" || InCode == n"PartDepleted" ||
            InCode == n"PartWrongOwner" || InCode == n"PartPendingDestroy" || InCode == n"ConditionDisallowed" || InCode == n"LimbDisabled" || InCode == n"LimbDetached")
        { return EMars_Crawler_AttackReject::RequiredPartUnavailable; }
        return EMars_Crawler_AttackReject::NotReady;
    }

    TOptional<FMars_Attack_ResolvedEntry> Find_ResolvedAttack(const FMars_Attack_ResolvedLoadout& InLoadout, FGameplayTag InId)
    {
        for (const auto& Entry : InLoadout.Entries)
        {
            if (Entry.Identity.Id == InId)
            { return TOptional<FMars_Attack_ResolvedEntry>(Entry); }
        }
        return TOptional<FMars_Attack_ResolvedEntry>();
    }
    FString Get_AttackValidationText(const FMars_Attack_ValidationReport& InReport)
    {
        if (InReport.Diagnostics.Num() == 1 && InReport.Diagnostics[0].Code == n"LegacyCombatInvalid")
        { return InReport.Diagnostics[0].Actual; }
        auto Text = FString();
        for (const auto& Diagnostic : InReport.Diagnostics)
        { Text = f"{Text}{Diagnostic.Code} at {Diagnostic.Field}: expected {Diagnostic.Expected}, actual {Diagnostic.Actual}; "; }
        return Text;
    }

    TArray<FMars_Attack_AnatomyBinding> Make_AttackAnatomy(const FMars_Crawler_Spec& InSpec)
    {
        if (InSpec.Combat.Anatomy.Num() > 0)
        { return InSpec.Combat.Anatomy; }
        auto Bindings = TArray<FMars_Attack_AnatomyBinding>();
        auto Body = FMars_Attack_AnatomyBinding();
        Body.Role = GameplayTags::AttackRole_Mars_Body;
        Bindings.Add(Body);
        auto Right = FMars_Attack_AnatomyBinding();
        Right.Role = GameplayTags::AttackRole_Mars_FrontRight;
        Right.Source = EMars_Attack_AnatomySource::ProceduralLimb;
        Right.LimbId = n"Leg0";
        Right.Locomotor = true;
        Bindings.Add(Right);
        auto Left = Right;
        Left.Role = GameplayTags::AttackRole_Mars_FrontLeft;
        Left.LimbId = InSpec.LegCount == 4 ? n"Leg3" : n"Leg5";
        Bindings.Add(Left);
        return Bindings;
    }

    FMars_Attack_Definition Make_LegacyAttack(const FMars_Crawler_Combat& InCombat, EMars_Crawler_AttackClipKind InKind)
    {
        auto Def = FMars_Attack_Definition();
        Def.Clip = InKind == EMars_Crawler_AttackClipKind::Pincer ? InCombat.PincerClip : InCombat.JabClip;
        Def.Prepare.MaxDistance = InCombat.Prepare.StartDistance;
        Def.Prepare.FacingToleranceDegrees = InCombat.Prepare.FacingToleranceDegrees;
        Def.Prepare.MaxHeightDifference = InCombat.Prepare.MaxHeightDifference;
        Def.Prepare.MaxSpeedToStart = InCombat.Prepare.MaxSpeedToStart;
        Def.Prepare.TimeoutSeconds = InCombat.Prepare.TimeoutSeconds;
        Def.Hit.Damage = InCombat.Hit.Damage;
        Def.Hit.DamageType = InCombat.Hit.DamageType;
        auto Emitter = FMars_Attack_Emitter();
        Emitter.Id = GameplayTags::AttackEmitter_Mars_Body;
        Emitter.LocalCenter = InCombat.Hit.LocalCenter;
        Emitter.Radius = InCombat.Hit.Radius;
        Emitter.MaxSampleTravel = InCombat.Hit.MaxSampleTravel;
        Def.Hit.Emitters.Add(Emitter);
        Def.Cooldown.RecoverySeconds = InCombat.Timing.CooldownSeconds;
        Def.CueProfile = InKind == EMars_Crawler_AttackClipKind::Pincer ? GameplayTags::AttackCue_Mars_Pincer : FGameplayTag();
        if (InKind == EMars_Crawler_AttackClipKind::Pincer)
        {
            auto Right = FMars_Attack_SlotRole();
            Right.Slot = n"ClawRight";
            Right.Role = GameplayTags::AttackRole_Mars_FrontRight;
            Def.Requirements.Slots.Add(Right);
            auto Left = Right;
            Left.Slot = n"ClawLeft";
            Left.Role = GameplayTags::AttackRole_Mars_FrontLeft;
            Def.Requirements.Slots.Add(Left);
        }
        return Def;
    }

    FMars_Attack_AnatomyBinding Find_AttackBinding(const TArray<FMars_Attack_AnatomyBinding>& InAnatomy, FGameplayTag InRole)
    {
        for (const auto& Binding : InAnatomy)
        {
            if (Binding.Role == InRole)
            { return Binding; }
        }
        return FMars_Attack_AnatomyBinding();
    }

    // Called only on copied definitions, before freezing; a shared authored graph is never mutated.
    FMars_Attack_ValidationReport Resolve_AttackCreatureDefaults(FMars_Attack_Definition& InOutDefinition, FVector InBodyHalfExtents)
    {
        auto Report = FMars_Attack_ValidationReport();
        auto Needed = InOutDefinition.Prepare.UseCreatureFrontRange;
        for (const auto& Emitter : InOutDefinition.Hit.Emitters)
        { Needed = Needed || Emitter.UseCreatureFrontCenter; }
        if (Needed == false) { return Report; }
        utils_attack::Add_Check(Report, utils_attack::Get_IsFinite(InBodyHalfExtents) && InBodyHalfExtents.X > 0.0,
            utils_attack::Make_Diagnostic(n"CreatureBodyBounds", "Rig.BodyHalfExtents", FMars_Attack_Comparison("finite bounds with positive front extent", InBodyHalfExtents.ToString())));
        if (Report.Get_IsValid() == false) { return Report; }
        if (InOutDefinition.Prepare.UseCreatureFrontRange)
        {
            InOutDefinition.Prepare.MaxDistance = float32(InBodyHalfExtents.X) + InOutDefinition.Prepare.CreatureFrontRangeMargin;
            InOutDefinition.Prepare.UseCreatureFrontRange = false;
        }
        for (auto& Emitter : InOutDefinition.Hit.Emitters)
        {
            if (Emitter.UseCreatureFrontCenter && Emitter.Source == EMars_Attack_EmitterSource::Body)
            {
                Emitter.LocalCenter = FVector(InBodyHalfExtents.X, 0.0, 0.0);
                Emitter.UseCreatureFrontCenter = false;
            }
        }
        return Report;
    }
    FMars_Attack_ValidationReport Resolve_AttackLoadout(const FMars_Crawler_Spec& InSpec, FMars_Crawler_AttackConstruction& OutConstruction)
    {
        OutConstruction = FMars_Crawler_AttackConstruction();
        auto Report = FMars_Attack_ValidationReport();
        if (InSpec.Combat.Enabled == false)
        { return Report; }
        auto& Resolved = OutConstruction.Resolved;
        Resolved.Anatomy = Make_AttackAnatomy(InSpec);
        for (auto& Binding : Resolved.Anatomy)
        {
            if (Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            { Binding.Locomotor = true; }
        }
        Resolved.GameRevision = 1;
        for (const auto& Binding : Resolved.Anatomy)
        {
            if (Binding.Source != EMars_Attack_AnatomySource::ProceduralLimb)
            { continue; }
            auto Exists = false;
            for (const auto& Leg : InSpec.Get_RigData().Get_Legs())
            { Exists = Exists || Leg.Get_Id() == Binding.LimbId; }
            utils_attack::Add_Check(Report, Exists, utils_attack::Make_Diagnostic(n"CrawlerLimbIdUnknown", "Anatomy",
                FMars_Attack_Comparison("stable ID in creature rig", Binding.LimbId.ToString())));
        }
        auto Legacy = InSpec.Combat.Loadout.IsNull();
        if (Legacy)
        {
            auto Combat = InSpec.Combat;
            if (Combat.JabClip.IsNull() == false)
            { OutConstruction.Clips.Add(System::LoadAsset_Blocking(Combat.JabClip)); }
            if (Combat.PincerClip.IsNull() == false)
            { OutConstruction.Clips.Add(System::LoadAsset_Blocking(Combat.PincerClip)); }
            const auto Validation = Combat.Validate();
            if (Validation.IsValid() == false)
            {
                utils_attack::Add_Check(Report, false, utils_attack::Make_Diagnostic(n"LegacyCombatInvalid", "Combat",
                    FMars_Attack_Comparison("valid legacy profile", Validation.Get_Error())));
                return Report;
            }
            auto Entry = FMars_Attack_ResolvedEntry();
            Entry.Identity.Id = GameplayTags::Attack_Mars_Jab;
            Entry.Definition = Make_LegacyAttack(Combat, EMars_Crawler_AttackClipKind::Jab);
            Resolved.Entries.Add(Entry);
            if (Combat.PincerClip.IsNull() == false)
            {
                Entry.Identity.Id = GameplayTags::Attack_Mars_Pincer;
                Entry.Identity.Priority = 10;
                Entry.Definition = Make_LegacyAttack(Combat, EMars_Crawler_AttackClipKind::Pincer);
                Resolved.Entries.Add(Entry);
            }
            Resolved.Execution.Tuning = Make_AttackTuning(InSpec);
            Resolved.Execution.MaxRootDrift = Combat.Hit.MaxRootDrift;
            Resolved.Execution.MaxGroundSlopeDegrees = Combat.Prepare.MaxGroundSlopeDegrees;
            if (Combat.Get_HasPincer())
            { Resolved.Execution.Locomotion = Make_PincerLocomotion(InSpec); }
        }
        else
        {
            utils_attack::Add_Check(Report, InSpec.Combat.JabClip.IsNull() && InSpec.Combat.PincerClip.IsNull(),
                utils_attack::Make_Diagnostic(n"MixedCombatAuthoring", "Combat", FMars_Attack_Comparison("Loadout XOR legacy clips", "mixed")));
            OutConstruction.Loadout = System::LoadAsset_Blocking(InSpec.Combat.Loadout);
            if (ck::Is_NOT_Valid(OutConstruction.Loadout))
            {
                utils_attack::Add_Check(Report, false, utils_attack::Make_Diagnostic(n"LoadoutUnloaded", "Combat.Loadout",
                    FMars_Attack_Comparison("loaded asset", InSpec.Combat.Loadout.ToString())));
                return Report;
            }
            const auto Authored = OutConstruction.Loadout.Spec;
            for (int32 EntryIndex = 0; EntryIndex < Math::Min(Authored.Entries.Num(), utils_attack::MaxEntries); ++EntryIndex)
            {
                const auto Entry = Authored.Entries[EntryIndex];
                if (Entry.Enabled == false)
                { continue; }
                auto Asset = System::LoadAsset_Blocking(Entry.Definition);
                if (ck::Is_NOT_Valid(Asset))
                { continue; }
                OutConstruction.Definitions.Add(Asset);
                OutConstruction.Clips.Add(System::LoadAsset_Blocking(Asset.Def.Clip));
                auto Runtime = FMars_Attack_ResolvedEntry();
                Runtime.Identity.Id = Entry.Id;
                Runtime.Identity.Priority = Entry.Priority;
                Runtime.Identity.DefinitionPath = Entry.Definition;
                Runtime.Definition = Asset.Def;
                Resolved.Entries.Add(Runtime);
            }
            utils_attack::Append_Report(Report, utils_attack::Validate_Loadout(Authored), "Combat.Loadout.");
            Resolved.Path = InSpec.Combat.Loadout;
            Resolved.Selection = Authored.Selection;
            Resolved.Execution = Authored.Execution;
            if (Report.Get_IsValid() == false)
            { return Report; }
        }
        utils_attack::Add_Check(Report, Resolved.Execution.Locomotion.Get_Support().Get_Mode() != ECk_ProceduralLimbControl_SupportMode::ProjectedSupportRegion,
            utils_attack::Make_Diagnostic(n"CrawlerSupportRegionUnsupported", "Execution.Locomotion.Support.Mode",
                FMars_Attack_Comparison("Disabled or CountOnly; no public region proof on crawler adapter", "ProjectedSupportRegion")));
        auto HasEndpoint = false;
        for (const auto& Entry : Resolved.Entries)
        {
            for (const auto& Emitter : Entry.Definition.Hit.Emitters)
            { HasEndpoint = HasEndpoint || Emitter.Source == EMars_Attack_EmitterSource::LimbEndpoint; }
        }
        // Native refinements are predictions, followed by one physical publication. One qualified sample makes its
        // settled-motion validation compare against the previous physical pose, rather than an intermediate prediction.
        utils_attack::Add_Check(Report, HasEndpoint == false || Resolved.Execution.Tuning.Get_Sampling().Get_MaxSamples() == 1,
            utils_attack::Make_Diagnostic(n"EndpointPublicationSampling", "Execution.Tuning.Sampling.MaxSamples",
                FMars_Attack_Comparison("1 for physical endpoint emitters", f"{Resolved.Execution.Tuning.Get_Sampling().Get_MaxSamples()}")));
        // Bind every authored requirement to stable schema IDs, never positions in the live record.
        float64 Longest = 0.0;
        for (int32 Index = 0; Index < Resolved.Entries.Num(); ++Index)
        {
            auto& Entry = Resolved.Entries[Index];
            Entry.Identity.GameRevision = Resolved.GameRevision;
            utils_attack::Append_Report(Report, Resolve_AttackCreatureDefaults(Entry.Definition, InSpec.Rig.BodyHalfExtents), f"Entries[{Index}].");
            Entry.SourceClip = Entry.Definition.Clip;
            for (const auto& Authored : Entry.Definition.Requirements.Slots)
            {
                auto Slot = FMars_Attack_ResolvedSlot();
                Slot.Slot = Authored.Slot;
                Slot.Binding = Find_AttackBinding(Resolved.Anatomy, Authored.Role);
                Slot.MaxCondition = Authored.MaxCondition;
                Entry.Slots.Add(Slot);
            }
            for (const auto& Authored : Entry.Definition.Requirements.Parts)
            {
                auto Part = FMars_Attack_ResolvedPart();
                Part.Binding = Find_AttackBinding(Resolved.Anatomy, Authored.Role);
                Part.MaxCondition = Authored.MaxCondition;
                Entry.Parts.Add(Part);
            }
            auto Source = Entry.SourceClip.Get();
            if (ck::Is_NOT_Valid(Source))
            { continue; }
            Longest = Math::Max(Longest, Get_ClipSeconds(Source));
            auto Draft = FCk_ProceduralAction_ClipDraft();
            const auto Copy = utils_procedural_action_builder::Make_Draft_FromData(Source, Draft);
            auto Frozen = Cast<UCk_ProceduralAction_Data>(NewObject(GetTransientPackage(), UCk_ProceduralAction_Data));
            const auto Built = utils_procedural_action_builder::Build_Into(Draft, Frozen);
            utils_attack::Add_Check(Report, Copy.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid && Built.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
                utils_attack::Make_Diagnostic(n"ClipCopyFailed", f"Entries[{Index}].Clip", FMars_Attack_Comparison("public draft/build Valid", Source.GetName().ToString())));
            OutConstruction.Clips.Add(Frozen);
            Entry.Definition.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(Frozen);
        }
        if (Legacy && InSpec.Combat.Get_HasPincer())
        {
            auto Locomotion = Resolved.Execution.Locomotion;
            auto Support = Locomotion.Get_Support();
            Support.Set_SupportHoldTimeout(FCk_Time(Longest + InSpec.Combat.Timing.CancelSeconds));
            Locomotion.Set_Support(Support);
            Resolved.Execution.Locomotion = Locomotion;
        }
        utils_attack::Append_Report(Report, utils_attack::Validate_ResolvedLoadout(Resolved), "");
        return Report;
    }

    FCk_Handle_BodyPart Find_AttackPart(const FCk_Handle_Crawler& InSelf, FName InLimbId)
    {
        for (const auto& Part : InSelf.Get_LegParts())
        {
            if (ck::IsValid(Part) && ck::IsValid(Part.Get_Leg()) && Part.Get_Leg().Get_Id() == InLimbId)
            { return Part; }
        }
        return FCk_Handle_BodyPart();
    }

    FMars_Attack_RoleObservation Capture_AttackRole(const FCk_Handle_Crawler& InSelf, const FMars_Attack_AnatomyBinding& InBinding)
    {
        auto Observation = FMars_Attack_RoleObservation();
        Observation.Role = InBinding.Role;
        Observation.Source = InBinding.Source;
        Observation.LimbId = InBinding.LimbId;
        FCk_Handle Root = InSelf;
        if (InBinding.Source == EMars_Attack_AnatomySource::Body)
        {
            Observation.Part.Live = ck::IsValid(Root);
            Observation.Part.PendingDestroy = utils_entity_lifetime::Get_IsPendingDestroy(Root, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
            Observation.Part.OwnerMatches = true;
            Observation.Part.Depleted = InSelf.Get_Monster().Get_BodyHealth().Get_IsDepleted();
            return Observation;
        }
        const auto Part = Find_AttackPart(InSelf, InBinding.LimbId);
        if (ck::Is_NOT_Valid(Part))
        { return Observation; }
        FCk_Handle Entity = Part;
        Observation.Part.Live = true;
        Observation.Part.PendingDestroy = utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
        Observation.Part.OwnerMatches = Part.Get_Monster() == InSelf.Get_Monster() && utils_entity_lifetime::Get_LifetimeOwner(Entity) == Root;
        Observation.Part.State = Part.Get_State();
        Observation.Part.Condition = Part.Get_Condition();
        Observation.Part.Depleted = ck::Is_NOT_Valid(Part.Get_Health()) || Part.Get_Health().Get_IsDepleted();
        const auto Leg = Part.Get_Leg();
        Observation.Limb.Exists = ck::IsValid(Leg);
        Observation.Limb.Attached = Leg.Get_IsAttached();
        Observation.Limb.Enabled = Leg.Get_Status() == ECk_ProceduralLeg_Status::Enabled;
        Observation.Limb.Control = InSelf.Get_Articulation().Get_LimbControl(InBinding.LimbId).Get_State();
        const auto Foot = Leg.Get_Foot();
        Observation.Limb.Planted = Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted;
        Observation.Limb.Trusted = Foot.Get_Contact() == ECk_ProceduralLeg_FootContact::Trusted;
        return Observation;
    }

    int64 Get_AttackTargetIdentity(FCk_Handle InTarget)
    {
        if (ck::Is_NOT_Valid(InTarget))
        { return 0; }
        auto Entity = FCk_Entity();
        InTarget.Break_Handle(Entity);
        int32 Id = 0;
        int32 Number = 0;
        int32 Version = 0;
        Entity.Break_Entity(Id, Number, Version);
        return int64(Id);
    }

    bool Get_AttackWindupClear(const FCk_Handle_Crawler& InSelf, const FMars_Attack_ResolvedEntry& InEntry)
    {
        const auto Clip = InEntry.Definition.Clip.Get();
        if (ck::Is_NOT_Valid(Clip))
        { return false; }
        auto End = FTransform::Identity;
        for (const auto& Phase : Clip.Get_Phases())
        {
            if (Phase.Get_Id() == InEntry.Definition.Motion.WindupPhase && Phase.Get_BodyKeys().Num() > 0)
            {
                const auto Key = Phase.Get_BodyKeys().Last();
                End = FTransform(Key.Get_Rotation(), Key.Get_Translation(), FVector::OneVector);
            }
        }
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(InSelf.Get_Presentation());
        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        for (const auto& Emitter : InEntry.Definition.Hit.Emitters)
        {
            // Endpoint clearance is native claimed-channel admission plus accepted offense casts; no requested endpoint is contact evidence.
            if (Emitter.Source != EMars_Attack_EmitterSource::Body)
            { continue; }
            const auto Neutral = Get_HitCenter(Presentation, Emitter.LocalCenter);
            const auto Windup = Neutral + Root.GetRotation().RotateVector(Make_HitCenterOffset(End, Emitter.LocalCenter));
            auto Query = Make_AttackQuery(Neutral, Windup, Emitter.Radius);
            Query.Set_IgnoredEntities(InSelf.Get_AttackIgnoredEntities());
            FCk_Handle Tracer = InSelf;
            const auto Hit = utils_probe_trace::Request_SingleShapeTrace(Tracer, Query);
            if (Hit.Get_HitKind() == ECk_ProbeTrace_HitKind::World)
            { return false; }
        }
        return true;
    }

    FMars_Attack_LoadoutEvaluation Evaluate_AttackLoadout(const FCk_Handle_Crawler& InSelf, FCk_Handle InTarget)
    {
        auto Result = FMars_Attack_LoadoutEvaluation();
        Result.ObservationFrame = utils_time::Get_FrameCounter();
        if (InSelf.Get_IsCombatArmed() == false)
        { return Result; }
        const auto Loadout = InSelf.Get_Spec().ResolvedAttacks;
        const auto& Selection = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection);
        Result.SelectionGeneration = Selection.Generation;
        Result.TargetIdentity = Get_AttackTargetIdentity(InTarget);
        Result.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        auto Query = FMars_Attack_EvaluationQuery();
        Query.Execution = Loadout.Execution;
        Query.Target.Valid = InTarget == InSelf.Get_CombatTarget() && InSelf.Get_IsCombatTargetValid(InTarget);
        Query.Target.Identity = Result.TargetIdentity;
        Query.Target.Generation = Result.TargetGeneration;
        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        const auto Motion = InSelf.Get_Motion();
        const auto Up = utils_surface_motion::Get_SupportNormal(Motion).GetSafeNormal();
        if (Query.Target.Valid)
        {
            const auto Offset = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform()) - Root.GetLocation();
            Query.Target.Distance = float32(Offset.Size2D());
            Query.Target.HeightDifference = float32(Offset.Z);
            Query.Target.FacingDegrees = float32(Get_PlanarAngleDegrees(Root.GetRotation().GetForwardVector(), Offset, Up));
        }
        Query.Self.State.Alive = InSelf.Get_IsCombatDead() == false;
        Query.Self.State.Ready = utils_procedural_gait::Get_Status(InSelf.Get_Gait()) == ECk_ProceduralAnimation_Status::Ready &&
            utils_procedural_body_pose::Get_Status(InSelf.Get_BodyPose()) == ECk_ProceduralAnimation_Status::Ready &&
            utils_surface_motion::Get_Status(Motion) == ECk_ProceduralAnimation_Status::Ready && ck::IsValid(InSelf.Get_ActionPlayer()) &&
            InSelf.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle;
        Query.Self.State.Grounded = utils_surface_motion::Get_Support(Motion) == ECk_SurfaceMotion_Support::Grounded &&
            utils_surface_motion::Get_ContactQuery(Motion) == ECk_SurfaceMotion_ContactQuery::Trusted && Up.IsNearlyZero() == false;
        Query.Self.State.SlopeDegrees = float32(Math::RadiansToDegrees(Math::Acos(Math::Clamp(Up.DotProduct(FVector::UpVector), -1.0, 1.0))));
        Query.Self.State.RootSpeed = float32(utils_surface_motion::Get_Velocity(Motion).Size());
        Query.Self.State.MobilityReady = utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) >= InSelf.Get_Spec().MinLegsToWalk;
        for (const auto& Binding : Loadout.Anatomy)
        { Query.Roles.Add(Capture_AttackRole(InSelf, Binding)); }
        for (const auto& Part : InSelf.Get_LegParts())
        {
            if (ck::Is_NOT_Valid(Part) || ck::Is_NOT_Valid(Part.Get_Leg()))
            { continue; }
            auto Binding = FMars_Attack_AnatomyBinding();
            Binding.Source = EMars_Attack_AnatomySource::ProceduralLimb;
            Binding.LimbId = Part.Get_Leg().Get_Id();
            const auto Role = Capture_AttackRole(InSelf, Binding);
            auto Support = FMars_Attack_SupportLimbObservation();
            Support.LimbId = Role.LimbId;
            Support.Part = Role.Part;
            Support.Limb = Role.Limb;
            Query.Self.SupportLimbs.Add(Support);
        }
        Query.Cooldown.GlobalRemaining = InSelf.Get_AttackCooldownRemaining();
        auto SelectionQuery = FMars_Attack_SelectionQuery();
        SelectionQuery.Policy = Loadout.Selection;
        SelectionQuery.Preparation = Selection.Preparation;
        SelectionQuery.Target = Query.Target;
        for (const auto& Entry : Loadout.Entries)
        {
            Query.Entry = Entry;
            Query.Cooldown.EntryRemaining = 0.0f;
            auto Candidate = FMars_Attack_SelectionCandidate();
            Candidate.Id = Entry.Identity.Id;
            Candidate.Priority = Entry.Identity.Priority;
            for (const auto& Reuse : Selection.Reuse)
            {
                if (Reuse.Id == Candidate.Id)
                {
                    Query.Cooldown.EntryRemaining = Reuse.Remaining;
                    Candidate.LastStartSequence = Reuse.LastStartSequence;
                }
            }
            // Spatial preflight is deferred while the evaluator already rejects an unready self or missing target.
            // Editor/populator registries can compose crawlers before a physics query context exists.
            Query.Self.WindupClear = true;
            if (Query.Target.Valid && Query.Self.State.Ready && Query.Self.State.Grounded)
            { Query.Self.WindupClear = Get_AttackWindupClear(InSelf, Entry); }
            Candidate.Evaluation = utils_attack::Evaluate(Query);
            Result.Evaluations.Add(Candidate.Evaluation);
            SelectionQuery.Candidates.Add(Candidate);
        }
        Result.Selection = utils_attack::Select(SelectionQuery);
        return Result;
    }

    TArray<FMars_Attack_Blocker> Evaluate_AttackContinuation(const FCk_Handle_Crawler& InSelf)
    {
        auto Evaluation = FMars_Attack_Evaluation();
        Evaluation.Capable = true;
        const auto Plan = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Plan;
        auto Roles = TArray<FMars_Attack_RoleObservation>();
        for (const auto& Binding : InSelf.Get_Spec().ResolvedAttacks.Anatomy)
        {
            auto Role = Capture_AttackRole(InSelf, Binding);
            if (Role.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            {
                const auto Control = InSelf.Get_Articulation().Get_LimbControl(Role.LimbId);
                FCk_Handle Action = InSelf.Get_AttackAction();
                if (Control.Get_State() != ECk_ProceduralLimbControl_State::Controlled || Control.Get_Owner() == Action)
                { Role.Limb.Control = ECk_ProceduralLimbControl_State::Default; }
                // Foot stance is an admission check. The action owns its admitted feet now.
                Role.Limb.Planted = true;
                Role.Limb.Trusted = true;
            }
            Roles.Add(Role);
        }
        for (const auto& Slot : Plan.Entry.Slots)
        { utils_attack::Evaluate_Role(Evaluation, Slot, Roles); }
        for (const auto& Part : Plan.Entry.Parts)
        {
            auto Requirement = FMars_Attack_ResolvedSlot();
            Requirement.Binding = Part.Binding;
            Requirement.MaxCondition = Part.MaxCondition;
            utils_attack::Evaluate_Role(Evaluation, Requirement, Roles);
        }
        return Evaluation.Blockers;
    }

    FString Get_AttackSelectionSignature(const FMars_Attack_LoadoutEvaluation& InEvaluation)
    {
        auto Signature = f"{InEvaluation.TargetIdentity}:{InEvaluation.TargetGeneration}";
        if (InEvaluation.Selection.Preferred.IsSet())
        { Signature = f"{Signature}|P:{InEvaluation.Selection.Preferred.GetValue().ToString()}"; }
        if (InEvaluation.Selection.ReadyChoice.IsSet())
        { Signature = f"{Signature}|R:{InEvaluation.Selection.ReadyChoice.GetValue().ToString()}"; }
        if (InEvaluation.Selection.Selected.IsSet())
        { Signature = f"{Signature}|S:{InEvaluation.Selection.Selected.GetValue().ToString()}"; }
        return f"{Signature}|{InEvaluation.Selection.Disposition :n}";
    }

    FString Get_AttackDecisionSignature(const FMars_Attack_LoadoutEvaluation& InEvaluation)
    {
        auto Signature = Get_AttackSelectionSignature(InEvaluation);
        for (const auto& Evaluation : InEvaluation.Evaluations)
        {
            Signature = f"{Signature}|{Evaluation.AttackId.ToString()}:{Evaluation.Availability :n}";
            for (const auto& Blocker : Evaluation.Blockers)
            { Signature = f"{Signature}/{Blocker.Code}:{Blocker.Role.ToString()}:{Blocker.Slot}"; }
        }
        return Signature;
    }
}

mixin FMars_Attack_LoadoutEvaluation Get_AttackEvaluation(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Decision.Evaluation : FMars_Attack_LoadoutEvaluation(); }
mixin FMars_Attack_Decision Get_AttackDecision(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Decision : FMars_Attack_Decision(); }
mixin FMars_Attack_Admission Get_AttackAdmission(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Admission : FMars_Attack_Admission(); }
mixin FMars_Attack_Result Get_AttackResult(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Result : FMars_Attack_Result(); }
mixin FMars_Attack_ResolvedPlan Get_AttackPlan(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Plan : FMars_Attack_ResolvedPlan(); }
mixin FGameplayTag Get_AttackId(const FCk_Handle_Crawler& Self)
{ return Self.Get_AttackPlan().Entry.Identity.Id; }
mixin TArray<FMars_Attack_HistoryEntry> Get_AttackHistory(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Ledger.History : TArray<FMars_Attack_HistoryEntry>(); }
mixin FMars_Attack_Preparation Get_AttackPreparation(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Preparation : FMars_Attack_Preparation(); }
mixin TArray<FMars_Crawler_AttackReuse> Get_AttackReuse(const FCk_Handle_Crawler& Self)
{ return Self.Get_IsCombatArmed() ? Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Reuse : TArray<FMars_Crawler_AttackReuse>(); }
mixin UCk_ProceduralAction_Data Get_AttackFrozenPlayedClip(const FCk_Handle_Crawler& Self)
{ return Self.Get_AttackPlan().Entry.Definition.Clip.Get(); }
mixin TOptional<EMars_Crawler_AttackClipKind> Get_AttackLegacyClipKind(const FCk_Handle_Crawler& Self)
{
    if (Self.Get_AttackId() == GameplayTags::Attack_Mars_Jab)
    { return TOptional<EMars_Crawler_AttackClipKind>(EMars_Crawler_AttackClipKind::Jab); }
    if (Self.Get_AttackId() == GameplayTags::Attack_Mars_Pincer)
    { return TOptional<EMars_Crawler_AttackClipKind>(EMars_Crawler_AttackClipKind::Pincer); }
    return TOptional<EMars_Crawler_AttackClipKind>();
}

mixin void Request_PrepareAttack(FCk_Handle_Crawler& Self, const FMars_Request_Crawler_PrepareAttack& InRequest)
{
    if (Self.Get_IsCombatArmed() == false)
    { return; }
    Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Requests).PrepareAttackRequests.Add(InRequest);
}

mixin void BindTo_OnAttackDecisionChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackDecisionChanged InDelegate)
{ Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals).OnAttackDecisionChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
mixin void BindTo_OnAttackAdmitted(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackAdmitted InDelegate)
{ Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals).OnAttackAdmitted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
mixin void BindTo_OnAttackCompleted(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackCompleted InDelegate)
{ Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCompleted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
mixin void UnbindFrom_OnAttackDecisionChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackDecisionChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals))
    { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackDecisionChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
mixin void UnbindFrom_OnAttackAdmitted(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackAdmitted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals))
    { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackAdmitted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
mixin void UnbindFrom_OnAttackCompleted(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackCompleted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals))
    { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCompleted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
