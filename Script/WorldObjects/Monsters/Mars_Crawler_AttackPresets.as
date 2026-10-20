// The reference crawlers the attack catalog ships for: their authored asset paths under the crawler's Content folders and
// the box spec the console validator and the seeders resolve against. Runtime callers never depend on the editor
// builders; an entity script picks a reference loadout by preset (Mars_SandboxMonsters.as).
enum EMars_Crawler_AttackPreset
{
    Crawler4,
    Crawler6,
    Spider6
}

// Which reference graph a loadout, definition or clip belongs to: the parity graph or the endpoint demo. Its name is the
// graph's part of the asset name.
enum EMars_AttackReference_Kind
{
    Parity,
    EndpointDemo
}

namespace utils_crawler
{
    const FString AttackReferenceFolder = "/Game/Mars/Gameplay/Monsters/Crawler/AttackCatalog";
    const FString AttackReferenceActionsFolder = "/Game/Mars/Gameplay/Monsters/Crawler/Actions";

    // The preset console text names, ignoring case; unset for anything else.
    TOptional<EMars_Crawler_AttackPreset> TryParse_AttackPreset(FString InText)
    {
        const auto Text = InText.ToLower();
        if (Text == "crawler4")
        { return TOptional<EMars_Crawler_AttackPreset>(EMars_Crawler_AttackPreset::Crawler4); }

        if (Text == "crawler6")
        { return TOptional<EMars_Crawler_AttackPreset>(EMars_Crawler_AttackPreset::Crawler6); }

        if (Text == "spider6")
        { return TOptional<EMars_Crawler_AttackPreset>(EMars_Crawler_AttackPreset::Spider6); }

        return TOptional<EMars_Crawler_AttackPreset>();
    }

    // An armed box crawler on the preset's rig with the default anatomy (Make_AttackAnatomy). The declared 40/55 cm
    // half lengths are the validator's geometry, never a loaded look's.
    FMars_Crawler_Spec Make_AttackReferenceSpec(EMars_Crawler_AttackPreset InPreset)
    {
        auto Spec = FMars_Crawler_Spec();
        Spec.LegCount = InPreset == EMars_Crawler_AttackPreset::Crawler4 ? 4 : 6;
        Spec.Layout = InPreset == EMars_Crawler_AttackPreset::Spider6 ? EMars_Crawler_Layout::Spider : EMars_Crawler_Layout::Radial;
        Spec.Combat.Enabled = true;
        Spec.MinLegsToWalk = 3;
        Spec.Rig.BodyHalfExtents = FVector(Spec.LegCount == 4 ? 40.0 : 55.0, 30.0, 15.0);
        Spec.RoamBounds = FBox(FVector(-400.0, -400.0, -100.0), FVector(400.0, 400.0, 100.0));
        Spec.Combat.Anatomy = Make_AttackAnatomy(Spec);
        return Spec;
    }

    // The asset-name stem of one of the four reference attacks; any other tag ensures and names itself.
    FString Get_AttackReferenceName(FGameplayTag InAttackId)
    {
        if (InAttackId == GameplayTags::Attack_Mars_Pincer)
        { return "Pincer"; }

        if (InAttackId == GameplayTags::Attack_Mars_Jab)
        { return "Jab"; }

        if (InAttackId == GameplayTags::Attack_Mars_SwipeRight)
        { return "SwipeRight"; }

        if (InAttackId == GameplayTags::Attack_Mars_SwipeLeft)
        { return "SwipeLeft"; }

        ck::EnsureIfNot(false, f"[Crawler] [{InAttackId.ToString()}] is not a reference attack");
        return InAttackId.ToString();
    }

    // Each reference attack's cue profile shares its name; the entity script dresses only the pincer's today.
    FGameplayTag Get_AttackReferenceCueProfile(FGameplayTag InAttackId)
    {
        if (InAttackId == GameplayTags::Attack_Mars_Pincer)
        { return GameplayTags::AttackCue_Mars_Pincer; }

        if (InAttackId == GameplayTags::Attack_Mars_Jab)
        { return GameplayTags::AttackCue_Mars_Jab; }

        if (InAttackId == GameplayTags::Attack_Mars_SwipeRight)
        { return GameplayTags::AttackCue_Mars_SwipeRight; }

        if (InAttackId == GameplayTags::Attack_Mars_SwipeLeft)
        { return GameplayTags::AttackCue_Mars_SwipeLeft; }

        return FGameplayTag();
    }

    // The endpoint emitter that rides a claw slot.
    FGameplayTag Get_AttackReferenceClawEmitter(FName InSlot)
    {
        if (InSlot == Get_RightClawSlotId())
        { return GameplayTags::AttackEmitter_Mars_ClawRight; }

        if (InSlot == Get_LeftClawSlotId())
        { return GameplayTags::AttackEmitter_Mars_ClawLeft; }

        ck::EnsureIfNot(false, f"[Crawler] slot [{InSlot}] is not a claw slot");
        return FGameplayTag();
    }

    FString Get_AttackReferenceObjectPath(FString InFolder, FString InName)
    { return f"{InFolder}/{InName}.{InName}"; }

    FString Get_AttackReferenceLoadoutPath(EMars_Crawler_AttackPreset InPreset, EMars_AttackReference_Kind InKind)
    {
        return Get_AttackReferenceObjectPath(AttackReferenceFolder, f"{InPreset :n}_{InKind :n}Loadout_Mars_DA");
    }

    TSoftObjectPtr<UMars_AttackLoadout_Data> Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset InPreset, EMars_AttackReference_Kind InKind)
    {
        return TSoftObjectPtr<UMars_AttackLoadout_Data>(FSoftObjectPath(Get_AttackReferenceLoadoutPath(InPreset, InKind)));
    }

    FString Get_AttackReferenceDefinitionPath(EMars_Crawler_AttackPreset InPreset, EMars_AttackReference_Kind InKind, FGameplayTag InAttackId)
    {
        return Get_AttackReferenceObjectPath(AttackReferenceFolder, f"{InPreset :n}_{InKind :n}_{Get_AttackReferenceName(InAttackId)}_Mars_DA");
    }

    FString Get_AttackReferenceEndpointClipPath(EMars_Crawler_AttackPreset InPreset, FGameplayTag InAttackId)
    {
        const auto Kind = InAttackId == GameplayTags::Attack_Mars_Pincer ? "EndpointPincer" : Get_AttackReferenceName(InAttackId);
        return Get_AttackReferenceObjectPath(AttackReferenceActionsFolder, f"{InPreset :n}_{Kind}_Mars_DA");
    }

    FString Get_AttackReferenceLegacyClipPath(EMars_Crawler_AttackPreset InPreset, FGameplayTag InAttackId)
    {
        const auto Prefix = InPreset == EMars_Crawler_AttackPreset::Spider6 ? "Spider" : "Crawler";
        return Get_AttackReferenceObjectPath(AttackReferenceActionsFolder, f"{Prefix}_{Get_AttackReferenceName(InAttackId)}_Mars_DA");
    }
}

// The reference loadouts' execution policy from a reference spec. Runtime-compiled (not under Script/Editor, which is
// editor-only): the editor seeder and the catalog test fixtures both build it.
namespace utils_crawler
{
    // A pincer lifting both claws keeps at least this many enabled legs on the ground.
    const int32 PincerMinStandingLegs = 2;

    // How long the gait may take to step a released claw back onto the ground before the leg is given up as unplanted.
    const float32 PincerReturnTimeoutSeconds = 3.0f;

    // The reference loadouts' action tuning, from InSpec's reference defaults (its retired Hit and Timing). Sampling: the
    // body keeps its travel guard (no accepted sample moves it further than MaxSampleTravel); a pincer's claws travel the
    // chain's reach, so with a pincer clip the guard is raised to twice the front leg's reach (a hitch can pose a whole
    // phase in one sample). Transition: no entry blend (the windup starts at admission, from the identity offset and the
    // claws' own feet), CancelSeconds as the dedicated return a cancel eases back through, and a return timeout no
    // shorter than that return, nor than the time the gait gets to step a released claw back down.
    FCk_ProceduralAction_Tuning Make_AttackTuning(const FMars_Crawler_Spec& InSpec)
    {
        const auto& Combat = InSpec.Combat;
        const auto HasPincer = ck::IsValid(Combat.PincerClip.Get());
        auto Tuning = FCk_ProceduralAction_Tuning();

        auto Sampling = Tuning.Get_Sampling();
        Sampling.Set_MaxEndpointTravelCm(Combat.Hit.MaxSampleTravel);
        Sampling.Set_MaxSegmentAngularStepDegrees(180.0f);
        if (HasPincer)
        {
            const TArray<FCk_ProceduralLeg_Spec> Legs = InSpec.Get_RigData().Get_Legs();
            Sampling.Set_MaxEndpointTravelCm(Math::Max(Combat.Hit.MaxSampleTravel, 2.0f * Get_ChainReach(Legs[0])));
        }

        Tuning.Set_Sampling(Sampling);

        auto Transition = Tuning.Get_Transition();
        const auto CancelReturn = float64(Combat.Timing.CancelSeconds);
        Transition.Set_EntryBlend(FCk_Time(0.0));
        Transition.Set_DedicatedReturn(FCk_Time(CancelReturn));
        auto ReturnTimeout = Math::Max(Transition.Get_ReturnTimeout().Get_Seconds(), CancelReturn);
        if (HasPincer)
        { ReturnTimeout = Math::Max(ReturnTimeout, float64(PincerReturnTimeoutSeconds)); }

        Transition.Set_ReturnTimeout(FCk_Time(ReturnTimeout));
        Tuning.Set_Transition(Transition);
        return Tuning;
    }

    // How a pincer borrows the front legs (the borrowing player's terms; a walking preview of the clip copies them): the
    // player counts the legs left standing and lets them wait out the whole pincer clip and a cancel's return before a
    // step the count forbids interrupts it, and hands a claw back to the gait as a real step from wherever the action left
    // it (the windup key, when a cancel lands in the air) to where the gait wants the foot, within the attack tuning's
    // sampling budget and PincerReturnTimeoutSeconds. Needs InSpec's PincerClip loaded.
    FCk_ProceduralLimbControl_Locomotion Make_PincerLocomotion(const FMars_Crawler_Spec& InSpec)
    {
        const auto& Combat = InSpec.Combat;
        const auto CancelSeconds = float64(Combat.Timing.CancelSeconds);
        auto Support = FCk_ProceduralLimbControl_Support(ECk_ProceduralLimbControl_SupportMode::CountOnly, PincerMinStandingLegs);
        Support.Set_SupportHoldTimeout(FCk_Time(Get_ClipSeconds(Combat.PincerClip.Get()) + CancelSeconds));

        auto Return = FCk_ProceduralLimbControl_Return();
        Return.Set_Duration(FCk_Time(CancelSeconds));
        Return.Set_Timeout(FCk_Time(float64(PincerReturnTimeoutSeconds)));

        auto Locomotion = FCk_ProceduralLimbControl_Locomotion();
        Locomotion.Set_Support(Support);
        Locomotion.Set_Return(Return);
        return Locomotion;
    }
}
