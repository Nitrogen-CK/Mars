#pragma once

#include "CkCore/Enums/CkEnums.h"
#include "CkCore/Macros/CkMacros.h"

#include <Kismet/BlueprintFunctionLibrary.h>

#include "CkHands_Utils_Editor.generated.h"

// --------------------------------------------------------------------------------------------------------------------

class UAnimBlueprint;

// --------------------------------------------------------------------------------------------------------------------

// Editor scripting helpers for wiring Ck Hands rigs into anim blueprints (Blueprint, Python and AngelScript).
UCLASS(NotBlueprintable)
class CKHANDSEDITOR_API UCk_Utils_HandsEditor_UE : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    CK_GENERATED_BODY(UCk_Utils_HandsEditor_UE);

public:
    /**
     * Shows (Enable) or hides (Disable) a Control Rig variable as an input pin on a Control Rig node of an anim
     * blueprint, the node's "Use Pin" checkbox, so it can be bound to an anim instance property. InNodeName is the
     * graph node's object name (e.g. AnimGraphNode_ControlRig_0). Atomic: the blueprint, a single Control Rig node of
     * that name, the variable (a public, writable variable of the node's rig class with a pin type) and the node's pin
     * list are all validated before anything changes; any failure ensures, changes nothing and returns Failed.
     * Succeeded when the pin is in the requested state afterwards, including when it already was. One undoable
     * transaction.
     */
    UFUNCTION(BlueprintCallable,
              Category = "Ck|Utils|Hands|Editor",
              DisplayName = "[Ck][Hands] Request Set Control Rig Node Pin Exposed")
    static ECk_SucceededFailed
    Request_SetControlRigNodePinExposed(
        UAnimBlueprint* InAnimBlueprint,
        FName InNodeName,
        FName InVariableName,
        ECk_EnableDisable InPinExposed);
};

// --------------------------------------------------------------------------------------------------------------------
