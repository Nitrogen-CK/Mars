#pragma once

#include "CkHands/CkHands_Contact_Data.h"

#include <Kismet/BlueprintFunctionLibrary.h>

#include "CkHands_Utils.generated.h"

// --------------------------------------------------------------------------------------------------------------------

UCLASS(NotBlueprintable, Meta = (ScriptMixin = "FCk_Hands_ContactShape"))
class CKHANDS_API UCk_Utils_Hands_ContactShape_UE : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    CK_GENERATED_BODY(UCk_Utils_Hands_ContactShape_UE);

public:
    // Each maker ensures and returns a None shape when the result would be invalid (Get Is Valid): negative or
    // non-finite dimensions, or a non-finite transform or unnormalized rotation.
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Make Box Contact Shape")
    static FCk_Hands_ContactShape
    Make_Box(
        const FTransform& InTransform,
        const FVector& InHalfExtents);

    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Make Sphere Contact Shape")
    static FCk_Hands_ContactShape
    Make_Sphere(
        const FTransform& InTransform,
        float InRadius);

    // The cylinder section runs along the shape's local Z, InHalfHeight on each side of the origin.
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Make Capsule Contact Shape")
    static FCk_Hands_ContactShape
    Make_Capsule(
        const FTransform& InTransform,
        float InHalfHeight,
        float InRadius);

    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Get Is Valid")
    static bool
    Get_IsValid(
        const FCk_Hands_ContactShape& InShape);

    // Negative inside; a very large positive value for a None shape. An invalid shape ensures and returns that same
    // very large value.
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Get Signed Distance")
    static double
    Get_SignedDistance(
        const FCk_Hands_ContactShape& InShape,
        const FVector& InPoint);

    // The same shape expressed relative to InSpace (e.g. a world-space shape in component space). Scale is ignored.
    // An invalid shape ensures and is returned unchanged.
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands|ContactShape",
        DisplayName="[Ck][Hands] Get In Space")
    static FCk_Hands_ContactShape
    Get_InSpace(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InSpace);
};

// --------------------------------------------------------------------------------------------------------------------

UCLASS(NotBlueprintable, Meta = (ScriptMixin = "FCk_Hands_DigitContactSettings"))
class CKHANDS_API UCk_Utils_Hands_UE : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    CK_GENERATED_BODY(UCk_Utils_Hands_UE);

public:
    // Radius finite and > 0, Max Search Steps >= 2, Tip Length Ratio finite and >= 0.
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands",
        DisplayName="[Ck][Hands] Get Is Settings Valid")
    static bool
    Get_IsSettingsValid(
        const FCk_Hands_DigitContactSettings& InSettings);

    /**
     * How far (0..1) a digit can curl from its rest pose toward its target pose before it newly touches InShape.
     * InRest and InPose are the digit's segment local transforms, root first (same count, at least 2); InParent is the
     * global transform of the root segment's parent, in the space of InShape. 1 for a None shape or nothing in the way.
     */
    UFUNCTION(BlueprintPure, Category = "Ck|Utils|Hands",
        DisplayName="[Ck][Hands] Solve Digit Curl")
    static float
    Solve_DigitCurl(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InParent,
        const TArray<FTransform>& InRest,
        const TArray<FTransform>& InPose,
        const FCk_Hands_DigitContactSettings& InSettings);
};

// --------------------------------------------------------------------------------------------------------------------
