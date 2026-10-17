// The reference crawlers the attack catalog ships for: their authored asset paths under the crawler's Content folders and
// the box spec the console validator and the seeders resolve against. Runtime callers never depend on the editor
// builders; an entity script picks a reference loadout by preset (Mars_SandboxMonsters.as).
enum EMars_Crawler_AttackPreset
{
    Crawler4,
    Crawler6,
    Spider6
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

    FString Get_AttackReferenceLoadoutPath(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo = false)
    {
        const auto Kind = InEndpointDemo ? "EndpointDemo" : "Parity";
        return Get_AttackReferenceObjectPath(AttackReferenceFolder, f"{InPreset :n}_{Kind}Loadout_Mars_DA");
    }

    TSoftObjectPtr<UMars_AttackLoadout_Data> Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo = false)
    { return TSoftObjectPtr<UMars_AttackLoadout_Data>(FSoftObjectPath(Get_AttackReferenceLoadoutPath(InPreset, InEndpointDemo))); }

    FString Get_AttackReferenceDefinitionPath(EMars_Crawler_AttackPreset InPreset, bool InEndpointDemo, FGameplayTag InAttackId)
    {
        const auto Kind = InEndpointDemo ? "EndpointDemo" : "Parity";
        return Get_AttackReferenceObjectPath(AttackReferenceFolder, f"{InPreset :n}_{Kind}_{Get_AttackReferenceName(InAttackId)}_Mars_DA");
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
