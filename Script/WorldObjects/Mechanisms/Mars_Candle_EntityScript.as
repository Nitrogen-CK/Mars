// Placeable candle: a bare wick on CandleSingle_A_Mars_SM (base pivot, wick top 10 cm up), lit only by an open flame held
// to it, burning forever once lit. Candles come in numbers, so its light casts no shadow. The mesh bakes its own flame
// (its Flame slot on CandleFlame_Mars_MI), so the candle draws no Niagara and the dressing darkens the baked one instead.
class UMars_Candle_EntityScript : UMars_FlameFixture_EntityScript
{
    default _ShowInPlaceActors = true;

    // The flame's teardrop sits on the wick's tip.
    private const FVector k_FlameLocal = FVector(0.0, 0.0, 13.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (Name.IsEmpty())
        { Name = FText::FromString("Candle"); }

        Flame.Fuel.Reset();
        Flame.Enclosure = EMars_Flame_Enclosure::Open;
        Flame.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Flame.Radius.World = 800.0f;
        return Super::DoConstruct(InHandle);
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _BakedFlamePart = InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, assets::load::CandleSingle_A_Mars_SM(), nullptr,
            collision::profile::NoCollision, n"Candle_Body"));
    }

    protected FVector Get_FlameLocal() const override
    {
        return k_FlameLocal;
    }

    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.67f, 0.35f, 1.0f);
        Look.IntensityWorld = 2500.0f;
        Look.ShadowsWorld = false;
        Look.FxSize = 0.0f;
        Look.FxEmberRate = 0.0f;
        return Look;
    }
}
