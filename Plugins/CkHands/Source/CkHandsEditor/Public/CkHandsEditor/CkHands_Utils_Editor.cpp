#include "CkHands_Utils_Editor.h"

#include "CkCore/Ensure/CkEnsure.h"
#include "CkCore/Validation/CkIsValid.h"

#include <AnimGraphNode_ControlRig.h>
#include <AnimGraphNode_CustomProperty.h>
#include <Animation/AnimBlueprint.h>
#include <ControlRigIOMapping.h>
#include <EdGraph/EdGraph.h>
#include <K2Node.h>
#include <Kismet2/BlueprintEditorUtils.h>
#include <RigVMCore/RigVMExternalVariable.h>
#include <RigVMDeveloperTypeUtils.h>
#include <ScopedTransaction.h>

#define LOCTEXT_NAMESPACE "CkHandsEditor"

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_utils_editor
{
    using NodesType = TArray<UEdGraphNode*, TInlineAllocator<1>>;

    auto
        DoFind_NodesNamed(
            const UAnimBlueprint& InAnimBlueprint,
            FName InNodeName)
        -> NodesType
    {
        auto Graphs = TArray<UEdGraph*>{};
        InAnimBlueprint.GetAllGraphs(Graphs);

        auto Nodes = NodesType{};
        for (const auto* Graph : Graphs)
        {
            for (const auto& GraphNode : Graph->Nodes)
            {
                if (ck::IsValid(GraphNode.Get()) && GraphNode->GetFName() == InNodeName)
                { Nodes.Add(GraphNode.Get()); }
            }
        }
        return Nodes;
    }

    // FControlRigIOMapping is the engine's own definition of the variables a Control Rig node can expose (the node
    // builds its pins from it). A probe bound to throwaway storage answers the question without touching the node.
    auto
        DoFind_InputVariable(
            const UAnimGraphNode_ControlRig& InNode,
            FName InVariableName)
        -> TOptional<FRigVMExternalVariable>
    {
        auto ProbeInputMapping = TMap<FName, FName>{};
        auto ProbeOutputMapping = TMap<FName, FName>{};
        auto ProbePins = TArray<FOptionalPinFromProperty>{};
        const auto Probe = MakeShared<FControlRigIOMapping>(ProbeInputMapping, ProbeOutputMapping, ProbePins);

        Probe->GetOnGetTargetClassDelegate().BindLambda([&InNode]() -> UClass* { return InNode.GetTargetClass(); });
        Probe->RebuildExposedProperties();

        const auto* Variable = Probe->GetInputVariables().Find(InVariableName);
        if (ck::Is_NOT_Valid(Variable, ck::IsValid_Policy_NullptrOnly{}))
        { return {}; }

        return *Variable;
    }

    // The node's pin list is protected (its details panel owns it); it is reached through reflection, and the
    // property's shape is checked before its memory is reinterpreted.
    auto
        DoGet_CustomPinPropertiesProperty()
        -> const FArrayProperty*
    {
        const auto* PinsProperty = FindFProperty<FArrayProperty>(UAnimGraphNode_CustomProperty::StaticClass(), TEXT("CustomPinProperties"));
        if (ck::Is_NOT_Valid(PinsProperty, ck::IsValid_Policy_NullptrOnly{}))
        { return nullptr; }

        const auto* PinProperty = CastField<FStructProperty>(PinsProperty->Inner);
        if (ck::Is_NOT_Valid(PinProperty, ck::IsValid_Policy_NullptrOnly{}) || PinProperty->Struct != FOptionalPinFromProperty::StaticStruct())
        { return nullptr; }

        return PinsProperty;
    }

    auto
        DoAdd_OptionalPin(
            TArray<FOptionalPinFromProperty>& InOutPins,
            FName InPropertyName)
        -> FOptionalPinFromProperty&
    {
        auto& Pin = InOutPins.AddDefaulted_GetRef();
        Pin.PropertyName = InPropertyName;
        Pin.bCanToggleVisibility = true;
        Pin.bIsOverrideEnabled = false;
        return Pin;
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    UCk_Utils_HandsEditor_UE::
    Request_SetControlRigNodePinExposed(
        UAnimBlueprint* InAnimBlueprint,
        FName InNodeName,
        FName InVariableName,
        ECk_EnableDisable InPinExposed)
    -> ECk_SucceededFailed
{
    const auto IsBlueprintValid = ck::IsValid(InAnimBlueprint);
    CK_ENSURE_IF_NOT(IsBlueprintValid, TEXT("Set Control Rig Node Pin Exposed rejected an invalid Anim Blueprint"))
    { return ECk_SucceededFailed::Failed; }

    const auto NamedNodes = ck_hands_utils_editor::DoFind_NodesNamed(*InAnimBlueprint, InNodeName);
    const auto IsSingleNode = NamedNodes.Num() == 1;
    CK_ENSURE_IF_NOT(IsSingleNode,
        TEXT("Set Control Rig Node Pin Exposed found [{}] nodes named [{}] in Anim Blueprint [{}], expected exactly one"),
        NamedNodes.Num(), InNodeName, InAnimBlueprint->GetName())
    { return ECk_SucceededFailed::Failed; }

    auto* Node = Cast<UAnimGraphNode_ControlRig>(NamedNodes[0]);
    const auto IsControlRigNode = ck::IsValid(Node);
    CK_ENSURE_IF_NOT(IsControlRigNode,
        TEXT("Set Control Rig Node Pin Exposed: node [{}] in Anim Blueprint [{}] is a [{}], not a Control Rig node"),
        InNodeName, InAnimBlueprint->GetName(), NamedNodes[0]->GetClass()->GetName())
    { return ECk_SucceededFailed::Failed; }

    const auto Variable = ck_hands_utils_editor::DoFind_InputVariable(*Node, InVariableName);
    const auto IsInputVariable = Variable.IsSet();
    CK_ENSURE_IF_NOT(IsInputVariable,
        TEXT("Set Control Rig Node Pin Exposed: [{}] is not a public, writable variable of the rig class [{}] used by node [{}] "
             "(or that rig is not loaded yet)"),
        InVariableName, GetNameSafe(Node->GetTargetClass()), InNodeName)
    { return ECk_SucceededFailed::Failed; }

    const auto HasPinType = RigVMTypeUtils::PinTypeFromExternalVariable(Variable.GetValue()).PinCategory.IsValid();
    CK_ENSURE_IF_NOT(HasPinType,
        TEXT("Set Control Rig Node Pin Exposed: variable [{}] of node [{}] has a type that cannot be a pin"),
        InVariableName, InNodeName)
    { return ECk_SucceededFailed::Failed; }

    const auto* PinsProperty = ck_hands_utils_editor::DoGet_CustomPinPropertiesProperty();
    const auto HasPinsProperty = ck::IsValid(PinsProperty, ck::IsValid_Policy_NullptrOnly{});
    CK_ENSURE_IF_NOT(HasPinsProperty,
        TEXT("Set Control Rig Node Pin Exposed: UAnimGraphNode_CustomProperty has no CustomPinProperties array of "
             "FOptionalPinFromProperty (engine changed?)"))
    { return ECk_SucceededFailed::Failed; }

    auto& Pins = *PinsProperty->ContainerPtrToValuePtr<TArray<FOptionalPinFromProperty>>(Node);
    const auto ShowPin = InPinExposed == ECk_EnableDisable::Enable;
    const auto PinIndex = Pins.IndexOfByPredicate([&](const FOptionalPinFromProperty& InPin)
    {
        return InPin.PropertyName == InVariableName;
    });

    if (PinIndex != INDEX_NONE && Pins[PinIndex].bShowPin == ShowPin)
    { return ECk_SucceededFailed::Succeeded; }

    const auto Transaction = FScopedTransaction{LOCTEXT("SetControlRigNodePinExposed", "Set Control Rig Node Pin Exposed")};
    Node->Modify();

    auto& Pin = PinIndex == INDEX_NONE ? ck_hands_utils_editor::DoAdd_OptionalPin(Pins, InVariableName) : Pins[PinIndex];

    // The same sequence as UAnimGraphNode_CustomProperty::SetCustomPinVisibility (protected): a pin being hidden must
    // not be saved as an orphan when the node reconstructs.
    auto OldShownPins = TArray<FName>{};
    FOptionalPinManager::CacheShownPins(Pins, OldShownPins);
    Pin.bShowPin = ShowPin;
    FOptionalPinManager::EvaluateOldShownPins(Pins, OldShownPins, Node);
    Node->ReconstructNode();

    FBlueprintEditorUtils::MarkBlueprintAsStructurallyModified(InAnimBlueprint);
    return ECk_SucceededFailed::Succeeded;
}

// --------------------------------------------------------------------------------------------------------------------

#undef LOCTEXT_NAMESPACE
