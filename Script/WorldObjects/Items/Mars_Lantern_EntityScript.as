// The lantern's assembly: a flame item (UMars_FlameItem_EntityScript) whose glass glows with its flame (the mesh's Glow
// slot) and whose body stays visible on the belt, where a lit lantern keeps burning at a smaller, dimmer pool. It
// dangles: a CkSway node (the Bail) sits at the hang point k_BailHeight over the root, and the body's mesh, the flame
// node and the light hang on the bail itself, k_BailHeight lower than they would on the root, so the hand's or the
// belt's motion swings the lantern about its bail (constants_lantern_item::Make_BailSway) and the lantern spends one
// scene-node layer below its root. The flame is behind glass: the effect stays inside and throws no embers.
class UMars_Lantern_EntityScript : UMars_FlameItem_EntityScript
{
    // CampLantern_Mars_SM's glass slot (Glow_Mars_MI: Emissive "Color" x "Strength").
    private const int32 k_GlassSlot = 1;
    private const FName k_GlassStrengthParameter = n"Strength";
    private const float32 k_GlassStrength = 8.0f;

    // The flame's height over the lantern's pivot (its base), at the item's MeshScale.
    private const float64 k_FlameHeight = 14.0;

    private UMaterialInstanceDynamic _Glass;
    private FCk_Handle_Sway _BailSway;
    // The bail: the mesh and the flame node hang on it, k_BailHeight lower than on the root.
    private FCk_Handle_Transform _BailNode;

    protected float64 Get_FlameHeight() const override
    {
        return k_FlameHeight;
    }

    protected float64 Get_FlameParentHeight() const override
    {
        return constants_lantern_item::k_BailHeight;
    }

    // Mars_TestLamp's colour and intensity in hand and in the world, which the sandbox has been lit by; dimmer and
    // unshadowed on the belt.
    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.67f, 0.35f, 1.0f);
        Look.IntensityHeld = 8000.0f;
        Look.IntensityStowed = 3000.0f;
        Look.IntensityWorld = 8000.0f;
        Look.ShadowsStowed = false;
        Look.FxSize = 10.0f;
        Look.FxEmberRate = 1.0f;
        Look.FxEnclosed = true;
        return Look;
    }

    protected bool Get_HidesWhileStowed() const override
    {
        return false;
    }

    // The Bail at the hang point with the pendulum spring on it; the flame node (and the dressing's light) go on it.
    protected FCk_Handle_Transform Make_FlameParent(FCk_Handle_Transform& InRoot) override
    {
        auto Bail = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, constants_lantern_item::k_BailHeight)));
        utils_handle::Set_DebugName(Bail.H(), n"Lantern.Bail");
        _BailSway = utils_sway::Add(Bail, constants_lantern_item::Make_BailSway());
        _BailNode = Bail.H().As_Transform();
        return _BailNode;
    }

    protected void DoOnFlameComposed() override
    {
        _Dressing.BindTo_OnBrightness(FMars_Delegate_FlameDressing_OnBrightness(this, n"OnFlameBrightness"));

        auto WorldItem = _Flame.H().As_WorldItem();
        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_Bail"));
    }

    // The glass glows only while the lantern is lit. The presentation mesh's node moves from the root to the bail, its
    // offset k_BailHeight lower, so the mesh swings with the bail and rests where it was (utils_scene_node::Add never
    // re-parents an attached node: detach first).
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        Super::DoOnVisualMeshAdded(InMesh);
        if (InMesh.GetNumMaterials() > k_GlassSlot)
        { _Glass = InMesh.CreateDynamicMaterialInstance(k_GlassSlot); }

        Rehang_Visual(InMesh);

        if (ck::IsValid(_Dressing))
        { _Dressing.Refresh(); }
    }

    private void Rehang_Visual(UStaticMeshComponent InMesh)
    {
        if (ck::Is_NOT_Valid(_BailNode))
        { return; }

        auto VisualEntity = utils_unreal_component::TryGet_OwningHandle_FromComponent(InMesh);
        auto VisualNode = VisualEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        auto VisualTransform = VisualEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(VisualNode) || ck::Is_NOT_Valid(VisualTransform))
        { return; }

        const auto Offset = utils_scene_node::Get_Offset(VisualNode)
            * FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        utils_scene_node::Request_Detach(VisualNode);
        utils_scene_node::Add(VisualTransform, _BailNode, Offset);
    }

    UFUNCTION()
    private void OnFlameBrightness(float32 InBrightness)
    {
        if (ck::IsValid(_Glass))
        { _Glass.SetScalarParameterValue(k_GlassStrengthParameter, k_GlassStrength * InBrightness); }
    }

    // A stow or a hang is a jump, not a swing: the spring restarts at rest.
    UFUNCTION()
    private void OnMountChanged_Bail(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        if (ck::IsValid(_BailSway))
        { utils_sway::Request_Reset(_BailSway, FCk_Request_Sway_Reset()); }
    }
}
