// Placeable eye-swarm test wall (+X is its facing): a 300 x 200 cm ProtoGrid slab standing on its origin with a jittered
// 7 x 5 grid of eyes set into its face, each an eyeball instance and a lid-shell instance (utils_eye_swarm::Add_Eye) with a
// random phase, variant, size (0.45..2.0, skewed small so a few eyes are big) and a tilt within 15 degrees of the slab's
// normal, bulging ~2 cm out of the face.
// The MarsEyeball / MarsEyelid looks do every blink and glance in the shader from the roster's player heads; the wall only
// places the instances, picks the preset uniforms and forwards a focus override. Placed by Mars.Sandbox.PlaceEyeWall
// (Script/Editor/Mars_SandboxMapBuilder.as); not under Script/Editor because the saved map references it at runtime.
// Until the EyeSwarm meshes are imported it draws engine spheres; until the looks are generated it wears no look (and
// under -nullrhi it never asks for one: a look asked for headless warns).
class UMars_EyeWallDummy_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Cartoon keeps the looks' defaults; Horror writes the bloodshot preset (utils_eye_swarm::Apply_Preset).
    UPROPERTY(ExposeOnSpawn)
    EMars_EyeSwarm_Preset Preset = EMars_EyeSwarm_Preset::Cartoon;

    // Off: the lid-shell meshes draw the lids. On: the lid ISM is hidden and the eyeball look draws them (ShaderLid 1).
    UPROPERTY(ExposeOnSpawn)
    bool ShaderLid = false;

    private TArray<FMars_EyeSwarm_Eye> _Eyes;
    private FMars_EyeSwarm_Meshes _Meshes;
    private FMars_EyeSwarm_Mids _Mids;
    private FMars_EyeSwarm_Instancers _Instancers;
    private FCk_Handle_UnrealComponent _EyeballPart;
    private FCk_Handle_UnrealComponent _EyelidPart;
    private FMars_EyeSwarm_FocusOverride _FocusOverride;
    private float32 _ClusterPhase = 0.0f;
    private bool _Filled = false;

    // A fixed seed: the same wall every time it is placed.
    private const int32 Seed = 4127;

    // Engine cube: 100 uu with a centred pivot. The slab is 20 deep with its front face on X = 0, standing on the origin;
    // the eyes' node sits at the face's centre.
    private const float SlabWidth = 300.0;
    private const float SlabHeight = 200.0;
    private const FVector SlabOffset = FVector(-10.0, 0.0, 100.0);
    private const FVector SlabScale = FVector(0.2, 3.0, 2.0);
    private const FVector FaceOffset = FVector(0.0, 0.0, 100.0);

    private const int32 Columns = 7;
    private const int32 Rows = 5;
    // Of a cell, each way from its centre.
    private const float JitterFraction = 0.25;
    // Skewed toward small (fraction ^ ScaleSkew): most eyes are 5..10 cm, a few reach 20 cm. A 2.0 lid is 22 cm across,
    // just under the 43 x 40 cm cells minus the jitter, so neighbours do not overlap.
    private const float ScaleMin = 0.45;
    private const float ScaleMax = 2.0;
    private const float ScaleSkew = 1.6;
    // Pitch and yaw each within MaxTiltDeg / sqrt(2), so the forward axis stays within MaxTiltDeg of the normal.
    private const float MaxTiltDeg = 15.0;
    private const float MaxRollDeg = 15.0;
    // How far an eyeball's front pokes out of the face.
    private const float ProtrusionCm = 2.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        // Everything on the wall is seen: where cosmetics cannot run (a dedicated server) it is only its root.
        if (utils_net::Get_CanExecuteCosmeticEvents(InHandle) == false)
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // Nothing on the wall collides.
        Root.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, SlabOffset, SlabScale),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"EyeWall_Slab"));

        Make_Eyes();
        _Meshes = utils_eye_swarm::Load_Meshes();

        // A headless boot has no compiled shader maps, and asking for a look there warns: no look, the mesh's own material.
        // An ungenerated master warns from CkUsf (run Ck_Usf_GenerateLooks MarsEyeball / MarsEyelid) and leaves its MID unset.
        if (FApp::CanEverRender())
        {
            _Mids = utils_eye_swarm::Make_Mids(utils_eye_swarm::Get_Masters(), Preset);
            utils_eye_swarm::Apply_ShaderLid(_Mids, ShaderLid);
        }

        auto Face = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FaceOffset)).As_Transform();
        utils_handle::Set_DebugName(Face.H(), n"EyeWall.Face");

        _EyeballPart = Add_Instancer(Face, FMars_MeshPart(FTransform::Identity, _Meshes.Eyeball, _Mids.Eyeball,
            collision::profile::NoCollision, n"EyeWall_Eyeballs"), true);
        _EyelidPart = Add_Instancer(Face, FMars_MeshPart(FTransform::Identity, _Meshes.Eyelid, _Mids.Eyelid,
            collision::profile::NoCollision, n"EyeWall_Eyelids"), ShaderLid == false);

        // The instances go in once both components exist (they are created asynchronously, in either order).
        if (ck::IsValid(_EyeballPart))
        { utils_unreal_component::BindTo_OnAdded(_EyeballPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnInstancerAdded")); }
        if (ck::IsValid(_EyelidPart))
        { utils_unreal_component::BindTo_OnAdded(_EyelidPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnInstancerAdded")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        TryFill();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Focus
    //----------------------------------------------------------------------------------------------------------------------

    // Every eye on the wall looks at InPoint (world cm) with InWeight (0..1) instead of the nearest player. Held until the
    // instancers exist when asked earlier.
    void Request_FocusOverride(FVector InPoint, float32 InWeight = 1.0f)
    {
        _FocusOverride = FMars_EyeSwarm_FocusOverride(InPoint, Math::Clamp(InWeight, 0.0f, 1.0f));
        Apply_FocusOverride();
    }

    void Clear_FocusOverride()
    {
        _FocusOverride = FMars_EyeSwarm_FocusOverride();
        Apply_FocusOverride();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Read-back (tests): custom primitive data and per-instance floats are write-only from script
    //----------------------------------------------------------------------------------------------------------------------

    FMars_EyeSwarm_FocusOverride Get_LastFocusOverride() const
    {
        return _FocusOverride;
    }

    // The instancers and the mirror of every per-instance float written to each; the components are null until filled.
    FMars_EyeSwarm_Instancers Get_Instancers() const
    {
        return _Instancers;
    }

    FCk_Handle_UnrealComponent Get_EyeballPart() const
    {
        return _EyeballPart;
    }

    FCk_Handle_UnrealComponent Get_EyelidPart() const
    {
        return _EyelidPart;
    }

    bool Get_IsFilled() const
    {
        return _Filled;
    }

    int32 Get_NumEyes() const
    {
        return _Eyes.Num();
    }

    bool Get_IsUsingFallbackMeshes() const
    {
        return _Meshes.IsFallback;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnInstancerAdded(FCk_Handle_UnrealComponent InHandle)
    {
        TryFill();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Assembly
    //----------------------------------------------------------------------------------------------------------------------

    // The jittered grid in the face node's frame, drawn once from Seed.
    private void Make_Eyes()
    {
        _Eyes.Empty();
        auto Stream = FRandomStream(Seed);
        _ClusterPhase = float32(Stream.GetFraction());

        const float CellY = SlabWidth / float(Columns);
        const float CellZ = SlabHeight / float(Rows);
        const float AxisTilt = MaxTiltDeg / Math::Sqrt(2.0);
        for (int32 Row = 0; Row < Rows; ++Row)
        {
            for (int32 Column = 0; Column < Columns; ++Column)
            {
                const float Y = -0.5 * SlabWidth + CellY * (float(Column) + 0.5) + Draw_Signed(Stream) * JitterFraction * CellY;
                const float Z = -0.5 * SlabHeight + CellZ * (float(Row) + 0.5) + Draw_Signed(Stream) * JitterFraction * CellZ;
                const float Scale = Math::Lerp(ScaleMin, ScaleMax, Math::Pow(float(Stream.GetFraction()), ScaleSkew));
                const auto Rotation = FRotator(Draw_Signed(Stream) * AxisTilt, Draw_Signed(Stream) * AxisTilt, Draw_Signed(Stream) * MaxRollDeg);
                const float X = ProtrusionCm - constants_eye_swarm::k_EyeballRadiusCm * Scale;

                const auto Phase = float32(Stream.GetFraction());
                const auto Variant = float32(Stream.GetFraction());
                _Eyes.Add(FMars_EyeSwarm_Eye(FTransform(Rotation, FVector(X, Y, Z), FVector(Scale, Scale, Scale)), Phase, Variant));
            }
        }
    }

    // -1..1.
    private float Draw_Signed(FRandomStream& InStream)
    {
        return float(InStream.GetFraction()) * 2.0 - 1.0;
    }

    // InPart's mesh as an instanced static mesh on its own node under InFace (at InPart.LocalTransform), made through
    // CkUnrealComponent; the part's material and collision profile apply. Hidden when InVisible is false (the lid ISM while
    // the eyeball look draws the lids).
    private FCk_Handle_UnrealComponent Add_Instancer(FCk_Handle_Transform& InFace, const FMars_MeshPart& InPart, bool InVisible)
    {
        if (ck::EnsureIfNot(ck::IsValid(InPart.Mesh), f"[EyeWallDummy] [{InPart.DebugName.ToString()}] has no mesh; the instancer is left out"))
        { return FCk_Handle_UnrealComponent(); }

        auto Node = utils_scene_node::Create(InFace, InPart.LocalTransform);

        auto Archetype = NewObject(this, UInstancedStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InPart.Mesh);
        if (ck::IsValid(InPart.Material))
        { Archetype.SetMaterial(0, InPart.Material); }
        Archetype.SetCollisionProfileName(InPart.CollisionProfile);
        if (InVisible == false)
        { Archetype.SetVisibility(false); }

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InPart.DebugName);
        return utils_unreal_component::Add(Node.H(), ComponentParams);
    }

    // Both instancers get every eye, index-paired, then the cluster's phase and focus override.
    private void TryFill()
    {
        if (_Filled || ck::Is_NOT_Valid(_EyeballPart) || ck::Is_NOT_Valid(_EyelidPart))
        { return; }

        auto Eyeballs = Cast<UInstancedStaticMeshComponent>(utils_unreal_component::Get_Component(_EyeballPart));
        auto Eyelids = Cast<UInstancedStaticMeshComponent>(utils_unreal_component::Get_Component(_EyelidPart));
        if (ck::Is_NOT_Valid(Eyeballs) || ck::Is_NOT_Valid(Eyelids))
        { return; }

        _Instancers.Eyeballs = Eyeballs;
        _Instancers.Eyelids = Eyelids;
        _Instancers.EyeballMeshScale = _Meshes.EyeballMeshScale;
        _Instancers.EyelidMeshScale = _Meshes.EyelidMeshScale;
        utils_eye_swarm::Prepare_Instancers(_Instancers);

        for (const auto& Eye : _Eyes)
        { utils_eye_swarm::Add_Eye(_Instancers, Eye); }

        Eyeballs.MarkRenderStateDirty();
        Eyelids.MarkRenderStateDirty();

        utils_eye_swarm::Set_PhaseCpd(Eyeballs, _ClusterPhase);
        utils_eye_swarm::Set_PhaseCpd(Eyelids, _ClusterPhase);
        _Filled = true;
        Apply_FocusOverride();
    }

    private void Apply_FocusOverride()
    {
        if (_Filled == false)
        { return; }

        utils_eye_swarm::Set_FocusOverride(_Instancers.Eyeballs, _FocusOverride);
        utils_eye_swarm::Set_FocusOverride(_Instancers.Eyelids, _FocusOverride);
    }
}
