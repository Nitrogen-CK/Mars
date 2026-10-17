#if EDITOR
UCLASS(Abstract)
class UMars_AutoTestRig_AttackCatalogAuthoring : UMars_AutoTestRig_AttackCatalogPure
{
    UPROPERTY() protected TArray<UMars_AttackLoadout_Data> _Loadouts;
    UPROPERTY() protected TArray<FMars_AttackAuthoring_ValidationResult> _ValidatedGraphs;
    private TArray<FString> _LegacyPaths;
    private TArray<FString> _LegacyValues;

    protected TArray<EMars_Crawler_AttackPreset> Get_Presets() const
    {
        auto Presets = TArray<EMars_Crawler_AttackPreset>();
        Presets.Add(EMars_Crawler_AttackPreset::Crawler4); Presets.Add(EMars_Crawler_AttackPreset::Crawler6); Presets.Add(EMars_Crawler_AttackPreset::Spider6);
        return Presets;
    }

    protected TArray<FString> Get_DeclaredAssetPaths() const
    {
        auto Paths = TArray<FString>();
        for (const auto Preset : Get_Presets())
        {
            for (int32 Demo = 0; Demo < 2; ++Demo)
            {
                const auto Endpoint = Demo == 1;
                Paths.Add(utils_crawler::Get_AttackReferenceLoadoutPath(Preset, Endpoint));
                Paths.Add(utils_crawler::Get_AttackReferenceDefinitionPath(Preset, Endpoint, GameplayTags::Attack_Mars_Pincer));
                Paths.Add(utils_crawler::Get_AttackReferenceDefinitionPath(Preset, Endpoint, GameplayTags::Attack_Mars_Jab));
                if (Endpoint)
                {
                    Paths.Add(utils_crawler::Get_AttackReferenceDefinitionPath(Preset, true, GameplayTags::Attack_Mars_SwipeRight));
                    Paths.Add(utils_crawler::Get_AttackReferenceDefinitionPath(Preset, true, GameplayTags::Attack_Mars_SwipeLeft));
                }
            }
            Paths.Add(utils_crawler::Get_AttackReferenceEndpointClipPath(Preset, GameplayTags::Attack_Mars_Pincer));
            Paths.Add(utils_crawler::Get_AttackReferenceEndpointClipPath(Preset, GameplayTags::Attack_Mars_SwipeRight));
            Paths.Add(utils_crawler::Get_AttackReferenceEndpointClipPath(Preset, GameplayTags::Attack_Mars_SwipeLeft));
        }
        return Paths;
    }

    private FString Get_ClipValues(UCk_ProceduralAction_Data InClip) const
    {
        auto Text = f"body={InClip.Get_BodyChannel().Get_Enabled()} initial={InClip.Get_BodyChannel().Get_InitialSource() :n}";
        for (const auto& Slot : InClip.Get_Slots())
        { Text = f"{Text}|slot={Slot.Get_Id()} source={Slot.Get_InitialSource() :n} space={Slot.Get_Space() :n}"; }
        for (const auto& Phase : InClip.Get_Phases())
        {
            Text = f"{Text}|phase={Phase.Get_Id()} duration={Phase.Get_Duration().Get_Seconds() :.9} easing={Phase.Get_Easing() :n} bodyInterpolation={Phase.Get_BodyInterpolation() :n}";
            for (const auto& Key : Phase.Get_BodyKeys())
            {
                const auto Q = Key.Get_Rotation();
                Text = f"{Text}|bodyKey={Key.Get_Time().Get_Value() :.9}/{Key.Get_Translation().ToString()}/{Q.X :.9},{Q.Y :.9},{Q.Z :.9},{Q.W :.9}/{Key.Get_ArriveTangent().ToString()}/{Key.Get_LeaveTangent().ToString()}";
            }
            for (const auto& Track : Phase.Get_LimbTracks())
            {
                Text = f"{Text}|track={Track.Get_Slot()} interpolation={Track.Get_Interpolation() :n} reach={Track.Get_ReachPolicy() :n}";
                for (const auto& Key : Track.Get_PositionKeys())
                { Text = f"{Text}|position={Key.Get_Time().Get_Value() :.9}/{Key.Get_Value().ToString()}/{Key.Get_ArriveTangent().ToString()}/{Key.Get_LeaveTangent().ToString()}"; }
                for (const auto& Key : Track.Get_OrientationKeys())
                {
                    const auto Q = Key.Get_Value();
                    Text = f"{Text}|orientation={Key.Get_Time().Get_Value() :.9}/{Q.X :.9},{Q.Y :.9},{Q.Z :.9},{Q.W :.9}";
                }
                for (const auto& Key : Track.Get_BendKeys())
                { Text = f"{Text}|bend={Key.Get_Time().Get_Value() :.9}/{Key.Get_Value().ToString()}"; }
            }
        }
        for (const auto& Window : InClip.Get_Windows())
        { Text = f"{Text}|window={Window.Get_Id()}/{Window.Get_Start().Get_PhaseId()}:{Window.Get_Start().Get_Time().Get_Value() :.9}/{Window.Get_End().Get_PhaseId()}:{Window.Get_End().Get_Time().Get_Value() :.9}"; }
        const auto EditorData = utils_procedural_action_editor::TryGet_EditorData(InClip);
        Text = f"{Text}|editorData={ck::IsValid(EditorData)}";
        if (ck::IsValid(EditorData))
        {
            const auto Subject = EditorData.Get_Subject();
            Text = f"{Text}|rig={Subject.Get_WalkingRig().ToString()} gait={Subject.Get_WalkingGait().ToString()} scenario={Subject.Get_Scenario().ToString()}";
            for (const auto& Binding : Subject.Get_SlotBindings())
            { Text = f"{Text}|binding={Binding.Get_Slot()}:{Binding.Get_LimbId()}"; }
        }
        return Text;
    }

    protected bool Capture_LegacyValues()
    {
        _LegacyPaths.Reset(); _LegacyValues.Reset();
        auto Presets = TArray<EMars_Crawler_AttackPreset>(); Presets.Add(EMars_Crawler_AttackPreset::Crawler4); Presets.Add(EMars_Crawler_AttackPreset::Spider6);
        auto Ids = TArray<FGameplayTag>(); Ids.Add(GameplayTags::Attack_Mars_Jab); Ids.Add(GameplayTags::Attack_Mars_Pincer);
        for (const auto Preset : Presets)
        {
            for (const auto Id : Ids)
            {
                const auto Path = utils_crawler::Get_AttackReferenceLegacyClipPath(Preset, Id);
                auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Path)));
                if (ck::Is_NOT_Valid(Clip)) { FinishFailure(f"missing immutable legacy source {Path}"); return false; }
                _Clips.Add(Clip);
                _LegacyPaths.Add(Path); _LegacyValues.Add(Get_ClipValues(Clip));
                Print(f"[AttackCatalog.D03] existing source observation captured: {Path}");
            }
        }
        return true;
    }

    protected void Assert_LegacyValuesUnchanged()
    {
        for (int32 Index = 0; Index < _LegacyPaths.Num(); ++Index)
        {
            auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(_LegacyPaths[Index])));
            Assert_True(ck::IsValid(Clip), f"legacy source remains loaded: {_LegacyPaths[Index]}");
            if (ck::IsValid(Clip))
            { Assert_Equals_String(Get_ClipValues(Clip), _LegacyValues[Index], f"read-only exposed legacy clip/subject values unchanged: {_LegacyPaths[Index]}"); }
        }
        Print("[AttackCatalog.D03] AS checked exposed values only; main gate must compare original 16 .uasset/.ckexport byte hashes externally");
    }

    protected void Assert_Preview(EMars_Crawler_AttackPreset InPreset, FGameplayTag InId)
    {
        const auto Path = utils_crawler::Get_AttackReferenceEndpointClipPath(InPreset, InId);
        auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Path)));
        Assert_True(ck::IsValid(Clip), f"new endpoint reference clip loads: {Path}");
        if (ck::Is_NOT_Valid(Clip)) { return; }
        _Clips.Add(Clip);
        const auto EditorData = utils_procedural_action_editor::TryGet_EditorData(Clip);
        Assert_True(ck::IsValid(EditorData), "new clip already carries its own editor data; test does not create metadata");
        if (ck::Is_NOT_Valid(EditorData)) { return; }
        const auto Subject = EditorData.Get_Subject();
        auto Rig = System::LoadAsset_Blocking(Subject.Get_WalkingRig());
        auto Gait = System::LoadAsset_Blocking(Subject.Get_WalkingGait());
        Assert_True(ck::IsValid(Rig) && ck::IsValid(Gait), "new clip pins its embedded preview rig and gait");
        if (ck::Is_NOT_Valid(Rig) || ck::Is_NOT_Valid(Gait)) { return; }
        const auto Spec = utils_crawler::Make_AttackReferenceSpec(InPreset);
        const auto Expected = Spec.Get_RigData().Get_Legs();
        const auto Actual = Rig.Get_Legs();
        Assert_Equals_Int(Actual.Num(), Expected.Num(), f"preview is on the exact {InPreset :n} leg count");
        if (Actual.Num() != Expected.Num()) { return; }
        for (int32 Index = 0; Index < Expected.Num(); ++Index)
        {
            Assert_True(Actual[Index].Get_Id() == Expected[Index].Get_Id() &&
                Actual[Index].Get_Placement().Get_HipLocal() == Expected[Index].Get_Placement().Get_HipLocal() &&
                Actual[Index].Get_Placement().Get_RestFootLocal() == Expected[Index].Get_Placement().Get_RestFootLocal(),
                "preview leg ID/hip/rest geometry is copied from the requested reference rig");
        }
        const auto Bindings = Subject.Get_SlotBindings();
        Assert_Equals_Int(Bindings.Num(), InId == GameplayTags::Attack_Mars_Pincer ? 2 : 1, "preview has exactly the claimed single or dual claw binding");
        for (const auto& Binding : Bindings)
        {
            const auto Right = Binding.Get_Slot() == n"ClawRight";
            const auto ExpectedId = Right ? n"Leg0" : Spec.LegCount == 4 ? n"Leg3" : n"Leg5";
            Assert_True(Binding.Get_LimbId() == ExpectedId, "preview binding names the exact stable front limb");
            if (InId == GameplayTags::Attack_Mars_SwipeRight) { Assert_True(Right, "right swipe previews only ClawRight"); }
            if (InId == GameplayTags::Attack_Mars_SwipeLeft) { Assert_True(Right == false, "left swipe previews only ClawLeft"); }
        }
    }
}
#endif
