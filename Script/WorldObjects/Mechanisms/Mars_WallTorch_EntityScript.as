// Placeable wall torch: an iron plate on the wall, a bracket reaching out from it and a pitch torch in the bracket, leaning
// out of the wall, its flame on the head. The origin is the mounting surface and the bracket reaches along local +X (out
// of the wall), up along +Z, like the lantern sconce. Lit only by an open flame held to it; burns forever once lit.
class UMars_WallTorch_EntityScript : UMars_FlameFixture_EntityScript
{
    default _ShowInPlaceActors = true;

    // The shaft leans this far out of the wall from upright.
    private const float64 k_ShaftTilt = 20.0;
    private const float64 k_ShaftLength = 40.0;
    // The bracket's end holds the shaft this far along it from its centre (below the centre).
    private const FVector k_BracketEnd = FVector(20.0, 0.0, -6.0);
    private const float64 k_GripAlongShaft = -8.0;

    private const FLinearColor k_Iron = FLinearColor(0.12f, 0.11f, 0.10f, 1.0f);
    private const FLinearColor k_Wood = FLinearColor(0.25f, 0.17f, 0.10f, 1.0f);
    private const FLinearColor k_Pitch = FLinearColor(0.08f, 0.06f, 0.05f, 1.0f);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (Name.IsEmpty())
        { Name = FText::FromString("Torch"); }

        Flame.Fuel.Reset();
        Flame.Enclosure = EMars_Flame_Enclosure::Open;
        Flame.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Flame.Radius.World = 800.0f;
        return Super::DoConstruct(InHandle);
    }

    // Engine shapes are 100 uu with a centered pivot. Plate: 4 x 14 x 26 on the wall; bracket: 16 x 3 x 3 out to its end;
    // shaft: a 3 cm cylinder through the bracket's end; head: a 6 x 6 x 8 block whose top is the shaft's top.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto CubeMesh = engine::load::Cube();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        auto Plate = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(2.0, 0.0, 0.0), FVector(0.04, 0.14, 0.26)),
            CubeMesh, Material, collision::profile::BlockAll, n"WallTorch_Plate");
        Plate.PrimaryColor = TOptional<FLinearColor>(k_Iron);
        InRoot.Add_MeshPart(this, Plate);

        auto Bracket = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(k_BracketEnd.X * 0.5 + 2.0, 0.0, k_BracketEnd.Z), FVector(0.16, 0.03, 0.03)),
            CubeMesh, Material, collision::profile::NoCollision, n"WallTorch_Bracket");
        Bracket.PrimaryColor = TOptional<FLinearColor>(k_Iron);
        InRoot.Add_MeshPart(this, Bracket);

        const auto Tilt = Get_ShaftRotation();
        auto Shaft = FMars_MeshPart(FTransform(Tilt, Get_ShaftCentre(), FVector(0.03, 0.03, k_ShaftLength * 0.01)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"WallTorch_Shaft");
        Shaft.PrimaryColor = TOptional<FLinearColor>(k_Wood);
        Shaft.Tint = EMars_MeshPart_Tint::ProtoGrid;
        Shaft.CastShadow = false;
        InRoot.Add_MeshPart(this, Shaft);

        auto Head = FMars_MeshPart(FTransform(Tilt, Get_ShaftTop() - Get_ShaftAxis() * 4.0, FVector(0.06, 0.06, 0.08)),
            CubeMesh, assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"WallTorch_Head");
        Head.PrimaryColor = TOptional<FLinearColor>(k_Pitch);
        Head.Tint = EMars_MeshPart_Tint::ProtoGrid;
        Head.CastShadow = false;
        InRoot.Add_MeshPart(this, Head);
    }

    protected FVector Get_FlameLocal() const override
    {
        return Get_ShaftTop();
    }

    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.55f, 0.25f, 1.0f);
        Look.IntensityWorld = 7000.0f;
        Look.ShadowsWorld = true;
        Look.FxSize = 18.0f;
        Look.FxEmberRate = 6.0f;
        return Look;
    }

    // Pitched down turns local +Z toward +X: the top leans out of the wall.
    private FRotator Get_ShaftRotation() const
    {
        return FRotator(-k_ShaftTilt, 0.0, 0.0);
    }

    private FVector Get_ShaftAxis() const
    {
        return Get_ShaftRotation().RotateVector(FVector::UpVector);
    }

    private FVector Get_ShaftCentre() const
    {
        return k_BracketEnd - Get_ShaftAxis() * k_GripAlongShaft;
    }

    private FVector Get_ShaftTop() const
    {
        return Get_ShaftCentre() + Get_ShaftAxis() * (k_ShaftLength * 0.5);
    }
}
