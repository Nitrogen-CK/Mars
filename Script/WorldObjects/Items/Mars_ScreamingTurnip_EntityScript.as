// The Screaming Turnip's persistent world item: the base's visual, body, pickup, holder, mounting, release and grip nodes
// (the definition's Grip.Points), with the body reporting persisted contacts (DoConfigure_BodySpec: the kernel's support
// sample needs them); then the ScreamingTurnip kernel on the same entity and the animated skeletal presentation that
// follows it. The static proxy (the base's visual) stays the body's shape and the pickup's fit; it is drawn only while no
// skeletal mesh loads. A Visual-mode spawn (a held visual of a non-persistent item) is the base's: it carries no kernel.
class UMars_ScreamingTurnip_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::ScreamingTurnip();

    // The voice's timings; tests spawn with short ones.
    UPROPERTY(ExposeOnSpawn)
    FMars_ScreamingTurnip_Vocal Vocal;

    UPROPERTY(ExposeOnSpawn)
    FMars_ScreamingTurnip_Settlement Settlement;

    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_ScreamingTurnip _Turnip;
    private UStaticMeshComponent _Proxy;
    private UMars_ScreamingTurnipPresentationComponent _Presentation;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (Mode != EMars_WorldItem_Mode::World)
        { return Flow; }

        // A rejected definition or spec destroyed the entity (the base ensured).
        _WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_WorldItem))
        { return Flow; }

        const auto HasBody = ck::IsValid(_WorldItem.Get_Body());
        if (ck::EnsureIfNot(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent && HasBody,
            f"[ScreamingTurnip] [{InHandle.ToString()}] needs a definition with a persistent Presentation and a proxy mesh (its body)"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return Flow;
        }

        auto Spec = FMars_ScreamingTurnip_Spec();
        Spec.Vocal = Vocal;
        Spec.Settlement = Settlement;
        Spec.Parts = FMars_ScreamingTurnip_Parts(_WorldItem);
        _Turnip = utils_screaming_turnip::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(_Turnip))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _Turnip.BindTo_OnPhaseChanged(FMars_Delegate_ScreamingTurnip_OnPhaseChanged(this, n"OnTurnipPhaseChanged"));
        _Turnip.BindTo_OnPlacementChanged(FMars_Delegate_ScreamingTurnip_OnPlacementChanged(this, n"OnTurnipPlacementChanged"));
        _WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnTurnipMountChanged"));

        auto Root = InHandle.As_Transform();
        AddTurnipPresentation(Root);
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Turnip))
        {
            _Turnip.UnbindFrom_OnPhaseChanged(FMars_Delegate_ScreamingTurnip_OnPhaseChanged(this, n"OnTurnipPhaseChanged"));
            _Turnip.UnbindFrom_OnPlacementChanged(FMars_Delegate_ScreamingTurnip_OnPlacementChanged(this, n"OnTurnipPlacementChanged"));
        }

        if (ck::IsValid(_WorldItem))
        { _WorldItem.UnbindFrom_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnTurnipMountChanged")); }

        _Turnip = FCk_Handle_ScreamingTurnip();
        _WorldItem = FCk_Handle_WorldItem();
        _Presentation = nullptr;
        _Proxy = nullptr;
        Super::DoEndPlay(InHandle);
    }

    // Invalid in Visual mode and before construction.
    FCk_Handle_ScreamingTurnip Get_Turnip() const
    { return _Turnip; }

    //--------------------------------------------------------------------------------------------------------------------------
    // Composition
    //--------------------------------------------------------------------------------------------------------------------------

    // The base body, reporting persisted contacts (the kernel's support sample stamps them).
    protected void DoConfigure_BodySpec(FCk_JoltBody_Spec& InOutSpec) override
    {
        InOutSpec.Set_PersistContacts(ECk_EnableDisable::Enable);
    }

    // The base's proxy visual exists: it is drawn only while the skeletal mesh is absent.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        _Proxy = InMesh;
        DoRefresh_Drawing();
    }

    private void AddTurnipPresentation(FCk_Handle_Transform& InRoot)
    {
        auto VisualNode = utils_scene_node::Create(InRoot, constants_screaming_turnip_assets::k_SkeletalOffset);
        utils_handle::Set_DebugName(VisualNode.H(), n"ScreamingTurnip.Visual");
        const auto Params = utils_unreal_component::Make_Params(UMars_ScreamingTurnipPresentationComponent,
            ECk_UnrealComponent_TickPolicy::TickViaProcessor, n"ScreamingTurnip_Presentation");
        auto ComponentHandle = utils_unreal_component::Add(VisualNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(ComponentHandle, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPresentationAdded"));
    }

    // The proxy is drawn only while the skeletal mesh is absent (not created yet, or not loaded).
    private void DoRefresh_Drawing()
    {
        const auto HasSkeletal = ck::IsValid(_Presentation) && _Presentation.Get_HasMesh();
        if (ck::IsValid(_Proxy))
        {
            _Proxy.SetVisibility(HasSkeletal == false);
            _Proxy.SetCastShadow(HasSkeletal == false);
        }

        if (ck::IsValid(_Presentation) && HasSkeletal && ck::IsValid(_WorldItem))
        { _Presentation.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_WorldItem)); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPresentationAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Presentation = Cast<UMars_ScreamingTurnipPresentationComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Presentation), "[ScreamingTurnip] the skeletal presentation component was not created"))
        { return; }

        _Presentation.Set_Turnip(_Turnip);
        DoRefresh_Drawing();
    }

    UFUNCTION()
    private void OnTurnipPhaseChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew)
    {
        if (ck::IsValid(_Presentation))
        { _Presentation.Refresh_FromKernel(); }
    }

    UFUNCTION()
    private void OnTurnipPlacementChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Placement InPrevious,
                                          EMars_ScreamingTurnip_Placement InNew)
    {
        if (ck::IsValid(_Presentation))
        { _Presentation.Refresh_FromKernel(); }
    }

    UFUNCTION()
    private void OnTurnipMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrevious, EMars_WorldItem_Mount InNew)
    {
        DoRefresh_Drawing();
    }
}
