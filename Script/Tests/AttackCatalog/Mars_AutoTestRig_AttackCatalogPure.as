UCLASS(Abstract)
class UMars_AutoTestRig_AttackCatalogPure : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UPROPERTY()
    protected TArray<UCk_ProceduralAction_Data> _Clips;

    UPROPERTY()
    protected TArray<UMars_AttackDefinition_Data> _Definitions;

    protected UCk_ProceduralAction_Data Make_BodyClip()
    {
        auto Draft = FCk_ProceduralAction_ClipDraft();
        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        Body.Set_InitialSource(ECk_ProceduralAction_InitialSource::IdentityOffset);
        Draft.Set_BodyChannel(Body);
        auto Phases = TArray<FCk_ProceduralAction_Phase>();
        Phases.Add(Make_BodyPhase(n"Windup", FVector::ZeroVector, FVector(-10.0, 0.0, 0.0)));
        Phases.Add(Make_BodyPhase(n"Strike", FVector(-10.0, 0.0, 0.0), FVector(24.0, 0.0, 0.0)));
        Phases.Add(Make_BodyPhase(n"Recover", FVector(24.0, 0.0, 0.0), FVector::ZeroVector));
        Draft.Set_Phases(Phases);
        auto Windows = TArray<FCk_ProceduralAction_Window>();
        Windows.Add(FCk_ProceduralAction_Window(n"Offense",
            FCk_ProceduralAction_TimeRef(n"Windup", FCk_FloatRange_0to1(0.0)),
            FCk_ProceduralAction_TimeRef(n"Recover", FCk_FloatRange_0to1(1.0))));
        Draft.Set_Windows(Windows);
        return Build_Clip(Draft);
    }

    private FCk_ProceduralAction_Phase Make_BodyPhase(FName InId, FVector InFrom, FVector InTo)
    {
        auto Phase = FCk_ProceduralAction_Phase(InId, FCk_Time(0.2));
        auto Keys = TArray<FCk_ProceduralAction_TransformKey>();
        Keys.Add(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(0.0), InFrom, FQuat::Identity));
        Keys.Add(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(1.0), InTo, FQuat::Identity));
        Phase.Set_BodyKeys(Keys);
        return Phase;
    }

    protected UCk_ProceduralAction_Data Build_Clip(const FCk_ProceduralAction_ClipDraft& InDraft)
    {
        auto Clip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        const auto Report = utils_procedural_action_builder::Build_Into(InDraft, Clip);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "the pure-validation clip fixture compiles");
        _Clips.Add(Clip);
        return Clip;
    }

    protected FMars_Attack_Definition Make_Definition(UCk_ProceduralAction_Data InClip)
    {
        auto Definition = FMars_Attack_Definition();
        Definition.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(InClip);
        Definition.Hit.DamageType = GameplayTags::DamageType_Mars_Blunt;
        auto Emitter = FMars_Attack_Emitter();
        Emitter.Id = GameplayTags::AttackEmitter_Mars_Body;
        Definition.Hit.Emitters.Add(Emitter);
        auto Part = FMars_Attack_PartRequirement();
        Part.Role = GameplayTags::AttackRole_Mars_Body;
        Definition.Requirements.Parts.Add(Part);
        return Definition;
    }

    protected FMars_Attack_AnatomyBinding Make_Binding(FGameplayTag InRole, FName InLimbId)
    {
        auto Binding = FMars_Attack_AnatomyBinding();
        Binding.Role = InRole;
        Binding.LimbId = InLimbId;
        Binding.Source = InLimbId.IsNone() ? EMars_Attack_AnatomySource::Body : EMars_Attack_AnatomySource::ProceduralLimb;
        return Binding;
    }

    protected FMars_Attack_RoleObservation Make_HealthyRole(const FMars_Attack_AnatomyBinding& InBinding)
    {
        auto Role = FMars_Attack_RoleObservation();
        Role.Role = InBinding.Role;
        Role.Source = InBinding.Source;
        Role.LimbId = InBinding.LimbId;
        Role.Part.Live = true;
        Role.Part.OwnerMatches = true;
        Role.Limb.Exists = true;
        Role.Limb.Attached = true;
        Role.Limb.Enabled = true;
        Role.Limb.Control = ECk_ProceduralLimbControl_State::Default;
        Role.Limb.Planted = true;
        Role.Limb.Trusted = true;
        return Role;
    }

    protected FMars_Attack_SupportLimbObservation Make_Support(FName InId)
    {
        const auto Role = Make_HealthyRole(Make_Binding(GameplayTags::AttackRole_Mars_Test_SyntheticSupport, InId));
        auto Support = FMars_Attack_SupportLimbObservation();
        Support.LimbId = InId;
        Support.Part = Role.Part;
        Support.Limb = Role.Limb;
        return Support;
    }

    protected FMars_Attack_EvaluationQuery Make_ReadyQuery()
    {
        auto Query = FMars_Attack_EvaluationQuery();
        Query.Entry.Identity.Id = GameplayTags::Attack_Mars_Test_SyntheticBite;
        Query.Entry.Identity.GameRevision = 1;
        Query.Entry.Definition.Prepare.MaxDistance = 100.0f;
        auto Slot = FMars_Attack_ResolvedSlot();
        Slot.Slot = n"Tip";
        Slot.Binding = Make_Binding(GameplayTags::AttackRole_Mars_Test_Jaw, n"Jaw0");
        Query.Entry.Slots.Add(Slot);
        Query.Roles.Add(Make_HealthyRole(Slot.Binding));
        Query.Self.State.Alive = true;
        Query.Self.State.Ready = true;
        Query.Self.State.Grounded = true;
        Query.Self.State.MobilityReady = true;
        Query.Self.State.SupportRegionReady = true;
        Query.Self.WindupClear = true;
        Query.Target.Valid = true;
        Query.Target.Identity = 11;
        Query.Target.Generation = 7;
        Query.Target.Distance = 50.0f;
        return Query;
    }

    protected FMars_Attack_SelectionCandidate Make_Candidate(FGameplayTag InId, int32 InPriority, EMars_Attack_Availability InAvailability)
    {
        auto Candidate = FMars_Attack_SelectionCandidate();
        Candidate.Id = InId;
        Candidate.Priority = InPriority;
        Candidate.Evaluation.AttackId = InId;
        Candidate.Evaluation.Capable = InAvailability != EMars_Attack_Availability::Unavailable;
        Candidate.Evaluation.Availability = InAvailability;
        return Candidate;
    }

    protected bool Has_Diagnostic(const FMars_Attack_ValidationReport& InReport, FName InCode, FString InField) const
    {
        for (const auto& Diagnostic : InReport.Diagnostics)
        {
            if (Diagnostic.Code == InCode && (InField == "" || Diagnostic.Field == InField))
            { return Diagnostic.Expected != "" && Diagnostic.Actual != ""; }
        }
        return false;
    }
}
