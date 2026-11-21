// The crawler net rig plus one production pawn a client controls: each machine stands the pawn on a slab of its own
// (a plain static mesh actor does not replicate, and a pawn the client controls moves on the client's world); the
// server spawns the AMars_PlayerCharacter, hands it to the one player controller in its world that is not local and
// gives that controller its old pawn back at the end. Each machine finds its copy of the pawn near its spot, takes its
// entity, its Health and its zone, records the applied amount and the frame of every OnDamaged its Health raises and,
// off authority, the frame of every rep-notify of its Health's ledger. The crawler's own Health, zone and target stay
// the crawler rig's. The server can put a lit lantern in the pawn's hand; the client lowers it with its select cue.
UCLASS(Abstract)
class UMars_AutoTestRig_NetCrawlerPawn : UMars_AutoTestRig_NetCrawler
{
    // A pawn is found within this of its spot.
    protected const float64 k_BlowPawnNearCm = 150.0;

    protected FVector _PawnAt = FVector::ZeroVector;
    protected AMars_PlayerCharacter _BlowPawn;
    protected FCk_Handle _BlowPlayer;
    protected FCk_Handle_Health _BlowHealth;
    protected FCk_Handle_HitZone _BlowZone;

    // The applied amount of every OnDamaged this machine's copy of the pawn raised, and the frame of the first (-1
    // before).
    protected TArray<float32> _BlowApplied;
    protected int32 _BlowDamagedFrame = -1;
    protected TArray<int32> _BlowNotifyFrames;
    // The first frame the server sampled its crawler's combat target as the pawn's entity; -1 before.
    protected int32 _BlowTargetFrame = -1;

    private AStaticMeshActor _BlowSlab;
    private bool _IsServerBlowPawn = false;
    private APlayerController _BlowRemoteController;
    private APawn _BlowRemotePreviousPawn;

    // Both machines: the crawler row at InBase, the pawn's spot at InPawnOffset from it and the slab under that spot.
    protected void Begin_CrawlerPawnRow(FVector InBase, FVector InPawnOffset)
    {
        Begin_CrawlerRow(InBase);
        _PawnAt = InBase + InPawnOffset;
        Spawn_BlowSlab();
    }

    protected UWorld Get_BlowWorld()
    {
        return utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
    }

    // An engine cube scaled to a 20 m slab centred under the pawn's spot, its top face at the spot's Z.
    private void Spawn_BlowSlab()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _BlowSlab = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, _PawnAt - FVector(0.0, 0.0, 50.0)));
        if (ck::Is_NOT_Valid(_BlowSlab) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the slab (the engine cube) did not spawn");
            return;
        }

        _BlowSlab.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _BlowSlab.StaticMeshComponent.SetStaticMesh(Cube);
        _BlowSlab.SetActorScale3D(FVector(20.0, 20.0, 1.0));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the pawn and its controller
    //----------------------------------------------------------------------------------------------------------------------

    // The production pawn standing at its spot, facing +X, possessed by nobody.
    protected void Spawn_ServerBlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        _BlowPawn = Cast<AMars_PlayerCharacter>(SpawnActor(AMars_PlayerCharacter, _PawnAt + FVector(0.0, 0.0, HalfHeight + 2.0), FRotator::ZeroRotator));
        _IsServerBlowPawn = ck::IsValid(_BlowPawn);
        if (_IsServerBlowPawn == false)
        { FinishFailure("AMars_PlayerCharacter did not spawn on the server"); }
    }

    // Hands the pawn to the one player controller in the server's world that is not local, found by a scan of the
    // world's player controllers. False (nothing possessed) without exactly one.
    protected bool Request_ServerPossessBlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);

        APlayerController Remote;
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController())
            { continue; }

            Remote = Controller;
            Count += 1;
        }

        if (Count != 1)
        { return false; }

        _BlowRemoteController = Remote;
        _BlowRemotePreviousPawn = Remote.GetControlledPawn();
        Remote.Possess(_BlowPawn);
        return true;
    }

    // The remote controller gets its old pawn back. Safe to call twice.
    protected void Request_ServerReturnRemote()
    {
        if (ck::Is_NOT_Valid(_BlowRemoteController))
        { return; }

        const auto Controlled = _BlowRemoteController.GetControlledPawn();
        if (ck::IsValid(Controlled) && Controlled == _BlowPawn)
        { _BlowRemoteController.UnPossess(); }

        if (ck::IsValid(_BlowRemotePreviousPawn) && _BlowRemoteController.GetControlledPawn() != _BlowRemotePreviousPawn)
        { _BlowRemoteController.Possess(_BlowRemotePreviousPawn); }

        _BlowRemoteController = nullptr;
    }

    // Returns the controller, destroys the pawn this machine spawned and this machine's slab. Safe to call twice.
    protected void TearDown_BlowPawn()
    {
        Request_ServerReturnRemote();
        if (_IsServerBlowPawn && ck::IsValid(_BlowPawn))
        { _BlowPawn.DestroyActor(); }

        if (ck::IsValid(_BlowSlab))
        { _BlowSlab.DestroyActor(); }

        _BlowSlab = nullptr;
        _IsServerBlowPawn = false;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        TearDown_BlowPawn();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The pawn's lantern: the server's pickup and light for it, the client's stow
    //----------------------------------------------------------------------------------------------------------------------

    // Server: the lantern world item it spawned for the pawn.
    protected FCk_Handle _Lantern;

    // Server: a lantern world item just in front of the pawn's spot under the replicated spawn owner, tracked.
    protected void Spawn_ServerLanternForPawn()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Lantern()),
            FTransform(FRotator::ZeroRotator, _PawnAt + FVector(40.0, 0.0, 20.0)));
        _Lantern = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(_Lantern);
    }

    // Server: the lantern's body has linked its item, it carries a flame, and the pawn's hotbar is ready.
    protected bool Get_IsServerLanternReady()
    {
        const auto WorldItem = _Lantern.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto Hotbar = Get_PawnHotbar();
        return ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() && ck::IsValid(WorldItem.Get_HeldItem())
            && ck::IsValid(_Lantern.As_Flame(ECk_SanityCheck::UnChecked)) && ck::IsValid(Hotbar) && Hotbar.Get_IsReady();
    }

    // Server: the pawn picks the lantern up (what a client's pickup cue becomes on the host) and the lantern is lit.
    protected void Request_ServerRaiseLitLantern()
    {
        auto WorldItem = _Lantern.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_BlowPlayer));
        auto Flame = _Lantern.As_Flame();
        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    protected FCk_Handle_Hotbar Get_PawnHotbar()
    {
        if (ck::Is_NOT_Valid(_BlowPlayer))
        { return FCk_Handle_Hotbar(); }

        return _BlowPlayer.As_Hotbar(ECk_SanityCheck::UnChecked);
    }

    // The pawn's hotbar selection on this machine; -1 without one.
    protected int32 Get_PawnSelection()
    {
        const auto Hotbar = Get_PawnHotbar();
        if (ck::Is_NOT_Valid(Hotbar))
        { return -1; }

        const auto Selected = Hotbar.Get_SelectedIndex();
        return Selected.IsSet() ? Selected.GetValue() : -1;
    }

    // The flame of the item in the pawn's hand on this machine, its body Held; invalid without one.
    protected FCk_Handle_Flame Get_PawnHeldFlame()
    {
        if (ck::Is_NOT_Valid(_BlowPlayer))
        { return FCk_Handle_Flame(); }

        const auto HeldItem = _BlowPlayer.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(HeldItem))
        { return FCk_Handle_Flame(); }

        const auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_PersistentWorldItem() == false)
        { return FCk_Handle_Flame(); }

        const auto Body = Item.Get_PersistentWorldItem();
        const auto Flame = Body.H().As_Flame(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Flame) || Body.Get_Mount() != EMars_WorldItem_Mount::Held)
        { return FCk_Handle_Flame(); }

        return Flame;
    }

    // A client: its pawn's hotbar selects the other of its first two slots (the empty one beside the lantern's) through
    // its select cue. Returns the slot asked for.
    protected int32 Fire_ClientStowCue()
    {
        const auto To = Get_PawnSelection() == 0 ? 1 : 0;
        utils_hotbar::Fire_SelectCue(Get_PawnHotbar(), FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Select(To)));
        return To;
    }

    // A client: its pawn and the flame item near the pawn's spot, watched from the first sample both are found.
    protected UMars_AutoTestHelper_HeldFlameDepth _LanternWatch;

    protected void Sample_RowExtra() override
    {
        if (Get_IsServer())
        { return; }

        if (ck::Is_NOT_Valid(_LanternWatch))
        { _LanternWatch = Cast<UMars_AutoTestHelper_HeldFlameDepth>(NewObject(this, UMars_AutoTestHelper_HeldFlameDepth)); }

        if (_LanternWatch.Get_IsWatching() == false && Get_IsBlowPawnComposed())
        {
            for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
            {
                auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
                if (ck::Is_NOT_Valid(WorldItem) || ck::Is_NOT_Valid(Candidate.As_Flame(ECk_SanityCheck::UnChecked)))
                { continue; }

                const auto Location = utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform());
                if ((Location - _PawnAt).Size() < 300.0)
                {
                    _LanternWatch.Watch(_BlowPawn, WorldItem);
                    break;
                }
            }
        }

        _LanternWatch.Sample();
    }

    protected FString Describe_PawnLantern()
    {
        const auto Held = Get_PawnHeldFlame();
        auto Mount = FString("none");
        auto Carrier = false;
        auto Pool = FString("none");
        auto Lit = false;
        const auto Flame = ck::IsValid(_Lantern) ? _Lantern.As_Flame(ECk_SanityCheck::UnChecked) : Held;
        if (ck::IsValid(Flame))
        {
            const auto WorldItem = Flame.H().As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(WorldItem))
            {
                Mount = f"{WorldItem.Get_Mount() :n}";
                Carrier = WorldItem.Get_Carrier() == _BlowPlayer;
            }

            const auto Shown = Flame.Get_ShownLightPool();
            Pool = Shown.IsSet() ? f"{Shown.GetValue() :n}" : FString("none");
            Lit = Flame.Get_IsLit();
        }

        const auto Watch = ck::IsValid(_LanternWatch) ? _LanternWatch.Describe() : FString("");
        return f"lantern=[held {ck::IsValid(Held)} lit {Lit} mount {Mount} carrierIsPawn {Carrier} pool {Pool} selection {Get_PawnSelection()}] {Watch}";
    }

    // Server: the first frame its crawler's combat target is the pawn's entity.
    protected void Sample_BlowTarget()
    {
        if (_BlowTargetFrame >= 0 || Get_IsServer() == false || Get_IsCrawlerGone() || ck::Is_NOT_Valid(_BlowPlayer))
        { return; }

        if (_Crawler.Get_CombatTarget() == _BlowPlayer)
        { _BlowTargetFrame = int32(utils_time::Get_FrameCounter()); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy of the pawn
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_BlowPawnComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBlowPawnComposed());
    }

    // This machine's copy of the pawn near its spot has composed its entity, its Health and its zone; the first time,
    // its Health's signals are recorded from here.
    protected bool Get_IsBlowPawnComposed()
    {
        if (ck::IsValid(_BlowHealth))
        { return true; }

        if (ck::Is_NOT_Valid(_BlowPawn))
        { _BlowPawn = DoFind_BlowPawn(); }

        if (ck::Is_NOT_Valid(_BlowPawn))
        { return false; }

        if (ck::Is_NOT_Valid(_BlowPlayer))
        { _BlowPlayer = _BlowPawn.Get_GameplayComposedEntity(); }

        if (ck::Is_NOT_Valid(_BlowPlayer))
        { return false; }

        auto Health = _BlowPlayer.As_Health(ECk_SanityCheck::UnChecked);
        auto Zone = _BlowPlayer.As_HitZone(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
        { return false; }

        _BlowZone = Zone;
        _BlowHealth = Health;
        _BlowHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnBlowPawnDamaged"));
        if (Get_IsServer() == false)
        { _BlowPlayer.BindTo_OnRepNotify(FMars_Fragment_Health_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBlowPawnHealthNotify")); }

        return true;
    }

    // The AMars_PlayerCharacter in this machine's world nearest the pawn's spot, within k_BlowPawnNearCm; null without
    // one.
    private AMars_PlayerCharacter DoFind_BlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Pawns = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(AMars_PlayerCharacter, Pawns);

        AMars_PlayerCharacter Found;
        auto Nearest = k_BlowPawnNearCm;
        for (auto Actor : Pawns)
        {
            if (ck::Is_NOT_Valid(Actor))
            { continue; }

            const auto Distance = (Actor.GetActorLocation() - _PawnAt).Size();
            if (Distance >= Nearest)
            { continue; }

            Found = Cast<AMars_PlayerCharacter>(Actor);
            Nearest = Distance;
        }

        return Found;
    }

    protected bool Get_BlowPawnHasTag(FName InTag)
    {
        return ck::IsValid(_BlowPlayer) && utils_entity_tag::Has(_BlowPlayer, InTag);
    }

    protected FString Describe_BlowPawn()
    {
        auto Applied = FString();
        for (const auto& Amount : _BlowApplied)
        { Applied += f"{Amount},"; }

        const auto Current = ck::IsValid(_BlowHealth) ? _BlowHealth.Get_Current() : -1.0f;
        const auto HasAuthority = ck::IsValid(_BlowPlayer) && utils_net::Get_HasAuthority(_BlowPlayer);
        const auto IsLocal = ck::IsValid(_BlowPawn) && _BlowPawn.IsLocallyControlled();
        const auto HasShared = Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget");
        const auto HasLocal = Get_BlowPawnHasTag(n"TAG_MarsCombatTarget");
        return f"pawn=[health {Current} damaged {_BlowApplied.Num()} applied {Applied} damagedFrame {_BlowDamagedFrame} "
            + f"shared {HasShared} local {HasLocal} authority {HasAuthority} locallyControlled {IsLocal} "
            + f"targetFrame {_BlowTargetFrame} notifies {_BlowNotifyFrames.Num()}]";
    }

    UFUNCTION()
    private void OnBlowPawnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _BlowApplied.Add(InApplied);
        if (_BlowDamagedFrame < 0)
        { _BlowDamagedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    // A notify can land on a pawn already ending.
    UFUNCTION()
    private void OnBlowPawnHealthNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Health_Net) == false)
        { return; }

        _BlowNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
    }
}

namespace mars_test_scene_depth
{
    // InNode's scene-node depth on this machine; -1 when it holds no layer.
    int32 Get_Depth(const FCk_Handle& InNode)
    {
        if (ck::Is_NOT_Valid(InNode))
        { return -1; }

        const auto Depth = utils_scene_node::Get_Depth(InNode);
        return Depth.IsSet() ? Depth.GetValue() : -1;
    }

    // The deepest scene-node depth in InRoot's transform tree (utils_fphands::Get_TransformTree) on this machine; -1
    // when none of it is layered.
    int32 Get_Deepest(const FCk_Handle& InRoot)
    {
        auto Deepest = -1;
        for (auto Entity : utils_fphands::Get_TransformTree(InRoot))
        { Deepest = Math::Max(Deepest, Get_Depth(Entity)); }

        return Deepest;
    }

    // Every layered node of InRoot's tree as name:depth.
    FString Describe(const FCk_Handle& InRoot)
    {
        FString Text = "";
        for (auto Entity : utils_fphands::Get_TransformTree(InRoot))
        {
            const auto Depth = Get_Depth(Entity);
            if (Depth >= 0)
            { Text += f"{utils_handle::Get_DebugName(Entity)}:{Depth},"; }
        }

        return Text;
    }

    // The node of InRoot's tree named InName (utils_handle::Set_DebugName); invalid without one.
    FCk_Handle Find_Named(const FCk_Handle& InRoot, FName InName)
    {
        for (auto Entity : utils_fphands::Get_TransformTree(InRoot))
        {
            if (utils_handle::Get_DebugName(Entity) == InName)
            { return Entity; }
        }

        return FCk_Handle();
    }
}

// Watches one machine's copy of a pawn and the flame item it raises: HandMount's parent when the item's mount committed
// Held (the pawn's body grip, its first-person hand node, or other), the first sampled frame HandMount was under the
// hand node, the deepest scene node under the item at the mount and at every sample while it is held, and where the
// flame node and its light sit. A lantern's flame stands k_LanternFlameHeight over its root while the bail rests, and
// its light half the look's FxSize over the flame (UMars_Lantern_EntityScript, UMars_FlameDressing).
class UMars_AutoTestHelper_HeldFlameDepth : UObject
{
    const float64 k_LanternFlameHeight = 14.0;
    const float64 k_LanternFxSize = 10.0;

    AMars_PlayerCharacter Pawn;
    FCk_Handle_WorldItem Item;
    FString ParentAtMount = "";
    int32 MountFrame = -1;
    int32 DepthAtMount = -1;
    int32 HandMountDepthAtMount = -1;
    int32 FlipFrame = -1;
    int32 Deepest = -1;
    int32 HeldSamples = 0;
    FString TreeAtDeepest = "";

    // Binds InItem's mount signal; an item already Held reads "heldBeforeWatch".
    void Watch(AMars_PlayerCharacter InPawn, FCk_Handle_WorldItem InItem)
    {
        Pawn = InPawn;
        Item = InItem;
        if (Item.Get_Mount() == EMars_WorldItem_Mount::Held)
        { ParentAtMount = "heldBeforeWatch"; }

        Item.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));
    }

    bool Get_IsWatching() const
    {
        return ck::IsValid(Item);
    }

    // HandMount's parent now: "body", "firstPerson", "other" or "none".
    FString Get_HandMountParent() const
    {
        if (ck::Is_NOT_Valid(Pawn))
        { return "none"; }

        FCk_Handle MountEntity = Pawn.Get_HandMount();
        const auto Node = MountEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return "none"; }

        FCk_Handle Parent = utils_scene_node::Get_Parent(Node);
        FCk_Handle Body = Pawn.Get_BodyGrip();
        if (Parent == Body)
        { return "body"; }

        const auto Player = Pawn.Get_GameplayComposedEntity();
        const auto Hands = ck::IsValid(Player) ? Player.As_FPHands(ECk_SanityCheck::UnChecked) : FCk_Handle_FPHands();
        if (ck::IsValid(Hands))
        {
            FCk_Handle HandNode = Hands.Get_HandNode();
            if (Parent == HandNode)
            { return "firstPerson"; }
        }

        return "other";
    }

    int32 Get_HandMountDepth() const
    {
        if (ck::Is_NOT_Valid(Pawn))
        { return -1; }

        FCk_Handle Mount = Pawn.Get_HandMount();
        return mars_test_scene_depth::Get_Depth(Mount);
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        if (InNew != EMars_WorldItem_Mount::Held || MountFrame >= 0)
        { return; }

        MountFrame = int32(utils_time::Get_FrameCounter());
        if (ParentAtMount.IsEmpty())
        { ParentAtMount = Get_HandMountParent(); }

        DepthAtMount = mars_test_scene_depth::Get_Deepest(Item.H());
        HandMountDepthAtMount = Get_HandMountDepth();
    }

    // Once a frame (more is harmless): the flip frame, and the deepest node while the item is Held.
    void Sample()
    {
        if (ck::Is_NOT_Valid(Pawn))
        { return; }

        if (FlipFrame < 0 && Get_HandMountParent() == "firstPerson")
        { FlipFrame = int32(utils_time::Get_FrameCounter()); }

        if (ck::Is_NOT_Valid(Item) || Item.Get_Mount() != EMars_WorldItem_Mount::Held)
        { return; }

        HeldSamples += 1;
        const auto Depth = mars_test_scene_depth::Get_Deepest(Item.H());
        if (Depth > Deepest)
        {
            Deepest = Depth;
            TreeAtDeepest = mars_test_scene_depth::Describe(Item.H());
        }
    }

    // The light's world distance from half the look's FxSize over the flame node; -1 without both nodes.
    float64 Get_LightErrorCm() const
    {
        FCk_Handle Root = Item;
        const auto Flame = mars_test_scene_depth::Find_Named(Root, n"FlameItem.Flame");
        const auto Light = mars_test_scene_depth::Find_Named(Root, n"Flame.Light");
        if (ck::Is_NOT_Valid(Flame) || ck::Is_NOT_Valid(Light))
        { return -1.0; }

        const auto Expected = utils_transform::Get_EntityCurrentTransform(Flame.As_Transform()).TransformPosition(FVector(0.0, 0.0, k_LanternFxSize * 0.5));
        return (utils_transform::Get_EntityCurrentLocation(Light.As_Transform()) - Expected).Size();
    }

    // The flame node's world distance from k_LanternFlameHeight over the item's root; -1 without it.
    float64 Get_FlameNodeErrorCm() const
    {
        FCk_Handle Root = Item;
        const auto Flame = mars_test_scene_depth::Find_Named(Root, n"FlameItem.Flame");
        if (ck::Is_NOT_Valid(Flame))
        { return -1.0; }

        const auto Expected = utils_transform::Get_EntityCurrentTransform(Root.As_Transform()).TransformPosition(FVector(0.0, 0.0, k_LanternFlameHeight));
        return (utils_transform::Get_EntityCurrentLocation(Flame.As_Transform()) - Expected).Size();
    }

    // The light's world location; zero without it.
    FVector Get_LightLocation() const
    {
        FCk_Handle Root = Item;
        const auto Light = mars_test_scene_depth::Find_Named(Root, n"Flame.Light");
        return ck::IsValid(Light) ? utils_transform::Get_EntityCurrentLocation(Light.As_Transform()) : FVector::ZeroVector;
    }

    FString Describe() const
    {
        return f"heldFlame=[parentAtMount {ParentAtMount} mountFrame {MountFrame} flipFrame {FlipFrame} depthAtMount {DepthAtMount} "
            + f"handMountAtMount {HandMountDepthAtMount} handMountNow {Get_HandMountDepth()} deepest {Deepest} samples {HeldSamples} "
            + f"lightError {Get_LightErrorCm() :.3} flameNodeError {Get_FlameNodeErrorCm() :.3} tree [{TreeAtDeepest}]]";
    }
}
