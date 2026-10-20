// Placeable vine with one fruit hanging over a basin. The origin is on the floor under the fruit; a post stands at
// local -X and an arm reaches over to the fruit, which hangs HangHeight up. A strike that empties its Health, or a
// thrown item closing on it at KnockMinSpeed or more, drops it as a world item into the basin ring; the vine regrows it
// RegrowSeconds later. Both triggers are composed here: a Health + Body zone + hurtbox for the strike and a static Jolt
// sphere at the fruit for the knock, there only while the fruit is.
UCLASS(Abstract)
class UMars_ForageVine_EntityScript : UMars_ForageSource_EntityScript
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    float32 HangHeight = 220.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 FruitRadius = 22.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 HitPoints = 1.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 RegrowSeconds = 30.0f;

    // Closing speed (uu/s) a thrown world item needs to knock the fruit down.
    UPROPERTY(ExposeOnSpawn)
    float32 KnockMinSpeed = 300.0f;

    // False skips the post, arm, fruit and basin meshes (headless tests); the zone, hurtbox and knock body stay.
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    private const float64 PostOffsetX = -120.0;
    private const float64 PostWidth = 24.0;
    // The post rises this far past the fruit to carry the arm.
    private const float64 PostOverhang = 40.0;
    private const float64 ArmThickness = 12.0;
    private const float32 BasinHalfWidth = 80.0f;
    private const float64 HurtboxMargin = 6.0;
    private const FVector FruitLaunch = FVector(0.0, 0.0, -80.0);

    protected float32 Get_KnockMinSpeed() const override
    {
        return KnockMinSpeed;
    }

    // Presets name the yield.
    protected TSoftObjectPtr<UCk_InventoryItem_Definition> Get_YieldDefinition() const
    {
        return TSoftObjectPtr<UCk_InventoryItem_Definition>();
    }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsForageVine");

        const auto FruitOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, HangHeight));
        auto FruitNode = utils_scene_node::Create(Root, FruitOffset);
        auto FruitTransform = FruitNode.As_Transform();

        // Each Add ensures on its own rejection.
        _Health = utils_health::Add(InHandle, FMars_Health_Spec(HitPoints));
        if (ck::Is_NOT_Valid(_Health))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        _Zone = utils_hit_zone::Add(InHandle, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        if (ck::Is_NOT_Valid(_Zone))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        const auto HurtboxHalfExtent = FruitRadius + HurtboxMargin;
        utils_hit_zone::AddHurtbox_Box(_Zone, Root, FMars_HitZone_Hurtbox(FVector(HurtboxHalfExtent, HurtboxHalfExtent, HurtboxHalfExtent), FruitOffset));

        auto Spec = FMars_Forage_Spec();
        Spec.Yield = FMars_Forage_YieldSpec(Get_YieldDefinition(), 1);
        Spec.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, RegrowSeconds);
        Spec.Launch = FMars_Forage_LaunchSpec(FruitLaunch);
        Spec.Parts = FMars_Forage_Parts(FruitTransform);

        _Forage = utils_forage::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(_Forage))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto KnockBody = FMars_ForageSource_KnockBody();
        KnockBody.Offset = FruitOffset;
        KnockBody.Radius = FruitRadius;
        KnockBody.MotionType = ECk_MotionType::Static;
        KnockBody.Presence = EMars_ForageSource_KnockPresence::FollowsYield;
        AddKnockBody(Root, KnockBody);

        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        BindForage();

        if (WithVisuals)
        { AddVisuals(Root, FruitTransform); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Triggers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Depleted));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals
    //----------------------------------------------------------------------------------------------------------------------

    // Engine cube and sphere are 100 uu with their pivot at the centre. The post and the basin walls are solid (a
    // collision-bearing mesh part bakes into the Jolt static world), so a dropped fruit lands inside the ring.
    protected void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Transform& InFruit)
    {
        auto CubeMesh = engine::load::Cube();
        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();

        const auto PostHeight = HangHeight + PostOverhang;
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(PostOffsetX, 0.0, PostHeight * 0.5), FVector(PostWidth, PostWidth, PostHeight) * 0.01),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"ForageVine_Post"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(PostOffsetX * 0.5, 0.0, PostHeight), FVector(Math::Abs(PostOffsetX), ArmThickness, ArmThickness) * 0.01),
            CubeMesh, WallMaterial, collision::profile::NoCollision, n"ForageVine_Arm"));

        _YieldMesh = InFruit.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector::OneVector * (FruitRadius * 2.0 * 0.01)),
            engine::load::Sphere(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"ForageVine_Fruit"));

        InRoot.Add_ForageBasinRing(this, FMars_ForageBasin_Spec(BasinHalfWidth));
    }
}

class UMars_Forage_FigVine_EntityScript : UMars_ForageVine_EntityScript
{
    protected TSoftObjectPtr<UCk_InventoryItem_Definition> Get_YieldDefinition() const override
    {
        return TSoftObjectPtr<UCk_InventoryItem_Definition>(mars_items::Fig());
    }
}

class UMars_Forage_BellnutVine_EntityScript : UMars_ForageVine_EntityScript
{
    protected TSoftObjectPtr<UCk_InventoryItem_Definition> Get_YieldDefinition() const override
    {
        return TSoftObjectPtr<UCk_InventoryItem_Definition>(mars_items::Bellnut());
    }
}
