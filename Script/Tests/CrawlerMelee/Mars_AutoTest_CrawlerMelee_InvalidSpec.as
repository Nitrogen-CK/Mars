// A malformed enabled combat profile rejects the whole crawler, and a disabled one changes nothing.
//   - Validate() names the first broken rule of an enabled profile (a loadout whose jab clip's strike end key is
//     rotated; an AcquireRadius beyond the LoseRadius; no Loadout; a retired clip still named) and ignores every field of
//     a disabled one, however broken.
//   - A crawler spawned with either broken profile is rejected with one ensure before anything is composed (the entity
//     script's loadout resolution, or utils_crawler::Add): its root carries no crawler feature, no combat fragment and no
//     damage dealer.
//   - A crawler spawned with the default (disabled) profile composes no combat: it is a crawler, it is not armed, and its
//     root carries no combat fragment and no damage dealer.
// The two rejections are expected errors of this test's hand-authored wrapper at the bottom of the file.
class UMars_AutoTest_CrawlerMelee_InvalidSpec : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-270000.0, -150000.0, 600.0);

    private FCk_Handle _RotatedKeyRoot;
    private FCk_Handle _BadRadiiRoot;
    private FCk_Handle _DisabledRoot;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnWall(InHandle, _Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));

        SpawnCrawler(InHandle, Make_RotatedKeySpec(), n"OnRotatedKeyConstructed");
        SpawnCrawler(InHandle, Make_BadRadiiSpec(), n"OnBadRadiiConstructed");
        SpawnCrawler(InHandle, Make_DisabledSpec(), n"OnDisabledConstructed");

        Add_Step("Validate() names the broken rule of an enabled profile and ignores a disabled one", n"Step_AssertValidate");
        Add_Step_WaitUntil("the three crawlers' entity scripts have constructed", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step_WaitFrames("let any deferred composition settle", 10);
        Add_Step("the broken profiles composed nothing; the disabled one composed an unarmed crawler", n"Step_AssertComposition");
        Run_Steps(InHandle);
    }

    // The reference jab with its strike end key yawed 30 degrees, built once.
    private UCk_ProceduralAction_Data _RotatedJab;

    private FMars_Crawler_Spec Make_RotatedKeySpec()
    {
        if (ck::Is_NOT_Valid(_RotatedJab))
        { _RotatedJab = Build_DerivedClip(Make_DraftWithRotatedStrike(Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab))); }

        auto Spec = Make_ArmedCrawlerSpec(4);
        Wear_DerivedClip(Spec, GameplayTags::Attack_Mars_Jab, _RotatedJab);
        return Spec;
    }

    private FMars_Crawler_Spec Make_BadRadiiSpec()
    {
        auto Spec = Make_ArmedCrawlerSpec(4);
        Spec.Combat.Targeting.AcquireRadius = 1000.0f;
        Spec.Combat.Targeting.LoseRadius = 900.0f;
        return Spec;
    }

    private FMars_Crawler_Spec Make_DisabledSpec() const
    {
        return FMars_Crawler_Spec(4, FBox(_Origin - FVector(150.0, 150.0, 200.0), _Origin + FVector(150.0, 150.0, 200.0)));
    }

    private void SpawnCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec, FName InConstructed)
    {
        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, InConstructed));
    }

    UFUNCTION()
    private void OnRotatedKeyConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _RotatedKeyRoot = InEntityScriptHandle;
    }

    UFUNCTION()
    private void OnBadRadiiConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _BadRadiiRoot = InEntityScriptHandle;
    }

    UFUNCTION()
    private void OnDisabledConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _DisabledRoot = InEntityScriptHandle;
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_RotatedKeyRoot) && ck::IsValid(_BadRadiiRoot) && ck::IsValid(_DisabledRoot));
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Rotated = Make_RotatedKeySpec().Combat.Validate();
        Assert_True(Rotated.IsValid() == false && Rotated.Get_Error().Contains("StrikeEndRotation"),
            f"a loadout whose jab clip has a rotated strike key is rejected (got [{Rotated.Get_Error()}])");

        const auto BadRadii = Make_BadRadiiSpec().Combat.Validate();
        Assert_True(BadRadii.IsValid() == false && BadRadii.Get_Error().Contains("AcquireRadius"),
            f"an AcquireRadius beyond the LoseRadius is rejected (got [{BadRadii.Get_Error()}])");

        auto NoLoadout = Make_ArmedCrawlerSpec(4).Combat;
        NoLoadout.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>();
        const auto Loadoutless = NoLoadout.Validate();
        Assert_True(Loadoutless.IsValid() == false && Loadoutless.Get_Error().Contains("no Loadout"),
            f"an enabled profile without a Loadout is rejected (got [{Loadoutless.Get_Error()}])");

        auto Retired = Make_ArmedCrawlerSpec(4).Combat;
        Retired.JabClip = Make_SoftClip(Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab));
        const auto RetiredClip = Retired.Validate();
        Assert_True(RetiredClip.IsValid() == false && RetiredClip.Get_Error().Contains("JabClip") && RetiredClip.Get_Error().Contains("author a Loadout"),
            f"an enabled profile that still names a retired clip is rejected (got [{RetiredClip.Get_Error()}])");

        auto Disabled = Make_RotatedKeySpec().Combat;
        Disabled.Enabled = false;
        Disabled.Targeting.AcquireRadius = -1.0f;
        Disabled.Timing.CancelSeconds = 0.0f;
        Assert_True(Disabled.Validate().IsValid(), "a disabled profile is not checked, however broken");

        const auto Reference = Make_ArmedCrawlerSpec(4).Combat.Validate();
        Assert_True(Reference.IsValid(), f"an enabled profile on its reference loadout passes (got [{Reference.Get_Error()}])");
    }

    private void Assert_NoCombat(FString InLabel, FCk_Handle InRoot)
    {
        Assert_False(InRoot.Has_Fragment(FMars_Fragment_Crawler_Combat), f"{InLabel}: no combat fragment");
        Assert_False(InRoot.Has_Fragment(FMars_Fragment_Crawler_Attack), f"{InLabel}: no attack fragment");
        Assert_False(InRoot.Has_Fragment(FMars_Fragment_Crawler_AttackObservations), f"{InLabel}: no observations fragment");
        Assert_False(InRoot.Has_Fragment(FMars_Fragment_Crawler_Targeting), f"{InLabel}: no targeting fragment");
        Assert_False(InRoot.Has_Fragment(FMars_Feature_DamageDealer), f"{InLabel}: no damage dealer");
    }

    UFUNCTION()
    private void Step_AssertComposition(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_RotatedKeyRoot.Has_Fragment(FMars_Feature_Crawler), "the rotated-key crawler was rejected: no crawler feature");
        Assert_NoCombat("rotated key", _RotatedKeyRoot);
        Assert_False(_BadRadiiRoot.Has_Fragment(FMars_Feature_Crawler), "the bad-radii crawler was rejected: no crawler feature");
        Assert_NoCombat("bad radii", _BadRadiiRoot);

        Assert_True(_DisabledRoot.Has_Fragment(FMars_Feature_Crawler), "the disabled-profile crawler composed");
        Assert_NoCombat("disabled profile", _DisabledRoot);
        if (_DisabledRoot.Has_Fragment(FMars_Feature_Crawler))
        { Assert_False(_DisabledRoot.As_Crawler().Get_IsCombatArmed(), "the disabled-profile crawler is not armed"); }
    }
}

// Hand-authored so the two expected rejections (the entity script's loadout resolution and utils_crawler::Add ensure on a
// malformed enabled combat profile) are expected errors rather than failures. Pinned to each rule's own wording, so any
// other rejection still fails the test.
class AMars_AutoTest_CrawlerMelee_InvalidSpec_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_CrawlerMelee_InvalidSpec;
    default _TimeoutSeconds = 40.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("StrikeEndRotation at Combat.Loadout.");
        Out.Add("rejected the spec: Crawler combat has an AcquireRadius");
        return Out;
    }
}
