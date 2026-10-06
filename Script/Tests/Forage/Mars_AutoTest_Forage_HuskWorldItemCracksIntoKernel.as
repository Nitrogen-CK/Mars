// A World-mode Bellnut composes its husk (Health 50, a Body zone, a hurtbox, a Forage). A Sever hit does nothing (the x0
// row); two Blunt 25 hits deplete it, which releases one kernel (Depleted), destroys the husk, and the kernel seeds as a
// World-mode BellnutKernel. The shell debris is visual and not asserted; its pieces are tracked for cleanup only (they are
// owned by the transient entity).
class UMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(-60000.0, 6000.0, -60000.0);
    private const float64 k_SpawnHeight = 30.0;
    private const float32 k_HitDamage = 25.0f;

    private FCk_Handle _Husk;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_WorldItem_Husk_EntityScript::Params();
        SpawnParams.Definition = mars_items::Bellnut();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 0.0, k_SpawnHeight));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_Husk_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnHuskConstructed"));

        Add_Step_WaitUntil("the husk is a seeded world item with a zone and a forage", n"Check_HuskComposed");
        Add_Step("bind the forage; hit the zone with Sever 25", n"Step_HitSever");
        Add_Step_WaitSeconds("the Sever hit would land in this window", 0.2f);
        Add_Step("the x0 row left the Health at 50 and released nothing; hit Blunt 25", n"Step_AssertSeverThenHitBlunt");
        Add_Step_WaitSeconds("the Blunt hit lands", 0.2f);
        Add_Step("Health 25; hit Blunt 25 again", n"Step_AssertHalfThenHitBlunt");
        Add_Step_WaitUntil("one kernel released on the depletion", n"Check_Released");
        Add_Step_WaitUntil("the husk is gone and the kernel seeded as a World-mode BellnutKernel", n"Check_HuskGoneKernelSeeded");
        Add_Step_WaitUntil("the shell debris exists (tracked for cleanup)", n"Check_DebrisTracked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHuskConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Husk = InEntityScriptHandle;
    }

    private FCk_Handle_HitZone Get_Zone()
    {
        return _Husk.As_HitZone();
    }

    UFUNCTION()
    private void Check_HuskComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Husk))
        {
            Res.Set(false);
            return;
        }

        const auto WorldItem = _Husk.As_WorldItem(ECk_SanityCheck::UnChecked);
        Res.Set(ck::IsValid(WorldItem) && ck::IsValid(WorldItem.Get_HeldItem()) && _Husk.Is_Forage() && _Husk.Is_HitZone());
    }

    UFUNCTION()
    private void Step_HitSever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Forage = _Husk.As_Forage();
        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));

        Assert_Equals_Float(Get_Zone().Get_Health().Get_Current(), 50.0f, 0.001f, "the husk starts at CrackHealth");
        Hit(GameplayTags::DamageType_Mars_Sever);
    }

    UFUNCTION()
    private void Step_AssertSeverThenHitBlunt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_Zone().Get_Health().Get_Current(), 50.0f, 0.001f, "a Sever hit does nothing (x0 row)");
        Assert_Equals_Int(_Released.Num(), 0, "nothing released yet");
        Hit(GameplayTags::DamageType_Mars_Blunt);
    }

    UFUNCTION()
    private void Step_AssertHalfThenHitBlunt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_Zone().Get_Health().Get_Current(), 25.0f, 0.001f, "a Blunt hit lands x1");
        Assert_Equals_Int(_Released.Num(), 0, "a half-cracked husk releases nothing");
        Hit(GameplayTags::DamageType_Mars_Blunt);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1 && _ReleaseReasons[0] == EMars_Forage_ReleaseReason::Depleted);
    }

    UFUNCTION()
    private void Check_HuskGoneKernelSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Husk) && _Released.Num() == 1 && Get_IsSeededWith(_Released[0], mars_items::BellnutKernel()));
    }

    UFUNCTION()
    private void Check_DebrisTracked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const UMars_ItemTrait_Husk Husk = mars_items::Bellnut().Get_ItemTraitByClass(UMars_ItemTrait_Husk);
        const auto Debris = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsForageDebris");
        if (Debris.Num() < Husk.Debris.Pieces)
        {
            Res.Set(false);
            return;
        }

        for (auto Piece : Debris)
        { Track_ForCleanup(Piece); }

        Res.Set(true);
    }

    private void Hit(FGameplayTag InDamageType)
    {
        auto Zone = Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(k_HitDamage, InDamageType)));
    }
}
