// The many-eyes contract shared by the MarsEyeball / MarsEyelid looks (Mars_EyeSwarm_Look_Assets.as, whose header is the
// full data contract) and everything that places or feeds them. Each eye is one instance on an eyeball ISM plus one on a
// lid-shell ISM; the two looks animate every eye in the shader (blink, saccade, look-at) from the per-instance floats
// below, the cluster's custom primitive data and the four player heads the roster (Mars_EyeSwarm_Roster_EntityScript.as)
// writes into EyeSwarm_Mars_MPC. Cosmetic only: nothing here is simulation, so there is no kernel, no fragment and no
// request - an eye has no state a processor reads.
//   Per instance (identical on both ISMs, NumCustomDataFloats = 2): 0 Phase 0..1, 1 Variant 0..1.
//   Custom primitive data (per ISM): 0 PhaseCpd, 4..7 FocusOverride xyz (7 unused), 8 FocusOverrideWeight (0 = off).
//   MPC vectors Player0..Player3: xyz = head in world cm; an absent player is parked at (0, 0, k_AbsentHeadZ).
enum EMars_EyeSwarm_Preset
{
    // The look's own defaults: no uniform is written.
    Cartoon,
    // Bloodshot red sclera, burning iris, raw-flesh lids.
    Horror
}

namespace constants_eye_swarm
{
    const FString k_MpcPackage = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Materials/EyeSwarm_Mars_MPC";
    const FString k_MpcPath = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Materials/EyeSwarm_Mars_MPC.EyeSwarm_Mars_MPC";
    const FName k_Param_Player0 = n"Player0";
    const FName k_Param_Player1 = n"Player1";
    const FName k_Param_Player2 = n"Player2";
    const FName k_Param_Player3 = n"Player3";
    const int32 k_NumPlayerSlots = 4;
    // Far below any map: the shader treats a head this low as no player.
    const float k_AbsentHeadZ = -10000000.0;

    const FString k_EyeballMeshPath = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes/EyeSwarm_Eyeball_Mars_SM.EyeSwarm_Eyeball_Mars_SM";
    const FString k_EyelidMeshPath = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes/EyeSwarm_Eyelid_Mars_SM.EyeSwarm_Eyelid_Mars_SM";
    // The real meshes: a 5 cm eyeball and a 5.5 cm lid shell, centred on the pivot, +X forward, +Z up.
    const float k_EyeballRadiusCm = 5.0;
    const float k_EyelidRadiusCm = 5.5;
    // The engine sphere's radius: the fallback scales it down to the real meshes' radii.
    const float k_EngineSphereRadiusCm = 50.0;

    // Per-instance slots.
    const int32 k_Slot_Phase = 0;
    const int32 k_Slot_Variant = 1;
    const int32 k_NumCustomDataFloats = 2;

    // Custom primitive data indices.
    const int32 k_Cpd_PhaseCpd = 0;
    const int32 k_Cpd_FocusOverride = 4;
    const int32 k_Cpd_FocusOverrideWeight = 8;

    // MID uniforms.
    const FName k_Param_ScleraColor = n"ScleraColor";
    const FName k_Param_IrisColor = n"IrisColor";
    const FName k_Param_PupilColor = n"PupilColor";
    const FName k_Param_EmissiveStrength = n"EmissiveStrength";
    const FName k_Param_ShaderLid = n"ShaderLid";
    const FName k_Param_LidColor = n"LidColor";
    const FName k_Param_ScleraRimColor = n"ScleraRimColor";
    const FName k_Param_IrisInnerColor = n"IrisInnerColor";
}

// One eye of a cluster, in the instancers' component space: centre, rotation (+X is where it looks at rest) and a uniform
// scale on the real mesh.
struct FMars_EyeSwarm_Eye
{
    UPROPERTY()
    FTransform Transform = FTransform::Identity;

    UPROPERTY()
    float32 Phase = 0.0f;

    UPROPERTY()
    float32 Variant = 0.0f;

    FMars_EyeSwarm_Eye() {}

    FMars_EyeSwarm_Eye(FTransform InTransform, float32 InPhase, float32 InVariant)
    {
        Transform = InTransform;
        Phase = InPhase;
        Variant = InVariant;
    }
}

// The two look masters (null when not generated).
struct FMars_EyeSwarm_Masters
{
    UPROPERTY()
    UMaterialInterface Eyeball;

    UPROPERTY()
    UMaterialInterface Eyelid;
}

struct FMars_EyeSwarm_Mids
{
    UPROPERTY()
    UMaterialInstanceDynamic Eyeball;

    UPROPERTY()
    UMaterialInstanceDynamic Eyelid;
}

// The meshes the instancers draw and the scale that brings each to its contract radius (1 for the real meshes).
struct FMars_EyeSwarm_Meshes
{
    UPROPERTY()
    UStaticMesh Eyeball;

    UPROPERTY()
    UStaticMesh Eyelid;

    UPROPERTY()
    float EyeballMeshScale = 1.0;

    UPROPERTY()
    float EyelidMeshScale = 1.0;

    // Engine spheres stand in until the EyeSwarm meshes are imported.
    UPROPERTY()
    bool IsFallback = false;
}

// A cluster's two instancers and a mirror of every per-instance float written to each (script cannot read an ISM's
// PerInstanceSMCustomData back), instance-major, k_NumCustomDataFloats per instance.
struct FMars_EyeSwarm_Instancers
{
    UPROPERTY()
    UInstancedStaticMeshComponent Eyeballs;

    UPROPERTY()
    UInstancedStaticMeshComponent Eyelids;

    UPROPERTY()
    float EyeballMeshScale = 1.0;

    UPROPERTY()
    float EyelidMeshScale = 1.0;

    UPROPERTY()
    TArray<float32> EyeballData;

    UPROPERTY()
    TArray<float32> EyelidData;
}

// Where a cluster's eyes look instead of the nearest player; Weight 0 is off.
struct FMars_EyeSwarm_FocusOverride
{
    UPROPERTY()
    FVector Point = FVector::ZeroVector;

    UPROPERTY()
    float32 Weight = 0.0f;

    FMars_EyeSwarm_FocusOverride() {}

    FMars_EyeSwarm_FocusOverride(FVector InPoint, float32 InWeight)
    {
        Point = InPoint;
        Weight = InWeight;
    }
}

namespace utils_eye_swarm
{
    //------------------------------------------------------------------------------------------------------------------
    // The roster's MPC
    //------------------------------------------------------------------------------------------------------------------

    FVector Get_AbsentHead()
    {
        return FVector(0.0, 0.0, constants_eye_swarm::k_AbsentHeadZ);
    }

    bool Get_IsAbsentHead(const FVector& InHead)
    {
        return InHead.Z <= constants_eye_swarm::k_AbsentHeadZ * 0.5;
    }

    FName Get_PlayerParam(int32 InSlot)
    {
        if (InSlot == 0)
        { return constants_eye_swarm::k_Param_Player0; }
        if (InSlot == 1)
        { return constants_eye_swarm::k_Param_Player1; }
        if (InSlot == 2)
        { return constants_eye_swarm::k_Param_Player2; }
        return constants_eye_swarm::k_Param_Player3;
    }

    // Exactly k_NumPlayerSlots heads: InHeads in order, the first four only, the rest parked at the sentinel.
    TArray<FVector> Pack_PlayerSlots(const TArray<FVector>& InHeads)
    {
        auto Slots = TArray<FVector>();
        for (int32 Slot = 0; Slot < constants_eye_swarm::k_NumPlayerSlots; ++Slot)
        { Slots.Add(InHeads.IsValidIndex(Slot) ? InHeads[Slot] : Get_AbsentHead()); }

        return Slots;
    }

    // Asset-registry existence check by object path, without loading: a blocking load of a missing asset warns, and a
    // warning fails an autotest. utils_i_o::Get_AssetInfoFromPath is NOT used here: its result struct carries an FAssetData
    // and destructing it as a script temporary crashed the editor (two in one expression, 2026-11-07).
    bool Get_DoesAssetExist(const FString& InObjectPath)
    {
        const auto Data = AssetRegistry::GetAssetByObjectPath(FSoftObjectPath(InObjectPath), false);
        return Data.GetObjectPathString().IsEmpty() == false;
    }

    // Null until the editor script creates the collection; the registry check keeps a missing one from warning.
    UMaterialParameterCollection Load_Mpc()
    {
        if (Get_DoesAssetExist(constants_eye_swarm::k_MpcPath) == false)
        { return nullptr; }

        return System::LoadAsset_Blocking(TSoftObjectPtr<UMaterialParameterCollection>(FSoftObjectPath(constants_eye_swarm::k_MpcPath)));
    }

    // Player0..Player3 from InSlots (k_NumPlayerSlots entries).
    void Write_PlayerSlots(UMaterialParameterCollection InMpc, const TArray<FVector>& InSlots)
    {
        if (ck::Is_NOT_Valid(InMpc))
        { return; }

        for (int32 Slot = 0; Slot < InSlots.Num() && Slot < constants_eye_swarm::k_NumPlayerSlots; ++Slot)
        {
            const auto& Head = InSlots[Slot];
            Material::SetVectorParameterValue(InMpc, Get_PlayerParam(Slot),
                FLinearColor(float32(Head.X), float32(Head.Y), float32(Head.Z), 0.0f));
        }
    }

    // The player's Head attach point (the camera director's bob node, i.e. the eyes) once its gameplay is composed, else
    // the capsule centre raised by the configured eye height.
    FVector Get_PlayerHead(const AMars_PlayerCharacter InPlayer)
    {
        auto Entity = InPlayer.Get_GameplayComposedEntity();
        if (ck::IsValid(Entity))
        {
            auto AttachPoints = Entity.As_AttachPoints(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(AttachPoints))
            {
                auto Head = AttachPoints.Get_AttachPoint(GameplayTags::AttachPoint_Mars_Head);
                if (ck::IsValid(Head))
                { return utils_transform::Get_EntityCurrentLocation(Head); }
            }
        }

        auto EyeHeight = 64.0;
        if (ck::IsValid(InPlayer.Config))
        { EyeHeight = InPlayer.Config.View.EyeHeight.Height; }

        return InPlayer.GetActorLocation() + FVector(0.0, 0.0, EyeHeight);
    }

    // Puts InHandle's transform on the roster after the players: anything the eyes should watch that is not a player
    // character (a test's stand-in head, an NPC). The roster finds it by entity tag.
    void Add_Watched(FCk_Handle_Transform& InHandle)
    {
        utils_entity_tag::Add(InHandle.H(), Get_WatchedTag());
    }

    FName Get_WatchedTag()
    {
        return n"TAG_MarsEyeSwarmWatched";
    }

    FName Get_RosterTag()
    {
        return n"TAG_MarsEyeSwarmRoster";
    }

    //------------------------------------------------------------------------------------------------------------------
    // Looks and materials
    //------------------------------------------------------------------------------------------------------------------

    // The look definitions (Mars_EyeSwarm_Look_Assets.as; script assets are file-local, so through its accessors).
    UCkUsf_LookDefinition Get_EyeballLook()
    {
        return utils_eyeswarm::Look_EyeSwarmEyeball();
    }

    UCkUsf_LookDefinition Get_EyelidLook()
    {
        return utils_eyeswarm::Look_EyeSwarmEyelid();
    }

    // The generated masters. Get_LookMasterMaterial warns when a master is not generated or when nothing can render (no
    // compiled shader maps under -nullrhi), so callers ask only where FApp::CanEverRender().
    UMaterialInterface Get_EyeballMaster()
    {
        auto Look = Get_EyeballLook();
        return ck::IsValid(Look) ? utils_usf::Get_LookMasterMaterial(Look) : nullptr;
    }

    UMaterialInterface Get_EyelidMaster()
    {
        auto Look = Get_EyelidLook();
        return ck::IsValid(Look) ? utils_usf::Get_LookMasterMaterial(Look) : nullptr;
    }

    FMars_EyeSwarm_Masters Get_Masters()
    {
        auto Masters = FMars_EyeSwarm_Masters();
        Masters.Eyeball = Get_EyeballMaster();
        Masters.Eyelid = Get_EyelidMaster();
        return Masters;
    }

    // One MID per set master with InPreset's uniforms on both (a name a master does not declare is ignored). Cartoon writes
    // nothing: the look's defaults are the cartoon eye.
    FMars_EyeSwarm_Mids Make_Mids(const FMars_EyeSwarm_Masters& InMasters, EMars_EyeSwarm_Preset InPreset)
    {
        auto Mids = FMars_EyeSwarm_Mids();
        if (ck::IsValid(InMasters.Eyeball))
        { Mids.Eyeball = Material::CreateDynamicMaterialInstance(InMasters.Eyeball); }
        if (ck::IsValid(InMasters.Eyelid))
        { Mids.Eyelid = Material::CreateDynamicMaterialInstance(InMasters.Eyelid); }

        Apply_Preset(Mids.Eyeball, InPreset);
        Apply_Preset(Mids.Eyelid, InPreset);
        return Mids;
    }

    void Apply_Preset(UMaterialInstanceDynamic InMid, EMars_EyeSwarm_Preset InPreset)
    {
        if (ck::Is_NOT_Valid(InMid) || InPreset == EMars_EyeSwarm_Preset::Cartoon)
        { return; }

        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_ScleraColor, FLinearColor(0.35f, 0.04f, 0.03f, 1.0f));
        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_IrisColor, FLinearColor(1.0f, 0.12f, 0.05f, 1.0f));
        // The stylised gradients' colours follow the recolour: a darker red rim, a hot orange ring round the pupil.
        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_ScleraRimColor, FLinearColor(0.12f, 0.012f, 0.01f, 1.0f));
        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_IrisInnerColor, FLinearColor(1.0f, 0.45f, 0.12f, 1.0f));
        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_PupilColor, FLinearColor(0.01f, 0.0f, 0.0f, 1.0f));
        InMid.SetScalarParameterValue(constants_eye_swarm::k_Param_EmissiveStrength, 8.0f);
        InMid.SetVectorParameterValue(constants_eye_swarm::k_Param_LidColor, FLinearColor(0.45f, 0.12f, 0.10f, 1.0f));
    }

    // On: the eyeball look draws its own lid (the lid shell is hidden by the caller). Off leaves the look default (0).
    void Apply_ShaderLid(FMars_EyeSwarm_Mids& InMids, bool InShaderLid)
    {
        if (InShaderLid == false)
        { return; }

        if (ck::IsValid(InMids.Eyeball))
        { InMids.Eyeball.SetScalarParameterValue(constants_eye_swarm::k_Param_ShaderLid, 1.0f); }
        if (ck::IsValid(InMids.Eyelid))
        { InMids.Eyelid.SetScalarParameterValue(constants_eye_swarm::k_Param_ShaderLid, 1.0f); }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Meshes and instances
    //------------------------------------------------------------------------------------------------------------------

    // The imported EyeSwarm meshes, or engine spheres scaled to 10 / 11 cm until both exist. The registry check keeps a
    // missing mesh from warning.
    FMars_EyeSwarm_Meshes Load_Meshes()
    {
        auto Meshes = FMars_EyeSwarm_Meshes();
        if (Get_DoesAssetExist(constants_eye_swarm::k_EyeballMeshPath)
            && Get_DoesAssetExist(constants_eye_swarm::k_EyelidMeshPath))
        {
            Meshes.Eyeball = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(constants_eye_swarm::k_EyeballMeshPath)));
            Meshes.Eyelid = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(constants_eye_swarm::k_EyelidMeshPath)));
        }

        if (ck::IsValid(Meshes.Eyeball) && ck::IsValid(Meshes.Eyelid))
        { return Meshes; }

        Meshes.Eyeball = engine::load::Sphere();
        Meshes.Eyelid = engine::load::Sphere();
        Meshes.EyeballMeshScale = constants_eye_swarm::k_EyeballRadiusCm / constants_eye_swarm::k_EngineSphereRadiusCm;
        Meshes.EyelidMeshScale = constants_eye_swarm::k_EyelidRadiusCm / constants_eye_swarm::k_EngineSphereRadiusCm;
        Meshes.IsFallback = true;
        return Meshes;
    }

    // Allocates the per-instance floats; resets any written values, so it runs before the first Add_Eye.
    void Prepare_Instancers(FMars_EyeSwarm_Instancers& InInstancers)
    {
        InInstancers.Eyeballs.SetNumCustomDataFloats(constants_eye_swarm::k_NumCustomDataFloats);
        InInstancers.Eyelids.SetNumCustomDataFloats(constants_eye_swarm::k_NumCustomDataFloats);
        InInstancers.EyeballData.Empty();
        InInstancers.EyelidData.Empty();
    }

    // The eyeball instance and its lid, same centre and rotation, the same two floats; each mesh scale is applied on top
    // of the eye's own (both 1 with the real meshes). Returns the pair's instance index (the same on both ISMs).
    int32 Add_Eye(FMars_EyeSwarm_Instancers& InInstancers, const FMars_EyeSwarm_Eye& InEye)
    {
        const auto& Eye = InEye.Transform;
        const auto EyeScale = Eye.GetScale3D();
        const auto EyeballAt = FTransform(Eye.GetRotation(), Eye.GetLocation(), EyeScale * InInstancers.EyeballMeshScale);
        const auto EyelidAt = FTransform(Eye.GetRotation(), Eye.GetLocation(), EyeScale * InInstancers.EyelidMeshScale);

        const int32 Index = InInstancers.Eyeballs.AddInstance(EyeballAt, false);
        const int32 LidIndex = InInstancers.Eyelids.AddInstance(EyelidAt, false);
        ck::EnsureIfNot(Index == LidIndex,
            f"[EyeSwarm] eyeball instance [{Index}] and lid instance [{LidIndex}] are out of step: the two ISMs were not filled together");

        Write_InstanceFloats(InInstancers, Index, InEye);
        return Index;
    }

    // InEye's Phase and Variant on instance InIndex of both ISMs, mirrored instance-major (index * k_NumCustomDataFloats
    // + slot); render state is marked dirty by the caller.
    void Write_InstanceFloats(FMars_EyeSwarm_Instancers& InInstancers, int32 InIndex, const FMars_EyeSwarm_Eye& InEye)
    {
        TArray<float32> Values;
        Values.SetNum(constants_eye_swarm::k_NumCustomDataFloats);
        Values[constants_eye_swarm::k_Slot_Phase] = InEye.Phase;
        Values[constants_eye_swarm::k_Slot_Variant] = InEye.Variant;

        const int32 First = InIndex * constants_eye_swarm::k_NumCustomDataFloats;
        while (InInstancers.EyeballData.Num() < First + Values.Num())
        { InInstancers.EyeballData.Add(0.0f); }
        while (InInstancers.EyelidData.Num() < First + Values.Num())
        { InInstancers.EyelidData.Add(0.0f); }

        for (int32 Slot = 0; Slot < Values.Num(); ++Slot)
        {
            InInstancers.Eyeballs.SetCustomDataValue(InIndex, Slot, Values[Slot], false);
            InInstancers.Eyelids.SetCustomDataValue(InIndex, Slot, Values[Slot], false);
            InInstancers.EyeballData[First + Slot] = Values[Slot];
            InInstancers.EyelidData[First + Slot] = Values[Slot];
        }
    }

    // The mirror of slot InSlot of instance InIndex, or -99999 when nothing was written there.
    float32 Get_WrittenFloat(const TArray<float32>& InMirror, int32 InIndex, int32 InSlot)
    {
        const int32 At = InIndex * constants_eye_swarm::k_NumCustomDataFloats + InSlot;
        return InMirror.IsValidIndex(At) ? InMirror[At] : -99999.0f;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Cluster custom primitive data
    //------------------------------------------------------------------------------------------------------------------

    // The cluster's phase offset, added to every instance's Phase.
    void Set_PhaseCpd(UPrimitiveComponent InPrimitive, float32 InPhase)
    {
        if (ck::IsValid(InPrimitive))
        { InPrimitive.SetCustomPrimitiveDataFloat(constants_eye_swarm::k_Cpd_PhaseCpd, InPhase); }
    }

    // Every eye of the cluster looks at InFocus.Point with InFocus.Weight (0..1) instead of the nearest player.
    void Set_FocusOverride(UPrimitiveComponent InPrimitive, const FMars_EyeSwarm_FocusOverride& InFocus)
    {
        if (ck::Is_NOT_Valid(InPrimitive))
        { return; }

        InPrimitive.SetCustomPrimitiveDataVector3(constants_eye_swarm::k_Cpd_FocusOverride, InFocus.Point);
        InPrimitive.SetCustomPrimitiveDataFloat(constants_eye_swarm::k_Cpd_FocusOverrideWeight, InFocus.Weight);
    }

    void Clear_FocusOverride(UPrimitiveComponent InPrimitive)
    {
        Set_FocusOverride(InPrimitive, FMars_EyeSwarm_FocusOverride());
    }
}
