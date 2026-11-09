// A planted Screaming Turnip: a one-shot Forage (one charge, Persists, no regrow) whose release is an unarmed walk-away
// pull. The bed composes a Walk Control (EMars_Control_PullSource::Walk): once the gloves grip the stalks, the player's
// ManipulateControl task begins the manipulation with the player as its Puller, and the ground gained from the grip, over
// Pull.Stretch.TravelCm (the bed's grouped tuner, FMars_ScreamingTurnipBed_PullSpec), is the Control's Pull; its spring
// (Pull.Spring) is the stretch's alpha. The Use target is ManuallyCompleted, needs both hands free and is worked
// AfterCompletion: the Control's threshold (Pull.Spring.EngageAlpha) ends the interaction Succeeded and runs
// UMars_SmState_ScreamingTurnipBed_Pull, which claims the target
// and asks the Forage for one Plucked release; Use let go (or the focus lost) before it cancels the interaction and
// consumes nothing. The target is the bed's own (not Make_InteractTarget): TryGet_ManipulatedControl resolves the Control
// through the interactable's owner, this entity, so the player's task and the prompt ring find it. The release is the ordinary Forage -> WorldItem
// yield (Request_SpawnWorld at the release point, hopping out of the bed): the bed never spawns, parents or destroys it.
//
// Not a UMars_ForageSource_EntityScript: that base composes a Health, a strike HitZone and a knock body, none of which an
// unarmed pull has, and its yield visibility casts to a static mesh; this bed owns its own visibility.
//
// The target is claimed (EMars_Interactable_DisableReason::Exhausted: the Forage holds no charge any more) from the
// pull's completion on and again on exhaustion, and never released: the bed does not regrow.
//
// The pull's look: the planted root plays SRC_Grip over Pull.Timing.GripSeconds from the press, then SRC_Tug (the strain's
// pose) is scrubbed to the Control's alpha and the stretch's distance drawn as a runtime crown offset by the presentation
// itself, in its own tick, from this frame's Control alpha (Set_PullDrawing, once: the Control and Pull.Stretch); the
// planted node turns its -X (the Use side) toward the puller, eased; and the gloves ride the stalks: the bed's grip table
// names the planted mesh's HarvestGrip sockets themselves (a socket grip on the planted node, with the handed grip rotation
// in the socket's frame), which FPHands reads live whenever it composes the gloves, so they sit on this frame's pose with
// no node to move. A pull let go early plays SRC_Cancel from
// the strain the scrub had reached (SRC_Cancel eases the full strain back to the rest, so its pose at 1 - alpha is near the
// Tug's at alpha). The turn is kept after a cancel: the next pull re-aims.
class UMars_ScreamingTurnipBed_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // The pull's tuner: the stretch's travel and lift (the Control's WalkCm is the travel), the spring, the timings. A spec
    // that fails its Validate() ensures and the bed destroys itself.
    UPROPERTY(ExposeOnSpawn)
    FMars_ScreamingTurnipBed_PullSpec Pull;

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
    // A puller within k_MinAimCm of the bed's axis (horizontally) gives no direction; the turn holds.
    private const float64 k_MinAimCm = 1.0;
    // A cancel from a strain under this plays SRC_Cancel's tail at its authored rate instead of Pull.Timing's span.
    private const float32 k_MinSpannedStrain = 0.05f;

    private FCk_Handle _Self;
    private FCk_Handle_Transform _Root;
    private FCk_Handle_Forage _Forage;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_Control _Control;
    // The planted skeletal mesh's node (k_PlantedOffset, turned by _PlantedYaw about the bed's Z).
    private FCk_Handle_SceneNode _PlantedNode;
    private float32 _PlantedYaw = 0.0f;
    // Who pressed Use (the interaction's source, as a transform): the turn aims at it from the press, through the Grip
    // clip and the gloves' reach, until the Control's Puller takes over at the grip. Cleared once the follow ends.
    private FCk_Handle_Transform _Aim;
    // Runs from a press until the root is out or back at its idle: turns the planted root toward the puller.
    private FCk_Handle_Timer _FollowTick;
    private FCk_Handle_UnrealComponent _BedPart;
    private FCk_Handle_UnrealComponent _BedEmptyPart;
    private FCk_Handle_UnrealComponent _PlantedPart;
    private UMars_ScreamingTurnipPresentationComponent _Planted;
    private bool _IsHarvested = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Validation = Pull.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ScreamingTurnipBed] [{InHandle.ToString()}] rejected the Pull: {Validation.Get_Error()}"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

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

        _Control = utils_control::Add(InHandle, Make_ControlSpec());
        if (ck::Is_NOT_Valid(_Control))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        AddInteractable(Root);
        AddVisuals(Root);
        AddHarvestGrips(InHandle);
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
        _Control = FCk_Handle_Control();
        _Planted = nullptr;
    }

    // Invalid before construction.
    FCk_Handle_Interactable Get_Interactable() const
    { return _Interactable; }

    //--------------------------------------------------------------------------------------------------------------------------
    // Composition
    //--------------------------------------------------------------------------------------------------------------------------

    // The walk pull: ManuallyCompleted, Walk over Pull.Stretch.TravelCm with Pull.Spring, no Mover (the presentation is the
    // drawing). The HarvestGrip sockets swing about 2 cm past the crown at full pitch (authored), so the gloves travel
    // TravelCm + ~2 while the player walks TravelCm: the arms give the 2 cm.
    // Behavior Toggle is unused: the bed's target runs UMars_SmState_ScreamingTurnipBed_Pull, never
    // UMars_SmState_Control_Engage, so nothing engages and IsActive stays false; ReturnsToRest keeps every pull running
    // toward the end even so.
    private FMars_Control_Spec Make_ControlSpec() const
    {
        auto Spec = FMars_Control_Spec();
        Spec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        Spec.Behavior = EMars_Control_Behavior::Toggle;
        Spec.Manipulation.PullSource = EMars_Control_PullSource::Walk;
        Spec.Manipulation.WalkCm = Pull.Stretch.TravelCm;
        Spec.Manipulation.EngageAlpha = Pull.Spring.EngageAlpha;
        Spec.Manipulation.Stiffness = Pull.Spring.Stiffness;
        Spec.Manipulation.Damping = Pull.Spring.Damping;
        Spec.Manipulation.ReturnsToRest = true;
        return Spec;
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(k_ProbeHalfExtents));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, k_ProbeOffset);

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        // Completed by the Control's threshold (UMars_Processor_Control_Tick), never by time.
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::ManuallyCompleted);

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

    // The pull's glove targets: the bed's grip table (the interactable's owner is this entity, as a Station's is), one socket
    // grip per hand on the planted node: the skeletal mesh's leaf-stalk sockets (constants_screaming_turnip_assets::
    // k_HarvestGripSocket_R / _L, on the crown), Power pose, Roll Fixed, and the handed grip rotation in the socket's frame:
    // fingers +X (round the stalk from the Use side), palm in toward the crown (-Y for the right glove, +Y for the left).
    // The sockets carry no authored rotation, so that frame is the crown bone's: whether these vectors read right on the
    // turned stalks is Phase L Part 2's PIE call (flip them there if the gloves come out wrong). FPHands reads the sockets
    // live (FMars_FPHands_HandGrip.SocketHost), so the gloves follow the pose and the planted node's turn without help.
    private void AddHarvestGrips(FCk_Handle& InHandle)
    {
        const auto PlantedNode = _PlantedNode.As_Transform();
        const auto RotationR = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::RightVector);
        const auto RotationL = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, FVector::RightVector);

        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, PlantedNode, TOptional<FName>(constants_screaming_turnip_assets::k_HarvestGripSocket_R),
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed,
            TOptional<FQuat>(RotationR)));
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Left, PlantedNode, TOptional<FName>(constants_screaming_turnip_assets::k_HarvestGripSocket_L),
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed,
            TOptional<FQuat>(RotationL)));
        utils_fphands::Add_Grips(InHandle, Entries);
    }

    // The turn toward the puller, each tick of a pull. Stops once the root is out or the planted idle is back; nothing to
    // turn without the skeletal mesh.
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

    // The planted node turns its -X (the Use side) toward the puller, horizontally, at most Pull.Timing.TurnDegreesPerSecond: the
    // Control's Puller while gripped, before that the one who pressed Use (_Aim), so the turn runs during the Grip clip
    // instead of snapping at the grip. Neither (a source without a transform, or the cancel back at idle): the turn holds.
    private void DoTurn_TowardPuller(float32 InDeltaSeconds)
    {
        auto Puller = _Control.TryGet_Puller();
        if (ck::Is_NOT_Valid(Puller))
        { Puller = _Aim; }

        if (ck::Is_NOT_Valid(Puller) || ck::Is_NOT_Valid(_PlantedNode))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Local = RootWorld.InverseTransformPosition(utils_transform::Get_EntityCurrentTransform(Puller).GetLocation());
        if (FVector2D(Local.X, Local.Y).Size() < k_MinAimCm)
        { return; }

        const auto Aim = float32(Math::RadiansToDegrees(Math::Atan2(-Local.Y, -Local.X)));
        const auto MaxStep = Pull.Timing.TurnDegreesPerSecond * InDeltaSeconds;
        const auto Step = Math::Clamp(float32(Math::FindDeltaAngleDegrees(_PlantedYaw, Aim)), -MaxStep, MaxStep);
        _PlantedYaw = float32(Math::UnwindDegrees(_PlantedYaw + Step));

        utils_scene_node::Request_UpdateOffset(_PlantedNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(FRotator(0.0, _PlantedYaw, 0.0), constants_screaming_turnip_assets::k_PlantedOffset.GetLocation())));
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
        _PlantedNode = PlantedNode;
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
        // The presentation draws the pull itself from this Control; the travel is known from the start, so the bounds are
        // widened before the first pull.
        _Planted.Set_PullDrawing(FMars_ScreamingTurnip_PullDrawing(_Control, Pull.Stretch.TravelCm, Pull.Stretch.LiftCm));
        DoRefresh_Visuals();
    }

    UFUNCTION()
    private void OnPullStarted(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction)
    {
        if (ck::Is_NOT_Valid(_Planted) || _IsHarvested)
        { return; }

        // The turn aims at the presser from now; the presentation scrubs the Tug to the Control's alpha.
        _Aim = utils_interaction::Get_InteractionSource(InInteraction).As_Transform(ECk_SanityCheck::UnChecked);
        _Planted.Play_Clip(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Grip,
            EMars_ScreamingTurnip_ClipEnd::HoldLastFrame, Pull.Timing.GripSeconds));
        DoStart_Following();
    }

    // A pull let go early (or refused, or the focus lost): back to the planted idle through the cancel clip, from the strain
    // the scrubbed Tug had reached (a scrubbed clip's played alpha is its scrub alpha; none during the Grip, whose 1 cm dip
    // the cancel's end covers); the presentation returns to SRC_Idle once it has played through, and the follow tick ends
    // there. A completed pull's release swaps the visuals (OnForageReleased); the Tug holds its last scrub until then.
    UFUNCTION()
    private void OnPullFinished(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InResult == ECk_SucceededFailed::Succeeded || ck::Is_NOT_Valid(_Planted) || _IsHarvested)
        { return; }

        const auto Strain = _Planted.Get_PlayingClip() == constants_screaming_turnip_assets::k_Clip_Tug ? _Planted.Get_PlayedAlpha() : 0.0f;
        auto Cancel = FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Cancel,
            EMars_ScreamingTurnip_ClipEnd::ReturnToLoop);
        Cancel.StartAlpha = 1.0f - Strain;
        // The span is the whole clip's (the presentation's rate = length / span, then the start alpha), so the rate is the
        // same from any strain and the remaining Strain of the clip takes Strain * CancelSecondsFromFullStrain.
        if (Strain >= k_MinSpannedStrain)
        { Cancel.SpanSeconds = TOptional<float32>(Pull.Timing.CancelSecondsFromFullStrain); }
        _Planted.Play_Clip(Cancel);
    }

    UFUNCTION()
    private void OnFollowTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Done = _IsHarvested || ck::Is_NOT_Valid(_Planted)
            || _Planted.Get_PlayingClip() == constants_screaming_turnip_assets::k_Clip_PlantedIdle;
        if (Done)
        {
            _Aim = FCk_Handle_Transform();
            DoDestroy_FollowTick();
            return;
        }

        DoTurn_TowardPuller(float32(InDeltaT.Get_Seconds()));
    }

    UFUNCTION()
    private void OnForageReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _IsHarvested = true;
        _Aim = FCk_Handle_Transform();
        // The root is out: the planted mesh it hides draws no pull any more.
        if (ck::IsValid(_Planted))
        { _Planted.Set_PullDrawing(FMars_ScreamingTurnip_PullDrawing()); }
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
