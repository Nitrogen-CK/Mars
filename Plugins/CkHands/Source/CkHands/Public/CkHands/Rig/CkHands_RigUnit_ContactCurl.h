#pragma once

#include "CkHands/CkHands_Contact_Data.h"

#include <Rigs/RigHierarchyCache.h>
#include <Units/Highlevel/RigUnit_HighlevelBase.h>

#include "CkHands_RigUnit_ContactCurl.generated.h"

// --------------------------------------------------------------------------------------------------------------------

USTRUCT()
struct CKHANDS_API FCk_RigUnit_Hands_ContactCurl_WorkData
{
    GENERATED_BODY()

    UPROPERTY()
    TArray<FCachedRigElement> CachedItems;

    UPROPERTY()
    float Curl = 1.0f;

    UPROPERTY()
    bool IsInitialized = false;
};

// --------------------------------------------------------------------------------------------------------------------

/**
 * Curls one digit from its initial (rest) pose toward the pose it came in with (the authored grip pose), stopping where
 * it first newly touches Shape (ck::hands::Solve_DigitCurl). With a None shape the digit keeps its incoming pose.
 * The curl follows its solved value with an exponential ease. Fewer than two items, or an item missing from the
 * hierarchy, is reported on the node and leaves the digit untouched. Invalid Settings are reported on the node and the
 * digit eases to its incoming pose. An invalid Shape is runtime data from the game and ensures in the solver.
 */
USTRUCT(meta = (DisplayName = "Contact Curl (Ck Hands)", Category = "Ck|Hands",
                Keywords = "Finger,Digit,Grip,Contact,Curl,Hand", NodeColor = "0.35 0.2 0.1"))
struct CKHANDS_API FCk_RigUnit_Hands_ContactCurl : public FRigUnit_HighlevelBaseMutable
{
    GENERATED_BODY()

    RIGVM_METHOD()
    virtual void Execute() override;

    // The digit's bones, root first (at least two). The root's parent is the hand.
    UPROPERTY(meta = (Input, ExpandByDefault))
    TArray<FRigElementKey> Items;

    // What the digit closes on, in rig global (component) space.
    UPROPERTY(meta = (Input))
    FCk_Hands_ContactShape Shape;

    UPROPERTY(meta = (Input))
    FCk_Hands_DigitContactSettings Settings;

    // How quickly the curl follows its solved value (1/s). 0 snaps.
    UPROPERTY(meta = (Input))
    float InterpSpeed = 18.0f;

    // Where the digit ended up: 0 = rest pose, 1 = the incoming pose.
    UPROPERTY(meta = (Output))
    float Curl = 1.0f;

    UPROPERTY(transient)
    FCk_RigUnit_Hands_ContactCurl_WorkData WorkData;
};

// --------------------------------------------------------------------------------------------------------------------
