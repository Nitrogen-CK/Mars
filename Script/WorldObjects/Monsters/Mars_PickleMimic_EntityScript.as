// The pickle mimic's pieces (Tools/Blender/mars_monsters/build_pickle_mimic_pieces.py, imported by its
// unreal/mars_pickle_mimic_ue.py), each modelled in the frame the assembly places it in: the jar's pieces (glass, liquid,
// frame, mouth, bow, shards) in the walker body's frame, the jar's base centre at the origin; the lid pivoting at its
// hinge, +X toward the front; the face dome at its base centre; a foot at its sole's centre. Change the art and these
// together.
namespace utils_pickle_mimic
{
    const FString PieceFolder = "/Game/Mars/Gameplay/Monsters/PickleMimic/Meshes";

    const FVector Hinge = FVector(-29.5, 0.0, 65.5);
    const float64 LidOpenDegrees = 80.0;
    const float64 FaceBase = 51.5;
    // The face dome rises this far as the lid opens wide (the eyes peek over the rim).
    const float64 FaceRise = 10.0;

    // The brine cylinder's middle over the jar's base; the brine's surface as the shader's level (half-heights from that
    // middle, -1 empty .. 1 full): the concept's jar is filled to just under the top hoop (z 45 of a 2.2 .. 49 cylinder).
    const float64 LiquidCentre = 25.6;
    const float32 BrineLevel = 0.829f;

    const int32 ShardCount = 10;

    TSoftObjectPtr<UStaticMesh> Get_PieceMesh(FString InPart)
    {
        const FString PieceName = f"PickleMimic_{InPart}_Mars_SM";
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(f"{PieceFolder}/{PieceName}.{PieceName}"));
    }

    // Each shard's centre in the jar's frame (the builder's PickleMimic_RestLayout.json shard_centres): it spins about it.
    TArray<FVector> Get_ShardCentres()
    {
        auto Centres = TArray<FVector>();
        Centres.Add(FVector(0.0, 0.0, 1.5));
        Centres.Add(FVector(12.55, -14.49, 33.5));
        Centres.Add(FVector(17.65, -9.55, 45.25));
        Centres.Add(FVector(9.67, 7.24, 33.5));
        Centres.Add(FVector(14.49, 10.61, 28.0));
        Centres.Add(FVector(-9.83, 19.76, 32.75));
        Centres.Add(FVector(-16.33, 3.88, 18.67));
        Centres.Add(FVector(-14.49, 4.11, 41.33));
        Centres.Add(FVector(-12.02, -15.34, 49.17));
        Centres.Add(FVector(-6.27, -19.76, 33.5));
        return Centres;
    }

    // A foot faces out along its diagonal.
    float64 Get_FootYaw(int32 InLegIndex)
    {
        const auto Mirror = Get_LegMirror(InLegIndex);
        return Math::RadiansToDegrees(Math::Atan2(Mirror.Y, Mirror.X));
    }
}

// The brine's custom primitive data, the pickle brine shader's contract (Tools/Blender/mars_environment/unreal/
// mars_potion_hlsl.py, Pickle Jar): 0-2 the surface normal (world, unit), 3 the level (half-heights), 4 Slosh (0..1),
// 5 Phase (0..1, this jar's own), 6 Agitation (0..1). The slosh is the potion's spring (UMars_Potion_EntityScript): the
// surface is a pendulum kicked by the jar's change of velocity and pulled back to level.
namespace utils_pickle_mimic
{
    const int32 BrineCpd_Surface = 0;
    const int32 BrineCpd_Slosh = 4;
    const int32 BrineCpd_Phase = 5;
    const int32 BrineCpd_Agitation = 6;

    // A bigger body of brine than the potion's: a slower, heavier swing.
    const float32 SloshHz = 1.6f;
    const float32 SloshDamping = 0.14f;
    const float32 GravityCmPerS2 = 980.0f;
    const float32 SloshGain = 1.0f;
    const float32 MaxTilt = 0.45f;
    const float32 FullSloshRate = 1.5f;
    const float32 AgitationSettleRate = 1.0f;
    const float32 MaxSpeedCmPerS = 600.0f;

    // The face's custom primitive data 0 is the eyes' Glow (PickleMimic_Mars_M).
    const int32 FaceCpd_Glow = 0;
    // Glow per second as the eyes come on, and as they go out.
    const float32 EyeOnRate = 3.0f;
    const float32 EyeOffRate = 1.5f;

    // The shatter: shards fly out from the jar's axis and up, spinning, under gravity, and stop where they land.
    const FVector2D ShardOutSpeed = FVector2D(110.0, 240.0);
    const FVector2D ShardUpSpeed = FVector2D(120.0, 260.0);
    const FVector2D ShardSpin = FVector2D(3.0, 9.0);
    // The brine drains out of the broken jar over this long.
    const float32 DrainSeconds = 0.35f;
    // What is left of the jar (hoops, lid, gums, eye dome, bows) tips over onto its side as the glass goes: about the
    // bottom hoop's edge, falling (eased in) over ToppleSeconds to ToppleDegrees, and down the last of its height (the
    // tucked base's 11 cm) onto the floor.
    const float32 ToppleSeconds = 0.55f;
    const float64 ToppleDegrees = 84.0;
    const float64 ToppleEdge = 32.6;
}

// `Mars.PickleMimic.DebugKill 1`: every living mimic deals itself a lethal blow once (to watch the shatter in PIE).
const FConsoleVariable CVar_Mars_PickleMimicDebugKill("Mars.PickleMimic.DebugKill", 0);

// One look piece, loaded, and its renderer (null without visuals or without the asset: the part then wears a tinted box).
struct FMars_PickleMimic_Piece
{
    UPROPERTY()
    UStaticMesh Mesh;

    UPROPERTY()
    UCk_IsmRenderer_Data Renderer;

    // The box the part wears without its mesh.
    UPROPERTY()
    FVector BoxHalfExtents;
}

// A glass shard in flight (the jar's frame at the shatter): its offset and velocity, its spin, landed or not.
struct FMars_PickleMimic_Shard
{
    UPROPERTY()
    FCk_Handle_Transform Transform;

    UPROPERTY()
    FVector Centre;

    UPROPERTY()
    FVector Offset = FVector::ZeroVector;

    UPROPERTY()
    FVector Velocity = FVector::ZeroVector;

    UPROPERTY()
    FVector SpinAxis = FVector::UpVector;

    UPROPERTY()
    float32 SpinRate = 0.0f;

    UPROPERTY()
    float32 Angle = 0.0f;

    UPROPERTY()
    bool Landed = false;
}

// Placeable enemy: the pickle-jar mimic, composed by utils_pickle_mimic::Add on the root at SpawnTransform (the jar's base,
// Clearance over the floor). This script is the assembly: it builds the walker body node the kernel moves (it sinks while
// the mimic sits disguised) and hangs everything seen off it: the glass, the wooden frame, the gums and rim teeth, the
// bows, the hinged lid and the eye dome as scene nodes, the brine as a mesh part wearing the pickle brine shader. The four
// feet float free (no legs): each is a transform of its own placed every frame where the walker's foot is. Every frame it
// poses the lid on its hinge from the kernel's LidOpen, raises the eye dome with it, fades the eyes in while the mimic is up,
// sloshes the brine, and on death breaks the glass into its shards and drains the brine.
class UMars_PickleMimic_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    // The root's transform: place it Clearance (30) above the floor it starts on.
    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_PickleMimic_Spec Spec;

    // False builds the same rig with no visuals and no posing (headless autotests).
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // Draws the bite's blow sphere while it runs.
    UPROPERTY(ExposeOnSpawn)
    bool DebugDraw = false;

    private FCk_Handle _Self;
    private FCk_Handle_PickleMimic _Mimic;

    private FMars_PickleMimic_Piece _GlassPiece;
    private FMars_PickleMimic_Piece _FramePiece;
    private FMars_PickleMimic_Piece _MouthPiece;
    private FMars_PickleMimic_Piece _BowPiece;
    private FMars_PickleMimic_Piece _LidPiece;
    private FMars_PickleMimic_Piece _FootPiece;
    private TArray<FMars_PickleMimic_Piece> _ShardPieces;

    // Every visual but the feet hangs off this node on the body: it tips the broken jar over.
    private FCk_Handle_SceneNode _LookNode;
    private FCk_Handle_SceneNode _GlassNode;
    private FCk_Handle_SceneNode _LidNode;
    private FCk_Handle_SceneNode _FaceNode;
    private TArray<FCk_Handle_Transform> _Feet;

    private FCk_Handle_UnrealComponent _LiquidPart;
    private UStaticMeshComponent _Liquid;
    private UStaticMeshComponent _Face;
    private float32 _Glow = 0.0f;
    private float32 _WrittenGlow = -1.0f;
    private float32 _LidPosed = -1.0f;

    // The brine's slosh spring (see the namespace above).
    private bool _HasPrevSample = false;
    private FVector _PrevLocation = FVector::ZeroVector;
    private FVector _PrevVelocity = FVector::ZeroVector;
    private FVector _Tilt = FVector::ZeroVector;
    private FVector _TiltRate = FVector::ZeroVector;
    private float32 _Agitation = 0.0f;
    private float32 _Level = 0.0f;

    // The shatter: set once, on death.
    private bool _Shattered = false;
    private FTransform _ShatterFrame;
    private float64 _ShatterGround = 0.0;
    private TArray<FMars_PickleMimic_Shard> _Shards;
    private bool _DebugKillSent = false;
    private float32 _Topple = 0.0f;
    private float64 _ToppleSign = 1.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // First: the sub-SM resolves ck::Ctx to this root only if the override precedes every child.
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"PickleMimic");
        _Self = InHandle;
        _Level = utils_pickle_mimic::BrineLevel;

        LoadPieces(InHandle);

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        auto Body = utils_scene_node::Create(Root, utils_pickle_mimic::Get_BodyOffset(0.0f));
        auto MimicSpec = Spec;
        MimicSpec.Rig.Body = Body;

        _Mimic = utils_pickle_mimic::Add(Root, MimicSpec);
        utils_entity_tag::Add(InHandle, n"TAG_MarsPickleMimic");
        if (ck::Is_NOT_Valid(_Mimic))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // The timer dies with the entity; nothing to unbind.
        if (WithVisuals)
        { BuildLook(InHandle, Body); }

        if (WithVisuals || DebugDraw)
        { utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Look
    //----------------------------------------------------------------------------------------------------------------------

    // The jar's pieces on a look node on the body node (so they sink with it, and topple on death), the lid on its hinge
    // and the face dome on nodes of their own, the brine and the face as mesh parts (their materials read custom primitive
    // data), the feet free.
    private void BuildLook(FCk_Handle& InRoot, FCk_Handle_SceneNode InBody)
    {
        auto BodyNode = InBody.As_Transform();
        _LookNode = utils_scene_node::Create(BodyNode, FTransform::Identity);
        auto Body = _LookNode.As_Transform();
        _GlassNode = AddNode(Body, FTransform::Identity, _GlassPiece);
        AddNode(Body, FTransform::Identity, _FramePiece);
        AddNode(Body, FTransform::Identity, _MouthPiece);
        AddNode(Body, FTransform::Identity, _BowPiece);
        AddNode(Body, FTransform(FRotator(0.0, 180.0, 0.0)), _BowPiece);
        _LidNode = AddNode(Body, FTransform(FRotator::ZeroRotator, utils_pickle_mimic::Hinge), _LidPiece);
        _FaceNode = utils_scene_node::Create(Body, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, utils_pickle_mimic::FaceBase)));

        for (int32 Index = 0; Index < utils_pickle_mimic::Get_LegCount(); ++Index)
        {
            auto Entity = utils_entity_lifetime::Request_CreateEntity(InRoot);
            auto Rest = utils_transform::Get_EntityCurrentTransform(_Mimic.As_Transform());
            auto Foot = utils_transform::Add(Entity, FTransform(Rest.GetRotation(), Rest.TransformPosition(utils_pickle_mimic::Get_RestFootLocal(Index))),
                ECk_Replication::DoesNotReplicate);
            AddProxy(Foot, _FootPiece);
            _Feet.Add(Foot);
        }

        // Mesh parts need a renderer: a headless boot has nothing to show and no material to compile.
        if (FApp::CanEverRender() == false)
        { return; }

        UStaticMesh FaceMesh = System::LoadAsset_Blocking(utils_pickle_mimic::Get_PieceMesh("Face"));
        if (ck::IsValid(FaceMesh))
        {
            auto FaceTransform = _FaceNode.As_Transform();
            auto FacePart = FaceTransform.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, FaceMesh, nullptr,
                collision::profile::NoCollision, n"PickleMimic_Face"));
            if (ck::IsValid(FacePart))
            { utils_unreal_component::BindTo_OnAdded(FacePart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFaceAdded")); }
        }

        UStaticMesh LiquidMesh = System::LoadAsset_Blocking(utils_pickle_mimic::Get_PieceMesh("Liquid"));
        if (ck::IsValid(LiquidMesh))
        {
            // The mesh's own slot wears PickleMimicBrine_Mars_MI (a child of the brine shader's Pickle Jar instance).
            auto Part = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, utils_pickle_mimic::LiquidCentre)), LiquidMesh, nullptr,
                collision::profile::NoCollision, n"PickleMimic_Brine");
            Part.CastShadow = false;
            Part.ReceivesDecals = false;
            _LiquidPart = Body.Add_MeshPart(this, Part);
            if (ck::IsValid(_LiquidPart))
            { utils_unreal_component::BindTo_OnAdded(_LiquidPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLiquidAdded")); }
        }
    }

    // A scene node under InParent at InOffset wearing InPiece.
    private FCk_Handle_SceneNode AddNode(FCk_Handle_Transform& InParent, FTransform InOffset, FMars_PickleMimic_Piece InPiece)
    {
        auto Node = utils_scene_node::Create(InParent, InOffset);
        auto Transform = Node.As_Transform();
        AddProxy(Transform, InPiece);
        return Node;
    }

    private void AddProxy(FCk_Handle_Transform& InTransform, FMars_PickleMimic_Piece InPiece)
    {
        if (ck::Is_NOT_Valid(InPiece.Renderer))
        { return; }

        auto ProxySpec = FCk_IsmProxy_Spec(InPiece.Renderer);
        // Engine cube: 100 uu side, 50 uu half extent.
        ProxySpec.Set_ScaleMultiplier(ck::IsValid(InPiece.Mesh) ? FVector::OneVector : InPiece.BoxHalfExtents / 50.0);
        utils_ism_proxy::Add(InTransform, ProxySpec);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Every frame
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = _Mimic;
        if (ck::Is_NOT_Valid(_Mimic) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        if (CVar_Mars_PickleMimicDebugKill.GetInt() != 0 && _DebugKillSent == false && _Mimic.Get_IsDead() == false)
        {
            _DebugKillSent = true;
            auto Health = _Mimic.Get_Monster().Get_BodyHealth();
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
        }

        if (WithVisuals)
        {
            PoseMouth();
            PoseFeet();
            FadeEyes(DeltaSeconds);
            if (_Mimic.Get_IsDead() && _Shattered == false)
            { Shatter(); }

            if (_Shattered)
            {
                FlyShards(DeltaSeconds);
                Topple(DeltaSeconds);
            }

            if (ck::IsValid(_Liquid))
            { Advance_Brine(DeltaSeconds); }
        }

        if (DebugDraw)
        { Draw(); }
    }

    // The lid on its hinge, the eye dome rising with it.
    private void PoseMouth()
    {
        const auto Lid = _Mimic.Get_LidOpen();
        if (Math::Abs(Lid - _LidPosed) < 1e-4f)
        { return; }

        _LidPosed = Lid;
        utils_scene_node::Request_UpdateOffset(_LidNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(FRotator(Lid * utils_pickle_mimic::LidOpenDegrees, 0.0, 0.0), utils_pickle_mimic::Hinge)));
        utils_scene_node::Request_UpdateOffset(_FaceNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, utils_pickle_mimic::FaceBase + utils_pickle_mimic::FaceRise * Lid))));
    }

    // Each floating foot where the walker has its foot, facing out along its diagonal of the body.
    private void PoseFeet()
    {
        const auto Feet = _Mimic.Get_Feet();
        const auto Body = _Mimic.Get_BodyTransform().GetRotation();
        for (int32 Index = 0; Index < _Feet.Num() && Index < Feet.Num(); ++Index)
        {
            const auto Rotation = Body * FQuat(FRotator(0.0, utils_pickle_mimic::Get_FootYaw(Index), 0.0));
            utils_transform::Request_SetTransform(_Feet[Index], FCk_Request_Transform_SetTransform(FTransform(Rotation, Feet[Index].Location)));
        }
    }

    // The eyes glow while it is up (or getting up) and alive; disguised or dead they go dark.
    private void FadeEyes(float32 InDeltaSeconds)
    {
        const auto Awake = _Mimic.Get_IsDead() == false && (_Mimic.Get_Stance() == EMars_PickleMimic_Stance::Standing || _Mimic.Get_Rise() > 0.0f);
        const auto Target = Awake ? 1.0f : 0.0f;
        _Glow = Math::FInterpConstantTo(_Glow, Target, InDeltaSeconds, Awake ? utils_pickle_mimic::EyeOnRate : utils_pickle_mimic::EyeOffRate);
        if (ck::IsValid(_Face) && Math::Abs(_Glow - _WrittenGlow) > 0.005f)
        {
            _WrittenGlow = _Glow;
            _Face.SetCustomPrimitiveDataFloat(utils_pickle_mimic::FaceCpd_Glow, _Glow);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Brine
    //----------------------------------------------------------------------------------------------------------------------

    // The jar's change of velocity tips the surface toward the acceleration (the brine piles up behind) and the spring
    // rocks it back to level; once the glass breaks the level drains away and the brine goes.
    private void Advance_Brine(float32 InDeltaSeconds)
    {
        if (InDeltaSeconds <= 0.0f)
        { return; }

        if (_Shattered)
        {
            _Level -= InDeltaSeconds * 2.0f / utils_pickle_mimic::DrainSeconds;
            if (_Level <= -1.0f)
            {
                utils_entity_lifetime::Request_DestroyEntity(utils_unreal_component::Get_OwningEntity(_LiquidPart));
                _Liquid = nullptr;
                return;
            }
        }

        const auto Location = _Liquid.GetWorldLocation();
        if (_HasPrevSample == false)
        {
            _PrevLocation = Location;
            _PrevVelocity = FVector::ZeroVector;
            _HasPrevSample = true;
            Write_Brine(0.0f);
            return;
        }

        const auto Velocity = ((Location - _PrevLocation) / InDeltaSeconds).GetClampedToMaxSize(utils_pickle_mimic::MaxSpeedCmPerS);
        const auto Omega = 2.0f * PI * utils_pickle_mimic::SloshHz;
        const auto DeltaVelocity = Velocity - _PrevVelocity;
        _TiltRate += FVector(DeltaVelocity.X, DeltaVelocity.Y, 0.0) * (Omega * Omega / utils_pickle_mimic::GravityCmPerS2 * utils_pickle_mimic::SloshGain);
        _PrevLocation = Location;
        _PrevVelocity = Velocity;

        // A damped spring to level, semi-implicit Euler in steps of at most 1/120 s, capped at MaxTilt.
        auto Remaining = Math::Min(InDeltaSeconds, 0.1f);
        while (Remaining > 0.0f)
        {
            const auto Step = Math::Min(Remaining, 1.0f / 120.0f);
            const auto Acceleration = _Tilt * -(Omega * Omega) - _TiltRate * (2.0f * utils_pickle_mimic::SloshDamping * Omega);
            _TiltRate = _TiltRate + Acceleration * Step;
            _Tilt = _Tilt + _TiltRate * Step;
            Remaining -= Step;
        }

        if (_Tilt.Size() > utils_pickle_mimic::MaxTilt)
        {
            _Tilt = _Tilt.GetSafeNormal() * utils_pickle_mimic::MaxTilt;
            _TiltRate = _TiltRate - _Tilt.GetSafeNormal() * Math::Max(0.0, _TiltRate.DotProduct(_Tilt.GetSafeNormal()));
        }

        const auto Slosh = Math::Clamp(float32(_TiltRate.Size()) / utils_pickle_mimic::FullSloshRate, 0.0f, 1.0f);
        _Agitation = Math::Max(Slosh, Math::FInterpTo(_Agitation, Slosh, InDeltaSeconds, utils_pickle_mimic::AgitationSettleRate));
        Write_Brine(Slosh);
    }

    private void Write_Brine(float32 InSlosh)
    {
        const auto Normal = (FVector::UpVector + _Tilt).GetSafeNormal();
        _Liquid.SetCustomPrimitiveDataVector4(utils_pickle_mimic::BrineCpd_Surface, FVector4(Normal.X, Normal.Y, Normal.Z, _Level));
        _Liquid.SetCustomPrimitiveDataFloat(utils_pickle_mimic::BrineCpd_Slosh, InSlosh);
        _Liquid.SetCustomPrimitiveDataFloat(utils_pickle_mimic::BrineCpd_Agitation, _Agitation);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shatter
    //----------------------------------------------------------------------------------------------------------------------

    // The whole glass goes; its ten shards appear where it was and fly out from the jar's axis, up and spinning. They move
    // in the jar's frame as it was at the shatter and stop on the ground under it.
    private void Shatter()
    {
        _Shattered = true;
        _ToppleSign = Math::RandRange(0.0, 1.0) < 0.5 ? 1.0 : -1.0;
        _ShatterFrame = _Mimic.Get_BodyTransform();
        // The root rides Clearance over the ground; the ground in the jar's frame at the shatter.
        _ShatterGround = (_Mimic.Get_Location().Z - utils_pickle_mimic::Clearance) - _ShatterFrame.GetLocation().Z;

        if (ck::IsValid(_GlassNode))
        { utils_entity_lifetime::Request_DestroyEntity(_GlassNode.H()); }

        const auto Centres = utils_pickle_mimic::Get_ShardCentres();
        for (int32 Index = 0; Index < Centres.Num() && Index < _ShardPieces.Num(); ++Index)
        {
            auto Entity = utils_entity_lifetime::Request_CreateEntity(_Self);
            auto Shard = FMars_PickleMimic_Shard();
            Shard.Transform = utils_transform::Add(Entity, _ShatterFrame, ECk_Replication::DoesNotReplicate);
            AddProxy(Shard.Transform, _ShardPieces[Index]);

            const auto Out = FVector(Centres[Index].X, Centres[Index].Y, 0.0).GetSafeNormal();
            Shard.Centre = Centres[Index];
            Shard.Velocity = Out * Math::RandRange(utils_pickle_mimic::ShardOutSpeed.X, utils_pickle_mimic::ShardOutSpeed.Y) +
                FVector::UpVector * Math::RandRange(utils_pickle_mimic::ShardUpSpeed.X, utils_pickle_mimic::ShardUpSpeed.Y) * (Index == 0 ? 0.2 : 1.0);
            Shard.SpinAxis = FVector(Math::RandRange(-1.0, 1.0), Math::RandRange(-1.0, 1.0), Math::RandRange(-1.0, 1.0)).GetSafeNormal();
            Shard.SpinRate = float32(Math::RandRange(utils_pickle_mimic::ShardSpin.X, utils_pickle_mimic::ShardSpin.Y)) * (Index == 0 ? 0.1f : 1.0f);
            _Shards.Add(Shard);
        }
    }

    private void FlyShards(float32 InDeltaSeconds)
    {
        for (auto& Shard : _Shards)
        {
            if (Shard.Landed)
            { continue; }

            Shard.Velocity.Z -= utils_pickle_mimic::GravityCmPerS2 * InDeltaSeconds;
            Shard.Offset += Shard.Velocity * InDeltaSeconds;
            Shard.Angle += Shard.SpinRate * InDeltaSeconds;
            if (Shard.Centre.Z + Shard.Offset.Z <= _ShatterGround + 1.5 && Shard.Velocity.Z < 0.0)
            {
                Shard.Offset.Z = _ShatterGround + 1.5 - Shard.Centre.Z;
                Shard.Landed = true;
            }

            // Spun about its own centre, then moved: (x - c) turned, put back at c + offset, all in the shatter's frame.
            const auto Spin = FQuat(Shard.SpinAxis, Shard.Angle);
            const auto Local = FTransform(Spin, Shard.Centre + Shard.Offset - Spin.RotateVector(Shard.Centre));
            utils_transform::Request_SetTransform(Shard.Transform, FCk_Request_Transform_SetTransform(Local * _ShatterFrame));
        }
    }

    // Tips the look node over the bottom hoop's edge on one side (chosen at the shatter): a turn about the body's X axis
    // through that edge, then down onto the floor.
    private void Topple(float32 InDeltaSeconds)
    {
        if (_Topple >= 1.0f || ck::Is_NOT_Valid(_LookNode))
        { return; }

        _Topple = Math::Min(_Topple + InDeltaSeconds / utils_pickle_mimic::ToppleSeconds, 1.0f);
        const auto Fall = utils_pickle_mimic::Get_EaseIn(_Topple);
        const auto Turn = FQuat(FVector::ForwardVector, _ToppleSign * Math::DegreesToRadians(utils_pickle_mimic::ToppleDegrees * Fall));
        // The edge it tips over: on the side its top falls toward.
        const auto Toward = FQuat(FVector::ForwardVector, _ToppleSign * 0.1).RotateVector(FVector::UpVector).Y;
        const auto Edge = FVector(0.0, (Toward >= 0.0 ? 1.0 : -1.0) * utils_pickle_mimic::ToppleEdge, 0.0);
        const auto Drop = FVector(0.0, 0.0, -(utils_pickle_mimic::Clearance - utils_pickle_mimic::TuckDrop) * Fall);
        utils_scene_node::Request_UpdateOffset(_LookNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(Turn, Edge - Turn.RotateVector(Edge) + Drop)));
    }

    private void Draw() const
    {
        const auto Frame = _Mimic.Get_ActionFrame();
        if (Frame.Action == EMars_PickleMimic_Action::None)
        { return; }

        const auto Color = Frame.Phase == EMars_PickleMimic_ActionPhase::Active ? FLinearColor::Red : FLinearColor::Yellow;
        utils_debug_draw::DrawDebugSphere(_Mimic.Get_MouthLocation(), _Mimic.Get_Spec().Bite.Blow.Radius, 12, Color, 0.0f, 1.5f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Pieces
    //----------------------------------------------------------------------------------------------------------------------

    private void LoadPieces(FCk_Handle& InRoot)
    {
        if (WithVisuals == false)
        { return; }

        const auto Wood = FLinearColor(0.46f, 0.16f, 0.045f, 1.0f);
        const auto Glass = FLinearColor(0.6f, 0.75f, 0.65f, 1.0f);
        _GlassPiece = Load_Piece(InRoot, "Glass", FVector(29.0, 29.0, 32.0), Glass);
        _FramePiece = Load_Piece(InRoot, "Frame", FVector(33.0, 33.0, 4.0), Wood);
        _MouthPiece = Load_Piece(InRoot, "Mouth", FVector(24.0, 24.0, 4.0), FLinearColor(0.26f, 0.014f, 0.018f, 1.0f));
        _BowPiece = Load_Piece(InRoot, "Bow", FVector(8.0, 4.0, 8.0), FLinearColor(0.6f, 0.016f, 0.022f, 1.0f));
        _LidPiece = Load_Piece(InRoot, "Lid", FVector(31.0, 31.0, 4.0), Wood);
        _FootPiece = Load_Piece(InRoot, "Foot", FVector(9.0, 9.0, 8.0), Wood);
        for (int32 Index = 0; Index < utils_pickle_mimic::ShardCount; ++Index)
        { _ShardPieces.Add(Load_Piece(InRoot, Index < 10 ? f"Shard0{Index}" : f"Shard{Index}", FVector(6.0, 6.0, 6.0), Glass)); }
    }

    // The piece's mesh when it is imported, otherwise a tinted engine-cube box; no renderer without a world.
    private FMars_PickleMimic_Piece Load_Piece(FCk_Handle& InRoot, FString InPart, FVector InBoxHalfExtents, FLinearColor InBoxColor)
    {
        auto Piece = FMars_PickleMimic_Piece();
        Piece.BoxHalfExtents = InBoxHalfExtents;

        auto EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InRoot);
        if (ck::Is_NOT_Valid(EntityWorld))
        { return Piece; }

        Piece.Mesh = System::LoadAsset_Blocking(utils_pickle_mimic::Get_PieceMesh(InPart));
        auto Overrides = TArray<FCk_MeshMaterialOverride>();
        auto Mesh = Piece.Mesh;
        if (ck::Is_NOT_Valid(Mesh))
        {
            Mesh = engine::load::Cube();
            auto Material = utils_usf::Create_MID_ForLook(CkUsf::LitMetal, EntityWorld);
            if (ck::IsValid(Material))
            {
                utils_usf::Set_Vector(Material, n"ColorA", InBoxColor);
                utils_usf::Set_Vector(Material, n"ColorB", InBoxColor);
                utils_usf::Set_Scalar(Material, n"Tiles", 0.0f);
                Overrides.Add(FCk_MeshMaterialOverride(0, Material));
            }
        }

        if (ck::IsValid(Mesh))
        { Piece.Renderer = utils_ism_renderer_transient_factory::GetOrCreate_ForMeshWithMaterials(EntityWorld, Mesh, Overrides, ECk_Mobility::Movable); }

        return Piece;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnFaceAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Face = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        _WrittenGlow = -1.0f;
    }

    UFUNCTION()
    private void OnLiquidAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Liquid = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Liquid), f"[PickleMimic] [{_Self.ToString()}] got no UStaticMeshComponent for its brine"))
        { return; }

        _Liquid.SetCustomPrimitiveDataFloat(utils_pickle_mimic::BrineCpd_Phase, Math::RandRange(0.0f, 1.0f));
        _HasPrevSample = false;
    }
}
