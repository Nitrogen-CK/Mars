// A lantern-hook spec with a HangNode, an Interactable and a finite HangOffset is accepted; one missing either part or with
// a NaN HangOffset is rejected, naming it. The parts are bare ECS nodes (a scene node and a probe-less interactable):
// Validate reads only that each handle is valid. Isolated Z band: -99700.
class UMars_AutoTest_LanternHook_SpecValidateRejectsMissingParts : UCk_AutoTest_Base
{
    private FCk_Handle_Transform _HangNode;
    private FCk_Handle_Interactable _Interactable;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto HookEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HookRoot = utils_transform::Add(HookEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -99700.0)), ECk_Replication::DoesNotReplicate);
        _HangNode = utils_scene_node::Create(HookRoot, FTransform::Identity).As_Transform();
        _Interactable = utils_interactable::Create(HookRoot, FMars_Interactable_Spec());

        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_Spec().Validate();
        Assert_True(Good.IsValid(), f"a hook with a node, an interactable and a finite offset is valid ({Good.Get_Error()})");

        auto NoNode = Make_Spec();
        NoNode.HangNode = FCk_Handle_Transform();
        AssertRejected(NoNode, "HangNode", "a hook with no HangNode");

        auto NoInteractable = Make_Spec();
        NoInteractable.Interactable = FCk_Handle_Interactable();
        AssertRejected(NoInteractable, "Interactable", "a hook with no Interactable");

        auto NaNOffset = Make_Spec();
        NaNOffset.HangOffset.SetTranslation(FVector(0.0, 0.0, Math::Sqrt(-1.0)));
        AssertRejected(NaNOffset, "HangOffset", "a NaN HangOffset");
    }

    private FMars_LanternHook_Spec Make_Spec() const
    {
        auto Spec = FMars_LanternHook_Spec();
        Spec.HangNode = _HangNode;
        Spec.HangOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -10.0));
        Spec.Interactable = _Interactable;
        return Spec;
    }

    private void AssertRejected(const FMars_LanternHook_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
