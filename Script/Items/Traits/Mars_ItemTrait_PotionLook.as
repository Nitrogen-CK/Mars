// What holds a potion's liquid: the vessel sets the mesh, the liquid inside it and how the fill becomes a level.
enum EMars_PotionVessel
{
    // The round-bottom flask (PotionFlask_Mars_SM): a sphere of liquid, held by the neck.
    Flask,
    // The pickle jar (PickleJar_Mars_SM): a cylinder of liquid, held round the body; wear a liquid instance with the Pickle
    // Jar switch on (PickleJarBrine_Mars_MI).
    Jar
}

// What a potion's liquid looks like: which instance of PotionLiquid_Mars_M it wears (its colours and its static switches:
// Bubbling, Brine, Pickle Jar), how full the vessel is, and which vessel. Read by UMars_Potion_EntityScript; an item
// without it gets the defaults.
struct FMars_PotionLook
{
    // Share of the vessel's volume the liquid fills, 0..1 (in the flask, past about 0.85 it reaches the neck).
    UPROPERTY()
    float32 Fill = 0.65f;

    // Null: PotionLiquid_Mars_MI (the green potion).
    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> LiquidMaterial;

    UPROPERTY()
    EMars_PotionVessel Vessel = EMars_PotionVessel::Flask;
}

UCLASS(Meta = (DisplayName = "🧪 Potion Look"))
class UMars_ItemTrait_PotionLook : UCk_ItemTrait
{
    UPROPERTY()
    FMars_PotionLook Look;
}
