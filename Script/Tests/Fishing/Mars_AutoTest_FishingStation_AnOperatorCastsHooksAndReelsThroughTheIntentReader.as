// An operator fishes the real fishing station through its intent reader. The station is spawned through its entity script
// (engine primitives, a fast kernel: a half-second bite, a wide hook window, a quick reel, no runs) with its water at the
// floor; the operator rig's carrier takes it through its Use interaction, which puts the gloves on the rod's grips and
// opens the Free view. Interact_Primary is then tapped on the carrier's own key stack: the station's aim reader casts on
// the release (a tap = the minimum power); the bait lands and a fish bites; a fresh press strikes the hook; a held press
// reels the line in until the fish lands; the landing task drops the catch on the bank as a world item and collects the spot.
// Back leaves the station with the line in. Isolated origin (176000, -70000, -30000).
class UMars_AutoTest_FishingStation_AnOperatorCastsHooksAndReelsThroughTheIntentReader : UMars_AutoTestRig_Operator
{
    default _TimeoutSeconds = 60.0f;

    private const FVector k_Origin = FVector(176000.0, -70000.0, -30000.0);
    // Behind the stand, facing the bank.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    // A poll budget, not a ceiling: the station constructs, the bait flies and the fish is reeled over seconds.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Fishing _Fishing;
    private int32 _Casts = 0;
    private int32 _Bites = 0;
    private int32 _Lands = 0;
    private int32 _Collects = 0;
    private FMars_Fishing_Catch _LastCollected;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_Origin + k_CarrierLocal);

        auto SpawnParams = UMars_FishingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        SpawnParams.Fishing.Launch.MaxDistanceCm = 300.0f;
        SpawnParams.Fishing.Launch.MinDistanceCm = 100.0f;
        SpawnParams.Fishing.Bite.MinWaitSeconds = 0.5f;
        SpawnParams.Fishing.Bite.MaxWaitSeconds = 0.5f;
        SpawnParams.Fishing.Bite.HookWindowSeconds = 3.0f;
        SpawnParams.Fishing.Reel.ReelSpeedCmPerS = 400.0f;
        SpawnParams.Fishing.Reel.HookSetSeconds = 0.1f;
        SpawnParams.Fishing.Run.MinGapSeconds = 100.0f;
        SpawnParams.Fishing.Run.MaxGapSeconds = 100.0f;
        SpawnParams.Fishing.Run.PullCmPerS = 0.0f;
        SpawnParams.Fishing.Fish.LandFlingSeconds = 0.3f;
        SpawnParams.Fishing.Fish.Table.Add(FMars_Fishing_FishEntry(utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab()), 1.0f, 1.0f));
        SpawnParams.Fishing.Water.SurfaceZ = k_Origin.Z;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_FishingStation_EntityScript, SpawnParams);
        auto StationEntity = Pending.Get_EntityUnderConstruction();
        StationEntity.Request_OverrideToSelf();
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Fishing", n"Check_StationReady", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the spot is engaged", n"Check_Engaged", 0, 0);
        Add_Step("press Primary to charge", n"Step_PressPrimary");
        Add_Step_WaitUntil("the Primary row is held", n"Check_PrimaryHeld", 0, 0);
        Add_Step_WaitSeconds("a short charge", 0.2f);
        Add_Step("release Primary to cast", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the bait is on the water", n"Check_Waiting", k_SlowPolls, 0);
        Add_Step("the tap cast the bait", n"Step_AssertCast");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite", k_SlowPolls, 0);
        Add_Step("press Primary to strike the hook", n"Step_PressPrimary");
        Add_Step_WaitUntil("the fight is on and the held press reels", n"Check_ReelingHeld", k_SlowPolls, 0);
        Add_Step_WaitUntil("the fish lands", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("release Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the catch is collected and the spot is Idle", n"Check_Collected", k_SlowPolls, 0);
        Add_Step("the catch reached the carrier", n"Step_AssertCaught");
        Add_Step("press Back", n"Step_PressBack");
        Add_Step_WaitUntil("the carrier left the station", n"Check_Left", k_SlowPolls, 0);
        Add_Step("release Back", n"Step_ReleaseBack");
        Add_Step_WaitUntil("the control's exit disengaged the spot", n"Check_Disengaged", k_SlowPolls, 0);
        Add_Step("leaving pulled the line in", n"Step_AssertLeft");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        Watch_Station(InEntityScriptHandle.As_Station());
        _Fishing = InEntityScriptHandle.As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Fishing))
        { return; }

        _Fishing.BindTo_OnCast(FMars_Delegate_Fishing_OnCast(this, n"OnCast"));
        _Fishing.BindTo_OnBite(FMars_Delegate_Fishing_OnBite(this, n"OnBite"));
        _Fishing.BindTo_OnLanded(FMars_Delegate_Fishing_OnLanded(this, n"OnLanded"));
        _Fishing.BindTo_OnCollected(FMars_Delegate_Fishing_OnCollected(this, n"OnCollected"));
    }

    UFUNCTION()
    private void OnCast(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity)
    {
        ++_Casts;
    }

    UFUNCTION()
    private void OnBite(FCk_Handle_Fishing InFishing)
    {
        ++_Bites;
    }

    UFUNCTION()
    private void OnLanded(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        ++_Lands;
    }

    UFUNCTION()
    private void OnCollected(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        ++_Collects;
        _LastCollected = InCatch;
    }

    UFUNCTION()
    private void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Station) && ck::IsValid(_Fishing));
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_IsOperatedBy(_Carrier) && _Fishing.Get_IsEngaged());
    }

    UFUNCTION()
    private void Step_PressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_ReleasePrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Check_PrimaryHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary));
    }

    UFUNCTION()
    private void Check_Waiting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Waiting);
    }

    UFUNCTION()
    private void Step_AssertCast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Casts, 1, "the charged press cast once");
        const auto Spec = _Fishing.Get_Spec();
        const auto Length = _Fishing.Get_LineLengthCm();
        Assert_True(Length >= Spec.Launch.MinDistanceCm - 5.0f && Length <= Spec.Launch.MaxDistanceCm + 40.0f,
            f"the bait landed inside the cast's range ({Length} cm)");
        Assert_True(_Fishing.Get_Bait().Position.X > k_Origin.X + 50.0, "the bait went out along the bank's +X");
    }

    UFUNCTION()
    private void Check_Bite(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Bite);
    }

    UFUNCTION()
    private void Check_ReelingHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Reeling && _Fishing.Get_Reel() == EMars_Fishing_Reel::Held);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lands >= 1);
    }

    UFUNCTION()
    private void Check_Collected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Collects >= 1 && _Fishing.Get_Phase() == EMars_Fishing_Phase::Idle);
    }

    UFUNCTION()
    private void Step_AssertCaught(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bites, 1, "one bite");
        Assert_Equals_Int(_Lands, 1, "one landing");
        Assert_Equals_Int(_Collects, 1, "one collect");
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, "the spot tallied one fish");
        Assert_True(_LastCollected.Item.Get() == mars_items::Food_MeatSlab(), "the catch is the table's item");
        Assert_True(_Station.Get_IsOperatedBy(_Carrier), "the carrier still operates the station");
        Assert_True(Get_HasHint("hold to charge, let go to cast"), "the rod's row is back to the cast");
    }

    UFUNCTION()
    private void Step_PressBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Step_ReleaseBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_Left(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_IsOperated() == false);
    }

    UFUNCTION()
    private void Check_Disengaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_IsEngaged() == false);
    }

    UFUNCTION()
    private void Step_AssertLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Station.Get_IsOperated(), "the station is free");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "the line is in");
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, "the tally stays");
    }
}
