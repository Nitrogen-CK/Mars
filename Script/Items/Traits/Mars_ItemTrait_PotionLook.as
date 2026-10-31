// What a potion's liquid looks like: which instance of PotionLiquid_Mars_M it wears (its colours and its static switches:
// Bubbling, Brine) and how full the flask is. Read by UMars_Potion_EntityScript; an item without it gets the defaults.
struct FMars_PotionLook
{
    // Share of the body's volume the liquid fills, 0..1 (past about 0.85 it reaches the neck).
    UPROPERTY()
    float32 Fill = 0.65f;

    // Null: PotionLiquid_Mars_MI (the green potion).
    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> LiquidMaterial;
}

UCLASS(Meta = (DisplayName = "🧪 Potion Look"))
class UMars_ItemTrait_PotionLook : UCk_ItemTrait
{
    UPROPERTY()
    FMars_PotionLook Look;
}
