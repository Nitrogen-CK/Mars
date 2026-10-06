// A World-mode item that cracks: Health, a Body zone with the Husk trait's reactions, a hurtbox over the mesh and a
// Forage that releases the kernel once and destroys the husk. The strike adapter is composed here: the Health's
// depletion requests the release. Visual mode composes nothing of this (a held or bagged nut has no body).
//
// A half-cracked nut picked up and dropped again composes fresh, at full CrackHealth.
class UMars_WorldItem_Husk_EntityScript : UMars_WorldItem_EntityScript
{
    private const float64 k_HurtboxMargin = 5.0;
    private const int32 k_CrackBurstBehavior = 13; // SparksBurst
    private const float32 k_CrackBurstSize = 0.6f;
    private const float32 k_CrackBurstColorIntensity = 0.3f;

    private FCk_Handle_Forage _Forage;
    private FCk_Handle_Transform _Root;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // The base destroys the entity on a bad definition; nothing to add then.
        if (InHandle.Is_WorldItem() == false || Mode != EMars_WorldItem_Mode::World)
        { return Flow; }

        auto WorldItem = InHandle.As_WorldItem();
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Husk Husk = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Husk);
        if (ck::EnsureIfNot(ck::IsValid(Husk), f"[Husk] [{InHandle.ToString()}] a Husk world item needs a Husk trait on [{Definition.ToString()}]"))
        { return Flow; }

        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(WorldItem);
        if (ck::EnsureIfNot(ck::IsValid(Presentation), f"[Husk] [{InHandle.ToString()}] needs a Presentation trait to fit its hurtbox"))
        { return Flow; }

        // Each Add ensures on its own rejection.
        auto Health = utils_health::Add(InHandle, FMars_Health_Spec(Husk.CrackHealth));
        if (ck::Is_NOT_Valid(Health))
        { return Flow; }

        auto ZoneSpec = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body);
        ZoneSpec.Reactions = Husk.Reactions;
        ZoneSpec.DefaultMultiplier = Husk.DefaultMultiplier;
        auto Zone = utils_hit_zone::Add(InHandle, ZoneSpec);
        if (ck::Is_NOT_Valid(Zone))
        { return Flow; }

        _Root = InHandle.As_Transform();
        const auto Fit = utils_world_item::Make_BoundsFit(Presentation);
        const auto Margin = FVector(k_HurtboxMargin, k_HurtboxMargin, k_HurtboxMargin);
        utils_hit_zone::AddHurtbox_Box(Zone, _Root, FMars_HitZone_Hurtbox(Fit.HalfExtents + Margin, FTransform(FRotator::ZeroRotator, Fit.Centre)));

        auto Spec = FMars_Forage_Spec();
        Spec.Yield = FMars_Forage_YieldSpec(Husk.Kernel, 1);
        Spec.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Destroyed);
        Spec.Launch = Husk.KernelLaunch;
        Spec.Parts = FMars_Forage_Parts(_Root);

        _Forage = utils_forage::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(_Forage))
        { return Flow; }

        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnCracked"));

        return Flow;
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Depleted));
    }

    // Shell pieces ringed around the crack point, owned by the transient entity (the husk dies this frame), and a puff.
    UFUNCTION()
    private void OnCracked(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Husk Husk = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Husk);
        const UMars_ItemTrait_Presentation Presentation = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto CrackPoint = RootWorld.GetLocation();

        auto Owner = ck::TransientEntity();
        const auto Debris = Husk.Debris;
        for (int32 Index = 0; Index < Debris.Pieces; ++Index)
        {
            const auto AngleRad = Math::DegreesToRadians(Index * 360.0 / Debris.Pieces);
            const auto Offset = FVector(Math::Cos(AngleRad), Math::Sin(AngleRad), 0.0) * Debris.Scatter;

            auto PieceParams = UMars_ForageDebris_EntityScript::Params();
            PieceParams.SpawnTransform = FTransform(FRotator::ZeroRotator, CrackPoint + Offset);
            PieceParams.Mesh = engine::Sphere();
            PieceParams.Material = Presentation.Visual.MaterialOverride;
            PieceParams.Scale = Debris.PieceScale;
            PieceParams.LifetimeSeconds = Debris.LifetimeSeconds;
            utils_entity_script::Request_SpawnEntity(Owner, UMars_ForageDebris_EntityScript, PieceParams);
        }

        // A cold template skips the puff rather than stall the game thread; null under nullrhi.
        if (utils_particles::Get_IsBehaviorTemplateReady(k_CrackBurstBehavior) == false)
        { return; }

        auto Burst = utils_particles::Spawn_BehaviorAtLocation(k_CrackBurstBehavior, CrackPoint, RootWorld.Rotator());
        if (ck::Is_NOT_Valid(Burst))
        { return; }

        // Nothing outlives the husk to destroy the component: it goes once the burst finishes.
        Burst.SetAutoDestroy(true);
        utils_particles::Request_ApplyTuningValues(Burst, k_CrackBurstSize, k_CrackBurstColorIntensity, 1.0f, 1.0f);
    }
}
