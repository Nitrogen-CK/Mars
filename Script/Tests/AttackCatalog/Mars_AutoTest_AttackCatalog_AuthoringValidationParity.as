#if EDITOR
class UMars_AutoTest_AttackCatalog_AuthoringValidationParity : UMars_AutoTestRig_AttackCatalogAuthoring
{
    default _TimeoutSeconds = 30.0f;

    UPROPERTY()
    private UMars_AttackDefinition_Data _CreatureDefinition;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("unsupported anatomy preset has a structured command diagnostic", n"Step_InvalidPreset");
        Add_Step("command and runtime construction report the same malformed prerequisite role", n"Step_BadRole");
        Add_Step("endpoint multi-refinement policy rejects and one-publication control validates", n"Step_EndpointPublicationPolicy");
        Add_Step("negative and nonfinite creature range margins reject through the same production reports", n"Step_CreatureMargins");
        Add_Step("nonfinite copied body bounds reject before creature defaults can be resolved", n"Step_CreatureBounds");
        Add_Step("a derived range smaller than its authored minimum rejects final numeric validation", n"Step_DerivedRange");
        Add_Step("independent default flags preserve literal zero and ignore unused default inputs", n"Step_DefaultFlagIndependence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_EndpointPublicationPolicy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Clip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        _Clips.Add(Clip);
        const auto Built = utils_crawler::Build_ReferenceSwipeClip(FMars_Crawler_ReferenceBody(EMars_Crawler_Layout::Radial, 4), EMars_Crawler_Side::Right, Clip);
        if (Built.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { FinishFailure(f"endpoint policy fixture did not build: {utils_crawler::Get_FirstDiagnosticText(Built)}"); return; }
        auto Definition = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        Definition.Def = utils_attack_authoring::Make_Definition(FMars_AttackAuthoring_DefinitionKey(
            EMars_Crawler_AttackPreset::Crawler4, EMars_AttackReference_Kind::EndpointDemo, GameplayTags::Attack_Mars_SwipeRight), Clip);
        _Definitions.Add(Definition);
        auto Loadout = Cast<UMars_AttackLoadout_Data>(NewObject(this, UMars_AttackLoadout_Data));
        auto Authored = FMars_Attack_Loadout();
        auto Entry = FMars_Attack_Entry(); Entry.Id = GameplayTags::Attack_Mars_Test_PublicationProbe;
        Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Definition); Authored.Entries.Add(Entry);
        Authored.Execution = utils_attack_authoring::Make_Execution(FMars_AttackAuthoring_ExecutionQuery(
            EMars_Crawler_AttackPreset::Crawler4, EMars_AttackReference_Kind::EndpointDemo, Clip, utils_crawler::Get_ClipSeconds(Clip)));
        auto Sampling = Authored.Execution.Tuning.Get_Sampling(); Sampling.Set_MaxSamples(2);
        auto Tuning = Authored.Execution.Tuning; Tuning.Set_Sampling(Sampling); Authored.Execution.Tuning = Tuning;
        Loadout.Spec = Authored; _Loadouts.Add(Loadout);
        auto Spec = utils_crawler::Make_AttackReferenceSpec(EMars_Crawler_AttackPreset::Crawler4);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(Loadout);
        auto Construction = FMars_Crawler_AttackConstruction();
        Definition.Def.Hit.Emitters[0].UseCreatureFrontCenter = true;
        const auto EndpointDefinition = utils_attack::Validate_Definition(Definition.Def);
        const auto EndpointRuntime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
        const auto EndpointCommand = utils_attack_authoring::Get_LoadoutValidation(Loadout.GetPathName(), EMars_Crawler_AttackPreset::Crawler4);
        Assert_True(EndpointDefinition.Get_IsValid() == false &&
            Has_Diagnostic(EndpointDefinition, n"EndpointCreatureCenter", "Hit.Emitters[0].UseCreatureFrontCenter"),
            "a real valid endpoint clip rejects the Body-only creature centre flag at the shared definition boundary");
        Assert_True(EndpointRuntime.Get_IsValid() == false && EndpointCommand.Report.Get_IsValid() == false &&
            Has_Diagnostic(EndpointRuntime, n"EndpointCreatureCenter", "Combat.Loadout.Entries[0].Definition.Hit.Emitters[0].UseCreatureFrontCenter") &&
            Has_Diagnostic(EndpointCommand.Report, n"EndpointCreatureCenter", "Combat.Loadout.Entries[0].Definition.Hit.Emitters[0].UseCreatureFrontCenter"),
            "the runtime and command preserve the exact unsupported endpoint-default diagnostic");
        Definition.Def.Hit.Emitters[0].UseCreatureFrontCenter = false;
        const auto Runtime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
        const auto Command = utils_attack_authoring::Get_LoadoutValidation(Loadout.GetPathName(), EMars_Crawler_AttackPreset::Crawler4);
        Assert_True(Runtime.Get_IsValid() == false && Command.Report.Get_IsValid() == false &&
            Has_Diagnostic(Runtime, n"EndpointPublicationSampling", "Execution.Tuning.Sampling.MaxSamples") &&
            Has_Diagnostic(Command.Report, n"EndpointPublicationSampling", "Execution.Tuning.Sampling.MaxSamples"),
            "both runtime and read-only command reject two refinement samples for physical endpoint emitters");
        Sampling.Set_MaxSamples(1); Tuning.Set_Sampling(Sampling); Authored.Execution.Tuning = Tuning; Loadout.Spec = Authored;
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Construction).Get_IsValid(),
            "the otherwise identical owned endpoint graph validates with one publication sample");
        Assert_True(utils_attack_authoring::Validate_LoadoutPath(Loadout.GetPathName(), EMars_Crawler_AttackPreset::Crawler4),
            "the one-sample control also validates through the read-only command");
    }

    UFUNCTION()
    private void Step_InvalidPreset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The preset is an enum past the console boundary; only the command's text parse can reject a name.
        Assert_True(utils_crawler::TryParse_AttackPreset("Serpent").IsSet() == false, "unsupported preset text parses to nothing before asset or creature composition");
        Assert_True(utils_crawler::TryParse_AttackPreset("crawler4").IsSet() && utils_crawler::TryParse_AttackPreset("crawler4").GetValue() == EMars_Crawler_AttackPreset::Crawler4,
            "preset text parses ignoring case");
        Assert_True(utils_crawler::TryParse_AttackPreset("Spider6").GetValue() == EMars_Crawler_AttackPreset::Spider6, "every supported preset name parses");
    }

    private FMars_Crawler_Spec Make_CreatureDefaultFixture()
    {
        _CreatureDefinition = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        auto Def = Make_Definition(Make_BodyClip());
        Def.Prepare.UseCreatureFrontRange = true;
        Def.Prepare.CreatureFrontRangeMargin = 70.0f;
        Def.Prepare.MaxDistance = 80.0f;
        Def.Hit.Emitters[0].UseCreatureFrontCenter = true;
        Def.Hit.Emitters[0].LocalCenter = FVector::ZeroVector;
        _CreatureDefinition.Def = Def; _Definitions.Add(_CreatureDefinition);
        auto Loadout = Cast<UMars_AttackLoadout_Data>(NewObject(this, UMars_AttackLoadout_Data));
        auto Authored = FMars_Attack_Loadout();
        auto Entry = FMars_Attack_Entry(); Entry.Id = GameplayTags::Attack_Mars_Test_CreatureDefaultsProbe;
        Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(_CreatureDefinition);
        Authored.Entries.Add(Entry); Loadout.Spec = Authored; _Loadouts.Add(Loadout);
        auto Spec = utils_crawler::Make_AttackReferenceSpec(EMars_Crawler_AttackPreset::Crawler4);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(Loadout);
        auto Construction = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Construction).Get_IsValid(), "the unmodified transient creature-default control resolves through production");
        return Spec;
    }

    UFUNCTION()
    private void Step_CreatureMargins(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = Make_CreatureDefaultFixture();
        float32 Infinity = 3.4e38f; Infinity *= 2.0f;
        auto Margins = TArray<float32>();
        Margins.Add(-1.0f); Margins.Add(float32(Math::Sqrt(-1.0))); Margins.Add(Infinity);
        Assert_True(Math::IsFinite(Margins[1]) == false && Math::IsFinite(Margins[2]) == false,
            "the nonfinite margin fixtures actually contain NaN and positive infinity");
        for (const auto Margin : Margins)
        {
            _CreatureDefinition.Def.Prepare.CreatureFrontRangeMargin = Margin;
            const auto Shared = utils_attack::Validate_Definition(_CreatureDefinition.Def);
            auto Construction = FMars_Crawler_AttackConstruction();
            const auto Runtime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
            const auto Command = utils_attack_authoring::Get_LoadoutValidation(Spec.Combat.Loadout.Get().GetPathName(), EMars_Crawler_AttackPreset::Crawler4);
            Assert_True(Shared.Get_IsValid() == false && Has_Diagnostic(Shared, n"NonnegativeFinite", "Prepare.CreatureFrontRangeMargin"),
                "shared validation rejects each malformed active creature range margin explicitly");
            Assert_True(Runtime.Get_IsValid() == false && Command.Report.Get_IsValid() == false &&
                Has_Diagnostic(Runtime, n"NonnegativeFinite", "Combat.Loadout.Entries[0].Definition.Prepare.CreatureFrontRangeMargin") &&
                Has_Diagnostic(Command.Report, n"NonnegativeFinite", "Combat.Loadout.Entries[0].Definition.Prepare.CreatureFrontRangeMargin"),
                "runtime and read-only command preserve the same exact active-margin failure");
        }
        _CreatureDefinition.Def.Prepare.CreatureFrontRangeMargin = 0.0f;
        auto ZeroMargin = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, ZeroMargin).Get_IsValid(), "zero remains a valid nonnegative margin control");
        if (ZeroMargin.Resolved.Entries.Num() == 1)
        { Assert_Equals_Float(ZeroMargin.Resolved.Entries[0].Definition.Prepare.MaxDistance, 40.0f, 0.0001f, "zero margin resolves to the supplied front extent"); }
    }

    UFUNCTION()
    private void Step_CreatureBounds(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = Make_CreatureDefaultFixture();
        float32 Infinity = 3.4e38f; Infinity *= 2.0f;
        auto Values = TArray<float64>(); Values.Add(Math::Sqrt(-1.0)); Values.Add(float64(Infinity));
        for (const auto Value : Values)
        {
            Assert_True(Math::IsFinite(Value) == false, "the supplied body-bound fixture is nonfinite");
            for (int32 Axis = 0; Axis < 3; ++Axis)
            {
                auto Bounds = FVector(40.0, 30.0, 15.0);
                if (Axis == 0) { Bounds.X = Value; }
                else if (Axis == 1) { Bounds.Y = Value; }
                else { Bounds.Z = Value; }
                Spec.Rig.BodyHalfExtents = Bounds;
                auto Construction = FMars_Crawler_AttackConstruction();
                const auto Runtime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
                Assert_True(Runtime.Get_IsValid() == false && Has_Diagnostic(Runtime, n"CreatureBodyBounds", "Entries[0].Rig.BodyHalfExtents"),
                    f"nonfinite body axis {Axis} rejects through the real copied-definition resolver");
                if (Construction.Resolved.Entries.Num() == 1)
                {
                    Assert_True(Construction.Resolved.Entries[0].Definition.Prepare.UseCreatureFrontRange &&
                        Construction.Resolved.Entries[0].Definition.Hit.Emitters[0].UseCreatureFrontCenter,
                        "failed bounds do not masquerade as resolved numeric defaults");
                }
            }
        }
    }

    UFUNCTION()
    private void Step_DerivedRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = Make_CreatureDefaultFixture();
        _CreatureDefinition.Def.Prepare.MinDistance = 111.0f;
        Assert_True(utils_attack::Validate_Definition(_CreatureDefinition.Def).Get_IsValid(),
            "authored active defaults defer the numeric maximum comparison until creature geometry is supplied");
        auto Construction = FMars_Crawler_AttackConstruction();
        const auto Runtime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
        const auto Command = utils_attack_authoring::Get_LoadoutValidation(Spec.Combat.Loadout.Get().GetPathName(), EMars_Crawler_AttackPreset::Crawler4);
        Assert_True(Runtime.Get_IsValid() == false && Command.Report.Get_IsValid() == false &&
            Has_Diagnostic(Runtime, n"RangeBounds", "Entries[0].Definition.Prepare") &&
            Has_Diagnostic(Command.Report, n"RangeBounds", "Entries[0].Definition.Prepare"),
            "derived maximum 110 below authored minimum 111 rejects final runtime and command numeric validation");
        if (Construction.Resolved.Entries.Num() != 1) { return; }
        Assert_Equals_Float(Construction.Resolved.Entries[0].Definition.Prepare.MaxDistance, 110.0f, 0.0001f,
            "failure describes the actual derived maximum rather than the unused authored placeholder 80");
        Assert_True(Construction.Resolved.Entries[0].Definition.Prepare.UseCreatureFrontRange == false,
            "the RangeBounds rejection comes from the completed numeric validation stage");
    }

    UFUNCTION()
    private void Step_DefaultFlagIndependence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = Make_CreatureDefaultFixture();
        _CreatureDefinition.Def.Prepare.UseCreatureFrontRange = false;
        _CreatureDefinition.Def.Prepare.CreatureFrontRangeMargin = float32(Math::Sqrt(-1.0));
        _CreatureDefinition.Def.Hit.Emitters[0].UseCreatureFrontCenter = false;
        // An inactive default policy never reads its inputs. No entity is constructed with these synthetic bounds.
        Spec.Rig.BodyHalfExtents.X = Math::Sqrt(-1.0);
        auto Literal = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Literal).Get_IsValid(),
            "both false flags preserve literal values despite unusable, inactive derivation inputs");
        if (Literal.Resolved.Entries.Num() != 1) { return; }
        Assert_True(Literal.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector::ZeroVector,
            "false Body default flag keeps literal zero instead of a default sentinel");
        Assert_Equals_Float(Literal.Resolved.Entries[0].Definition.Prepare.MaxDistance, 80.0f, 0.0001f, "false range flag keeps literal maximum 80");
        Spec.Rig.BodyHalfExtents = FVector(40.0, 30.0, 15.0);
        _CreatureDefinition.Def.Hit.Emitters[0].UseCreatureFrontCenter = true;
        auto CenterOnly = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, CenterOnly).Get_IsValid(), "Body-only derivation ignores the disabled nonfinite range margin");
        if (CenterOnly.Resolved.Entries.Num() != 1) { return; }
        Assert_True(CenterOnly.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector(40.0, 0.0, 0.0) &&
            CenterOnly.Resolved.Entries[0].Definition.Prepare.MaxDistance == 80.0f, "Body flag resolves the centre independently of the literal range");
        _CreatureDefinition.Def.Hit.Emitters[0].UseCreatureFrontCenter = false;
        _CreatureDefinition.Def.Prepare.UseCreatureFrontRange = true;
        _CreatureDefinition.Def.Prepare.CreatureFrontRangeMargin = 70.0f;
        auto RangeOnly = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, RangeOnly).Get_IsValid(), "range-only derivation preserves the disabled Body centre policy");
        if (RangeOnly.Resolved.Entries.Num() != 1) { return; }
        Assert_True(RangeOnly.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector::ZeroVector &&
            RangeOnly.Resolved.Entries[0].Definition.Prepare.MaxDistance == 110.0f, "range flag resolves maximum independently of literal zero centre");
    }

    UFUNCTION()
    private void Step_BadRole(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Definition = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        auto Def = Make_Definition(Make_BodyClip());
        Def.Requirements.Parts[0].Role = GameplayTags::AttackRole_Mars_Test_MissingBrace;
        Definition.Def = Def;
        _Definitions.Add(Definition);
        auto Loadout = Cast<UMars_AttackLoadout_Data>(NewObject(this, UMars_AttackLoadout_Data));
        auto Entry = FMars_Attack_Entry(); Entry.Id = GameplayTags::Attack_Mars_Test_AuthoredProbe; Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Definition);
        auto Authored = FMars_Attack_Loadout(); Authored.Entries.Add(Entry); Loadout.Spec = Authored; _Loadouts.Add(Loadout);
        auto Spec = utils_crawler::Make_AttackReferenceSpec(EMars_Crawler_AttackPreset::Crawler4);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(Loadout);
        auto Construction = FMars_Crawler_AttackConstruction();
        const auto Runtime = utils_crawler::Resolve_AttackLoadout(Spec, Construction);
        const auto Command = utils_attack_authoring::Get_LoadoutValidation(Loadout.GetPathName(), EMars_Crawler_AttackPreset::Crawler4);
        Assert_True(Runtime.Get_IsValid() == false && Command.Report.Get_IsValid() == false,
            "the malformed authored role rejects in both command and runtime resolver");
        Assert_True(Has_Diagnostic(Runtime, n"RoleUnbound", "Entries[0].Parts[0].Binding") &&
            Has_Diagnostic(Command.Report, n"RoleUnbound", "Entries[0].Parts[0].Binding"), "both surfaces retain the same exact role-binding failure");
        Assert_True(Command.Construction.Resolved.Entries.Num() == 1 &&
            Command.Construction.Resolved.Entries[0].Definition.Requirements.Parts.Num() == 1 &&
            Command.Construction.Resolved.Entries[0].Definition.Requirements.Parts[0].Role == GameplayTags::AttackRole_Mars_Test_MissingBrace,
            "command diagnostic context retains the authored failing role identity");
        Assert_True(utils_attack_authoring::Validate_LoadoutPath(Loadout.GetPathName(), EMars_Crawler_AttackPreset::Crawler4) == false,
            "the command prints this runtime construction diagnostic without saving the transient fixture");
        // This checks schema/role resolution, not a claim that an asset validator observes live severance state.
    }
}
#endif
