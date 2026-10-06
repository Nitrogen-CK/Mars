// The shell pieces a cracked husk leaves around the crack point (UMars_ForageDebris_EntityScript).
struct FMars_Husk_DebrisSpec
{
    UPROPERTY()
    int32 Pieces = 2;

    UPROPERTY()
    float32 LifetimeSeconds = 8.0f;

    // Radial offset of each piece from the crack point (uu).
    UPROPERTY()
    float32 Scatter = 18.0f;

    UPROPERTY()
    FVector PieceScale = FVector(0.2, 0.2, 0.1);
}

// A shelled ingredient: struck in the world past CrackHealth it cracks into Kernel (UMars_WorldItem_Husk_EntityScript).
UCLASS(Meta = (DisplayName = "🌰 Husk"))
class UMars_ItemTrait_Husk : UCk_ItemTrait
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Kernel;

    UPROPERTY()
    float32 CrackHealth = 50.0f;

    // First row naming a hit's damage type wins; types with no row take DefaultMultiplier.
    UPROPERTY()
    TArray<FMars_HitZone_Reaction> Reactions;

    UPROPERTY()
    float32 DefaultMultiplier = 1.0f;

    UPROPERTY()
    FMars_Forage_LaunchSpec KernelLaunch = FMars_Forage_LaunchSpec(FVector(0.0, 0.0, 120.0));

    UPROPERTY()
    FMars_Husk_DebrisSpec Debris;
}

mixin bool Has_Husk(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Husk);
}

mixin const UMars_ItemTrait_Husk Get_Husk(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Husk);
}
