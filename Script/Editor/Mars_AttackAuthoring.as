#if EDITOR
UFUNCTION()
void Mars_AttackValidateLoadoutFunc(const TArray<FString>& Args)
{
    if (Args.Num() != 2)
    {
        LogDisplay("[Mars.Attack.ValidateLoadout] Expected <LoadoutObjectPath> <Crawler4|Crawler6|Spider6>");
        return;
    }
    const auto Preset = utils_crawler::TryParse_AttackPreset(Args[1]);
    if (Preset.IsSet() == false)
    {
        LogDisplay(f"[Mars.Attack.ValidateLoadout] code=AnatomyPresetUnsupported expected=Crawler4/Crawler6/Spider6 actual={Args[1]}");
        return;
    }
    utils_attack_authoring::Validate_LoadoutPath(Args[0], Preset.GetValue());
}
const FConsoleCommand Mars_AttackValidateLoadoutCommand("Mars.Attack.ValidateLoadout", n"Mars_AttackValidateLoadoutFunc");

UFUNCTION()
void Mars_AttackSeedReferenceLoadoutsFunc(const TArray<FString>& Args)
{
    if (Args.Num() != 0)
    {
        LogDisplay("[Mars.Attack.SeedReferenceLoadouts] This command takes no arguments");
        return;
    }
    utils_attack_authoring::Seed_ReferenceLoadouts();
}
const FConsoleCommand Mars_AttackSeedReferenceLoadoutsCommand("Mars.Attack.SeedReferenceLoadouts", n"Mars_AttackSeedReferenceLoadoutsFunc");

// Strong references exist only in this editor operation, never in an ECS fragment. Existing objects are read-only.
struct FMars_AttackAuthoring_ClipPlan
{
    FString Path;
    EMars_Crawler_AttackPreset Preset = EMars_Crawler_AttackPreset::Crawler4;
    FGameplayTag Kind;
    bool Existed = false;
    UCk_ProceduralAction_Data Asset;
}
struct FMars_AttackAuthoring_DefinitionPlan
{
    FString Path;
    FString ClipPath;
    bool Existed = false;
    UMars_AttackDefinition_Data Asset;
}
struct FMars_AttackAuthoring_LoadoutPlan
{
    FString Path;
    EMars_Crawler_AttackPreset Preset = EMars_Crawler_AttackPreset::Crawler4;
    bool Existed = false;
    UMars_AttackLoadout_Data Asset;
    FMars_Crawler_AttackConstruction Construction;
}
struct FMars_AttackAuthoring_Preflight
{
    TArray<FMars_AttackAuthoring_ClipPlan> Clips;
    TArray<FMars_AttackAuthoring_DefinitionPlan> Definitions;
    TArray<FMars_AttackAuthoring_LoadoutPlan> Loadouts;
    TArray<UCk_ProceduralAction_Data> Dependencies;
}
struct FMars_AttackAuthoring_ValidationResult
{
    FString Path;
    EMars_Crawler_AttackPreset Preset = EMars_Crawler_AttackPreset::Crawler4;
    FMars_Attack_ValidationReport Report;
    FMars_Crawler_AttackConstruction Construction;
}
enum EMars_AttackAuthoring_AssetKind { Clip, Definition, Loadout }

struct FMars_AttackAuthoring_SeedReport
{
    bool PreflightValid = false;
    bool Completed = false;
    FString FailureStage;
    int32 CreatedClips = 0;
    int32 CreatedDefinitions = 0;
    int32 CreatedLoadouts = 0;
    int32 SkippedClips = 0;
    int32 SkippedDefinitions = 0;
    int32 SkippedLoadouts = 0;
    int32 SaveCalls = 0;
    TArray<FString> CreatedPaths;
    TArray<FString> SkippedPaths;
}

namespace utils_attack_authoring
{
    void Print_Report(FString InPath, EMars_Crawler_AttackPreset InPreset, const FMars_Attack_ValidationReport& InReport,
        const FMars_Crawler_AttackConstruction& InConstruction)
    {
        LogDisplay(f"[Mars.Attack.ValidateLoadout] path={InPath} preset={InPreset :n} geometry=preset-box-only result={InReport.Get_IsValid()}");
        for (const auto& Entry : InConstruction.Resolved.Entries)
        {
            LogDisplay(f"[Mars.Attack.ValidateLoadout] entry={Entry.Identity.Id.ToString()} definition={Entry.Identity.DefinitionPath.ToString()}");
            for (const auto& Slot : Entry.Slots)
            { LogDisplay(f"[Mars.Attack.ValidateLoadout] entry={Entry.Identity.Id.ToString()} role={Slot.Binding.Role.ToString()} slot={Slot.Slot} limb={Slot.Binding.LimbId}"); }
            for (const auto& Part : Entry.Parts)
            { LogDisplay(f"[Mars.Attack.ValidateLoadout] entry={Entry.Identity.Id.ToString()} role={Part.Binding.Role.ToString()} prerequisite=true limb={Part.Binding.LimbId}"); }
        }
        for (const auto& Diagnostic : InReport.Diagnostics)
        {
            auto EntryId = FGameplayTag();
            auto Role = FGameplayTag();
            auto SlotId = NAME_None;
            auto Definition = FMars_Attack_Definition();
            // Raw graph diagnostics use original entry indices (including disabled entries); resolved diagnostics use
            // enabled runtime indices. The identity mapping must respect that distinction.
            if (Diagnostic.Field.StartsWith("Combat.Loadout.") && ck::IsValid(InConstruction.Loadout))
            {
                const auto Entries = InConstruction.Loadout.Spec.Entries;
                for (int32 Index = 0; Index < Entries.Num(); ++Index)
                {
                    if (Diagnostic.Field.Contains(f"Entries[{Index}]") == false) { continue; }
                    EntryId = Entries[Index].Id;
                    const auto Asset = Entries[Index].Definition.Get();
                    if (ck::IsValid(Asset)) { Definition = Asset.Def; }
                    break;
                }
            }
            else
            {
                for (int32 Index = 0; Index < InConstruction.Resolved.Entries.Num(); ++Index)
                {
                    if (Diagnostic.Field.Contains(f"Entries[{Index}]") == false) { continue; }
                    EntryId = InConstruction.Resolved.Entries[Index].Identity.Id;
                    Definition = InConstruction.Resolved.Entries[Index].Definition;
                    break;
                }
            }
            for (int32 Index = 0; Index < Definition.Requirements.Slots.Num(); ++Index)
            {
                if (Diagnostic.Field.Contains(f"Slots[{Index}]") == false) { continue; }
                Role = Definition.Requirements.Slots[Index].Role;
                SlotId = Definition.Requirements.Slots[Index].Slot;
                break;
            }
            for (int32 Index = 0; Index < Definition.Requirements.Parts.Num(); ++Index)
            {
                if (Diagnostic.Field.Contains(f"Parts[{Index}]") == false) { continue; }
                Role = Definition.Requirements.Parts[Index].Role;
                break;
            }
            LogDisplay(f"[Mars.Attack.ValidateLoadout] path={InPath} entry={EntryId.ToString()} role={Role.ToString()} slot={SlotId} code={Diagnostic.Code} field={Diagnostic.Field} expected={Diagnostic.Expected} actual={Diagnostic.Actual}");
        }
        if (InReport.Truncated)
        { LogDisplay("[Mars.Attack.ValidateLoadout] validation diagnostics truncated at the shared bounded limit"); }
    }

    bool Resolve_ForPreset(UMars_AttackLoadout_Data InLoadout, EMars_Crawler_AttackPreset InPreset, FMars_Crawler_AttackConstruction& OutConstruction)
    {
        auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(InLoadout);
        const auto Report = utils_crawler::Resolve_AttackLoadout(Spec, OutConstruction);
        Print_Report(ck::IsValid(InLoadout) ? InLoadout.GetPathName() : "null", InPreset, Report, OutConstruction);
        return Report.Get_IsValid();
    }

    // Loads and freezes through the runtime resolver; no editor data accessor, mutation or save is used here.
    FMars_AttackAuthoring_ValidationResult Get_LoadoutValidation(FString InPath, EMars_Crawler_AttackPreset InPreset)
    {
        auto Result = FMars_AttackAuthoring_ValidationResult();
        Result.Path = InPath;
        Result.Preset = InPreset;
        if (FSoftObjectPath(InPath).IsValid() == false)
        {
            utils_attack::Add_Check(Result.Report, false, utils_attack::Make_Diagnostic(n"LoadoutPathInvalid", "LoadoutPath",
                FMars_Attack_Comparison("valid object path", InPath)));
            return Result;
        }
        auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(FSoftObjectPath(InPath));
        Result.Report = utils_crawler::Resolve_AttackLoadout(Spec, Result.Construction);
        return Result;
    }

    bool Validate_LoadoutPath(FString InPath, EMars_Crawler_AttackPreset InPreset)
    {
        const auto Result = Get_LoadoutValidation(InPath, InPreset);
        Print_Report(InPath, InPreset, Result.Report, Result.Construction);
        return Result.Report.Get_IsValid();
    }

    int32 Find_ClipPlan(const FMars_AttackAuthoring_Preflight& InPlan, FString InPath)
    {
        for (int32 Index = 0; Index < InPlan.Clips.Num(); ++Index)
        { if (InPlan.Clips[Index].Path == InPath) { return Index; } }
        return -1;
    }
    int32 Find_DefinitionPlan(const FMars_AttackAuthoring_Preflight& InPlan, FString InPath)
    {
        for (int32 Index = 0; Index < InPlan.Definitions.Num(); ++Index)
        { if (InPlan.Definitions[Index].Path == InPath) { return Index; } }
        return -1;
    }

    UCk_ProceduralAction_Data Load_LegacyClip(EMars_Crawler_AttackPreset InPreset, FGameplayTag InId, FMars_AttackAuthoring_Preflight& InOutPlan)
    {
        const auto Path = utils_crawler::Get_AttackReferenceLegacyClipPath(InPreset, InId);
        auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Path)));
        if (ck::Is_NOT_Valid(Clip))
        { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=LegacyDependencyMissing path={Path}; existing assets are never reseeded"); return nullptr; }
        InOutPlan.Dependencies.Add(Clip);
        return Clip;
    }

    UCk_ProceduralAction_Data Plan_Clip(EMars_Crawler_AttackPreset InPreset, FGameplayTag InId, FMars_AttackAuthoring_Preflight& InOutPlan)
    {
        const auto Path = utils_crawler::Get_AttackReferenceEndpointClipPath(InPreset, InId);
        const auto Found = Find_ClipPlan(InOutPlan, Path);
        if (Found >= 0)
        { return InOutPlan.Clips[Found].Asset; }
        auto Plan = FMars_AttackAuthoring_ClipPlan();
        Plan.Path = Path;
        Plan.Preset = InPreset;
        Plan.Kind = InId;
        Plan.Existed = EditorAsset::DoesAssetExist(Path);
        if (Plan.Existed)
        {
            Plan.Asset = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Path)));
            LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] existing clip skipped: {Path}");
        }
        else
        {
            const auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
            Plan.Asset = Cast<UCk_ProceduralAction_Data>(NewObject(GetTransientPackage(), UCk_ProceduralAction_Data));
            auto Report = FCk_ProceduralAction_ValidationReport();
            if (InId == GameplayTags::Attack_Mars_Pincer)
            {
                auto Source = Load_LegacyClip(InPreset, GameplayTags::Attack_Mars_Pincer, InOutPlan);
                if (ck::Is_NOT_Valid(Source))
                { return nullptr; }
                Report = utils_crawler::Build_ReferenceEndpointPincerClip(Spec.Layout, Spec.LegCount, Source, Plan.Asset);
            }
            else
            { Report = utils_crawler::Build_ReferenceSwipeClip(Spec.Layout, Spec.LegCount, InId == GameplayTags::Attack_Mars_SwipeRight, Plan.Asset); }
            if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
            { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] preflight clip failed: {Path} {utils_crawler::Get_FirstDiagnosticText(Report)}"); return nullptr; }
        }
        if (ck::Is_NOT_Valid(Plan.Asset))
        { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=ClipClassMismatch path={Path}"); return nullptr; }
        InOutPlan.Clips.Add(Plan);
        return Plan.Asset;
    }

    FMars_Attack_Definition Make_Definition(EMars_Crawler_AttackPreset InPreset, FGameplayTag InId, bool InEndpointDemo, UCk_ProceduralAction_Data InClip)
    {
        auto Def = FMars_Attack_Definition();
        Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(InClip);
        Def.Hit.DamageType = GameplayTags::DamageType_Mars_Blunt;
        Def.Hit.Damage = 15.0f;
        Def.CueProfile = utils_crawler::Get_AttackReferenceCueProfile(InId);
        Def.Prepare.FacingToleranceDegrees = 10.0f;
        Def.Prepare.MaxHeightDifference = 60.0f;
        Def.Cooldown.RecoverySeconds = 0.70f;
        Def.Cooldown.ReuseSeconds = InEndpointDemo && InId != GameplayTags::Attack_Mars_Jab ? 0.80f : 0.0f;
        if (InEndpointDemo && InId != GameplayTags::Attack_Mars_Jab)
        { Def.Prepare.MaxDistance = 190.0f; }
        else
        {
            Def.Prepare.UseCreatureFrontRange = true;
            Def.Prepare.CreatureFrontRangeMargin = 70.0f;
        }
        if (InId != GameplayTags::Attack_Mars_Jab)
        {
            if (InId == GameplayTags::Attack_Mars_Pincer || InId == GameplayTags::Attack_Mars_SwipeRight)
            {
                auto Slot = FMars_Attack_SlotRole(); Slot.Slot = n"ClawRight"; Slot.Role = GameplayTags::AttackRole_Mars_FrontRight;
                Def.Requirements.Slots.Add(Slot);
            }
            if (InId == GameplayTags::Attack_Mars_Pincer || InId == GameplayTags::Attack_Mars_SwipeLeft)
            {
                auto Slot = FMars_Attack_SlotRole(); Slot.Slot = n"ClawLeft"; Slot.Role = GameplayTags::AttackRole_Mars_FrontLeft;
                Def.Requirements.Slots.Add(Slot);
            }
        }
        if (InEndpointDemo && InId != GameplayTags::Attack_Mars_Jab)
        {
            for (const auto& Slot : Def.Requirements.Slots)
            {
                auto Emitter = FMars_Attack_Emitter();
                Emitter.Id = utils_crawler::Get_AttackReferenceClawEmitter(Slot.Slot);
                Emitter.Source = EMars_Attack_EmitterSource::LimbEndpoint;
                Emitter.Slot = Slot.Slot;
                Emitter.DamageWindow = n"Damage";
                Emitter.ObstructionWindow = n"ClawSweep";
                Emitter.Radius = 12.0f;
                Emitter.MaxSampleTravel = 16.0f;
                Def.Hit.Emitters.Add(Emitter);
            }
        }
        else
        {
            auto Emitter = FMars_Attack_Emitter();
            Emitter.Id = GameplayTags::AttackEmitter_Mars_Body;
            Emitter.UseCreatureFrontCenter = true;
            const auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
            Emitter.MaxSampleTravel = FMars_Crawler_AttackHit().MaxSampleTravel * utils_crawler::Get_LayoutSizeScale(Spec.Layout);
            Def.Hit.Emitters.Add(Emitter);
        }
        return Def;
    }

    UMars_AttackDefinition_Data Plan_Definition(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo, FGameplayTag InId, FMars_AttackAuthoring_Preflight& InOutPlan)
    {
        auto Plan = FMars_AttackAuthoring_DefinitionPlan();
        Plan.Path = utils_crawler::Get_AttackReferenceDefinitionPath(InPreset, InEndpointDemo, InId);
        Plan.Existed = EditorAsset::DoesAssetExist(Plan.Path);
        if (Plan.Existed)
        {
            Plan.Asset = System::LoadAsset_Blocking(TSoftObjectPtr<UMars_AttackDefinition_Data>(FSoftObjectPath(Plan.Path)));
            LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] existing definition skipped: {Plan.Path}");
            if (ck::IsValid(Plan.Asset))
            { InOutPlan.Dependencies.Add(System::LoadAsset_Blocking(Plan.Asset.Def.Clip)); }
        }
        else
        {
            auto Clip = InEndpointDemo && InId != GameplayTags::Attack_Mars_Jab ? Plan_Clip(InPreset, InId, InOutPlan) : Load_LegacyClip(InPreset, InId, InOutPlan);
            if (ck::Is_NOT_Valid(Clip))
            { return nullptr; }
            Plan.ClipPath = InEndpointDemo && InId != GameplayTags::Attack_Mars_Jab ? utils_crawler::Get_AttackReferenceEndpointClipPath(InPreset, InId) :
                utils_crawler::Get_AttackReferenceLegacyClipPath(InPreset, InId);
            Plan.Asset = Cast<UMars_AttackDefinition_Data>(NewObject(GetTransientPackage(), UMars_AttackDefinition_Data));
            Plan.Asset.Def = Make_Definition(InPreset, InId, InEndpointDemo, Clip);
        }
        if (ck::Is_NOT_Valid(Plan.Asset))
        { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=DefinitionClassMismatch path={Plan.Path}"); return nullptr; }
        InOutPlan.Definitions.Add(Plan);
        return Plan.Asset;
    }

    FMars_Attack_ExecutionPolicy Make_Execution(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo, UCk_ProceduralAction_Data InPincer, float64 InLongestClip)
    {
        auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
        Spec.Combat.PincerClip = TSoftObjectPtr<UCk_ProceduralAction_Data>(InPincer);
        Spec.Combat.Hit.MaxSampleTravel *= utils_crawler::Get_LayoutSizeScale(Spec.Layout);
        auto Execution = FMars_Attack_ExecutionPolicy();
        Execution.Tuning = utils_crawler::Make_AttackTuning(Spec);
        Execution.Locomotion = utils_crawler::Make_PincerLocomotion(Spec);
        auto Support = Execution.Locomotion.Get_Support();
        // Exact legacy resolver parity: longest enabled clip plus the original cancellation duration (0.15 s).
        Support.Set_SupportHoldTimeout(FCk_Time(InEndpointDemo ? 6.0 : InLongestClip + float64(Spec.Combat.Timing.CancelSeconds)));
        auto Locomotion = Execution.Locomotion;
        Locomotion.Set_Support(Support);
        Execution.Locomotion = Locomotion;
        if (InEndpointDemo)
        {
            auto Sampling = Execution.Tuning.Get_Sampling();
            Sampling.Set_MaxAdvance(FCk_Time(1.0 / 60.0));
            Sampling.Set_MaxEndpointTravelCm(16.0f);
            // Preserve the legacy native joint swivel allowance. Zero-offset sphere geometry still uses the
            // independently checked 16 cm chord between physically accepted endpoint positions.
            Sampling.Set_MaxSegmentAngularStepDegrees(180.0f);
            // Refinement predictions are not additional physical publications. One sample makes native
            // settled-motion validation compare against the previous accepted physical pose.
            Sampling.Set_MaxSamples(1);
            auto Tuning = Execution.Tuning;
            Tuning.Set_Sampling(Sampling);
            Execution.Tuning = Tuning;
        }
        return Execution;
    }

    bool Plan_Loadout(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo, FMars_AttackAuthoring_Preflight& InOutPlan)
    {
        auto Plan = FMars_AttackAuthoring_LoadoutPlan();
        Plan.Path = utils_crawler::Get_AttackReferenceLoadoutPath(InPreset, InEndpointDemo);
        Plan.Preset = InPreset;
        Plan.Existed = EditorAsset::DoesAssetExist(Plan.Path);
        if (Plan.Existed)
        {
            Plan.Asset = System::LoadAsset_Blocking(TSoftObjectPtr<UMars_AttackLoadout_Data>(FSoftObjectPath(Plan.Path)));
            LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] existing loadout and its graph skipped: {Plan.Path}");
        }
        else
        {
            Plan.Asset = Cast<UMars_AttackLoadout_Data>(NewObject(GetTransientPackage(), UMars_AttackLoadout_Data));
            auto Ids = TArray<FGameplayTag>(); Ids.Add(GameplayTags::Attack_Mars_Pincer);
            if (InEndpointDemo) { Ids.Add(GameplayTags::Attack_Mars_SwipeRight); Ids.Add(GameplayTags::Attack_Mars_SwipeLeft); }
            Ids.Add(GameplayTags::Attack_Mars_Jab);
            auto Loadout = FMars_Attack_Loadout();
            UCk_ProceduralAction_Data Pincer;
            float64 LongestClip = 0.0;
            for (const auto Id : Ids)
            {
                auto Definition = Plan_Definition(InPreset, InEndpointDemo, Id, InOutPlan);
                if (ck::Is_NOT_Valid(Definition))
                { return false; }
                const auto DefinitionReport = utils_attack::Validate_Definition(Definition.Def);
                if (DefinitionReport.Get_IsValid() == false)
                { Print_Report(utils_crawler::Get_AttackReferenceDefinitionPath(InPreset, InEndpointDemo, Id), InPreset, DefinitionReport, FMars_Crawler_AttackConstruction()); return false; }
                if (Id == GameplayTags::Attack_Mars_Pincer) { Pincer = Definition.Def.Clip.Get(); }
                LongestClip = Math::Max(LongestClip, utils_crawler::Get_ClipSeconds(Definition.Def.Clip.Get()));
                auto Entry = FMars_Attack_Entry();
                Entry.Id = Id;
                Entry.Priority = Id == GameplayTags::Attack_Mars_Pincer ? 100 : Id == GameplayTags::Attack_Mars_Jab ? 0 : 50;
                Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Definition);
                Loadout.Entries.Add(Entry);
            }
            Loadout.Execution = Make_Execution(InPreset, InEndpointDemo, Pincer, LongestClip);
            Loadout.Selection.TemporaryReadiness = InEndpointDemo ? EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative :
                EMars_Attack_TemporaryReadinessPolicy::WaitPreferred;
            Loadout.Selection.ControlWait = EMars_Attack_ControlWaitPolicy::PreferAvailable;
            Loadout.Selection.ReadyAlternativeDelaySeconds = 0.25f;
            Plan.Asset.Spec = Loadout;
        }
        if (ck::Is_NOT_Valid(Plan.Asset))
        { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=LoadoutClassMismatch path={Plan.Path}"); return false; }
        if (Resolve_ForPreset(Plan.Asset, InPreset, Plan.Construction) == false)
        { return false; }
        InOutPlan.Loadouts.Add(Plan);
        return true;
    }

    UObject Create_MissingAsset(FString InPath, FString InFolder, TSubclassOf<UDataAsset> InClass)
    {
        if (EditorAsset::DoesAssetExist(InPath))
        { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=AssetAppearedDuringPreflight path={InPath}; no overwrite"); return nullptr; }
        const auto Object = FSoftObjectPath(InPath);
        const auto Name = Object.GetAssetName();
        auto Factory = Cast<UDataAssetFactory>(NewObject(GetTransientPackage(), UDataAssetFactory));
        return AssetTools::CreateAsset(Name, InFolder, InClass, Factory);
    }

    bool Save_New(UObject InAsset, FString InPath, FMars_AttackAuthoring_SeedReport& InOutReport)
    {
        const bool OnlyIfIsDirty = false;
        ++InOutReport.SaveCalls;
        const auto Saved = EditorAsset::SaveLoadedAsset(InAsset, OnlyIfIsDirty);
        LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] created={InPath} saved={Saved}");
        return Saved;
    }

    bool Persist_NewClips(FMars_AttackAuthoring_Preflight& InOutPlan, FMars_AttackAuthoring_SeedReport& InOutReport)
    {
        for (int32 Index = 0; Index < InOutPlan.Clips.Num(); ++Index)
        {
            const auto Plan = InOutPlan.Clips[Index];
            if (Plan.Existed) { continue; }
            auto Clip = Cast<UCk_ProceduralAction_Data>(Create_MissingAsset(Plan.Path, utils_crawler::AttackReferenceActionsFolder, UCk_ProceduralAction_Data));
            if (ck::Is_NOT_Valid(Clip)) { return false; }
            ++InOutReport.CreatedClips;
            InOutReport.CreatedPaths.Add(Plan.Path);
            auto Draft = FCk_ProceduralAction_ClipDraft();
            const auto Copy = utils_procedural_action_builder::Make_Draft_FromData(Plan.Asset, Draft);
            if (Copy.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid) { return false; }
            const auto Built = utils_procedural_action_builder::Build_Into(Draft, Clip);
            if (Built.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid) { return false; }
            const auto Spec = utils_crawler::Make_AttackReferenceSpec(Plan.Preset);
            const auto Subject = Plan.Kind == GameplayTags::Attack_Mars_Pincer ? utils_crawler::Make_ReferenceEndpointPincerEditorSubject(Clip, Spec.Layout, Spec.LegCount) :
                utils_crawler::Make_ReferenceSwipeEditorSubject(Clip, Spec.Layout, Spec.LegCount, Plan.Kind == GameplayTags::Attack_Mars_SwipeRight);
            utils_procedural_action_editor::Get_EditorData(Clip).Set_Subject(Subject);
            auto PreviewRig = Subject.Get_WalkingRig().Get();
            auto PreviewGait = Subject.Get_WalkingGait().Get();
            if (UMars_AttackPreviewOwnership::Attach_EmbeddedPreviewObjects(Clip, PreviewRig, PreviewGait) == false)
            { LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] code=PreviewOwnershipRejected path={Plan.Path}"); return false; }
            InOutPlan.Clips[Index].Asset = Clip;
            if (Save_New(Clip, Plan.Path, InOutReport) == false) { return false; }
        }
        return true;
    }

    bool Persist_NewDefinitions(FMars_AttackAuthoring_Preflight& InOutPlan, FMars_AttackAuthoring_SeedReport& InOutReport)
    {
        for (int32 Index = 0; Index < InOutPlan.Definitions.Num(); ++Index)
        {
            const auto Plan = InOutPlan.Definitions[Index];
            if (Plan.Existed) { continue; }
            auto Definition = Cast<UMars_AttackDefinition_Data>(Create_MissingAsset(Plan.Path, utils_crawler::AttackReferenceFolder, UMars_AttackDefinition_Data));
            if (ck::Is_NOT_Valid(Definition)) { return false; }
            ++InOutReport.CreatedDefinitions;
            InOutReport.CreatedPaths.Add(Plan.Path);
            auto Def = Plan.Asset.Def;
            const auto ClipIndex = Find_ClipPlan(InOutPlan, Plan.ClipPath);
            if (ClipIndex >= 0) { Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(InOutPlan.Clips[ClipIndex].Asset); }
            else { Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Plan.ClipPath)); }
            Definition.Def = Def;
            const auto Report = utils_attack::Validate_Definition(Def);
            if (Report.Get_IsValid() == false) { return false; }
            InOutPlan.Definitions[Index].Asset = Definition;
            if (Save_New(Definition, Plan.Path, InOutReport) == false) { return false; }
        }
        return true;
    }

    bool Persist_NewLoadouts(FMars_AttackAuthoring_Preflight& InOutPlan, FMars_AttackAuthoring_SeedReport& InOutReport)
    {
        // First replace every transient definition reference and revalidate every resulting graph. No loadout has
        // been saved yet. Existing loadouts remain untouched, including custom entries and their definition paths.
        for (int32 Index = 0; Index < InOutPlan.Loadouts.Num(); ++Index)
        {
            auto& Plan = InOutPlan.Loadouts[Index];
            if (Plan.Existed) { continue; }
            auto Spec = Plan.Asset.Spec;
            const auto EndpointDemo = Plan.Path.Contains("EndpointDemo");
            for (int32 EntryIndex = 0; EntryIndex < Spec.Entries.Num(); ++EntryIndex)
            {
                auto Entry = Spec.Entries[EntryIndex];
                const auto Path = utils_crawler::Get_AttackReferenceDefinitionPath(Plan.Preset, EndpointDemo, Entry.Id);
                const auto DefinitionIndex = Find_DefinitionPlan(InOutPlan, Path);
                if (DefinitionIndex < 0) { return false; }
                Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(InOutPlan.Definitions[DefinitionIndex].Asset);
                Spec.Entries[EntryIndex] = Entry;
            }
            Plan.Asset.Spec = Spec;
            if (Resolve_ForPreset(Plan.Asset, Plan.Preset, Plan.Construction) == false) { return false; }
        }
        for (int32 Index = 0; Index < InOutPlan.Loadouts.Num(); ++Index)
        {
            const auto Plan = InOutPlan.Loadouts[Index];
            if (Plan.Existed) { continue; }
            auto Loadout = Cast<UMars_AttackLoadout_Data>(Create_MissingAsset(Plan.Path, utils_crawler::AttackReferenceFolder, UMars_AttackLoadout_Data));
            if (ck::Is_NOT_Valid(Loadout)) { return false; }
            ++InOutReport.CreatedLoadouts;
            InOutReport.CreatedPaths.Add(Plan.Path);
            Loadout.Spec = Plan.Asset.Spec;
            InOutPlan.Loadouts[Index].Asset = Loadout;
            if (Save_New(Loadout, Plan.Path, InOutReport) == false) { return false; }
        }
        return true;
    }

    void Record_Skipped(FMars_AttackAuthoring_SeedReport& InOutReport, FString InPath, EMars_AttackAuthoring_AssetKind InKind)
    {
        if (InOutReport.SkippedPaths.Contains(InPath)) { return; }
        InOutReport.SkippedPaths.Add(InPath);
        if (InKind == EMars_AttackAuthoring_AssetKind::Clip) { ++InOutReport.SkippedClips; }
        if (InKind == EMars_AttackAuthoring_AssetKind::Definition) { ++InOutReport.SkippedDefinitions; }
        if (InKind == EMars_AttackAuthoring_AssetKind::Loadout) { ++InOutReport.SkippedLoadouts; }
    }

    bool Seed_ReferenceLoadouts(FMars_AttackAuthoring_SeedReport& OutReport)
    {
        OutReport = FMars_AttackAuthoring_SeedReport();
        if (Editor::IsPlaying())
        {
            OutReport.FailureStage = "EditorOnly";
            LogDisplay("[Mars.Attack.SeedReferenceLoadouts] code=EditorOnly expected=editor-not-playing actual=PIE");
            return false;
        }
        auto Plan = FMars_AttackAuthoring_Preflight();
        auto Presets = TArray<EMars_Crawler_AttackPreset>(); Presets.Add(EMars_Crawler_AttackPreset::Crawler4); Presets.Add(EMars_Crawler_AttackPreset::Crawler6); Presets.Add(EMars_Crawler_AttackPreset::Spider6);
        for (const auto Preset : Presets)
        {
            if (Plan_Loadout(Preset, false, Plan) == false || Plan_Loadout(Preset, true, Plan) == false)
            { OutReport.FailureStage = "Preflight"; LogDisplay("[Mars.Attack.SeedReferenceLoadouts] preflight rejected; no asset packages were created"); return false; }
        }
        OutReport.PreflightValid = true;
        for (const auto& Clip : Plan.Clips)
        { if (Clip.Existed) { Record_Skipped(OutReport, Clip.Path, EMars_AttackAuthoring_AssetKind::Clip); } }
        for (const auto& Definition : Plan.Definitions)
        { if (Definition.Existed) { Record_Skipped(OutReport, Definition.Path, EMars_AttackAuthoring_AssetKind::Definition); } }
        for (const auto& Loadout : Plan.Loadouts)
        {
            if (Loadout.Existed == false) { continue; }
            Record_Skipped(OutReport, Loadout.Path, EMars_AttackAuthoring_AssetKind::Loadout);
            for (const auto& Entry : Loadout.Asset.Spec.Entries)
            {
                if (Entry.Enabled == false) { continue; }
                Record_Skipped(OutReport, Entry.Definition.ToString(), EMars_AttackAuthoring_AssetKind::Definition);
                const auto Definition = Entry.Definition.Get();
                if (ck::IsValid(Definition)) { Record_Skipped(OutReport, Definition.Def.Clip.ToString(), EMars_AttackAuthoring_AssetKind::Clip); }
            }
        }
        if (Persist_NewClips(Plan, OutReport) == false) { OutReport.FailureStage = "Clips"; return false; }
        if (Persist_NewDefinitions(Plan, OutReport) == false) { OutReport.FailureStage = "Definitions"; return false; }
        if (Persist_NewLoadouts(Plan, OutReport) == false) { OutReport.FailureStage = "Loadouts"; return false; }
        OutReport.Completed = true;
        LogDisplay("[Mars.Attack.SeedReferenceLoadouts] all reference graphs validated; only missing assets were written");
        return true;
    }

    bool Seed_ReferenceLoadouts()
    {
        auto Report = FMars_AttackAuthoring_SeedReport();
        const auto Completed = Seed_ReferenceLoadouts(Report);
        LogDisplay(f"[Mars.Attack.SeedReferenceLoadouts] completed={Completed} stage={Report.FailureStage} createdClips={Report.CreatedClips} createdDefinitions={Report.CreatedDefinitions} createdLoadouts={Report.CreatedLoadouts} skippedClips={Report.SkippedClips} skippedDefinitions={Report.SkippedDefinitions} skippedLoadouts={Report.SkippedLoadouts} saveCalls={Report.SaveCalls}");
        if (Completed == false)
        { LogDisplay("[Mars.Attack.SeedReferenceLoadouts] inspect named created paths; partial NEW assets may exist; existing assets were not overwritten"); }
        return Completed;
    }
}
#endif
