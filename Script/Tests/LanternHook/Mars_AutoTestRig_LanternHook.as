// The lantern-hook tests' rig: the flame-item rig (a carrier with a belt and one lantern spawned as its own world item,
// UMars_Lantern_EntityScript) plus hooks built from the kernel the way UMars_LanternSconce_EntityScript composes them - a
// root, a hang node, an interactable with the hook's target, the hook and an optional source - without its meshes.
UCLASS(Abstract)
class UMars_AutoTestRig_LanternHook : UMars_AutoTestRig_FlameItem
{
    protected FCk_Handle_LanternHook _Hook;

    // A hook at InLocation whose source asserts InChannel (unset = no source).
    protected FCk_Handle_LanternHook MakeHook(FCk_Handle InHandle, FVector InLocation, FGameplayTag InChannel)
    {
        auto HookEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(HookEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        auto HangNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(30.0, 0.0, 0.0))).As_Transform();

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(14.0, 14.0, 22.0)));

        auto InteractableSpec = FMars_Interactable_Spec();
        InteractableSpec.ProbeInfo = Probe;
        InteractableSpec.Targets.Add(utils_lantern_hook::Make_InteractTarget());

        auto Spec = FMars_LanternHook_Spec();
        Spec.HangNode = HangNode;
        Spec.HangOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        Spec.Interactable = utils_interactable::Create(Root, InteractableSpec);

        FCk_Handle HookHandle = HookEntity;
        auto Hook = utils_lantern_hook::Add(HookHandle, Spec);

        if (InChannel.IsValid())
        {
            auto SourceSpec = FMars_MechanismSource_Spec();
            SourceSpec.OutputChannel = InChannel;
            utils_mechanism_source::Add(HookHandle, SourceSpec);
        }

        return Hook;
    }

    // InHook's source is asserted; false when it has none.
    protected bool Get_IsSourceAsserted(const FCk_Handle_LanternHook& InHook) const
    {
        const auto Source = InHook.As_MechanismSource(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Source) && Source.Get_IsAsserted();
    }

    UFUNCTION()
    protected void Step_Hang(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Hook.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_LanternHook_Action::Hang, f"a carrier holding a lantern reads Hang on an empty hook (got [{Action :n}])");
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(Get_FlameItem()));
    }

    // On the hook, settled on it, Carried by the hook entity.
    UFUNCTION()
    protected void Check_Hung(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hook.Get_Item() == Get_FlameItem() && _Hook.Get_HasArrived());
    }
}
