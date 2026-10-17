#if EDITOR
// Read-only prerequisite: run native Ck.Mars.AttackCatalog.EditorSeedReferenceGraphs outside PIE first.
class UMars_AutoTest_AttackCatalog_ShippedReferenceGraphs : UMars_AutoTestRig_AttackCatalogAuthoring
{
    default _TimeoutSeconds = 90.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("D03 all six shipped graphs compile and resolve through the runtime and command surfaces", n"Step_Graphs");
        Add_Step("D03 new clip preview subjects survive loading and a later GC without metadata writes", n"Step_Previews");
        Add_Step("per-creature geometry copies preserve source values and frozen pins through GC", n"Step_PrivateCopies");
        Add_Step("literal zero centre and authored range remain literal when default policies are false", n"Step_LiteralGeometry");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_LiteralGeometry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Definition = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        auto Def = Make_Definition(Make_BodyClip());
        Def.Prepare.UseCreatureFrontRange = false; Def.Prepare.MaxDistance = 80.0f;
        Def.Hit.Emitters[0].UseCreatureFrontCenter = false; Def.Hit.Emitters[0].LocalCenter = FVector::ZeroVector;
        Definition.Def = Def; _Definitions.Add(Definition);
        auto Loadout = Cast<UMars_AttackLoadout_Data>(NewObject(this, UMars_AttackLoadout_Data));
        auto Authored = FMars_Attack_Loadout();
        auto Entry = FMars_Attack_Entry(); Entry.Id = GameplayTags::Attack_Mars_Test_LiteralBody; Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Definition);
        Authored.Entries.Add(Entry); Loadout.Spec = Authored; _Loadouts.Add(Loadout);
        auto Spec = utils_crawler::Make_AttackReferenceSpec(EMars_Crawler_AttackPreset::Crawler4);
        Spec.Rig.BodyHalfExtents.X = 97.0; Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(Loadout);
        auto Construction = FMars_Crawler_AttackConstruction();
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Construction).Get_IsValid(), "literal geometry fixture resolves");
        if (Construction.Resolved.Entries.Num() != 1 || Construction.Resolved.Entries[0].Definition.Hit.Emitters.Num() != 1) { return; }
        Assert_True(Construction.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector::ZeroVector,
            "a literal zero Body centre remains zero instead of becoming the front face");
        Assert_Equals_Float(Construction.Resolved.Entries[0].Definition.Prepare.MaxDistance, 80.0f, 0.0001f,
            "false derivation flag retains the explicitly authored range");
    }

    UFUNCTION()
    private void Step_Graphs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (Capture_LegacyValues() == false) { return; }
        for (const auto Preset : Get_Presets())
        {
            for (int32 Demo = 0; Demo < 2; ++Demo)
            {
                const auto Endpoint = Demo == 1;
                const auto Path = utils_crawler::Get_AttackReferenceLoadoutPath(Preset, Endpoint);
                const auto Loaded = System::LoadAsset_Blocking(utils_crawler::Get_AttackReferenceLoadout(Preset, Endpoint));
                Assert_True(ck::IsValid(Loaded), f"native bootstrap prerequisite loads read-only: {Path}");
                const auto Result = utils_attack_authoring::Get_LoadoutValidation(Path, Preset);
                Assert_True(Result.Report.Get_IsValid(), f"command report validates {Path}: {utils_crawler::Get_AttackValidationText(Result.Report)}");
                Assert_True(utils_attack_authoring::Validate_LoadoutPath(Path, Preset), "read-only command reports the same valid graph");
                _ValidatedGraphs.Add(Result);
                Assert_Equals_Int(Result.Construction.Resolved.Entries.Num(), Endpoint ? 4 : 2, "reference loadout enables exactly its approved entries");
                Assert_True(utils_attack::Validate_ResolvedLoadout(Result.Construction.Resolved).Get_IsValid(), "the same resolved graph passes final runtime validation");
                const auto Selection = Result.Construction.Resolved.Selection;
                Assert_True(Selection.TemporaryReadiness == (Endpoint ? EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative :
                    EMars_Attack_TemporaryReadinessPolicy::WaitPreferred), "reference selection policy matches parity/demo intent");
                if (Endpoint)
                {
                    const auto Sampling = Result.Construction.Resolved.Execution.Tuning.Get_Sampling();
                    Assert_Equals_Int(Sampling.Get_MaxSamples(), 1, "endpoint graph uses one qualified physical-publication sample");
                    Assert_Equals_Float(Sampling.Get_MaxSegmentAngularStepDegrees(), 180.0f, 0.0001f,
                        "native joint allowance preserves legacy swivel admission independently of sphere geometry");
                    Assert_Equals_Float(Sampling.Get_MaxEndpointTravelCm(), 16.0f, 0.0001f, "native endpoint travel remains 16 cm");
                    Assert_Equals_Float(float32(Sampling.Get_MaxAdvance().Get_Seconds()), 1.0f / 60.0f, 0.000001f,
                        "endpoint graph caps requested advance at 1/60 s");
                }
                for (const auto& Entry : Result.Construction.Resolved.Entries)
                {
                    auto Source = Entry.SourceClip.Get(); auto Frozen = Entry.Definition.Clip.Get();
                    Assert_True(ck::IsValid(Source) && ck::IsValid(Frozen) && Source != Frozen, "every entry pins an independent public-built frozen clip");
                    if (ck::IsValid(Frozen))
                    { Assert_True(utils_procedural_action::Validate_Data(Frozen).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "frozen clip compiles through the native public validator"); }
                    Assert_True(Entry.Definition.Prepare.UseCreatureFrontRange == false, "runtime range defaults have been fully resolved");
                    for (const auto& Emitter : Entry.Definition.Hit.Emitters)
                    { Assert_True(Emitter.UseCreatureFrontCenter == false, "runtime centre defaults have been fully resolved"); }
                }
            }
        }
        Assert_Equals_Int(_ValidatedGraphs.Num(), 6, "all three rigs have both shipped graph variants");
        Assert_LegacyValuesUnchanged();
    }

    UFUNCTION()
    private void Step_PrivateCopies(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Source = System::LoadAsset_Blocking(utils_crawler::Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset::Crawler4, false));
        Assert_True(ck::IsValid(Source), "the shipped parity loadout is loaded");
        if (ck::Is_NOT_Valid(Source)) { return; }
        _Loadouts.Add(Source);
        if (Source.Spec.Entries.Num() != 2)
        { FinishFailure("parity reference must contain exactly two entries before geometry assertions"); return; }
        auto Definition = Source.Spec.Entries[0].Definition.Get();
        Assert_True(ck::IsValid(Definition), "the parity definition is loaded");
        if (ck::Is_NOT_Valid(Definition)) { return; }
        _Definitions.Add(Definition);
        const auto Before = Definition.Def;
        if (Before.Hit.Emitters.Num() != 1)
        { FinishFailure("parity reference must contain exactly one Body emitter before geometry assertions"); return; }
        Assert_True(Before.Prepare.UseCreatureFrontRange && Before.Hit.Emitters[0].UseCreatureFrontCenter,
            "owned parity reference explicitly requests per-creature front geometry");
        auto Spec = utils_crawler::Make_AttackReferenceSpec(EMars_Crawler_AttackPreset::Crawler4);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(Source);
        auto Small = FMars_Crawler_AttackConstruction(); auto Large = FMars_Crawler_AttackConstruction();
        Spec.Rig.BodyHalfExtents.X = 40.0;
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Small).Get_IsValid(), "first creature resolves its copied geometry");
        Spec.Rig.BodyHalfExtents.X = 97.0;
        Assert_True(utils_crawler::Resolve_AttackLoadout(Spec, Large).Get_IsValid(), "second creature resolves an independently supplied body half length");
        if (Small.Resolved.Entries.Num() != 2 || Large.Resolved.Entries.Num() != 2 ||
            Small.Resolved.Entries[0].Definition.Hit.Emitters.Num() != 1 || Large.Resolved.Entries[0].Definition.Hit.Emitters.Num() != 1)
        { FinishFailure("resolved parity geometry shape differs; stop indexed assertions"); return; }
        Assert_Equals_Float(Small.Resolved.Entries[0].Definition.Prepare.MaxDistance, 110.0f, 0.0001f, "small creature derives half length + 70");
        Assert_Equals_Float(Large.Resolved.Entries[0].Definition.Prepare.MaxDistance, 167.0f, 0.0001f, "larger creature derives its own half length + 70");
        Assert_True(Small.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector(40.0, 0.0, 0.0) &&
            Large.Resolved.Entries[0].Definition.Hit.Emitters[0].LocalCenter == FVector(97.0, 0.0, 0.0), "shared definition yields distinct per-creature centres");
        Assert_True(Definition.Def.Prepare.UseCreatureFrontRange == Before.Prepare.UseCreatureFrontRange &&
            Definition.Def.Prepare.MaxDistance == Before.Prepare.MaxDistance && Definition.Def.Hit.Emitters[0].UseCreatureFrontCenter == Before.Hit.Emitters[0].UseCreatureFrontCenter &&
            Definition.Def.Hit.Emitters[0].LocalCenter == Before.Hit.Emitters[0].LocalCenter, "source definition flags and numeric geometry remain unchanged");
        auto Pin = FMars_AttackAuthoring_ValidationResult(); Pin.Construction = Small; _ValidatedGraphs.Add(Pin);
        Pin.Construction = Large; _ValidatedGraphs.Add(Pin);
        System::CollectGarbage();
        for (const auto& Graph : _ValidatedGraphs)
        {
            for (const auto& Entry : Graph.Construction.Resolved.Entries)
            { Assert_True(ck::IsValid(Entry.SourceClip.Get()) && ck::IsValid(Entry.Definition.Clip.Get()), "test-owned construction pins source and frozen graph objects through GC"); }
        }
        Assert_LegacyValuesUnchanged();
        Print("[AttackCatalog.D03] 40/97 geometry fixture supplies dimensions; actual mesh sizing is a separate EntityScript acceptance gate");
    }

    UFUNCTION()
    private void Step_Previews(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto Preset : Get_Presets())
        { Assert_Preview(Preset, GameplayTags::Attack_Mars_Pincer); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeRight); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeLeft); }
        System::CollectGarbage();
        for (const auto Preset : Get_Presets())
        { Assert_Preview(Preset, GameplayTags::Attack_Mars_Pincer); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeRight); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeLeft); }
        Assert_LegacyValuesUnchanged();
    }
}
#endif
