// The ordinary persistent WorldItem owns pickup, mounting, collision and release. Its closed static proxy remains the
// definition's remote held-item mesh; only this assembly replaces its local drawing with the animated book.
class UMars_Cookbook_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Cookbook();

    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_SceneNode _VisualNode;
    private UMars_CookbookPresentationComponent _Presentation;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        _WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(_WorldItem))
        { return Flow; }

        if (ck::EnsureIfNot(Mode == EMars_WorldItem_Mode::World && _WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent,
            f"[Cookbook] [{InHandle.ToString()}] needs a persistent World-mode item"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return Flow;
        }

        const auto Params = utils_unreal_component::Make_Params(UMars_CookbookPresentationComponent,
            ECk_UnrealComponent_TickPolicy::TickViaProcessor, n"Cookbook_Presentation");
        auto Root = InHandle.As_Transform();
        _VisualNode = utils_scene_node::Create(Root, FTransform::Identity);
        utils_handle::Set_DebugName(_VisualNode.H(), n"Cookbook.Visual");
        auto PresentationHandle = utils_unreal_component::Add(_VisualNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(PresentationHandle, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPresentationAdded"));
        _WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnCookbookMountChanged"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Request_Close();
        if (ck::IsValid(_Presentation))
        { _Presentation.OnReadingPoseChanged.Unbind(this, n"OnReadingPoseChanged"); }
        if (ck::IsValid(_WorldItem))
        { _WorldItem.UnbindFrom_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnCookbookMountChanged")); }

        _Presentation = nullptr;
        _WorldItem = FCk_Handle_WorldItem();
        _VisualNode = FCk_Handle_SceneNode();
        Super::DoEndPlay(InHandle);
    }

    UMars_CookbookPresentationComponent Get_Presentation() const
    { return _Presentation; }

    bool Get_IsOpen() const
    { return ck::IsValid(_Presentation) && _Presentation.Get_IsOpen(); }

    void Request_Toggle()
    {
        if (Get_IsHeld() && ck::IsValid(_Presentation))
        { _Presentation.Request_Toggle(); }
    }

    void Request_Turn(int32 InDelta)
    {
        if (Get_IsHeld() && ck::IsValid(_Presentation))
        { _Presentation.Request_Turn(InDelta); }
    }

    void Request_Close(bool InImmediate = true)
    {
        if (ck::IsValid(_Presentation))
        { _Presentation.Request_Close(InImmediate); }
    }

    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        InMesh.SetVisibility(false);
        InMesh.SetHiddenInGame(true);
        InMesh.SetCastShadow(false);
    }

    private bool Get_IsHeld() const
    {
        return ck::IsValid(_WorldItem) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held;
    }

    private void DoRefresh_Presentation()
    {
        if (ck::Is_NOT_Valid(_WorldItem) || ck::Is_NOT_Valid(_Presentation))
        { return; }

        const auto Mount = _WorldItem.Get_Mount();
        if (Mount != EMars_WorldItem_Mount::Held)
        { Request_Close(); }

        _Presentation.SetVisibility(Mount != EMars_WorldItem_Mount::Carried);
        _Presentation.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_WorldItem));
    }

    UFUNCTION()
    private void OnPresentationAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Presentation = Cast<UMars_CookbookPresentationComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Presentation), "[Cookbook] the skeletal presentation component was not created"))
        { return; }

        _Presentation.OnReadingPoseChanged.AddUFunction(this, n"OnReadingPoseChanged");
        DoApply_ReadingOffset(_Presentation.Get_ReadingAlpha());
        DoRefresh_Presentation();
    }

    private void DoApply_ReadingOffset(float32 InAlpha)
    {
        if (ck::Is_NOT_Valid(_VisualNode) || ck::Is_NOT_Valid(_Presentation) || ck::Is_NOT_Valid(_WorldItem))
        { return; }

        const auto Presentation = utils_world_item::TryGet_Presentation(_WorldItem);
        if (ck::Is_NOT_Valid(Presentation))
        { return; }

        const auto Alpha = Math::Clamp(InAlpha, 0.0f, 1.0f);
        const auto Recenter = FVector(constants_cookbook::k_ClosedSpineOffset * Alpha, 0.0, 0.0) * Presentation.Visual.MeshScale;
        const auto ReadOffset = Presentation.Mounting.HeldOffset.InverseTransformVector(_Presentation.ReadingHandOffset * Alpha);
        const auto Offset = FTransform(FRotator::ZeroRotator, Recenter + ReadOffset, Presentation.Visual.MeshScale);
        utils_scene_node::Request_UpdateOffset(_VisualNode, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    UFUNCTION()
    private void OnReadingPoseChanged(float32 InAlpha)
    { DoApply_ReadingOffset(InAlpha); }

    UFUNCTION()
    private void OnCookbookMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrevious, EMars_WorldItem_Mount InNew)
    { DoRefresh_Presentation(); }
}
