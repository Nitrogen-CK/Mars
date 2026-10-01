#pragma once

#include "CkCore/Format/CkFormat.h"
#include "CkCore/Macros/CkMacros.h"

#include "CoreMinimal.h"
#include "CkHands_Contact_Data.generated.h"

// --------------------------------------------------------------------------------------------------------------------

UENUM(BlueprintType)
enum class ECk_Hands_ContactShapeType : uint8
{
    Box,
    Sphere,
    Capsule,

    None UMETA(DisplayName = "No Shape"),
};

CK_DEFINE_CUSTOM_FORMATTER_ENUM(ECk_Hands_ContactShapeType);

// --------------------------------------------------------------------------------------------------------------------

/**
 * A primitive the digits close on, expressed in the space of the pose being solved (component space for Control Rig
 * and anim graph nodes). Only the rotation and translation of _Transform are used; its scale is ignored, so the
 * dimensions are always in cm of that space. A Capsule's cylinder section runs along the shape's local Z, _HalfHeight
 * on each side of the origin (the cylinder section only, as UE capsules and FCk_Jolt_ShapeDimensions define it).
 */
USTRUCT(BlueprintType)
struct CKHANDS_API FCk_Hands_ContactShape
{
    GENERATED_BODY()

public:
    CK_GENERATED_BODY(FCk_Hands_ContactShape);

private:
    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Type"))
    ECk_Hands_ContactShapeType _Type = ECk_Hands_ContactShapeType::None;

    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Transform",
                      EditCondition = "_Type != ECk_Hands_ContactShapeType::None", EditConditionHides))
    FTransform _Transform = FTransform::Identity;

    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Half Extents",
                      EditCondition = "_Type == ECk_Hands_ContactShapeType::Box", EditConditionHides))
    FVector _HalfExtents = FVector::ZeroVector;

    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Radius", Units = "cm", ClampMin = "0.0",
                      EditCondition = "_Type == ECk_Hands_ContactShapeType::Sphere || _Type == ECk_Hands_ContactShapeType::Capsule",
                      EditConditionHides))
    float _Radius = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Half Height", Units = "cm", ClampMin = "0.0",
                      EditCondition = "_Type == ECk_Hands_ContactShapeType::Capsule", EditConditionHides))
    float _HalfHeight = 0.0f;

public:
    CK_PROPERTY(_Type);
    CK_PROPERTY(_Transform);
    CK_PROPERTY(_HalfExtents);
    CK_PROPERTY(_Radius);
    CK_PROPERTY(_HalfHeight);

public:
    CK_DEFINE_CONSTRUCTORS(FCk_Hands_ContactShape, _Type, _Transform);
};

// --------------------------------------------------------------------------------------------------------------------

// How one digit is tested against a contact shape.
USTRUCT(BlueprintType)
struct CKHANDS_API FCk_Hands_DigitContactSettings
{
    GENERATED_BODY()

public:
    CK_GENERATED_BODY(FCk_Hands_DigitContactSettings);

private:
    // Digit thickness. Also the spacing of the contact samples along the digit and the furthest any sample may move
    // between two curl search steps.
    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Radius", Units = "cm", ClampMin = "0.01", UIMin = "0.01"))
    float _Radius = 1.3f;

    // Upper bound of the curl search resolution; the step count is chosen from how far the digit travels.
    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Max Search Steps", ClampMin = "2", UIMin = "2"))
    int32 _MaxSearchSteps = 32;

    // The last segment has no child bone to measure; its length is this fraction of its own offset from its parent.
    UPROPERTY(EditAnywhere, BlueprintReadWrite,
              meta = (AllowPrivateAccess = true, DisplayName = "Tip Length Ratio", ClampMin = "0.0", UIMin = "0.0"))
    float _TipLengthRatio = 0.9f;

public:
    CK_PROPERTY(_Radius);
    CK_PROPERTY(_MaxSearchSteps);
    CK_PROPERTY(_TipLengthRatio);

public:
    CK_DEFINE_CONSTRUCTORS(FCk_Hands_DigitContactSettings, _Radius, _MaxSearchSteps, _TipLengthRatio);
};

// --------------------------------------------------------------------------------------------------------------------
