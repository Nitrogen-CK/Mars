// A carried flame's assembly: a World-mode, Persistent world item whose definition carries UMars_ItemTrait_Flame. It composes
// the Flame kernel from the trait's Spec, puts a flame node at the subclass's height and draws what the kernel decides
// through a UMars_FlameDressing, following the item from the floor to the hand to the belt to a hook. The kernel owns the
// fuel clock and the pools; a subclass owns its look, its flame height, whether its body shows while stowed, and anything
// else it dresses (DoOnFlameComposed).
class UMars_FlameItem_EntityScript : UMars_WorldItem_EntityScript
{
    protected FCk_Handle_Flame _Flame;
    protected UMars_FlameDressing _Dressing;
    private UStaticMeshComponent _Body;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // Super destroyed itself (bad definition) - nothing to compose on.
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(WorldItem))
        { return Flow; }

        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Flame FlameTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Flame);
        const auto IsPersistent = WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        const auto IsFlameItem = Mode == EMars_WorldItem_Mode::World && IsPersistent && ck::IsValid(FlameTrait);
        if (ck::EnsureIfNot(IsFlameItem,
            f"[Flame] [{InHandle.ToString()}] needs World mode and a Persistent definition with a Flame trait (mode [{Mode :n}], persistent [{IsPersistent}], flame trait [{ck::IsValid(FlameTrait)}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        // A rejected spec already ensured in utils_flame::Add; the item then stays dark.
        _Flame = utils_flame::Add(InHandle, FlameTrait.Spec);
        if (ck::Is_NOT_Valid(_Flame))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Root = InHandle.As_Transform();
        auto FlameParent = Make_FlameParent(Root);
        auto FlameNode = utils_scene_node::Create(FlameParent, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, Get_FlameHeight()))).As_Transform();
        utils_handle::Set_DebugName(FlameNode.H(), n"FlameItem.Flame");

        _Dressing = Cast<UMars_FlameDressing>(NewObject(this, UMars_FlameDressing));
        _Dressing.Setup(_Flame, FlameNode, Get_Look());

        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_Flame"));
        DoOnFlameComposed();

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);

        if (ck::IsValid(_Dressing))
        { _Dressing.Teardown(); }
    }

    // The flame's height over the item's pivot, at the item's MeshScale.
    protected float64 Get_FlameHeight() const
    {
        return 0.0;
    }

    // The transform the flame node (and so the light and the flame effect) hangs under: the item's root, unless a subclass
    // puts a moving node between them (the lantern's swinging bail). Called before the flame node exists.
    protected FCk_Handle_Transform Make_FlameParent(FCk_Handle_Transform& InRoot)
    {
        return InRoot;
    }

    protected FMars_FlameLook Get_Look() const
    {
        return FMars_FlameLook();
    }

    // The body hides while it rides its carry point (an unlit stick on the belt reads as nothing).
    protected bool Get_HidesWhileStowed() const
    {
        return true;
    }

    // The flame is composed and dressed (_Flame, _Dressing valid): a subclass adds what else it draws.
    protected void DoOnFlameComposed()
    {
    }

    // The item's own body never shadows its flame.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        _Body = InMesh;
        InMesh.SetCastShadow(false);
        Refresh_Body();
    }

    private void Refresh_Body()
    {
        if (ck::IsValid(_Body) && ck::IsValid(_Flame))
        { _Body.SetVisibility(Get_HidesWhileStowed() == false || _Flame.Get_IsStowed() == false); }
    }

    // The light's radius, strength and shadows and the body's visibility follow the mount (hand, stowed, world).
    UFUNCTION()
    private void OnMountChanged_Flame(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        Refresh_Body();
        if (ck::IsValid(_Dressing))
        { _Dressing.Refresh(); }
    }
}
