#include "CkHands_Utils.h"

#include "CkHands/CkHands_Kernel.h"

#include "CkCore/Ensure/CkEnsure.h"

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_utils
{
    auto
        DoMake_Shape(
            const FCk_Hands_ContactShape& InShape)
        -> FCk_Hands_ContactShape
    {
        const auto IsShapeValid = ck::hands::Get_IsShapeValid(InShape);
        CK_ENSURE_IF_NOT(IsShapeValid,
            TEXT("Hands Utils Make rejected an invalid [{}] contact shape: Transform [{}], HalfExtents [{}], Radius [{}], HalfHeight [{}]"),
            InShape.Get_Type(), InShape.Get_Transform(), InShape.Get_HalfExtents(), InShape.Get_Radius(), InShape.Get_HalfHeight())
        { return FCk_Hands_ContactShape{}; }

        return InShape;
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    UCk_Utils_Hands_ContactShape_UE::
    Make_Box(
        const FTransform& InTransform,
        const FVector& InHalfExtents)
    -> FCk_Hands_ContactShape
{
    return ck_hands_utils::DoMake_Shape(FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Box, InTransform}.Set_HalfExtents(InHalfExtents));
}

auto
    UCk_Utils_Hands_ContactShape_UE::
    Make_Sphere(
        const FTransform& InTransform,
        float InRadius)
    -> FCk_Hands_ContactShape
{
    return ck_hands_utils::DoMake_Shape(FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, InTransform}.Set_Radius(InRadius));
}

auto
    UCk_Utils_Hands_ContactShape_UE::
    Make_Capsule(
        const FTransform& InTransform,
        float InHalfHeight,
        float InRadius)
    -> FCk_Hands_ContactShape
{
    return ck_hands_utils::DoMake_Shape(FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Capsule, InTransform}
        .Set_HalfHeight(InHalfHeight)
        .Set_Radius(InRadius));
}

auto
    UCk_Utils_Hands_ContactShape_UE::
    Get_IsValid(
        const FCk_Hands_ContactShape& InShape)
    -> bool
{
    return ck::hands::Get_IsShapeValid(InShape);
}

auto
    UCk_Utils_Hands_ContactShape_UE::
    Get_SignedDistance(
        const FCk_Hands_ContactShape& InShape,
        const FVector& InPoint)
    -> double
{
    const auto IsShapeValid = ck::hands::Get_IsShapeValid(InShape);
    CK_ENSURE_IF_NOT(IsShapeValid, TEXT("Hands Utils Get_SignedDistance rejected an invalid [{}] contact shape"), InShape.Get_Type())
    { return TNumericLimits<double>::Max(); }

    return ck::hands::Get_SignedDistance(InShape, InPoint);
}

auto
    UCk_Utils_Hands_ContactShape_UE::
    Get_InSpace(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InSpace)
    -> FCk_Hands_ContactShape
{
    const auto IsShapeValid = ck::hands::Get_IsShapeValid(InShape);
    CK_ENSURE_IF_NOT(IsShapeValid, TEXT("Hands Utils Get_InSpace rejected an invalid [{}] contact shape"), InShape.Get_Type())
    { return InShape; }

    return ck::hands::Get_ShapeInSpace(InShape, InSpace);
}

// --------------------------------------------------------------------------------------------------------------------

auto
    UCk_Utils_Hands_UE::
    Get_IsSettingsValid(
        const FCk_Hands_DigitContactSettings& InSettings)
    -> bool
{
    return ck::hands::Get_IsSettingsValid(InSettings);
}

auto
    UCk_Utils_Hands_UE::
    Solve_DigitCurl(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InParent,
        const TArray<FTransform>& InRest,
        const TArray<FTransform>& InPose,
        const FCk_Hands_DigitContactSettings& InSettings)
    -> float
{
    return ck::hands::Solve_DigitCurl(InShape, InParent, InRest, InPose, InSettings);
}

// --------------------------------------------------------------------------------------------------------------------
