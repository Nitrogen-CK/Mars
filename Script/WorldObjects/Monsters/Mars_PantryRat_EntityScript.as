// One clip of the Phase 2 candidate and whether it loops.
struct FMars_PantryRat_Clip
{
    FName Name;
    bool Loop = false;

    FMars_PantryRat_Clip() {}

    FMars_PantryRat_Clip(FName InName, bool InLoop)
    {
        Name = InName;
        Loop = InLoop;
    }
}

// The locomotion loops' design speeds (cm/s): the speed at which each clip's planted paws slide back exactly as fast as the
// mover carries the rat (Tools/Blender/mars_monsters/pantry_rat_r02/scripts/animate_pantry_rat.py DESIGN_SPEED, written into
// PantryRat_R02_Manifest.json clips.<name>.design_speed_cm_s; keep the three in sync). The play rate is the measured planar
// speed over the playing loop's design speed, clamped to [k_MinPlayRate, k_MaxPlayRate].
namespace constants_pantry_rat_clips
{
    const float32 k_WalkDesignSpeed = 100.0f;
    const float32 k_BoundDesignSpeed = 200.0f;
    const float32 k_LoadedBoundDesignSpeed = 280.0f;

    // Below: standing (the phase's idle clip). From k_BoundSpeed: the bound; between: the walk.
    const float32 k_MovingSpeed = 20.0f;
    const float32 k_BoundSpeed = 160.0f;

    const float32 k_MinPlayRate = 0.7f;
    const float32 k_MaxPlayRate = 1.5f;

    // The measured speed's smoothing time constant (a waypoint corner or a single slow frame is not a stop).
    const float32 k_SpeedSmoothingSeconds = 0.05f;

    // How long a new speed band must hold before the clip follows it. The bound band commits at once (a burst starts
    // bounding at its first frames); standing commits after k_StandHoldSeconds; the walk band only once it has held
    // k_WalkHoldSeconds from standing, or k_WalkFromBoundHoldSeconds from a bound - longer than a stop's smoothed speed
    // takes to fall through it (0.05 s x ln(160 / 20) = 0.10 s), so a bound coming to rest goes BoundCycle -> BoundStop,
    // and a start ramping through it (0.05 s) never walks.
    const float32 k_StandHoldSeconds = 0.06f;
    const float32 k_WalkHoldSeconds = 0.08f;
    const float32 k_WalkFromBoundHoldSeconds = 0.2f;
}

// The assembly's own fragment on the rat root: a weak pointer back to its entity script (automation and the review court
// read the body, eyes and topple through it; nothing in the kernel reads it).
struct FMars_Fragment_PantryRat_Assembly
{
    UPROPERTY()
    TWeakObjectPtr<UMars_PantryRat_EntityScript> Script;
}

// A pantry rat: the assembly. The root is the rat's SurfaceMotion body (utils_pantry_rat::Add composes the kernel on it),
// riding utils_pantry_rat::k_Clearance above the floor; this script hangs everything seen off a presentation node dropped
// back to the floor: the Phase 2 skeletal mesh (its saved per-slot material instances - body, pink, belly, the wooden spoon
// and the harness are slots of that ONE primitive, so one CPD 14 write fades all of them - and the EyePatch slot on the
// rat-local MarsPantryRatEyePlate master), CPD 14 (FadeAlpha) seeded before the first visible frame (an unwritten slot 14
// renders the rat invisible) and copied from the kernel's one fade clock on every frame it changes, the body hidden once the
// kernel hides the returned rat, the Eyes on the head drawing on the EyePatch slot, and the clips: no AnimBP, so every frame
// the clip table picks the phase's clip and PlayAnimation runs it (UMars_PantryRat_AnimInstance carries the same telemetry
// for a later blend graph). Dead: the emote layer cleared, then the persistent Downed (X) state; the authored topple toward
// the side the blow pushed (DeathToppleLeft / DeathToppleRight, the other side when that floor is blocked), then DeadHold.
// A recreated body primitive is re-seeded: CPD 14 first, then the Eyes are re-pointed at it (the Eyes feature pushes every
// group, 0..13, to a new plate). Headless (FApp::CanEverRender false) it composes the kernel only, unless BuildBodyHeadless
// (tests read the real component's custom primitive data).
class UMars_PantryRat_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_PantryRat_Spec Spec;

    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // Builds the skeletal body and its eyes even where nothing renders (automation reads their custom primitive data).
    UPROPERTY(ExposeOnSpawn)
    bool BuildBodyHeadless = false;

    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh = TSoftObjectPtr<USkeletalMesh>(
        FSoftObjectPath("/Game/ArtCandidates/PantryRat/R02/Meshes/PantryRat_R02_Mars_SK.PantryRat_R02_Mars_SK"));

    UPROPERTY()
    FName HeadBone = n"head";

    UPROPERTY()
    FName EyePatchSlot = n"EyePatch";

    // The eye face node off the head bone (+X forward, between the two patches).
    UPROPERTY()
    FTransform FaceOffset = FTransform::Identity;

    // The eyes: the Wide style's cells (19, a full oval, the sheet's Curious eye) in the sheet amber #FEC534 (linear), at a
    // strength low enough that the lit eye stays a saturated amber oval instead of clipping to white (the style default is
    // (1, 0.78, 0.45) x 6).
    UPROPERTY()
    FLinearColor EyeColor = FLinearColor(0.9911, 0.5583, 0.0343, 1.0);

    UPROPERTY()
    float32 EyeEmissiveStrength = 1.0f;

    // The skeletal sockets the mouth node follows once the body exists (utils_pantry_rat::k_MouthRest is the pre-mesh frame).
    UPROPERTY()
    FName MouthSocket = n"Carry_Mouth";

    // The authored topple clips are 0.8 s (24 frames at 30 Hz); DeadHold follows.
    UPROPERTY()
    float32 ToppleSeconds = 0.8f;

    // The floor clearance a topple needs beside the body (from the body's centre, at belly height).
    UPROPERTY()
    float32 ToppleClearanceCm = 35.0f;

    UPROPERTY()
    float32 ToppleProbeHeightCm = 10.0f;

    private FCk_Handle_PantryRat _Rat;
    private FCk_Handle_SceneNode _LookNode;
    private FCk_Handle_UnrealComponent _BodyPart;
    private USkeletalMeshComponent _Body;
    private FCk_Handle_Eyes _Eyes;
    private int32 _EyePatchIndex = -1;
    // The clip the assembly chose (also headless, where no body plays it) and the clip the body was last told to play.
    private FName _PlayingClip;
    private bool _PlayingLoop = false;
    private FName _BodyClip;
    private float32 _PlayRate = 1.0f;
    private float32 _AppliedRate = 1.0f;
    private float32 _ClipElapsed = 0.0f;
    private float32 _ClipLength = 0.0f;
    // The committed speed band (0 standing, 1 walk, 2 bound) and how long a different band has held.
    private int32 _Band = 0;
    private float32 _BandHeld = 0.0f;
    private float32 _MeasuredSpeed = 0.0f;
    private bool _DeadEyesApplied = false;
    private TOptional<EMars_PantryRat_ToppleSide> _ToppleSide;
    private float32 _DeadSeconds = 0.0f;
    private TOptional<float32> _WrittenFade;
    private bool _BodyHidden = false;
    private int32 _BodiesBuilt = 0;
    private TOptional<FVector> _LastLocation;
    private TOptional<float32> _LastClock;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"PantryRat");

        auto Spawn = SpawnTransform;
        Spawn.SetLocation(Spawn.GetLocation() + FVector(0.0, 0.0, utils_pantry_rat::k_Clearance));
        auto Root = utils_transform::Add(InHandle, Spawn, ECk_Replication::DoesNotReplicate);

        _Rat = utils_pantry_rat::Add(Root, Spec);
        if (ck::Is_NOT_Valid(_Rat))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Assembly = FMars_Fragment_PantryRat_Assembly();
        Assembly.Script = this;
        InHandle.Add_Fragment(Assembly);

        if (WithVisuals)
        {
            BuildLook(Root);
            utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick"));
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    FCk_Handle_PantryRat Get_Rat() const
    {
        return _Rat;
    }

    // The body primitive (invalid until its component is added, and headless unless BuildBodyHeadless).
    USkeletalMeshComponent Get_Body() const
    {
        return _Body;
    }

    FCk_Handle_UnrealComponent Get_BodyPart() const
    {
        return _BodyPart;
    }

    FCk_Handle_Eyes Get_Eyes() const
    {
        return _Eyes;
    }

    // Unset until the corpse chose its topple.
    TOptional<EMars_PantryRat_ToppleSide> Get_ToppleSide() const
    {
        return _ToppleSide;
    }

    FName Get_PlayingClip() const
    {
        return _PlayingClip;
    }

    // The play rate the chosen clip runs at: measured speed / its design speed for a locomotion loop, 1 otherwise.
    float32 Get_PlayRate() const
    {
        return _PlayRate;
    }

    // The smoothed planar root speed the clip choice reads (cm/s).
    float32 Get_MeasuredSpeed() const
    {
        return _MeasuredSpeed;
    }

    int32 Get_BodiesBuilt() const
    {
        return _BodiesBuilt;
    }

    // Recreates the body primitive (a fresh component; the old one is removed). The new one is re-seeded on its OnAdded.
    void Rebuild_Body()
    {
        if (ck::IsValid(_BodyPart))
        { utils_unreal_component::Request_Remove(_BodyPart); }

        _Body = nullptr;
        _BodyPart = FCk_Handle_UnrealComponent();
        _BodyClip = NAME_None;
        _WrittenFade.Reset();
        Add_BodyPart();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Assembly
    //----------------------------------------------------------------------------------------------------------------------

    private void BuildLook(FCk_Handle_Transform& InRoot)
    {
        _LookNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -utils_pantry_rat::k_Clearance)));
        if (FApp::CanEverRender() == false && BuildBodyHeadless == false)
        { return; }

        USkeletalMesh Loaded = Mesh.IsNull() ? nullptr : System::LoadAsset_Blocking(Mesh);
        if (ck::Is_NOT_Valid(Loaded))
        {
            Warning(f"[PantryRat] the candidate mesh [{Mesh.ToSoftObjectPath().ToString()}] is not loadable: the rat draws nothing");
            return;
        }

        Add_BodyPart();
    }

    private void Add_BodyPart()
    {
        auto Params = utils_unreal_component::Make_Params(USkeletalMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"PantryRat_Body");
        _BodyPart = utils_unreal_component::Add(_LookNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(_BodyPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnBodyAdded"));
    }

    UFUNCTION()
    private void OnBodyAdded(FCk_Handle_UnrealComponent InHandle)
    {
        if (InHandle != _BodyPart)
        { return; }

        _Body = Cast<USkeletalMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Body), f"[PantryRat] [{_Rat.ToString()}] got no USkeletalMeshComponent for its body"))
        { return; }

        ++_BodiesBuilt;
        _Body.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        // CPD 14 first: a primitive whose custom data stops at 13 draws nothing (Phase 2, close_Rat_Cpd14Unset.png).
        Write_Fade(true);
        _Body.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Mesh));
        Write_Fade(true);
        _Body.SetAnimInstanceClass(UMars_PantryRat_AnimInstance);
        _BodyHidden = false;
        Apply_Hidden();

        if (ck::IsValid(_Eyes))
        { Repoint_Eyes(); }
        else
        { BuildEyes(); }

        // A recreated body picks up the chosen clip (a first body: the phase's clip at rest).
        if (_PlayingClip == NAME_None)
        { Select_Clip(Get_BaseClip(_Rat.Get_Phase(), 0)); }
        Apply_BodyClip();
    }

    // The Eyes on the head bone, drawing on the EyePatch slot (which wears the rat-local eye-plate master from the import).
    private void BuildEyes()
    {
        if (_Body.DoesSocketExist(HeadBone) == false)
        {
            Warning(f"[PantryRat] the body mesh has no [{HeadBone}] bone: the rat gets no eyes");
            return;
        }

        _EyePatchIndex = _Body.GetMaterialIndex(EyePatchSlot);
        if (_EyePatchIndex == ck::INDEX_NONE())
        {
            Warning(f"[PantryRat] the body mesh has no [{EyePatchSlot}] material slot: the rat gets no eyes");
            return;
        }

        auto Root = _Rat.As_Transform();
        auto FaceNode = utils_scene_node::CreateAndAttachToUnrealMesh(Root, _Body, HeadBone, FaceOffset);
        utils_handle::Set_DebugName(FaceNode.H(), n"PantryRat.Face");
        auto Face = FaceNode.As_Transform();

        auto EyesSpec = FMars_Eyes_Spec();
        EyesSpec.Style = Make_EyeStyle(EyeEmissiveStrength);
        EyesSpec.Blink = FMars_Eyes_BlinkSpec();
        EyesSpec.Look = FMars_Eyes_LookSpec();
        _Eyes = utils_eyes::Add(Face, EyesSpec);
        if (ck::IsValid(_Eyes))
        { _Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(_Body, _EyePatchIndex)); }
    }

    private FMars_Eyes_StyleDef Make_EyeStyle(float32 InStrength) const
    {
        auto Style = utils_eyes::Style_Wide().Def;
        Style.Color = EyeColor;
        Style.EmissiveStrength = InStrength;
        return Style;
    }

    // Review only (the court's eye-strength sweep): the same style at InStrength.
    void Review_SetEyeStrength(float32 InStrength)
    {
        if (ck::IsValid(_Eyes))
        { _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(Make_EyeStyle(InStrength))); }
    }

    // A recreated body: the Eyes draw on the new primitive (their apply pass pushes every group to a new plate, so the
    // latest state - Downed on a corpse - lands on it; nothing resets the face to alive).
    private void Repoint_Eyes()
    {
        _EyePatchIndex = _Body.GetMaterialIndex(EyePatchSlot);
        if (_EyePatchIndex != ck::INDEX_NONE())
        { _Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(_Body, _EyePatchIndex)); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Per frame
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Rat))
        { return; }

        // The step is the kernel clock's (the rat's own simulation time): this timer's delta read zero headless (Phase 9 lane
        // run phase9-run02-alone: every measured speed 0), and a second call in one frame must not read as a stop.
        const auto Here = _Rat.Get_Location();
        const auto Clock = _Rat.Get_Clock();
        const auto Delta = _LastClock.IsSet() ? float64(Clock - _LastClock.GetValue()) : 0.0;
        _LastClock = Clock;
        if (_LastLocation.IsSet() && Delta > 0.0)
        {
            const auto Speed = float32((Here - _LastLocation.GetValue()).Size2D() / Delta);
            const auto Alpha = 1.0f - Math::Exp(-float32(Delta) / constants_pantry_rat_clips::k_SpeedSmoothingSeconds);
            _MeasuredSpeed = _MeasuredSpeed + (Speed - _MeasuredSpeed) * Alpha;
        }
        _LastLocation = Here;

        const auto Phase = _Rat.Get_Phase();
        if (ck::Is_NOT_Valid(_Body))
        {
            // Headless: the same clip choice (tests read Get_PlayingClip / Get_PlayRate), nothing drawn.
            Tick_Clip(Phase, float32(Delta));
            return;
        }

        auto Frame = FMars_PantryRat_AnimFrame();
        Frame.Phase = Phase;
        Frame.Speed = _MeasuredSpeed;
        Frame.Carrying = _Rat.Get_IsLoaded();
        Frame.Dead = _Rat.Get_IsDead();

        auto Anim = Cast<UMars_PantryRat_AnimInstance>(_Body.GetAnimInstance());
        if (ck::IsValid(Anim))
        { Anim.Apply(Frame); }

        // Hide before the fade write: the kernel resets FadeAlpha to 1 in the frame it hides the returned rat.
        Apply_Hidden();
        Write_Fade(false);
        Follow_MouthSocket();

        if (Frame.Dead)
        {
            Apply_DeadEyes();
            Choose_Topple();
            if (Delta > 0.0)
            { _DeadSeconds += float32(Delta); }
        }

        Tick_Clip(Phase, float32(Delta));
        Apply_BodyClip();
    }

    // The mouth node (the kernel's AttachPoint.Mars.RatMouth, built at k_MouthRest on the root) rides the skeletal Carry_Mouth
    // socket on the jaw: its offset on the root is set to the socket's current world frame every frame, so the carried item
    // follows the head through every clip. Without a body (headless) the node keeps k_MouthRest.
    private void Follow_MouthSocket()
    {
        if (_Body.DoesSocketExist(MouthSocket) == false)
        { return; }

        FCk_Handle MouthEntity = _Rat.Get_MouthNode();
        auto Node = MouthEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto Socket = _Body.GetSocketTransform(MouthSocket, ERelativeTransformSpace::RTS_World);
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Rat.As_Transform());
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Socket.GetRelativeTransform(Root)));
    }

    // CPD 14 = the kernel's FadeAlpha, written only when it changed (or forced on a new primitive).
    private void Write_Fade(bool InForce)
    {
        const auto Fade = _Rat.Get_FadeAlpha();
        if (InForce == false && _WrittenFade.IsSet() && _WrittenFade.GetValue() == Fade)
        { return; }

        _Body.SetCustomPrimitiveDataFloat(utils_pantry_rat_look::Get_FadeAlphaCpdIndex(), Fade);
        _WrittenFade = Fade;
    }

    private void Apply_Hidden()
    {
        const auto Hidden = _Rat.Get_IsHidden();
        if (Hidden == _BodyHidden)
        { return; }

        _BodyHidden = Hidden;
        _Body.SetHiddenInGame(Hidden, true);
        _Body.SetVisibility(Hidden == false, true);
    }

    // Once: the emote layer cleared, then the persistent Downed state (cell 20, no duration, no blink, no look).
    private void Apply_DeadEyes()
    {
        if (_DeadEyesApplied || ck::Is_NOT_Valid(_Eyes))
        { return; }

        _DeadEyesApplied = true;
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
        _Eyes.Request_SetStateExpression(FMars_Request_Eyes_SetStateExpression(utils_eyes::Expression_Downed().Def));
    }

    // Once, on the first dead frame: the side the lethal blow pushes the rat toward, unless a static floor/wall blocks that
    // side within ToppleClearanceCm at belly height and the other side is clear.
    private void Choose_Topple()
    {
        if (_ToppleSide.IsSet())
        { return; }

        const auto Root = utils_transform::Get_EntityCurrentTransform(_Rat.As_Transform());
        const auto Right = Root.GetRotation().GetRightVector();
        auto Centre = Root.GetLocation();
        Centre.Z = Centre.Z - utils_pantry_rat::k_Clearance + ToppleProbeHeightCm;
        const auto LeftClear = Get_IsSideClear(Centre, Centre - Right * ToppleClearanceCm);
        const auto RightClear = Get_IsSideClear(Centre, Centre + Right * ToppleClearanceCm);
        _ToppleSide = utils_pantry_rat::Get_ToppleSide(Right, _Rat.Get_Death().HitImpulse, LeftClear, RightClear);
        Log(f"[PantryRat] [{_Rat.ToString()}] topples {_ToppleSide.GetValue() :n} (impulse [{_Rat.Get_Death().HitImpulse.ToString()}], "
            + f"left clear [{LeftClear}], right clear [{RightClear}])");
    }

    private bool Get_IsSideClear(FVector InFrom, FVector InTo) const
    {
        FCk_Handle RatEntity = _Rat;
        const UWorld World = utils_entity_lifetime::Get_WorldForEntity(RatEntity);
        if (ck::Is_NOT_Valid(World) || World.IsGameWorld() == false)
        { return true; }

        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);
        return utils_jolt_query::Get_RayCast(InFrom, InTo, Filter).Get_HasHit() == false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Clips (no AnimBP: the assembly chooses one clip per frame - also headless - and the body plays it)
    //----------------------------------------------------------------------------------------------------------------------

    // The phase's clip at the measured speed, then the edges: standing -> BoundCycle plays BoundStart to its end first,
    // BoundCycle -> a standing loop plays BoundStop to its end first (Emerge shows DenEmerge only until its creep commits to the
    // walk band).
    // An edge clip gives way at once to anything other than the two clips it joins (a phase change, a death). A locomotion
    // loop runs at measured speed / its design speed (clamped); every other clip at rate 1.
    private void Tick_Clip(EMars_PantryRat_Phase InPhase, float32 InDelta)
    {
        _ClipElapsed += InDelta * _PlayRate;
        // The speed band (0 standing, 1 walk, 2 bound) changes once the new band has held its hold time (constants above).
        const auto Raw = _MeasuredSpeed >= constants_pantry_rat_clips::k_BoundSpeed ? 2
            : (_MeasuredSpeed >= constants_pantry_rat_clips::k_MovingSpeed ? 1 : 0);
        _BandHeld = Raw == _Band ? 0.0f : _BandHeld + InDelta;
        const auto Hold = Raw == 2 ? 0.0f : (Raw == 0 ? constants_pantry_rat_clips::k_StandHoldSeconds
            : (_Band == 2 ? constants_pantry_rat_clips::k_WalkFromBoundHoldSeconds : constants_pantry_rat_clips::k_WalkHoldSeconds));
        if (Raw != _Band && _BandHeld >= Hold)
        {
            _Band = Raw;
            _BandHeld = 0.0f;
        }

        const auto Base = Get_BaseClip(InPhase, _Band);
        const auto Running = _PlayingLoop || _ClipElapsed < _ClipLength;
        const auto Standing = Get_IsStandingLoop(InPhase, Base);

        auto Next = Base;
        if (_PlayingClip == n"BoundStart" && Running && Base.Name == n"BoundCycle")
        { Next = FMars_PantryRat_Clip(n"BoundStart", false); }
        else if (_PlayingClip == n"BoundStop" && Running && Standing)
        { Next = FMars_PantryRat_Clip(n"BoundStop", false); }
        else if (Base.Name == n"BoundCycle" && _PlayingClip != n"BoundCycle" && _PlayingClip != n"BoundStart"
            && _PlayingClip != n"BoundStop" && _PlayingClip != n"Walk" && _PlayingClip != NAME_None)
        { Next = FMars_PantryRat_Clip(n"BoundStart", false); }
        else if (_PlayingClip == n"BoundCycle" && Standing)
        { Next = FMars_PantryRat_Clip(n"BoundStop", false); }

        Select_Clip(Next);
        _PlayRate = Get_PlayRateFor(_PlayingClip, _MeasuredSpeed);
    }

    // The clip table's choice for a phase at a steady speed (its band committed), before the start / stop edges. Tests read
    // the assembly's decision through this without a body.
    FName Get_ClipFor(EMars_PantryRat_Phase InPhase, float32 InSpeed) const
    {
        const auto Band = InSpeed >= constants_pantry_rat_clips::k_BoundSpeed ? 2 : (InSpeed >= constants_pantry_rat_clips::k_MovingSpeed ? 1 : 0);
        return Get_BaseClip(InPhase, Band).Name;
    }

    // A locomotion loop's play rate at InSpeed (speed / its design speed, clamped); 1 for every other clip.
    float32 Get_PlayRateFor(FName InClip, float32 InSpeed) const
    {
        const auto Design = Get_DesignSpeed(InClip);
        return Design > 0.0f
            ? Math::Clamp(InSpeed / Design, constants_pantry_rat_clips::k_MinPlayRate, constants_pantry_rat_clips::k_MaxPlayRate)
            : 1.0f;
    }

    // A looping clip the rat stands in (not a locomotion loop, not dead): where a bound comes to rest.
    private bool Get_IsStandingLoop(EMars_PantryRat_Phase InPhase, const FMars_PantryRat_Clip& InClip) const
    {
        return InClip.Loop && Get_DesignSpeed(InClip.Name) <= 0.0f && utils_pantry_rat::Get_IsDeadPhase(InPhase) == false;
    }

    // The locomotion loops' design speeds (0: not a locomotion loop).
    private float32 Get_DesignSpeed(FName InClip) const
    {
        if (InClip == n"Walk")
        { return constants_pantry_rat_clips::k_WalkDesignSpeed; }

        if (InClip == n"BoundCycle")
        { return constants_pantry_rat_clips::k_BoundDesignSpeed; }

        if (InClip == n"LoadedBound")
        { return constants_pantry_rat_clips::k_LoadedBoundDesignSpeed; }

        return 0.0f;
    }

    // Keeps the clip already chosen (no restart); a new one starts from its first frame.
    private void Select_Clip(const FMars_PantryRat_Clip& InClip)
    {
        if (InClip.Name == _PlayingClip)
        { return; }

        const auto Clip = Load_Clip(InClip.Name);
        if (ck::Is_NOT_Valid(Clip))
        { return; }

        _PlayingClip = InClip.Name;
        _PlayingLoop = InClip.Loop;
        _ClipElapsed = 0.0f;
        _ClipLength = Clip.GetPlayLength();
    }

    // The body plays the chosen clip (from its start when it changed) at the chosen rate.
    private void Apply_BodyClip()
    {
        if (ck::Is_NOT_Valid(_Body) || _PlayingClip == NAME_None)
        { return; }

        if (_BodyClip != _PlayingClip)
        {
            UAnimSequence Clip = Load_Clip(_PlayingClip);
            if (ck::Is_NOT_Valid(Clip))
            { return; }

            _BodyClip = _PlayingClip;
            _Body.PlayAnimation(Clip, _PlayingLoop);
            _AppliedRate = -1.0f;
        }

        if (Math::Abs(_AppliedRate - _PlayRate) > 0.005f)
        {
            _Body.SetPlayRate(_PlayRate);
            _AppliedRate = _PlayRate;
        }
    }

    private UAnimSequence Load_Clip(FName InName) const
    {
        const auto Path = f"/Game/ArtCandidates/PantryRat/R02/Animation/PantryRat_R02_{InName}_Mars_ANIM.PantryRat_R02_{InName}_Mars_ANIM";
        return System::LoadAsset_Blocking(TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(Path)));
    }

    // The clip table (Phase 2 clip names; no AnimBP), before the edges: the phase first; a moving rat walks in band 1 and
    // bounds in band 2; a loaded flee bounds loaded in either.
    private FMars_PantryRat_Clip Get_BaseClip(EMars_PantryRat_Phase InPhase, int32 InBand) const
    {
        const auto Moving = InBand > 0;
        if (utils_pantry_rat::Get_IsDeadPhase(InPhase))
        {
            if (_ToppleSide.IsSet() && _DeadSeconds < ToppleSeconds)
            {
                return _ToppleSide.GetValue() == EMars_PantryRat_ToppleSide::Right
                    ? FMars_PantryRat_Clip(n"DeathToppleRight", false) : FMars_PantryRat_Clip(n"DeathToppleLeft", false);
            }

            return FMars_PantryRat_Clip(n"DeadHold", true);
        }

        if (InPhase == EMars_PantryRat_Phase::Emerge && Moving == false)
        { return FMars_PantryRat_Clip(n"DenEmerge", false); }

        if (InPhase == EMars_PantryRat_Phase::DenEnter || InPhase == EMars_PantryRat_Phase::DormantInDen)
        { return FMars_PantryRat_Clip(n"DenEnter", false); }

        if (InPhase == EMars_PantryRat_Phase::Inspect)
        { return FMars_PantryRat_Clip(n"InspectSlot", false); }

        if (InPhase == EMars_PantryRat_Phase::ClaimTell)
        { return FMars_PantryRat_Clip(n"Rummage", true); }

        if (InPhase == EMars_PantryRat_Phase::ClaimTransfer || InPhase == EMars_PantryRat_Phase::CarryMountPending)
        { return FMars_PantryRat_Clip(n"Snatch", false); }

        if (InPhase == EMars_PantryRat_Phase::FleeWithLoot)
        { return Moving ? FMars_PantryRat_Clip(n"LoadedBound", true) : FMars_PantryRat_Clip(n"LoadedIdle", true); }

        if (InPhase == EMars_PantryRat_Phase::FleePause)
        { return FMars_PantryRat_Clip(n"LoadedLookBack", false); }

        if (InPhase == EMars_PantryRat_Phase::FleeCornered)
        { return FMars_PantryRat_Clip(n"LoadedCornered", true); }

        if (InPhase == EMars_PantryRat_Phase::WatchGuarded)
        { return FMars_PantryRat_Clip(n"GuardedWatch", true); }

        if (Moving)
        {
            return InBand >= 2
                ? FMars_PantryRat_Clip(n"BoundCycle", true) : FMars_PantryRat_Clip(n"Walk", true);
        }

        if (InPhase == EMars_PantryRat_Phase::Observe)
        { return FMars_PantryRat_Clip(n"SniffGround", true); }

        return FMars_PantryRat_Clip(n"IdleBreath", true);
    }
}
