// Editor-only: the crawler's reference attack clips, the motion the crawler shipped with before its clips became authored
// assets, and Mars.Crawler.SeedAttackClips, which writes them as the starting assets under
// /Game/Mars/Gameplay/Monsters/Crawler/Actions/, each remembering the crawler it is previewed on. The CrawlerMelee tests
// build their clips here too, so they never depend on content an author tunes.
//
// Four clips, all three phases Windup, Strike and Recover over one Offense window, the body channel from the identity
// offset (the attack definition's clip contract, utils_attack::Validate_Definition): the body-only jab and the rearing pincer, each on the radial layout (valid
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
    // The rig a reference clip is authored on and previewed with: the radial clips on the four-leg rig (Room 5's radial
    // crawler), the spider's on its own.
    UCk_ProceduralRig_Data Get_ReferenceRig(EMars_Crawler_Layout InLayout)
    {
        return InLayout == EMars_Crawler_Layout::Spider ? utils_crawler::Mars_SpiderRig6 : utils_crawler::Mars_CrawlerRig4;
    }

    // The reference clip's object path, the one the attack catalog's legacy definitions load: a radial layout's clip is
    // shared by both radial presets, so Crawler4 names it.
    FString Get_ReferenceClipPath(EMars_Crawler_Layout InLayout, EMars_Crawler_AttackClipKind InKind)
    {
        const auto Preset = InLayout == EMars_Crawler_Layout::Spider ? EMars_Crawler_AttackPreset::Spider6 : EMars_Crawler_AttackPreset::Crawler4;
        const auto AttackId = InKind == EMars_Crawler_AttackClipKind::Pincer ? GameplayTags::Attack_Mars_Pincer : GameplayTags::Attack_Mars_Jab;
        return Get_AttackReferenceLegacyClipPath(Preset, AttackId);
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

    // Writes each reference clip that does not exist yet at Get_ReferenceClipPath, remembering the crawler the clip editor
    // previews it on (Make_EditorSubject, pinned so the save keeps it). An existing asset keeps its motion, so authored
    // work survives a re-run; one that does not remember its crawler yet is given it and saved.
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
        const auto ClipPath = Get_ReferenceClipPath(InLayout, InKind);
        if (EditorAsset::DoesAssetExist(ClipPath))
        {
            Seed_EditorSubject(ClipPath, InLayout, InKind);
            return;
        }

        auto Clip = Cast<UCk_ProceduralAction_Data>(Create_DataAsset(ClipPath, AttackReferenceActionsFolder, UCk_ProceduralAction_Data));
        if (ck::EnsureIfNot(ck::IsValid(Clip), f"[Mars.Crawler.SeedAttackClips] Failed to create [{ClipPath}]"))
        { return; }

        const auto Report = Build_ReferenceClip(InLayout, InKind, Clip);
        if (ck::EnsureIfNot(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            f"[Mars.Crawler.SeedAttackClips] [{ClipPath}] did not build: {Get_FirstDiagnosticText(Report)}"))
        { return; }

        if (ck::EnsureIfNot(Set_PinnedPreviewSubject(Clip, Make_EditorSubject(Clip, InLayout, InKind)),
            f"[Mars.Crawler.SeedAttackClips] [{ClipPath}] refused its preview pins"))
        { return; }

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

        if (ck::EnsureIfNot(Set_PinnedPreviewSubject(Clip, Make_EditorSubject(Clip, InLayout, InKind)),
            f"[Mars.Crawler.SeedAttackClips] [{InClipPath}] refused its preview pins"))
        { return; }

        const bool OnlyIfIsDirty = false;
        EditorAsset::SaveLoadedAsset(Clip, OnlyIfIsDirty);
        Print(f"[Mars.Crawler.SeedAttackClips] [{InClipPath}] now remembers its crawler", 10.0f);
    }

    // A subject names a rig, a dedicated layout or an authored scenario; a clip seeded before clips remembered their
    // subject has none of them.
    bool Get_IsEditorSubjectSet(UCk_ProceduralAction_Data InClip)
    {
        const auto EditorData = utils_procedural_action_editor::TryGet_EditorData(InClip);
        if (EditorData == nullptr)
        { return false; }
        const auto Subject = EditorData.Get_Subject();
        return Subject.Get_WalkingRig().IsNull() == false || Subject.Get_Layout().Get_Limbs().Num() > 0 ||
            Subject.Get_Scenario().IsNull() == false;
    }

    // A new asset of InClass at the object path InPath, in InFolder. AssetTools::CreateAsset never runs the factory's
    // class-picker dialog, and a data asset factory with no DataAssetClass (script cannot set it) creates the class it is
    // given.
    UObject Create_DataAsset(FString InPath, FString InFolder, TSubclassOf<UDataAsset> InClass)
    {
        auto Factory = Cast<UDataAssetFactory>(NewObject(GetTransientPackage(), UDataAssetFactory));
        return AssetTools::CreateAsset(FSoftObjectPath(InPath).GetAssetName(), InFolder, InClass, Factory);
    }

    // A preview subject walking a copy of InLegs with a copy of InSourceGait, both embedded in the clip's editor data (the
    // script assets they come from are not saved packages, and the runtime clip must not carry them). Soft references
    // only: a seeder that saves the clip pins them with Set_PinnedPreviewSubject.
    FCk_ProceduralActionEditor_Subject Make_EmbeddedPreviewSubject(UCk_ProceduralAction_Data InClip,
        const TArray<FCk_ProceduralLeg_Spec>& InLegs, UCk_ProceduralGait_Data InSourceGait)
    {
        auto EditorData = utils_procedural_action_editor::Get_EditorData(InClip);
        auto Rig = Cast<UCk_ProceduralRig_Data>(NewObject(EditorData, UCk_ProceduralRig_Data, n"SubjectRig"));
        auto Gait = Cast<UCk_ProceduralGait_Data>(NewObject(EditorData, UCk_ProceduralGait_Data, n"SubjectGait"));
        Rig.Set_Legs(InLegs);
        Gait.Set_Timing(InSourceGait.Get_Timing());
        Gait.Set_Step(InSourceGait.Get_Step());
        Gait.Set_Probe(InSourceGait.Get_Probe());
        Gait.Set_Foothold(InSourceGait.Get_Foothold());

        auto Subject = FCk_ProceduralActionEditor_Subject();
        Subject.Set_WalkingRig(TSoftObjectPtr<UCk_ProceduralRig_Data>(Rig));
        Subject.Set_WalkingGait(TSoftObjectPtr<UCk_ProceduralGait_Data>(Gait));
        return Subject;
    }

    // Sets InSubject on the clip and hard-pins its embedded rig and gait, without which the save drops them. Editor only,
    // outside PIE; false when the pins are refused.
    bool Set_PinnedPreviewSubject(UCk_ProceduralAction_Data InClip, const FCk_ProceduralActionEditor_Subject& InSubject)
    {
        utils_procedural_action_editor::Get_EditorData(InClip).Set_Subject(InSubject);
        return UMars_AttackPreviewOwnership::Attach_EmbeddedPreviewObjects(InClip, InSubject.Get_WalkingRig().Get(), InSubject.Get_WalkingGait().Get());
    }

    // The crawler the clip editor previews a reference clip on: the reference rig and the layout's gait, and a pincer's
    // claw slots bound to the first and last leg. The editor derives the rest of the preview (floor, rest pose, support)
    // from the rig.
    FCk_ProceduralActionEditor_Subject Make_EditorSubject(UCk_ProceduralAction_Data InClip, EMars_Crawler_Layout InLayout,
        EMars_Crawler_AttackClipKind InKind)
    {
        const TArray<FCk_ProceduralLeg_Spec> Legs = Get_ReferenceRig(InLayout).Get_Legs();
        auto Subject = Make_EmbeddedPreviewSubject(InClip, Legs, Get_LayoutGaitData(InLayout));
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

#if EDITOR
// One claw's swipe keys in the root's frame: the swipe references and the endpoint pincer, authored independently of the
// reference pincer.
struct FMars_Crawler_ReferenceSwipeKeys
{
    bool Valid = false;
    FName Slot;
    FName LimbId;
    FVector Rest;
    FVector Windup;
    FVector StrikeEntry;
    FVector StrikeAcross;
    FVector StrikeEnd;
    FVector RecoverLift;
}

// The reference rig a reference clip is authored against.
struct FMars_Crawler_ReferenceBody
{
    EMars_Crawler_Layout Layout = EMars_Crawler_Layout::Radial;
    int32 LegCount = 4;

    FMars_Crawler_ReferenceBody() {}

    FMars_Crawler_ReferenceBody(EMars_Crawler_Layout InLayout, int32 InLegCount)
    {
        Layout = InLayout;
        LegCount = InLegCount;
    }
}

namespace utils_crawler
{
    // Endpoint emitters use radius 12 cm. The additional 5 cm is a reference-pose margin, measured again on accepted
    // endpoint receipts by the endpoint catalog tests. It is not permission to ignore floor hits or stretch trace budgets.
    const float64 ReferenceEndpointClawClearance = 17.0;

    // Select by stable reference ID so changing asset array order cannot borrow another leg.
    FMars_Crawler_ReferenceSwipeKeys Make_ReferenceSwipeKeys(const FMars_Crawler_ReferenceBody& InBody, EMars_Crawler_Side InSide)
    {
        auto Keys = FMars_Crawler_ReferenceSwipeKeys();
        if (InBody.Layout != EMars_Crawler_Layout::Radial && InBody.Layout != EMars_Crawler_Layout::Spider)
        { return Keys; }
        const auto Rig = Get_LayoutRigData(InBody.Layout, InBody.LegCount);
        if (ck::Is_NOT_Valid(Rig))
        { return Keys; }
        const auto IsRight = InSide == EMars_Crawler_Side::Right;
        Keys.Slot = IsRight ? Get_RightClawSlotId() : Get_LeftClawSlotId();
        Keys.LimbId = IsRight ? n"Leg0" : FName(f"Leg{InBody.LegCount - 1}");
        for (const auto& Leg : Rig.Get_Legs())
        {
            if (Leg.Get_Id() != Keys.LimbId)
            { continue; }
            const auto Hip = Leg.Get_Placement().Get_HipLocal();
            const auto Reach = float64(Get_ChainReach(Leg));
            const auto Side = IsRight ? 1.0 : -1.0;
            Keys.Rest = Leg.Get_Placement().Get_RestFootLocal();
            const auto Floor = Keys.Rest.Z + ReferenceEndpointClawClearance;
            // Outward/back relative to the strike, with the foot raised. Strike closes across the front in three
            // segments; Recover lifts outward before placing this same foot at its own authored rest position.
            Keys.Windup = Hip + FVector(0.20, Side * 0.55, 0.30) * Reach;
            Keys.StrikeEntry = Hip + FVector(0.48, Side * 0.40, -0.15) * Reach;
            Keys.StrikeAcross = Hip + FVector(0.65, Side * 0.06, -0.20) * Reach;
            Keys.StrikeEnd = Hip + FVector(0.70, -Side * 0.06, -0.20) * Reach;
            Keys.RecoverLift = Hip + FVector(0.28, Side * 0.50, 0.08) * Reach;
            Keys.StrikeEntry.Z = Math::Max(Keys.StrikeEntry.Z, Floor);
            Keys.StrikeAcross.Z = Math::Max(Keys.StrikeAcross.Z, Floor);
            Keys.StrikeEnd.Z = Math::Max(Keys.StrikeEnd.Z, Floor);
            Keys.RecoverLift.Z = Math::Max(Keys.RecoverLift.Z, Floor);
            Keys.Valid = true;
            return Keys;
        }
        return Keys;
    }

    FCk_ProceduralAction_PoseKey Make_ReferenceSwipePoseKey(float32 InTime, FTransform InBody, const FCk_ProceduralAction_LimbPoseTarget& InClaw)
    {
        auto Key = Make_ReferencePoseKey(InTime, InBody);
        auto Limbs = TArray<FCk_ProceduralAction_LimbPoseTarget>();
        Limbs.Add(InClaw);
        Key.Set_Limbs(Limbs);
        return Key;
    }

    // Three supported reference morphologies: Radial4, Radial6 and Spider6. One claimed RootAtStart slot, independent
    // windup/strike/recovery keys, body pitch <=10 degrees, identity Strike end and Recover rotations, linear channels.
    // Build_Into leaves the destination untouched unless every public builder step and final compilation succeeds.
    FCk_ProceduralAction_ValidationReport Build_ReferenceSwipeClip(const FMars_Crawler_ReferenceBody& InBody, EMars_Crawler_Side InSide,
        UCk_ProceduralAction_Data InClip)
    {
        const auto Keys = Make_ReferenceSwipeKeys(InBody, InSide);
        if (Keys.Valid == false)
        {
            auto Diagnostics = TArray<FCk_ProceduralAction_Diagnostic>();
            Diagnostics.Add(FCk_ProceduralAction_Diagnostic(ECk_ProceduralAction_DiagnosticSeverity::Error,
                n"ReferenceSwipeRigUnsupported", "", "ReferenceSwipe.Rig", NAME_None, NAME_None, -1,
                "Radial4, Radial6 or Spider6 with the named front leg", f"{InBody.Layout :n} {InBody.LegCount}"));
            return FCk_ProceduralAction_ValidationReport(ECk_ProceduralAction_ReportStatus::Invalid, Diagnostics);
        }
        const auto Size = float64(Get_LayoutSizeScale(InBody.Layout));
        const auto WindupBody = FTransform(FRotator(10.0, 0.0, 0.0), FVector(-4.0, 0.0, 4.0) * Size, FVector::OneVector);
        const auto EntryBody = FTransform(FRotator(7.0, 0.0, 0.0), FVector(0.0, 0.0, 3.0) * Size, FVector::OneVector);
        const auto AcrossBody = FTransform(FRotator::ZeroRotator, FVector(8.0, 0.0, 0.0) * Size, FVector::OneVector);
        const auto StrikeBody = FTransform(FRotator::ZeroRotator, FVector(9.0, 0.0, 0.0) * Size, FVector::OneVector);
        const auto RecoverBody = FTransform(FRotator::ZeroRotator, FVector(2.0, 0.0, 2.0) * Size, FVector::OneVector);
        const auto WindupId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup);
        const auto StrikeId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike);
        const auto RecoverId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover);
        auto Draft = FCk_ProceduralAction_ClipDraft();
        auto Reports = TArray<FCk_ProceduralAction_ValidationReport>();
        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        Body.Set_InitialSource(ECk_ProceduralAction_InitialSource::IdentityOffset);
        Reports.Add(utils_procedural_action_builder::Set_BodyChannel(Draft, Body));
        Reports.Add(utils_procedural_action_builder::Add_Slot(Draft, FCk_ProceduralAction_Slot(Keys.Slot)));
        Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Keys.Slot, ECk_ProceduralAction_TrackSpace::RootAtStart));

        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(WindupId,
            FMars_Crawler_ReferencePhase(0.45f, ECk_ProceduralAction_Easing::OutCubic, WindupBody))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, WindupId, Make_ReferencePoseKey(0.0f, FTransform::Identity)));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, WindupId,
            Make_ReferenceSwipePoseKey(1.0f, WindupBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.Windup))));

        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(StrikeId,
            FMars_Crawler_ReferencePhase(0.18f, ECk_ProceduralAction_Easing::InQuad, StrikeBody))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId,
            Make_ReferenceSwipePoseKey(0.0f, WindupBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.Windup))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId,
            Make_ReferenceSwipePoseKey(0.25f, EntryBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.StrikeEntry))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId,
            Make_ReferenceSwipePoseKey(0.75f, AcrossBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.StrikeAcross))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, StrikeId,
            Make_ReferenceSwipePoseKey(1.0f, StrikeBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.StrikeEnd))));

        Reports.Add(utils_procedural_action_builder::Add_Phase(Draft, Make_ReferencePhase(RecoverId,
            FMars_Crawler_ReferencePhase(0.55f, ECk_ProceduralAction_Easing::InOutCubic, FTransform::Identity))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, RecoverId,
            Make_ReferenceSwipePoseKey(0.0f, StrikeBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.StrikeEnd))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, RecoverId,
            Make_ReferenceSwipePoseKey(0.35f, RecoverBody, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.RecoverLift))));
        Reports.Add(utils_procedural_action_builder::Add_PoseKey(Draft, RecoverId,
            Make_ReferenceSwipePoseKey(1.0f, FTransform::Identity, FCk_ProceduralAction_LimbPoseTarget(Keys.Slot, Keys.Rest))));

        Reports.Add(utils_procedural_action_builder::Add_Window(Draft, FCk_ProceduralAction_Window(Get_OffenseWindowId(),
            FCk_ProceduralAction_TimeRef(WindupId, FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(RecoverId, FCk_FloatRange_0to1(1.0f)))));
        Add_EndpointClawWindows(Draft, Reports);
        for (const auto& Report : Reports)
        {
            if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
            { return Report; }
        }
        return utils_procedural_action_builder::Build_Into(Draft, InClip);
    }

    // The Strike-phase Damage window and the ClawSweep window an endpoint claw's emitters read. The initial planted
    // endpoint and the final replant are deliberately outside ClawSweep; Offense stays full length for the lifecycle.
    void Add_EndpointClawWindows(FCk_ProceduralAction_ClipDraft& InOutDraft, TArray<FCk_ProceduralAction_ValidationReport>& InOutReports)
    {
        const auto WindupId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup);
        const auto StrikeId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike);
        const auto RecoverId = Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover);
        InOutReports.Add(utils_procedural_action_builder::Add_Window(InOutDraft, FCk_ProceduralAction_Window(n"Damage",
            FCk_ProceduralAction_TimeRef(StrikeId, FCk_FloatRange_0to1(0.25f)),
            FCk_ProceduralAction_TimeRef(StrikeId, FCk_FloatRange_0to1(0.75f)))));
        InOutReports.Add(utils_procedural_action_builder::Add_Window(InOutDraft, FCk_ProceduralAction_Window(n"ClawSweep",
            FCk_ProceduralAction_TimeRef(WindupId, FCk_FloatRange_0to1(0.80f)),
            FCk_ProceduralAction_TimeRef(RecoverId, FCk_FloatRange_0to1(0.25f)))));
    }

    // Metadata only; caller sets it on a NEW owned clip. This function neither seeds nor saves an asset.
    FCk_ProceduralActionEditor_Subject Make_ReferenceSwipeEditorSubject(UCk_ProceduralAction_Data InClip,
        const FMars_Crawler_ReferenceBody& InBody, EMars_Crawler_Side InSide)
    {
        const auto Keys = Make_ReferenceSwipeKeys(InBody, InSide);
        if (Keys.Valid == false)
        { return FCk_ProceduralActionEditor_Subject(); }

        const TArray<FCk_ProceduralLeg_Spec> Legs = Get_LayoutRigData(InBody.Layout, InBody.LegCount).Get_Legs();
        auto Subject = Make_EmbeddedPreviewSubject(InClip, Legs, Get_LayoutGaitData(InBody.Layout));
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        Bindings.Add(FCk_ProceduralAction_SlotBinding(Keys.Slot, Keys.LimbId));
        Subject.Set_SlotBindings(Bindings);
        return Subject;
    }

    FCk_ProceduralAction_ValidationReport Make_ReferenceEndpointPincerError(FString InActual)
    {
        auto Diagnostics = TArray<FCk_ProceduralAction_Diagnostic>();
        Diagnostics.Add(FCk_ProceduralAction_Diagnostic(ECk_ProceduralAction_DiagnosticSeverity::Error,
            n"ReferenceEndpointPincerContract", "", "ReferenceEndpointPincer", NAME_None, NAME_None, -1,
            "separate destination, valid reference pincer source, Radial4/Radial6/Spider6 rig", InActual));
        return FCk_ProceduralAction_ValidationReport(ECk_ProceduralAction_ReportStatus::Invalid, Diagnostics);
    }

    // Opt-in endpoint pincer: copy the supplied legacy reference through the public draft surface. Neither the source
    // object nor its saved package is changed. Keep its body motion/timings and two claws; clear each claw against its
    // own current rig rest-floor, hold the raised Strike endpoint through early Recover, then recover to its own rest.
    FCk_ProceduralAction_ValidationReport Build_ReferenceEndpointPincerClip(const FMars_Crawler_ReferenceBody& InBody,
        UCk_ProceduralAction_Data InSource, UCk_ProceduralAction_Data InClip)
    {
        const auto Right = Make_ReferenceSwipeKeys(InBody, EMars_Crawler_Side::Right);
        const auto Left = Make_ReferenceSwipeKeys(InBody, EMars_Crawler_Side::Left);
        if (Right.Valid == false || Left.Valid == false || ck::Is_NOT_Valid(InSource) || InSource == InClip)
        { return Make_ReferenceEndpointPincerError("unsupported rig, missing source or shared destination"); }
        const auto Compiled = utils_procedural_action::Validate_Data(InSource);
        if (Compiled.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { return Make_ReferenceEndpointPincerError(f"the source does not compile: {Get_FirstDiagnosticText(Compiled)}"); }
        auto Draft = FCk_ProceduralAction_ClipDraft();
        const auto Copy = utils_procedural_action_builder::Make_Draft_FromData(InSource, Draft);
        if (Copy.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { return Copy; }
        auto Phases = Draft.Get_Phases();
        for (const auto& Phase : Phases)
        {
            const auto Tracks = Phase.Get_LimbTracks();
            if (Tracks.Num() != 2)
            { return Make_ReferenceEndpointPincerError("each reference phase needs both claw tracks"); }
            auto HasRight = false;
            auto HasLeft = false;
            for (const auto& Track : Tracks)
            {
                HasRight = HasRight || Track.Get_Slot() == Right.Slot;
                HasLeft = HasLeft || Track.Get_Slot() == Left.Slot;
                if (Track.Get_PositionKeys().Num() == 0)
                { return Make_ReferenceEndpointPincerError("each reference claw track needs position keys"); }
            }
            if (HasRight == false || HasLeft == false)
            { return Make_ReferenceEndpointPincerError("each reference phase needs ClawRight and ClawLeft"); }
        }
        auto StrikeRight = FVector::ZeroVector;
        auto StrikeLeft = FVector::ZeroVector;
        for (int32 PhaseIndex = 0; PhaseIndex < Phases.Num(); ++PhaseIndex)
        {
            auto Phase = Phases[PhaseIndex];
            auto Tracks = Phase.Get_LimbTracks();
            for (int32 TrackIndex = 0; TrackIndex < Tracks.Num(); ++TrackIndex)
            {
                auto Track = Tracks[TrackIndex];
                const auto Rest = Track.Get_Slot() == Right.Slot ? Right.Rest : Left.Rest;
                const auto Floor = Rest.Z + ReferenceEndpointClawClearance;
                auto Positions = Track.Get_PositionKeys();
                if (Phase.Get_Id() == Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover))
                {
                    const auto Strike = Track.Get_Slot() == Right.Slot ? StrikeRight : StrikeLeft;
                    Positions.Empty();
                    Positions.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), Strike));
                    Positions.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.25f), Strike));
                    Positions.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), Rest));
                }
                else
                {
                    for (int32 KeyIndex = 0; KeyIndex < Positions.Num(); ++KeyIndex)
                    {
                        auto Key = Positions[KeyIndex];
                        auto Position = Key.Get_Value();
                        Position.Z = Math::Max(Position.Z, Floor);
                        Key.Set_Value(Position);
                        Positions[KeyIndex] = Key;
                    }
                    if (Phase.Get_Id() == Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike))
                    {
                        if (Track.Get_Slot() == Right.Slot)
                        { StrikeRight = Positions.Last().Get_Value(); }
                        else
                        { StrikeLeft = Positions.Last().Get_Value(); }
                    }
                }
                Track.Set_PositionKeys(Positions);
                // Linear interpolation and reject-unreachable keep the authored clearance argument meaningful.
                // Native solved/accepted geometry is still measured before this reference is approved for gameplay.
                Track.Set_Interpolation(ECk_ProceduralAction_Interpolation::Linear);
                Track.Set_ReachPolicy(ECk_ProceduralAction_ReachPolicy::RejectUnreachable);
                Tracks[TrackIndex] = Track;
            }
            Phase.Set_LimbTracks(Tracks);
            Phases[PhaseIndex] = Phase;
        }
        Draft.Set_Phases(Phases);
        auto Reports = TArray<FCk_ProceduralAction_ValidationReport>();
        Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Right.Slot, ECk_ProceduralAction_TrackSpace::RootAtStart));
        Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Left.Slot, ECk_ProceduralAction_TrackSpace::RootAtStart));
        Add_EndpointClawWindows(Draft, Reports);
        for (const auto& Report : Reports)
        {
            if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
            { return Report; }
        }
        return utils_procedural_action_builder::Build_Into(Draft, InClip);
    }

    FCk_ProceduralActionEditor_Subject Make_ReferenceEndpointPincerEditorSubject(UCk_ProceduralAction_Data InClip,
        const FMars_Crawler_ReferenceBody& InBody)
    {
        const auto Right = Make_ReferenceSwipeKeys(InBody, EMars_Crawler_Side::Right);
        const auto Left = Make_ReferenceSwipeKeys(InBody, EMars_Crawler_Side::Left);
        auto Subject = Make_ReferenceSwipeEditorSubject(InClip, InBody, EMars_Crawler_Side::Right);
        if (Right.Valid == false || Left.Valid == false)
        { return Subject; }
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        Bindings.Add(FCk_ProceduralAction_SlotBinding(Right.Slot, Right.LimbId));
        Bindings.Add(FCk_ProceduralAction_SlotBinding(Left.Slot, Left.LimbId));
        Subject.Set_SlotBindings(Bindings);
        return Subject;
    }

    // The swipe whose claw is InAttackId's (SwipeRight: the right claw).
    EMars_Crawler_Side Get_ReferenceSwipeSide(FGameplayTag InAttackId)
    {
        return InAttackId == GameplayTags::Attack_Mars_SwipeRight ? EMars_Crawler_Side::Right : EMars_Crawler_Side::Left;
    }
}
#endif
