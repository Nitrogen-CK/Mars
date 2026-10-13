// Editor-only: the crawler's reference attack clips, the motion the crawler shipped with before its clips became authored
// assets, and Mars.Crawler.SeedAttackClips, which writes them as the starting assets under
// /Game/Mars/Gameplay/Monsters/Crawler/Actions/, each remembering the crawler it is previewed on. The CrawlerMelee tests
// build their clips here too, so they never depend on content an author tunes.
//
// Four clips, all three phases Windup, Strike and Recover over one Offense window, the body channel from the identity
// offset (utils_crawler::Validate_AttackClip): the body-only jab and the rearing pincer, each on the radial layout (valid
// on both radial rigs) and on the spider (its body keys grown by its size, its claw keys moved onto its front leg).

#if EDITOR
UFUNCTION()
void Mars_SeedCrawlerAttackClipsFunc(const TArray<FString>& Args)
{
    utils_crawler::Seed_AttackClips();
}

const FConsoleCommand Mars_SeedCrawlerAttackClipsCommand("Mars.Crawler.SeedAttackClips", n"Mars_SeedCrawlerAttackClipsFunc");

// One posed phase of a reference clip: its length, its easing and the body offset it ends on (the next phase starts there).
struct FMars_Crawler_ReferencePhase
{
    float32 Seconds = 0.0f;
    ECk_ProceduralAction_Easing Easing = ECk_ProceduralAction_Easing::Linear;
    FTransform EndBody = FTransform::Identity;

    FMars_Crawler_ReferencePhase() {}

    FMars_Crawler_ReferencePhase(float32 InSeconds, ECk_ProceduralAction_Easing InEasing, FTransform InEndBody)
    {
        Seconds = InSeconds;
        Easing = InEasing;
        EndBody = InEndBody;
    }
}

struct FMars_Crawler_ReferenceAttack
{
    FMars_Crawler_ReferencePhase Windup;
    FMars_Crawler_ReferencePhase Strike;
    FMars_Crawler_ReferencePhase Recover;
}

// Where a pincer's claws go, in the root's frame at the attack's start: the right claw's windup and strike keys (the left
// claw mirrors them across the body's XZ plane), and each claw's rest foot, where Recover ends.
struct FMars_Crawler_ReferenceClawKeys
{
    FVector Windup = FVector::ZeroVector;
    FVector Strike = FVector::ZeroVector;
    FVector RightRest = FVector::ZeroVector;
    FVector LeftRest = FVector::ZeroVector;
}

namespace utils_crawler
{
    const FString ReferenceClipFolder = "/Game/Mars/Gameplay/Monsters/Crawler/Actions";

    // The rig a reference clip is authored on and previewed with: the radial clips on the four-leg rig (Room 5's radial
    // crawler), the spider's on its own.
    UCk_ProceduralRig_Data Get_ReferenceRig(EMars_Crawler_Layout InLayout)
    {
        return InLayout == EMars_Crawler_Layout::Spider ? utils_crawler::Mars_SpiderRig6 : utils_crawler::Mars_CrawlerRig4;
    }

    // <Crawler|Spider>_<Jab|Pincer>_Mars_DA.
    FString Get_ReferenceClipName(EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind)
    {
        const FString Prefix = InLayout == EMars_Crawler_Layout::Spider ? "Spider" : "Crawler";
        return f"{Prefix}_{Get_ClipKindName(InKind)}_Mars_DA";
    }

    // The jab: a short dip back and down, then a lunge forward. The pincer: a longer windup that rears the body back and
    // up, nose thrown high, then a lunge forward and down. Translations grow with the layout's size; rotations and timings
    // do not.
    FMars_Crawler_ReferenceAttack Make_ReferenceAttack(EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind)
    {
        const auto Size = float64(Get_LayoutSizeScale(InLayout));
        const auto Pincer = InKind == EMars_Crawler_AttackClipKind::Pincer;
        const auto WindupRotation = Pincer ? FRotator(28.0, 0.0, 0.0) : FRotator::ZeroRotator;
        const auto WindupOffset = Pincer ? FVector(-12.0, 0.0, 14.0) : FVector(-10.0, 0.0, -5.0);
        const auto StrikeOffset = Pincer ? FVector(30.0, 0.0, -6.0) : FVector(24.0, 0.0, 0.0);

        auto Attack = FMars_Crawler_ReferenceAttack();
        Attack.Windup = FMars_Crawler_ReferencePhase(Pincer ? 0.60f : 0.40f, ECk_ProceduralAction_Easing::OutCubic,
            FTransform(WindupRotation, WindupOffset * Size, FVector::OneVector));
        Attack.Strike = FMars_Crawler_ReferencePhase(0.12f, ECk_ProceduralAction_Easing::InQuad,
            FTransform(FRotator::ZeroRotator, StrikeOffset * Size, FVector::OneVector));
        Attack.Recover = FMars_Crawler_ReferencePhase(0.50f, ECk_ProceduralAction_Easing::InOutCubic, FTransform::Identity);
        return Attack;
    }

    // The right claw thrown up and apart for the windup and slammed down in front of the body on the strike, authored on
    // the radial six-leg rig's front leg. The spider's keys keep each key's offset from the front hip, scaled by the ratio
    // of the two front chains' reaches, and stay ReferenceClawGroundClearance (grown with the size) over its rest feet's
    // ground: its shorter, lower-slung chain would otherwise strike into the floor. The rest feet are the reference rig's
    // first and last leg's.
    FMars_Crawler_ReferenceClawKeys Make_ReferenceClawKeys(EMars_Crawler_Layout InLayout)
    {
        auto Keys = FMars_Crawler_ReferenceClawKeys();
        Keys.Windup = FVector(70.0, 55.0, 85.0);
        Keys.Strike = FVector(125.0, 16.0, -30.0);

        const TArray<FCk_ProceduralLeg_Spec> Legs = Get_ReferenceRig(InLayout).Get_Legs();
        Keys.RightRest = Legs[0].Get_Placement().Get_RestFootLocal();
        Keys.LeftRest = Legs.Last().Get_Placement().Get_RestFootLocal();
        if (InLayout == EMars_Crawler_Layout::Radial)
        { return Keys; }

        const TArray<FCk_ProceduralLeg_Spec> From = utils_crawler::Mars_CrawlerRig6.Get_Legs();
        const auto FromHip = From[0].Get_Placement().Get_HipLocal();
        const auto ToHip = Legs[0].Get_Placement().Get_HipLocal();
        const auto Scale = float64(Get_ChainReach(Legs[0]) / Get_ChainReach(From[0]));
        const auto Floor = Keys.RightRest.Z + ReferenceClawGroundClearance * float64(Get_LayoutSizeScale(InLayout));

        Keys.Windup = ToHip + (Keys.Windup - FromHip) * Scale;
        Keys.Strike = ToHip + (Keys.Strike - FromHip) * Scale;
        Keys.Windup.Z = Math::Max(Keys.Windup.Z, Floor);
        Keys.Strike.Z = Math::Max(Keys.Strike.Z, Floor);
        return Keys;
    }

    const float64 ReferenceClawGroundClearance = 10.0;

    FVector Make_LeftClawKey(FVector InRightKey)
    {
        return FVector(InRightKey.X, -InRightKey.Y, InRightKey.Z);
    }

    // The reference clip of InLayout and InKind, built into InClip (which the caller keeps referenced) through the
    // procedural action builder. Each phase gets a pose key at 0 and at 1 writing the body (Windup from the identity offset
    // to its key, Strike to its key, Recover back to identity). A pincer adds the ClawRight and ClawLeft slots, framed
    // RootAtStart so the claw keys do not ride the body keys: Windup keys each claw only at its end (the windup key on its
    // side; it lifts off from wherever its foot is planted), Strike moves it from the windup key to the strike key, and
    // Recover from the strike key to its rest foot, where the limb control's return replants it. Returns the first
    // rejected step's report, or Build_Into's; InClip is untouched unless the whole draft compiled.
    FCk_ProceduralAction_ValidationReport Build_ReferenceClip(EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind,
        UCk_ProceduralAction_Data InClip)
    {
        const auto Attack = Make_ReferenceAttack(InLayout, InKind);
        const auto Pincer = InKind == EMars_Crawler_AttackClipKind::Pincer;
        const auto Claws = Make_ReferenceClawKeys(InLayout);
        const auto Right = Get_RightClawSlotId();
        const auto Left = Get_LeftClawSlotId();
        auto Draft = FCk_ProceduralAction_ClipDraft();
        auto Reports = TArray<FCk_ProceduralAction_ValidationReport>();

        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        Body.Set_InitialSource(ECk_ProceduralAction_InitialSource::IdentityOffset);
        Reports.Add(utils_procedural_action_builder::Set_BodyChannel(Draft, Body));

        if (Pincer)
        {
            Reports.Add(utils_procedural_action_builder::Add_Slot(Draft, FCk_ProceduralAction_Slot(Right)));
            Reports.Add(utils_procedural_action_builder::Add_Slot(Draft, FCk_ProceduralAction_Slot(Left)));
        }

        const auto WindupId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup);
        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(WindupId, Attack.Windup)));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, WindupId, Make_ReferencePoseKey(0.0f, FTransform::Identity)));
        auto WindupEnd = Make_ReferencePoseKey(1.0f, Attack.Windup.EndBody);
        if (Pincer)
        { WindupEnd.Set_Limbs(Make_ClawTargets(Claws.Windup, Make_LeftClawKey(Claws.Windup))); }
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, WindupId, WindupEnd));

        const auto StrikeId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike);
        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(StrikeId, Attack.Strike)));
        auto StrikeStart = Make_ReferencePoseKey(0.0f, Attack.Windup.EndBody);
        auto StrikeEnd = Make_ReferencePoseKey(1.0f, Attack.Strike.EndBody);
        if (Pincer)
        {
            StrikeStart.Set_Limbs(Make_ClawTargets(Claws.Windup, Make_LeftClawKey(Claws.Windup)));
            StrikeEnd.Set_Limbs(Make_ClawTargets(Claws.Strike, Make_LeftClawKey(Claws.Strike)));
        }
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId, StrikeStart));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId, StrikeEnd));

        const auto RecoverId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover);
        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(RecoverId, Attack.Recover)));
        auto RecoverStart = Make_ReferencePoseKey(0.0f, Attack.Strike.EndBody);
        auto RecoverEnd = Make_ReferencePoseKey(1.0f, Attack.Recover.EndBody);
        if (Pincer)
        {
            RecoverStart.Set_Limbs(Make_ClawTargets(Claws.Strike, Make_LeftClawKey(Claws.Strike)));
            RecoverEnd.Set_Limbs(Make_ClawTargets(Claws.RightRest, Claws.LeftRest));
        }
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, RecoverId, RecoverStart));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, RecoverId, RecoverEnd));

        if (Pincer)
        {
            Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Right, ECk_ProceduralAction_TrackSpace::RootAtStart));
            Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Left, ECk_ProceduralAction_TrackSpace::RootAtStart));
        }

        Reports.Add(utils_procedural_action_builder::Add_Window(Draft, FCk_ProceduralAction_Window(Get_OffenseWindowId(),
            FCk_ProceduralAction_TimeRef(WindupId, FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(RecoverId, FCk_FloatRange_0to1(1.0f)))));

        for (const auto& Report : Reports)
        {
            if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
            { return Report; }
        }

        return utils_procedural_action_builder::Build_Into(Draft, InClip);
    }

    FCk_ProceduralAction_Phase Make_ReferencePhase(FName InPhaseId, const FMars_Crawler_ReferencePhase& InPhase)
    {
        auto Phase = FCk_ProceduralAction_Phase(InPhaseId, FCk_Time(float64(InPhase.Seconds)));
        Phase.Set_Easing(InPhase.Easing);
        return Phase;
    }

    FCk_ProceduralAction_PoseKey Make_ReferencePoseKey(float32 InTime, FTransform InBody)
    {
        auto Key = FCk_ProceduralAction_PoseKey(FCk_FloatRange_0to1(InTime));
        Key.Set_BodyMode(ECk_ProceduralAction_ValueMode::Set);
        Key.Set_Body(InBody);
        return Key;
    }

    TArray<FCk_ProceduralAction_LimbPoseTarget> Make_ClawTargets(FVector InRight, FVector InLeft)
    {
        auto Targets = TArray<FCk_ProceduralAction_LimbPoseTarget>();
        Targets.Add(FCk_ProceduralAction_LimbPoseTarget(Get_RightClawSlotId(), InRight));
        Targets.Add(FCk_ProceduralAction_LimbPoseTarget(Get_LeftClawSlotId(), InLeft));
        return Targets;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Mars.Crawler.SeedAttackClips
    //----------------------------------------------------------------------------------------------------------------------

    // Writes each reference clip that does not exist yet as <Name> under ReferenceClipFolder, remembering the crawler the
    // clip editor previews it on (Make_EditorSubject). An existing asset keeps its motion, so authored work survives a
    // re-run; one that does not remember its crawler yet is given it and saved.
    void Seed_AttackClips()
    {
        auto Layouts = TArray<EMars_Crawler_Layout>();
        Layouts.Add(EMars_Crawler_Layout::Radial);
        Layouts.Add(EMars_Crawler_Layout::Spider);
        for (const auto Layout : Layouts)
        {
            Seed_AttackClip(Layout, EMars_Crawler_AttackClipKind::Jab);
            Seed_AttackClip(Layout, EMars_Crawler_AttackClipKind::Pincer);
        }
    }

    void Seed_AttackClip(EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind)
    {
        const auto Name = Get_ReferenceClipName(InLayout, InKind);
        const auto ClipPath = f"{ReferenceClipFolder}/{Name}";
        if (EditorAsset::DoesAssetExist(ClipPath))
        {
            Seed_EditorSubject(ClipPath, InLayout, InKind);
            return;
        }

        auto Clip = Cast<UCk_ProceduralAction_Data>(CreateDataAsset(Name, UCk_ProceduralAction_Data));
        if (ck::EnsureIfNot(ck::IsValid(Clip), f"[Mars.Crawler.SeedAttackClips] Failed to create [{ClipPath}]"))
        { return; }

        const auto Report = Build_ReferenceClip(InLayout, InKind, Clip);
        if (ck::EnsureIfNot(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            f"[Mars.Crawler.SeedAttackClips] [{ClipPath}] did not build: {Get_FirstDiagnosticText(Report)}"))
        { return; }

        Clip.Set_EditorSubject(Make_EditorSubject(Clip, InLayout, InKind));
        const bool OnlyIfIsDirty = false;
        EditorAsset::SaveLoadedAsset(Clip, OnlyIfIsDirty);
        Print(f"[Mars.Crawler.SeedAttackClips] [{ClipPath}] written", 10.0f);
    }

    void Seed_EditorSubject(FString InClipPath, EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind)
    {
        auto Clip = Cast<UCk_ProceduralAction_Data>(EditorAsset::LoadAsset(InClipPath));
        if (ck::EnsureIfNot(ck::IsValid(Clip), f"[Mars.Crawler.SeedAttackClips] [{InClipPath}] is not a procedural action clip"))
        { return; }

        if (Get_IsEditorSubjectSet(Clip))
        {
            Print(f"[Mars.Crawler.SeedAttackClips] [{InClipPath}] exists; skipped", 10.0f);
            return;
        }

        Clip.Set_EditorSubject(Make_EditorSubject(Clip, InLayout, InKind));
        const bool OnlyIfIsDirty = false;
        EditorAsset::SaveLoadedAsset(Clip, OnlyIfIsDirty);
        Print(f"[Mars.Crawler.SeedAttackClips] [{InClipPath}] now remembers its crawler", 10.0f);
    }

    // A subject names a rig, a dedicated layout or an authored scenario; a clip seeded before clips remembered their
    // subject has none of them.
    bool Get_IsEditorSubjectSet(UCk_ProceduralAction_Data InClip)
    {
        const auto Subject = InClip.Get_EditorSubject();
        return Subject.Get_WalkingRig().IsNull() == false || Subject.Get_Layout().Get_Limbs().Num() > 0 ||
            Subject.Get_Scenario().IsNull() == false;
    }

    // A new asset of InClass named InName in ReferenceClipFolder. AssetTools::CreateAsset never runs the factory's
    // class-picker dialog, and a data asset factory with no DataAssetClass (script cannot set it) creates the class it is
    // given.
    UObject CreateDataAsset(FString InName, TSubclassOf<UDataAsset> InClass)
    {
        auto Factory = Cast<UDataAssetFactory>(NewObject(GetTransientPackage(), UDataAssetFactory));
        return AssetTools::CreateAsset(InName, ReferenceClipFolder, InClass, Factory);
    }

    // The crawler the clip editor previews a reference clip on: the reference rig and the layout's gait, copied into the
    // clip (the script assets they come from are not saved packages), and a pincer's claw slots bound to the first and
    // last leg. The editor derives the rest of the preview (floor, rest pose, support) from the rig.
    FCk_ProceduralAction_EditorSubject Make_EditorSubject(UCk_ProceduralAction_Data InClip, EMars_Crawler_Layout InLayout,
        EMars_Crawler_AttackClipKind InKind)
    {
        const auto SourceGait = Get_LayoutGaitData(InLayout);
        const TArray<FCk_ProceduralLeg_Spec> Legs = Get_ReferenceRig(InLayout).Get_Legs();
        auto Rig = Cast<UCk_ProceduralRig_Data>(NewObject(InClip, UCk_ProceduralRig_Data, n"SubjectRig"));
        auto Gait = Cast<UCk_ProceduralGait_Data>(NewObject(InClip, UCk_ProceduralGait_Data, n"SubjectGait"));
        Rig.Set_Legs(Legs);
        Gait.Set_Timing(SourceGait.Get_Timing());
        Gait.Set_Step(SourceGait.Get_Step());
        Gait.Set_Probe(SourceGait.Get_Probe());
        Gait.Set_Foothold(SourceGait.Get_Foothold());

        auto Subject = FCk_ProceduralAction_EditorSubject();
        Subject.Set_WalkingRig(TSoftObjectPtr<UCk_ProceduralRig_Data>(Rig));
        Subject.Set_WalkingGait(TSoftObjectPtr<UCk_ProceduralGait_Data>(Gait));
        if (InKind == EMars_Crawler_AttackClipKind::Pincer)
        {
            auto SlotBindings = TArray<FCk_ProceduralAction_SlotBinding>();
            SlotBindings.Add(FCk_ProceduralAction_SlotBinding(Get_RightClawSlotId(), Legs[0].Get_Id()));
            SlotBindings.Add(FCk_ProceduralAction_SlotBinding(Get_LeftClawSlotId(), Legs.Last().Get_Id()));
            Subject.Set_SlotBindings(SlotBindings);
        }
        return Subject;
    }
}
#endif
