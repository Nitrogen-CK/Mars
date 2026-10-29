// Presentation only. Service definitions and the replicated party own mission data.
struct FMars_StewardService_Parchment
{
    // Service-only corrected garment weights; other Steward placements keep the original mesh.
    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> BodyMesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/Steward/Service/Steward_Service_Mars_SK.Steward_Service_Mars_SK"));

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/Game/Mars/Gameplay/Steward/Service/ServiceParchment_Mars_SM.ServiceParchment_Mars_SM"));

    UPROPERTY()
    TSoftObjectPtr<UAnimSequence> PresentLoop = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath("/Game/Mars/Gameplay/Steward/Anims/Steward_Present_Mars_AS.Steward_Present_Mars_AS"));

    // In the Steward root frame (+X forward); the mesh origin is the reading rectangle centre.
    UPROPERTY()
    FTransform Offset = FTransform(FRotator::ZeroRotator, FVector(55.0, 0.0, 175.0));

    UPROPERTY()
    FVector2D ReadingSizeCm = FVector2D(80.0, 90.0);
}

struct FMars_StewardService_View
{
    UPROPERTY()
    float32 BlendInSeconds = 0.65f;

    UPROPERTY()
    float32 BlendOutSeconds = 0.35f;

    UPROPERTY()
    float32 FieldOfView = 58.0f;
}

class UMars_StewardService_Config : UDataAsset
{
    UPROPERTY(Category = "Visuals")
    FMars_StewardService_Parchment Parchment;

    UPROPERTY(Category = "View")
    FMars_StewardService_View View;

    UPROPERTY(Category = "Widgets")
    TSoftClassPtr<UMars_ChalkService_Widget> WidgetClass = TSoftClassPtr<UMars_ChalkService_Widget>(FSoftObjectPath("/Game/Mars/UI/Widgets/Steward/ServiceParchment_Mars_WBP.ServiceParchment_Mars_WBP_C"));

    FMars_Validation Validate() const
    {
        if (Parchment.BodyMesh.IsNull() || Parchment.Mesh.IsNull() || Parchment.PresentLoop.IsNull() || WidgetClass.IsNull())
        { return FMars_Validation("Parchment mesh, present loop and widget class are required"); }
        if (Parchment.Offset.IsValid() == false || Parchment.Offset.GetScale3D().Equals(FVector::OneVector) == false)
        { return FMars_Validation("Parchment offset must be finite, normalized and unit scale"); }
        if (Math::IsFinite(Parchment.ReadingSizeCm.X) == false || Math::IsFinite(Parchment.ReadingSizeCm.Y) == false ||
            Parchment.ReadingSizeCm.X <= 0.0 || Parchment.ReadingSizeCm.Y <= 0.0)
        { return FMars_Validation("Reading dimensions must be finite and positive"); }
        if (Math::IsFinite(View.BlendInSeconds) == false || Math::IsFinite(View.BlendOutSeconds) == false ||
            View.BlendInSeconds < 0.0f || View.BlendOutSeconds < 0.0f)
        { return FMars_Validation("View blend durations must be finite and nonnegative"); }
        if (Math::IsFinite(View.FieldOfView) == false || View.FieldOfView <= 1.0f || View.FieldOfView >= 170.0f)
        { return FMars_Validation("View field of view must be finite and within (1, 170)"); }
        return FMars_Validation();
    }
}

namespace mars
{
    asset Mars_StewardService_Config of UMars_StewardService_Config
    {
        Parchment = FMars_StewardService_Parchment();
        View = FMars_StewardService_View();
        WidgetClass = TSoftClassPtr<UMars_ChalkService_Widget>(FSoftObjectPath("/Game/Mars/UI/Widgets/Steward/ServiceParchment_Mars_WBP.ServiceParchment_Mars_WBP_C"));
    }
}

// A target supplies position/orientation; its FOV modifier blends with the same layer alpha.
class UMars_CameraLayer_CampService : UCk_CameraLayer_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoEnter(FCk_Handle_CameraLayer InHandle)
    {
        utils_camera_layer::Acquire_CameraModifier_FOV(InHandle, ECk_AttributeModifier_Operation::Override,
            mars::Mars_StewardService_Config.View.FieldOfView);
    }
}
