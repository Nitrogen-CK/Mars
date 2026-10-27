// A fixed flame's assembly (a candle, a wall torch): the subclass's meshes, a flame node, an interactable whose ignite row
// lights the flame from a held one or lights a held one from it, the Flame kernel, an optional MechanismSource the kernel
// asserts while the flame is lit, and the flame's drawing. Subclasses set the flame's rules and their name in DoConstruct
// before Super (the spawn-params generator cannot emit struct defaults), and give the meshes, the flame's place and its look.
UCLASS(Abstract)
class UMars_FlameFixture_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = false;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Its Interactable is the fixture's own; StartIgnition comes from StartLit.
    UPROPERTY(ExposeOnSpawn)
    FMars_Flame_Spec Flame;

    // Optional: unwired while OutputChannel is unset (utils_mechanism_source::TryAdd).
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // What the prompt calls the fixture ("Light Candle"); the subclass names it when left empty.
    UPROPERTY(ExposeOnSpawn)
    FText Name;

    UPROPERTY(ExposeOnSpawn)
    EMars_Flame_Ignition StartLit = EMars_Flame_Ignition::Snuffed;

    private FCk_Handle_Flame _Flame;
    private UMars_FlameDressing _Dressing;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsFlameFixture");

        AddVisuals(Root);

        auto FlameNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, Get_FlameLocal())).As_Transform();
        utils_handle::Set_DebugName(FlameNode.H(), n"FlameFixture.Flame");

        Flame.StartIgnition = StartLit;
        Flame.Interactable = AddInteractable(Root);

        // A rejected spec already ensured in utils_flame::Add.
        _Flame = utils_flame::Add(InHandle, Flame);
        if (ck::Is_NOT_Valid(_Flame))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        auto FixtureName = FMars_Fragment_FlameFixture_Name();
        FixtureName.Name = Name;
        InHandle.Add_Fragment(FixtureName);

        utils_mechanism_source::TryAdd(InHandle, Source);

        _Dressing = Cast<UMars_FlameDressing>(NewObject(this, UMars_FlameDressing));
        _Dressing.Setup(_Flame, FlameNode, Get_Look());

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Dressing))
        { _Dressing.Teardown(); }
    }

    // The fixture's meshes on its root.
    protected void AddVisuals(FCk_Handle_Transform& InRoot)
    {
    }

    // Where the flame burns, relative to the root.
    protected FVector Get_FlameLocal() const
    {
        return FVector::ZeroVector;
    }

    protected FMars_FlameLook Get_Look() const
    {
        return FMars_FlameLook();
    }

    // Around the flame, so aiming at it finds the row. It outranks a world item's pickup, as a lantern hook does.
    private FCk_Handle_Interactable AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(14.0, 14.0, 22.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, Get_FlameLocal());

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(utils_flame::Make_IgniteTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, Name)));
        Spec.FocusPriority = constants_lantern_hook::k_FocusPriority;

        return utils_interactable::Create(InRoot, Spec);
    }
}
