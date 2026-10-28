// Optional assembly art. The placed forage anchor owns this asset strongly; ECS contexts carry only a weak reference.
// All meshes use the existing normalized 100cm primitive frame and are NoCollision visual replacements.
struct FMars_ForageCenser_Presentation
{
    UPROPERTY()
    UStaticMesh BobMesh;

    UPROPERTY()
    UStaticMesh ChainMesh;

    // One combined yield mesh, including every part that disappears on exhaustion.
    UPROPERTY()
    UStaticMesh ContentsMesh;

    // Zero omits the stationary cosmetic ceiling support.
    UPROPERTY()
    float32 CeilingHeightCm = 0.0f;
}

struct FMars_ForageVine_Presentation
{
    UPROPERTY()
    UStaticMesh FigMesh;

    UPROPERTY()
    UStaticMesh BellnutMesh;

    // Stationary twine above the fruit; separate from the disappearing yield.
    UPROPERTY()
    float32 ConnectorLengthCm = 0.0f;

    UPROPERTY()
    float32 ConnectorWidthCm = 2.5f;
}

class UMars_ForagePresentation_Def : UDataAsset
{
    UPROPERTY()
    FMars_ForageCenser_Presentation Censer;

    UPROPERTY()
    FMars_ForageVine_Presentation Vine;

    UPROPERTY()
    UMaterialInterface StoneMaterial;

    UPROPERTY()
    UMaterialInterface TimberPostMaterial;

    UPROPERTY()
    UMaterialInterface TimberArmMaterial;
}
