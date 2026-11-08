// R16 (one weapon hit kills, duplicated contacts deplete once, fractional damage normalised) + R21 (corpse dither and loot,
// headless half). The rat steals the Mushroom (Persistent Food). The chef strikes it with the player's real strike path -
// the cleaver's Strike trait through the chef's DamageDealer StrikeSweep - with a fractional weapon (DamageScale 0.02:
// 20 x 0.02 = 0.4 damage against Health 1) and TWICE in one step (two contacts on the one hurtbox in the same frame). The
// rat's Health depletes exactly once, the rat enters Dying exactly once, and releases the Mushroom once (one release
// operation; its own body back World with its pickup live). The corpse holds at least DeathHoldSeconds (3 s, counted
// from the death), then CorpseFade ramps FadeAlpha 1 -> 0 over CorpseFadeSeconds (0.35 s, rat clock) and the rat is
// destroyed once. The Mushroom outlives the corpse: same item, same world item, World, pickup live, never faded.
class UMars_AutoTest_PantryRat_RealStrikeKillsOnceAndTheCorpseFades : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private FCk_Handle _RatEntity;
    private FCk_Handle_DamageDealer _Dealer;
    private int32 _Depletions = 0;
    private int32 _DyingEntries = 0;
    private bool _BothSweepsHit = false;
    private float32 _DiedAt = -1.0f;
    private float32 _FadeStartedAt = -1.0f;
    private float32 _FadeEndedAt = -1.0f;
    private float32 _MinMidFade = 2.0f;
    private int32 _MidFadeSamples = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(712000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _MushroomFirst = true;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        _Dealer = Make_ChefDealer(0, 0.02f);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the Mushroom is stolen and rides the rat", n"Check_Carried", k_LongPolls, 0);
        Add_Step("two fractional real strikes in one step", n"Step_Strike");
        Add_Step_WaitUntil("the corpse is gone", n"Check_Destroyed", k_LongPolls, 0);
        Add_Step_WaitSeconds("the Mushroom outlives it", 0.5f);
        Add_Step("one depletion, one death, one release, a held then faded corpse, a live Mushroom", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent)
    {
        ++_Depletions;
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        if (InNew == EMars_PantryRat_Phase::Dying)
        {
            ++_DyingEntries;
            _DiedAt = InRat.Get_Clock();
        }

        if (InNew == EMars_PantryRat_Phase::CorpseFade)
        { _FadeStartedAt = InRat.Get_Clock(); }

        if (InNew == EMars_PantryRat_Phase::Destroyed)
        { _FadeEndedAt = InRat.Get_Clock(); }
    }

    // Samples the corpse's fade clock every frame it fades.
    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Rat) || utils_entity_lifetime::Get_IsPendingDestroy(_RatEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        if (_Rat.Get_Phase() != EMars_PantryRat_Phase::CorpseFade)
        { return; }

        const auto Fade = _Rat.Get_FadeAlpha();
        if (Fade > 0.0f && Fade < 1.0f)
        {
            ++_MidFadeSamples;
            _MinMidFade = Math::Min(_MinMidFade, Fade);
        }
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        _RatEntity = _Rat;
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_HasCarryReceipt() && _Rat.Get_Loot() == _FoodItem);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = _Rat.Get_Monster().Get_BodyHealth();
        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        _Rat.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));

        const auto First = Strike_RatAsTheChef(_Rat, 0, FVector(0.0, 1.0, 0.0));
        const auto Second = Strike_RatAsTheChef(_Rat, 0, FVector(0.0, 1.0, 0.0));
        _BothSweepsHit = First && Second;
    }

    UFUNCTION()
    private void Check_Destroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_RatEntity) || utils_entity_lifetime::Get_IsPendingDestroy(_RatEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_BothSweepsHit, "both real strike sweeps hit the rat's hurtbox (two contacts in one frame)");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 2, "the dealer dealt both contacts");
        Assert_Equals_Int(_Depletions, 1, "one Health depletion from two fractional contacts");
        Assert_Equals_Int(_DyingEntries, 1, "one Dying transition");
        Assert_True(_DiedAt >= 0.0f && _FadeStartedAt - _DiedAt >= 3.0f - 0.001f,
            f"the corpse held at least 3 s from its death (died [{_DiedAt}], fade [{_FadeStartedAt}])");
        const auto FadeSeconds = _FadeEndedAt - _FadeStartedAt;
        Assert_True(FadeSeconds >= 0.35f - 0.001f && FadeSeconds < 0.35f + 0.25f, f"the corpse faded over ~0.35 s (took [{FadeSeconds}])");
        Assert_True(_MidFadeSamples > 0 && _MinMidFade < 1.0f, f"FadeAlpha passed through (0, 1) ({_MidFadeSamples} samples, min [{_MinMidFade}])");

        FCk_Handle FoodEntity = _Food;
        Assert_True(ck::IsValid(FoodEntity) && utils_world_item::Get_IsEnding(FoodEntity) == false, "the Mushroom's world item outlives the corpse");
        Assert_True(_FoodItem.Get_PersistentWorldItem() == _Food, "the same Mushroom item on the same world item");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::World, "World");
        const FCk_Handle FoodParent = _FoodItem.Get_ParentInventory();
        FCk_Handle FoodHolder = _Food.Get_Holder();
        Assert_True(FoodParent == FoodHolder, "the Mushroom is in its own holder");
        Assert_True(ck::IsValid(_Food.Get_Pickup()) && _Food.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable,
            "its pickup is live (a hand can take it)");
    }
}
