// One ISM renderer per tint, each with its own LitMetal MID.
struct FMars_Crawler_TintedRenderer
{
    UPROPERTY()
    FLinearColor Color;

    UPROPERTY()
    UCk_IsmRenderer_Data Renderer;
}

// Placeable crawler (Room 5): a 4- or 6-legged procedural walker whose every leg is a body part. This script owns the
// visuals: it builds the presentation, segment and foot transform entities (each a DIRECT lifetime child of the root, as
// the rig requires) with ISM box visuals tinted Color, then hands them to utils_crawler::Add in Spec.Rig, which composes
// the walker, the monster, the leg parts and their hurtboxes. Render scale lives on the ISM proxies, never on the
// entities: the gait, the rig and Jolt use the unscaled transforms.
class UMars_Crawler_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // An unset (empty) RoamBounds becomes +-400 around the spawn at construction.
    UPROPERTY(ExposeOnSpawn)
    FMars_Crawler_Spec Spec;

    // The body tint; the leg segments darken along the chain.
    UPROPERTY(ExposeOnSpawn)
    FLinearColor Color = FLinearColor(0.75f, 0.35f, 0.2f, 1.0f);

    // False builds the same rig entities with no ISM visuals: headless autotests (no compiled look material under
    // -nullrhi, and the transient ISM renderers would outlive the test's entity subtree).
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    private const float64 DefaultRoamHalfExtent = 400.0;
    private const float64 DefaultRoamHalfHeight = 200.0;
    private const float64 SegmentHalfThickness = 6.0;
    private const float64 FootHalfExtent = 8.0;

    // Created on first use of each tint.
    private TArray<FMars_Crawler_TintedRenderer> _Renderers;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // First: the crawler's sub-SM resolves ck::Ctx to this root only if the override precedes every child.
        InHandle.Request_OverrideToSelf();

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_handle::Set_DebugName(InHandle, FName(f"Crawler{Spec.LegCount}"));

        // Before any rig entity or visual is built: only some leg counts have a rig asset.
        auto RigData = utils_crawler::Get_RigData(Spec.LegCount);
        if (ck::EnsureIfNot(ck::IsValid(RigData), f"[Crawler] [{InHandle.ToString()}] has LegCount [{Spec.LegCount}]; only 4 and 6 have rigs"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto CrawlerSpec = Spec;
        if (CrawlerSpec.RoamBounds.Max.X <= CrawlerSpec.RoamBounds.Min.X || CrawlerSpec.RoamBounds.Max.Y <= CrawlerSpec.RoamBounds.Min.Y)
        {
            const auto Half = FVector(DefaultRoamHalfExtent, DefaultRoamHalfExtent, DefaultRoamHalfHeight);
            CrawlerSpec.RoamBounds = FBox(SpawnTransform.GetLocation() - Half, SpawnTransform.GetLocation() + Half);
        }

        CrawlerSpec.Rig = BuildRig(InHandle, RigData);
        utils_crawler::Add(Root, CrawlerSpec);
        utils_entity_tag::Add(InHandle, n"TAG_MarsCrawler");

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Rig
    //----------------------------------------------------------------------------------------------------------------------

    // The presentation (the body visual, sagged by the body pose) and, per leg of the rig asset, its segment boxes
    // (Length/2 x 6 x 6, centred, +X along the segment) and a foot box.
    private FMars_Crawler_Rig BuildRig(FCk_Handle& InRoot, UCk_ProceduralRig_Data InRigData)
    {
        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = InRigData.Get_Legs();

        auto Rig = FMars_Crawler_Rig();
        Rig.BodyHalfExtents = LegSpecs.Num() == 6 ? FVector(55.0, 30.0, 15.0) : FVector(40.0, 30.0, 15.0);
        Rig.Presentation = AddVisual(InRoot, Rig.BodyHalfExtents, Color);

        const auto FootHalfExtents = FVector(FootHalfExtent, FootHalfExtent, FootHalfExtent);
        const auto FootColor = FLinearColor(0.85f, 0.85f, 0.8f, 1.0f);

        for (const auto& LegSpec : LegSpecs)
        {
            auto LegRig = FMars_Crawler_LegRig();
            LegRig.LegId = LegSpec.Get_Id();

            const auto Lengths = LegSpec.Get_Chain().Get_SegmentLengths();
            for (int32 Index = 0; Index < Lengths.Num(); ++Index)
            {
                const auto HalfExtents = FVector(Lengths[Index] * 0.5, SegmentHalfThickness, SegmentHalfThickness);
                auto Shade = Color * (1.0 - 0.25 * Index);
                Shade.A = 1.0f;

                LegRig.Segments.Add(AddVisual(InRoot, HalfExtents, Shade));
                LegRig.SegmentHalfExtents.Add(HalfExtents);
            }

            LegRig.Foot = AddVisual(InRoot, FootHalfExtents, FootColor);
            LegRig.SegmentHalfExtents.Add(FootHalfExtents);
            Rig.Legs.Add(LegRig);
        }

        return Rig;
    }

    // A direct lifetime child of InRoot with a transform at the spawn and an ISM box of InHalfExtents. The visual is
    // optional: without a renderer (no world, no RHI) the entity still exists for the rig.
    private FCk_Handle_Transform AddVisual(FCk_Handle& InRoot, FVector InHalfExtents, FLinearColor InColor)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InRoot);
        auto Transform = utils_transform::Add(Entity, SpawnTransform, ECk_Replication::DoesNotReplicate);

        if (WithVisuals == false)
        { return Transform; }

        auto Renderer = GetOrCreate_Renderer(InRoot, InColor);
        if (ck::IsValid(Renderer))
        {
            auto ProxySpec = FCk_IsmProxy_Spec(Renderer);
            // Engine cube: 100 uu side, 50 uu half extent.
            ProxySpec.Set_ScaleMultiplier(InHalfExtents / 50.0);
            utils_ism_proxy::Add(Transform, ProxySpec);
        }

        return Transform;
    }

    // NewObject-backed MIDs need a world; hence a method on the entity script, not on the feature.
    private UCk_IsmRenderer_Data GetOrCreate_Renderer(FCk_Handle& InRoot, FLinearColor InColor)
    {
        for (const auto& Tinted : _Renderers)
        {
            if (Tinted.Color.Equals(InColor) && ck::IsValid(Tinted.Renderer))
            { return Tinted.Renderer; }
        }

        auto EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InRoot);
        if (ck::Is_NOT_Valid(EntityWorld))
        { return nullptr; }

        auto Mesh = engine::load::Cube();
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[Crawler] [{InRoot.ToString()}] could not load the engine cube"))
        { return nullptr; }

        auto Material = utils_usf::Create_MID_ForLook(CkUsf::LitMetal, EntityWorld);
        if (ck::Is_NOT_Valid(Material))
        { return nullptr; }

        utils_usf::Set_Vector(Material, n"ColorA", InColor);
        utils_usf::Set_Vector(Material, n"ColorB", InColor);
        utils_usf::Set_Scalar(Material, n"Tiles", 0.0f);

        auto Overrides = TArray<FCk_MeshMaterialOverride>();
        Overrides.Add(FCk_MeshMaterialOverride(0, Material));
        auto Renderer = utils_ism_renderer_transient_factory::GetOrCreate_ForMeshWithMaterials(EntityWorld, Mesh, Overrides, ECk_Mobility::Movable);
        if (ck::Is_NOT_Valid(Renderer))
        { return nullptr; }

        auto Tinted = FMars_Crawler_TintedRenderer();
        Tinted.Color = InColor;
        Tinted.Renderer = Renderer;
        _Renderers.Add(Tinted);
        return Renderer;
    }
}
