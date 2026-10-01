#pragma once

#include "CkHands/CkHands_Contact_Data.h"

// --------------------------------------------------------------------------------------------------------------------

namespace ck::hands
{
    /** The transform is finite with a normalized rotation, and every dimension the type reads is finite and >= 0. None is valid. */
    CKHANDS_API auto Get_IsShapeValid(const FCk_Hands_ContactShape& InShape) -> bool;

    /** Radius finite and > 0, MaxSearchSteps >= 2, TipLengthRatio finite and >= 0. */
    CKHANDS_API auto Get_IsSettingsValid(const FCk_Hands_DigitContactSettings& InSettings) -> bool;

    /**
     * Signed distance from InPoint to the shape's surface, negative inside, computed by GeometryCore (TOrientedBox3,
     * TSphere3, TCapsule3). TNumericLimits<double>::Max() for None. Expects a shape that passes Get_IsShapeValid.
     */
    CKHANDS_API auto Get_SignedDistance(const FCk_Hands_ContactShape& InShape, const FVector& InPoint) -> double;

    /**
     * The same shape expressed relative to InSpace (a component-space shape re-expressed in a bone's space, or back).
     * Rigid: the scale of both transforms is ignored, so the dimensions are unchanged. Round trip:
     * Get_SignedDistance(InShape, P) == Get_SignedDistance(Get_ShapeInSpace(InShape, InSpace), InSpace.InverseTransformPositionNoScale(P)).
     */
    CKHANDS_API auto Get_ShapeInSpace(const FCk_Hands_ContactShape& InShape, const FTransform& InSpace) -> FCk_Hands_ContactShape;

    /**
     * How far (0..1) a digit can curl from its rest pose toward its target pose before it NEWLY touches the shape.
     * InRest and InPose are the digit's segment local transforms, root first; InParent is the global transform of the
     * root segment's parent. Curling slerps each segment's rotation from rest toward pose; translations and scales come
     * from the pose. 1 = the full target pose.
     *
     * Contact is tested at samples spaced <= Radius along every segment that moves with the curl: each segment from one
     * joint to the next (the segment rooted in the palm, up to the first joint, cannot move and is not sampled) and the
     * tip segment, which runs from the last joint along that joint's own offset from its parent
     * (InPose.Last().GetTranslation() * TipLengthRatio, in the last joint's frame), so +X and mirrored -X chains both
     * work. A zero tip offset (or a zero TipLengthRatio) has no tip segment. A sample touches when it is closer than
     * Radius to the surface; a sample already that close at rest never stops the curl (a handle through the palm).
     *
     * Search: every sample's speed per unit of curl is bounded by sum_i(Angle_i * Reach_i), where Angle_i is joint i's
     * rest->pose angular distance and Reach_i is the chain length beyond joint i (assumes uniform scale along the chain).
     * The curl range is split into ceil(Bound / Radius) coarse steps clamped to [2, MaxSearchSteps], then the first
     * touching step is refined by 4 bisections and the last clear curl is returned.
     * Guarantee while the step count is not clamped: no sample moves more than Radius between two coarse steps, so it
     * cannot cross a stretch of the Radius-inflated shape that is >= Radius long along its path without a step landing
     * inside it. A sample that reaches the shape's surface crosses at least 2 * Radius of the inflated shape (Radius in,
     * Radius out), so no shape, however thin, can be passed through between steps. Only a graze that stays more than
     * Radius / 2 from the surface can be missed. Once clamped, the per-step travel is Bound / MaxSearchSteps instead.
     *
     * Contract (each violation ensures and returns 1): InRest.Num() == InPose.Num(), at least 2 segments, a valid shape,
     * valid settings (Get_IsSettingsValid) and finite transforms.
     * A None shape is not a violation: it returns 1 without looking at anything else.
     */
    CKHANDS_API auto Solve_DigitCurl(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InParent,
        TConstArrayView<FTransform> InRest,
        TConstArrayView<FTransform> InPose,
        const FCk_Hands_DigitContactSettings& InSettings) -> float;

    /**
     * Where to put a floating hand's root (InPlacedBone, component space) so that one of its descendants (InTargetBone,
     * component space, taken from the same pose) lands exactly on InTarget. The hand moves rigidly: the root-to-target
     * offset is measured without scale, InTarget's scale is ignored, and the result keeps InPlacedBone's own scale.
     */
    CKHANDS_API auto Get_GlovePlacement(
        const FTransform& InPlacedBone,
        const FTransform& InTargetBone,
        const FTransform& InTarget) -> FTransform;
}

// --------------------------------------------------------------------------------------------------------------------
