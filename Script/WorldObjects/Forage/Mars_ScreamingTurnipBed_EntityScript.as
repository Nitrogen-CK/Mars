// A planted Screaming Turnip: a one-shot Forage (one charge, Persists, no regrow) whose release is an unarmed pull. Its
// Use target is Timed (Grip + Tug seconds), needs both hands free and is worked AfterCompletion: a press held through the
// duration runs UMars_SmState_ScreamingTurnipBed_Pull, which claims the target and asks the Forage for one Plucked release;
// a press let go early cancels the interaction and consumes nothing. The release is the ordinary Forage -> WorldItem
// yield (Request_SpawnWorld at the release point, hopping out of the bed): the bed never spawns, parents or destroys it.
//
// Not a UMars_ForageSource_EntityScript: that base composes a Health, a strike HitZone and a knock body, none of which an
// unarmed pull has, and its yield visibility casts to a static mesh; this bed owns its own visibility.
//
// The target is claimed (EMars_Interactable_DisableReason::Exhausted: the Forage holds no charge any more) from the
// pull's completion on and again on exhaustion, and never released: the bed does not regrow.
//
// The pull's look: the planted root plays SRC_Grip over GripSeconds then SRC_Tug over TugSeconds (each clip stretched to
// span its stage), and the gloves ride the stalks: the two grip nodes the gloves hold are moved every tick to the
// planted mesh's HarvestGrip sockets (position; the authored handed rotation stays), from the press until the root is
// out or the cancel has returned the root to its idle. A pull let go early plays SRC_Cancel from the strain the Tug had
// reached (SRC_Cancel eases the full strain back to the rest, so its pose at 1 - alpha is near the Tug's at alpha).
class UMars_ScreamingTurnipBed_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // The two stages of the pull, seconds; the hold lasts their sum. Twice the clips' authored 0.2 + 0.5 s (the maintainer's
    // 2026-11-06 ruling: a longer pull is easier to test and judge); the clips are stretched to span the stages.
    UPROPERTY(ExposeOnSpawn)
    float32 GripSeconds = 0.4f;

    UPROPERTY(ExposeOnSpawn)
    float32 TugSeconds = 1.0f;

    // The yield's hop out of the bed, in the bed's frame: it lands on the floor beside the bed, within reach, and rolls and
    // settles by physics (never set upright). Kept at the 48 cm size: from the 60 cm release point the root lands 77.6 cm
    // out, on its side, mouth back toward the bed and 28 deg up (PIE run-03, both beds).
    UPROPERTY(ExposeOnSpawn)
    FVector ReleaseLaunch = FVector(120.0, 0.0, 170.0);

    // The yield's spin, degrees/s about the WORLD axes (the Forage launch does not turn it into the bed's frame): a yaw
    // only, so the hop does not tumble it over its mouth.
    UPROPERTY(ExposeOnSpawn)
    FVector ReleaseSpinDeg = FVector(0.0, 0.0, 270.0);

    // The hop starts 60 cm over the soil-line centre, the 48 cm root's base clear of the bed top (+2.06 cm; manifest
    // gameplay_numbers.k_ReleasePointOffset_suggestion).
    private const FVector k_ReleasePointOffset = FVector(0.0, 0.0, 60.0);
    // The Use probe covers the 72 cm bed (half 36, + 4 cm) from its bottom (-10.2) to the planted root's tallest clip pose
    // (envelope top 61.79 - soil line 28.8 = 33.0 cm over the soil line): Z -10 .. +34 (manifest gameplay_numbers.bed,
    // dimensions_cm.global_clip_envelope, planted.soil_line_z). The yield lands 77.6 cm out (PIE run-03), clear of it.
    private const FVector k_ProbeHalfExtents = FVector(40.0, 40.0, 22.0);
    private const FVector k_ProbeOffset = FVector(0.0, 0.0, 12.0);

    private FCk_Handle _Self;
    private FCk_Handle_Transform _Root;
    private FCk_Handle_Forage _Forage;
    private FCk_Handle_Interactable _Interactable;
    // The pull's glove targets (AddHarvestGrips) and their authored rotations in the bed's frame.
    private FCk_Handle_SceneNode _HarvestGrip_R;
    private FCk_Handle_SceneNode _HarvestGrip_L;
    private FQuat _HarvestGripRotation_R;
    private FQuat _HarvestGripRotation_L;
    // Runs from a press until the root is out or back at its idle: keeps the grip nodes on the stalk sockets.
    private FCk_Handle_Timer _FollowTick;
    private FCk_Handle_UnrealComponent _BedPart;
    private FCk_Handle_UnrealComponent _BedEmptyPart;
    private FCk_Handle_UnrealComponent _PlantedPart;
    private UMars_ScreamingTurnipPresentationComponent _Planted;
    private bool _IsHarvested = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_handle::Set_DebugName(InHandle, n"ScreamingTurnipBed");
        _Self = InHandle;
        _Root = Root;

        auto ReleasePoint = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_ReleasePointOffset)).As_Transform();

        auto Spec = FMars_Forage_Spec();
        Spec.Yield = FMars_Forage_YieldSpec(mars_items::ScreamingTurnip(), 1);
        Spec.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Persists);
        Spec.Launch = FMars_Forage_LaunchSpec(ReleaseLaunch, ReleaseSpinDeg);
        Spec.Parts = FMars_Forage_Parts(ReleasePoint);
        _Forage = utils_forage::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(_Forage))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));
        _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));

        AddInteractable(Root);
        AddVisuals(Root);
        AddHarvestGrips(InHandle, Root);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        DoDestroy_FollowTick();
        if (ck::IsValid(_Forage))
        {
            _Forage.UnbindFrom_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));
            _Forage.UnbindFrom_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));
        }

        if (ck::IsValid(_Interactable))
        {
            _Interactable.UnbindFrom_OnInteractionStarted(GameplayTags::InteractionChannel_Mars_Use,
                FMars_Delegate_Interactable_OnInteractionStarted(this, n"OnPullStarted"));
            _Interactable.UnbindFrom_OnInteractionFinished(GameplayTags::InteractionChannel_Mars_Use,
                FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnPullFinished"));
        }

        _Forage = FCk_Handle_Forage();
        _Interactable = FCk_Handle_Interactable();
        _Planted = nullptr;
    }

    // Invalid before construction.
    FCk_Handle_Interactable Get_Interactable() const
    { return _Interactable; }

    //--------------------------------------------------------------------------------------------------------------------------
    // Composition
    //--------------------------------------------------------------------------------------------------------------------------

    private void AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(k_ProbeHalfExtents));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, k_ProbeOffset);

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Timed);
        TargetSpec.Set_InteractionDuration(FCk_Time(GripSeconds + TugSeconds));

        UCk_InventoryItem_Definition Yield = mars_items::ScreamingTurnip();
        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString(f"Pull {Yield.Get_CoreInfo().Get_Name().ToString()}");

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_ScreamingTurnipBed_Pull;
        Target.RequiresFreeHands = true;
        Target.Work = EMars_Interactable_Work::AfterCompletion;
        Target.ReachKind = EMars_FPHands_ReachKind::Hold;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);

        _Interactable = utils_interactable::Create(InRoot, Spec);
        _Interactable.BindTo_OnInteractionStarted(GameplayTags::InteractionChannel_Mars_Use,
            FMars_Delegate_Interactable_OnInteractionStarted(this, n"OnPullStarted"));
        _Interactable.BindTo_OnInteractionFinished(GameplayTags::InteractionChannel_Mars_Use,
            FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnPullFinished"));
    }

    // The pull's glove targets: the bed's grip table (the interactable's owner is this entity, as a Station's is), one node
    // per hand on the planted root's leaf stalks, Power pose, the node's own frame: fingers forward (+X, round the stalk
    // from the bed's -X side, where the Use reach comes from), palm in toward the crown. They start at the bind-pose
    // sockets (constants_screaming_turnip_assets::k_HarvestGripLocation_R / _L placed through k_PlantedOffset) and ride
    // the planted mesh's sockets through a pull (OnFollowTick); FPHands re-reads a grip node's transform every tick.
    private void AddHarvestGrips(FCk_Handle& InHandle, FCk_Handle_Transform& InRoot)
    {
        const auto Planted = constants_screaming_turnip_assets::k_PlantedOffset;
        _HarvestGripRotation_R = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::RightVector);
        _HarvestGripRotation_L = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, FVector::RightVector);
        _HarvestGrip_R = utils_scene_node::Create(InRoot, FTransform(_HarvestGripRotation_R,
            Planted.TransformPosition(constants_screaming_turnip_assets::k_HarvestGripLocation_R)));
        _HarvestGrip_L = utils_scene_node::Create(InRoot, FTransform(_HarvestGripRotation_L,
            Planted.TransformPosition(constants_screaming_turnip_assets::k_HarvestGripLocation_L)));
        utils_handle::Set_DebugName(_HarvestGrip_R.H(), n"ScreamingTurnipBed.HarvestGrip_R");
        utils_handle::Set_DebugName(_HarvestGrip_L.H(), n"ScreamingTurnipBed.HarvestGrip_L");

        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, _HarvestGrip_R.As_Transform(), TOptional<FName>(),
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Left, _HarvestGrip_L.As_Transform(), TOptional<FName>(),
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        utils_fphands::Add_Grips(InHandle, Entries);
    }

    // The grip nodes onto the planted mesh's stalk sockets (bed-frame position; the authored rotation), each tick of a
    // pull. Stops once the root is out (the sockets are gone with it) or the planted idle is back; nothing to follow
    // without the skeletal mesh.
    private void DoStart_Following()
    {
        if (ck::Is_NOT_Valid(_FollowTick) && ck::IsValid(_Planted) && _Planted.Get_HasMesh())
        { _FollowTick = utils_timer::Create_Tick(_Self, FCk_Delegate_Timer(this, n"OnFollowTick")); }
    }

    private void DoDestroy_FollowTick()
    {
        if (ck::Is_NOT_Valid(_FollowTick))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_FollowTick.H());
        _FollowTick = FCk_Handle_Timer();
    }

    private void DoMove_GripNode(FCk_Handle_SceneNode& InNode, FName InSocket, const FQuat& InRotation)
    {
        const auto SocketWorld = _Planted.GetSocketTransform(InSocket, ERelativeTransformSpace::RTS_World).GetLocation();
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        utils_scene_node::Request_UpdateOffset(InNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(InRotation, RootWorld.InverseTransformPosition(SocketWorld))));
    }

    // The bed and the empty bed (one shown at a time, pivot at the soil-line centre), the planted root's static stand-in
    // (the item's proxy hull) and the planted skeletal mesh, which hides the stand-in once it loads; both sit at
    // k_PlantedOffset. Meshes come from constants_screaming_turnip_assets.
    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        const auto BedScale = constants_screaming_turnip_assets::k_BedScale;
        const auto BedTransform = FTransform(FRotator::ZeroRotator, FVector::ZeroVector, BedScale);
        auto Soil = assets::load::ProtoGrid_Floor_Mars_MI();

        auto Bed = FMars_MeshPart(BedTransform, System::LoadAsset_Blocking(constants_screaming_turnip_assets::Bed()), Soil,
            collision::profile::NoCollision, n"ScreamingTurnipBed_Bed");
        Bed.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.35, 0.22, 0.12, 1.0));
        Bed.Tint = EMars_MeshPart_Tint::ProtoGrid;
        _BedPart = InRoot.Add_MeshPart(this, Bed);

        auto BedEmpty = FMars_MeshPart(BedTransform, System::LoadAsset_Blocking(constants_screaming_turnip_assets::BedEmpty()), Soil,
            collision::profile::NoCollision, n"ScreamingTurnipBed_BedEmpty");
        BedEmpty.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.2, 0.13, 0.08, 1.0));
        BedEmpty.Tint = EMars_MeshPart_Tint::ProtoGrid;
        _BedEmptyPart = InRoot.Add_MeshPart(this, BedEmpty);

        // The stand-in: the item's own proxy hull, planted as the skeletal mesh is (its pivot is the skeletal root).
        const auto PlantedTransform = FTransform(FRotator::ZeroRotator, FVector::ZeroVector, constants_screaming_turnip_assets::k_ProxyScale)
            * constants_screaming_turnip_assets::k_PlantedOffset;
        auto Planted = FMars_MeshPart(PlantedTransform,
            System::LoadAsset_Blocking(constants_screaming_turnip_assets::Proxy()), assets::load::ProtoGrid_Item_Mars_MI(),
            collision::profile::NoCollision, n"ScreamingTurnipBed_Planted");
        Planted.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.85, 0.25, 0.6, 1.0));
        Planted.Tint = EMars_MeshPart_Tint::ProtoGrid;
        _PlantedPart = InRoot.Add_MeshPart(this, Planted);

        utils_unreal_component::BindTo_OnAdded(_BedPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded"));
        utils_unreal_component::BindTo_OnAdded(_BedEmptyPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded"));
        utils_unreal_component::BindTo_OnAdded(_PlantedPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded"));

        auto PlantedNode = utils_scene_node::Create(InRoot, constants_screaming_turnip_assets::k_PlantedOffset);
        const auto Params = utils_unreal_component::Make_Params(UMars_ScreamingTurnipPresentationComponent,
            ECk_UnrealComponent_TickPolicy::TickViaProcessor, n"ScreamingTurnipBed_PlantedSkeletal");
        auto PlantedSkeletal = utils_unreal_component::Add(PlantedNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(PlantedSkeletal, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPlantedSkeletalAdded"));
    }

    // Planted: the bed, the root (skeletal, or its stand-in without one). Harvested: the empty bed only.
    private void DoRefresh_Visuals()
    {
        const auto HasSkeletal = ck::IsValid(_Planted) && _Planted.Get_HasMesh();
        Set_PartVisible(_BedPart, _IsHarvested == false);
        Set_PartVisible(_BedEmptyPart, _IsHarvested);
        Set_PartVisible(_PlantedPart, _IsHarvested == false && HasSkeletal == false);
        if (ck::IsValid(_Planted))
        { _Planted.SetVisibility(_IsHarvested == false && HasSkeletal); }
    }

    // The component is created after construction; until then (and under nullrhi) there is nothing to show or hide.
    private void Set_PartVisible(FCk_Handle_UnrealComponent InPart, bool InVisible)
    {
        if (ck::Is_NOT_Valid(InPart))
        { return; }

        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InPart));
        if (ck::IsValid(Mesh))
        { Mesh.SetVisibility(InVisible); }
    }

    private void Claim_Target()
    {
        if (ck::IsValid(_Interactable))
        { _Interactable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Exhausted)); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        DoRefresh_Visuals();
    }

    UFUNCTION()
    private void OnPlantedSkeletalAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Planted = Cast<UMars_ScreamingTurnipPresentationComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Planted), "[ScreamingTurnipBed] the planted skeletal component was not created"))
        { return; }

        _Planted.Play_Clip(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_PlantedIdle,
            EMars_ScreamingTurnip_ClipEnd::Loop));
        DoRefresh_Visuals();
    }

    UFUNCTION()
    private void OnPullStarted(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction)
    {
        if (ck::Is_NOT_Valid(_Planted) || _IsHarvested)
        { return; }

        auto Clips = TArray<FMars_ScreamingTurnip_PresentationClip>();
        Clips.Add(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Grip,
            EMars_ScreamingTurnip_ClipEnd::HoldLastFrame, GripSeconds));
        Clips.Add(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Tug,
            EMars_ScreamingTurnip_ClipEnd::HoldLastFrame, TugSeconds));
        _Planted.Play_ClipChain(Clips);
        DoStart_Following();
    }

    // A pull let go early (or refused): back to the planted idle through the cancel clip, from the strain the Tug had
    // reached (none during the Grip, whose 1 cm dip the cancel's end covers); the presentation returns to SRC_Idle once
    // it has played through, and the follow tick ends there. A completed pull's release swaps the visuals
    // (OnForageReleased); the Tug holds its strain until then.
    UFUNCTION()
    private void OnPullFinished(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InResult == ECk_SucceededFailed::Succeeded || ck::Is_NOT_Valid(_Planted) || _IsHarvested)
        { return; }

        const auto Strain = _Planted.Get_PlayingClip() == constants_screaming_turnip_assets::k_Clip_Tug ? _Planted.Get_PlayedAlpha() : 0.0f;
        auto Cancel = FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Cancel,
            EMars_ScreamingTurnip_ClipEnd::ReturnToLoop);
        Cancel.StartAlpha = 1.0f - Strain;
        _Planted.Play_Clip(Cancel);
    }

    UFUNCTION()
    private void OnFollowTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Done = _IsHarvested || ck::Is_NOT_Valid(_Planted)
            || _Planted.Get_PlayingClip() == constants_screaming_turnip_assets::k_Clip_PlantedIdle;
        if (Done)
        {
            DoDestroy_FollowTick();
            return;
        }

        DoMove_GripNode(_HarvestGrip_R, constants_screaming_turnip_assets::k_HarvestGripSocket_R, _HarvestGripRotation_R);
        DoMove_GripNode(_HarvestGrip_L, constants_screaming_turnip_assets::k_HarvestGripSocket_L, _HarvestGripRotation_L);
    }

    UFUNCTION()
    private void OnForageReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _IsHarvested = true;
        DoDestroy_FollowTick();
        DoRefresh_Visuals();
    }

    UFUNCTION()
    private void OnForageExhausted(FCk_Handle_Forage InForage)
    {
        Claim_Target();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// The pull
//--------------------------------------------------------------------------------------------------------------------------

// What a completed pull does: claim the bed's target and ask its Forage for one Plucked release.
class UMars_SmState_ScreamingTurnipBed_Pull : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ScreamingTurnipBed_Pull;
}

class UMars_SmTask_ScreamingTurnipBed_Pull : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Context = Get_StateMachineContext();
        if (Context.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto& Interaction = Context.Get_Fragment(FMars_Fragment_InteractionContext);
        auto Forage = Interaction.InteractableOwner.As_Forage(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Forage) || Forage.Get_IsExhausted())
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Interactable = Interaction.Interactable;
        Interactable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Exhausted));
        Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Plucked));
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
