// One movable editor assembly: board, support, local render surface and camera endpoint.
// Actor origin is the board centre, +X points out of its face. Camera pose is local to it.
class AMars_MenuBoardStation : AMars_CampStationCamera
{
    UPROPERTY(DefaultComponent, Attach = SceneComponent)
    UWidgetComponent MenuSurface;
    // These are stationary menus, so Slate owns the real pointer and keyboard (including text editing).
    default MenuSurface.bReceiveHardwareInput = true;
    default MenuSurface.bHiddenInGame = true;
    default MenuSurface.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    UPROPERTY(DefaultComponent, Attach = SceneComponent)
    UStaticMeshComponent Backing;

    UPROPERTY(DefaultComponent, Attach = SceneComponent)
    UStaticMeshComponent Support;

    UPROPERTY(EditAnywhere, Category = "Menu Board", meta = (ClampMin = "1.0"))
    FVector2D BoardSizeCm = FVector2D(180.0, 200.0);

    UPROPERTY(EditAnywhere, Category = "Menu Board", meta = (ClampMin = "0.0"))
    float SupportHeightCm = 55.0;

    UPROPERTY(EditAnywhere, Category = "Menu Board", meta = (ClampMin = "1.0", ClampMax = "10.0"))
    float PixelsPerCm = 5.0;

    UPROPERTY(EditAnywhere, Category = "Menu Camera")
    FVector CameraOffset = FVector(360.0, 0.0, 0.0);

    UPROPERTY(EditAnywhere, Category = "Menu Camera")
    FRotator CameraRotation = FRotator(0.0, 180.0, 0.0);

    UPROPERTY(EditAnywhere, Category = "Menu Camera", meta = (ClampMin = "30.0", ClampMax = "100.0"))
    float32 FieldOfView = 65.0f;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    { RefreshAssembly(); }

    // Also callable by scoped editor authoring after setting instance properties.
    UFUNCTION(CallInEditor)
    void RefreshAssembly()
    {
        const float Width = Math::Max(1.0, BoardSizeCm.X);
        const float Height = Math::Max(1.0, BoardSizeCm.Y);
        const float Resolution = Math::Clamp(PixelsPerCm, 1.0, 10.0);
        const float PlinthHeight = Math::Max(0.0, SupportHeightCm);
        CameraComponent.SetRelativeLocation(CameraOffset);
        CameraComponent.SetRelativeRotation(CameraRotation);
        CameraComponent.SetFieldOfView(FieldOfView);
        CameraComponent.AspectRatio = 16.0f / 9.0f;
        CameraComponent.bConstrainAspectRatio = true;
        MenuSurface.SetDrawSize(FVector2D(Math::RoundToInt(Width * Resolution), Math::RoundToInt(Height * Resolution)));
        MenuSurface.SetRelativeScale3D(FVector(1.0 / Resolution));
        MenuSurface.SetWidgetSpace(EWidgetSpace::World);
        MenuSurface.SetTwoSided(false);
        Backing.SetStaticMesh(engine::load::Cube());
        Backing.SetRelativeLocation(FVector(-7.0, 0.0, 0.0));
        Backing.SetRelativeScale3D(FVector(0.12, (Width + 14.0) / 100.0, (Height + 14.0) / 100.0));
        Support.SetStaticMesh(engine::load::Cube());
        Support.SetRelativeLocation(FVector(-18.0, 0.0, -(Height + PlinthHeight) * 0.5));
        Support.SetRelativeScale3D(FVector(0.78, (Width + 30.0) / 100.0, Math::Max(0.01, PlinthHeight) / 100.0));
        Support.SetVisibility(PlinthHeight > 0.0);
        Support.SetCollisionEnabled(PlinthHeight > 0.0 ? ECollisionEnabled::QueryAndPhysics : ECollisionEnabled::NoCollision);
    }
}

