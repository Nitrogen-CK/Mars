// A key-lock spec with an AcceptedKey, a KeyMount and an Interactable is accepted; one missing any of the three is rejected,
// naming it. The parts are bare ECS nodes (a scene node and a probe-less interactable): Validate reads only that each handle
// is valid. Isolated Z band: -95700.
class UMars_AutoTest_KeyLock_SpecValidateRejectsMissingParts : UCk_AutoTest_Base
{
    private FCk_Handle_Transform _KeyMount;
    private FCk_Handle_Interactable _Interactable;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LockEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto LockRoot = utils_transform::Add(LockEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -95700.0)), ECk_Replication::DoesNotReplicate);
        _KeyMount = utils_scene_node::Create(LockRoot, FTransform::Identity).As_Transform();
        _Interactable = utils_interactable::Create(LockRoot, FMars_Interactable_Spec());

        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_Spec().Validate();
        Assert_True(Good.IsValid(), f"a lock with a key, a mount and an interactable is valid ({Good.Get_Error()})");

        auto NoKey = Make_Spec();
        NoKey.AcceptedKey = FGameplayTag();
        AssertRejected(NoKey, "AcceptedKey", "a lock with no AcceptedKey");

        auto NoMount = Make_Spec();
        NoMount.KeyMount = FCk_Handle_Transform();
        AssertRejected(NoMount, "KeyMount", "a lock with no KeyMount");

        auto NoInteractable = Make_Spec();
        NoInteractable.Interactable = FCk_Handle_Interactable();
        AssertRejected(NoInteractable, "Interactable", "a lock with no Interactable");
    }

    private FMars_KeyLock_Spec Make_Spec() const
    {
        auto Spec = FMars_KeyLock_Spec();
        Spec.AcceptedKey = GameplayTags::Key_Mars_Red;
        Spec.KeyMount = _KeyMount;
        Spec.Interactable = _Interactable;
        return Spec;
    }

    private void AssertRejected(const FMars_KeyLock_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
