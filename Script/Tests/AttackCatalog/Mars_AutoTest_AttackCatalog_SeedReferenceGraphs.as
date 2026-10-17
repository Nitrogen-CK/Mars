#if EDITOR
// PIE lifetime/read-only inspection only. Native Ck.Mars.AttackCatalog.EditorSeedReferenceGraphs persists the
// approved missing packages outside PIE before this lane; EditorAsset APIs are intentionally absent here.
class UMars_AutoTest_AttackCatalog_SeedReferenceGraphs : UMars_AutoTestRig_AttackCatalogAuthoring
{
    default _TimeoutSeconds = 180.0f;
    UPROPERTY() private UCk_ProceduralAction_Data _PreviewProbeClip;
    private bool _PreviewProbePassed = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("build transient preview subject with only its clip strongly held", n"Step_PreviewProbe");
        Add_Step("GC preview probe with only the clip retained", n"Step_PreviewProbeGC");
        Add_Step("capture old values and inspect packages persisted by the native editor test", n"Step_PersistedPackages");
        Add_Step("verify new preview metadata without writing it", n"Step_Previews");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PreviewProbe(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PreviewProbeClip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        const auto Report = utils_crawler::Build_ReferenceSwipeClip(EMars_Crawler_Layout::Spider, 6, true, _PreviewProbeClip);
        if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { FinishFailure(f"preview lifetime probe clip failed to build: {utils_crawler::Get_FirstDiagnosticText(Report)}"); return; }
        // Subject contains soft references only. The helper's local hard references expire before the NEXT step.
        const auto Subject = utils_crawler::Make_ReferenceSwipeEditorSubject(_PreviewProbeClip, EMars_Crawler_Layout::Spider, 6, true);
        utils_procedural_action_editor::Get_EditorData(_PreviewProbeClip).Set_Subject(Subject);
    }

    UFUNCTION()
    private void Step_PreviewProbeGC(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        System::CollectGarbage();
        const auto EditorData = utils_procedural_action_editor::TryGet_EditorData(_PreviewProbeClip);
        if (ck::Is_NOT_Valid(EditorData))
        { FinishFailure("clip-only strong pin did not retain the preview editor data; this PIE test wrote no assets"); return; }
        const auto Subject = EditorData.Get_Subject();
        const auto Rig = Subject.Get_WalkingRig().Get();
        const auto Gait = Subject.Get_WalkingGait().Get();
        if (ck::Is_NOT_Valid(Rig) || ck::Is_NOT_Valid(Gait))
        { FinishFailure("clip-only strong pin lost its embedded walking rig/gait after GC; this PIE test wrote no assets"); return; }
        const auto Actual = Rig.Get_Legs();
        const auto Expected = utils_crawler::Mars_SpiderRig6.Get_Legs();
        if (Actual.Num() != Expected.Num())
        { FinishFailure("preview rig geometry changed after GC; this PIE test wrote no assets"); return; }
        for (int32 Index = 0; Index < Expected.Num(); ++Index)
        {
            if (Actual[Index].Get_Id() != Expected[Index].Get_Id() ||
                Actual[Index].Get_Placement().Get_HipLocal() != Expected[Index].Get_Placement().Get_HipLocal() ||
                Actual[Index].Get_Placement().Get_RestFootLocal() != Expected[Index].Get_Placement().Get_RestFootLocal())
            { FinishFailure("preview rig differs from Spider6 after GC; this PIE test wrote no assets"); return; }
        }
        const auto Bindings = Subject.Get_SlotBindings();
        if (Bindings.Num() != 1 || Bindings[0].Get_Slot() != n"ClawRight" || Bindings[0].Get_LimbId() != n"Leg0")
        { FinishFailure("preview binding differs after GC; this PIE test wrote no assets"); return; }
        const auto ExpectedGait = utils_crawler::Mars_SpiderGait;
        if (Gait.Get_Timing().Get_CycleDuration().Get_Seconds() != ExpectedGait.Get_Timing().Get_CycleDuration().Get_Seconds() ||
            Gait.Get_Timing().Get_StepDuration().Get_Seconds() != ExpectedGait.Get_Timing().Get_StepDuration().Get_Seconds() ||
            Gait.Get_Timing().Get_LegLossPolicy() != ExpectedGait.Get_Timing().Get_LegLossPolicy() ||
            Gait.Get_Step().Get_Height() != ExpectedGait.Get_Step().Get_Height() ||
            Gait.Get_Step().Get_Threshold() != ExpectedGait.Get_Step().Get_Threshold())
        { FinishFailure("preview gait timing/step preset differs after GC; this PIE test wrote no assets"); return; }
        _PreviewProbePassed = true;
        Assert_True(true, "clip-only strong ownership retains the exact embedded preview subject through a later GC step");
    }

    UFUNCTION()
    private void Step_PersistedPackages(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_PreviewProbePassed == false)
        { FinishFailure("preview ownership prerequisite did not pass; this PIE test performs no persistence"); return; }
        if (Capture_LegacyValues() == false) { return; }
        const auto Paths = Get_DeclaredAssetPaths();
        Assert_Equals_Int(Paths.Num(), 33, "the approved reference package inventory is bounded and exact");
        for (const auto& Path : Paths)
        {
            const auto Dot = Path.Find(".");
            const auto Package = Dot >= 0 ? Path.Left(Dot) : Path;
            const auto Disk = FPaths::CombinePaths(FPaths::ProjectContentDir(), Package.Mid(6) + ".uasset");
            Assert_True(FPaths::FileExists(Disk), f"native editor bootstrap persisted this approved package: {Disk}");
            const auto Loaded = System::LoadAsset_Blocking(TSoftObjectPtr<UObject>(FSoftObjectPath(Path)));
            Assert_True(ck::IsValid(Loaded), f"persisted approved object loads read-only in PIE: {Path}");
        }
        Assert_LegacyValuesUnchanged();
        Print("[AttackCatalog.D03] PIE inspected persisted packages only; native EditorSeedReferenceGraphs owns seeding/idempotence and disk byte/mtime proof");
    }

    UFUNCTION()
    private void Step_Previews(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto Preset : Get_Presets())
        {
            Assert_Preview(Preset, GameplayTags::Attack_Mars_Pincer); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeRight); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeLeft);
        }
        System::CollectGarbage();
        for (const auto Preset : Get_Presets())
        {
            Assert_Preview(Preset, GameplayTags::Attack_Mars_Pincer); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeRight); Assert_Preview(Preset, GameplayTags::Attack_Mars_SwipeLeft);
        }
    }
}
#endif
