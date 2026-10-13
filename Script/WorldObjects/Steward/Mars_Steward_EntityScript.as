// The service steward (+X is its facing): a 2.9 m figure standing where it is placed, breathing through its idle loop,
// its two eyes blinking and following the nearest player in front of it. The same eyes tech as the chef: the body
// mesh's face plate is an eye-plate slot, and a face node riding the head bone composes Gaze and Eyes, which write the
// body's custom primitive data. Every machine builds the body and the eyes' logic; the look and the gaze only where
// cosmetics can run. Its look is mars::Mars_Steward_Config (Mars_Steward_Config.as).
//
// Assembly only for now: it hands out no recipe and has no fail state yet. Placed from the Place Actors panel
// (Ck Entity Scripts); the spawner's transform is where its feet stand.
class UMars_Steward_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    private UMars_Steward_Config _Config = mars::Mars_Steward_Config;

    // The scene node the body mesh sits on (the config's MeshOffset and Scale under the root).
    private FCk_Handle_Transform _BodyNode;
    private FCk_Handle_UnrealComponent _Body;
    private FCk_Handle_Eyes _Eyes;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        const auto Validation = _Config.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Steward] [{InHandle.ToString()}] rejected its config: {Validation.Get_Error()}"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        const auto& Body = _Config.Body;
        const auto BodyTransform = FTransform(Body.MeshOffset.Rotator(), Body.MeshOffset.GetLocation(), FVector(Body.Scale, Body.Scale, Body.Scale));
        _BodyNode = utils_scene_node::Create(Root, BodyTransform).As_Transform();
        utils_handle::Set_DebugName(_BodyNode.H(), n"Steward.Body");

        // The component is created later; the mesh, the idle and the face are set up once it exists (OnBodyAdded).
        const auto ComponentParams = utils_unreal_component::Make_Params(USkeletalMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Steward_Body");
        _Body = utils_unreal_component::Add(_BodyNode.H(), ComponentParams);
        utils_unreal_component::BindTo_OnAdded(_Body, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnBodyAdded"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnBodyAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Mesh = Cast<USkeletalMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[Steward] [{_BodyNode.ToString()}] got no USkeletalMeshComponent for its body"))
        { return; }

        const auto& Body = _Config.Body;

        // Nothing on the steward collides yet.
        Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Mesh.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Body.Mesh));

        if (Body.Idle.IsNull() == false)
        {
            const auto Looping = true;
            Mesh.PlayAnimation(System::LoadAsset_Blocking(Body.Idle), Looping);
        }

        ConstructEyes(Mesh);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The eyes: a face node following the head bone carries Gaze (looking at players' heads) and Eyes, which write their
    // values into the body's custom primitive data; the body's eye slot draws them.
    //----------------------------------------------------------------------------------------------------------------------

    // Where cosmetics cannot run (a dedicated server) the face is only its node and the eyes' logic: no look, no gaze.
    private void ConstructEyes(USkeletalMeshComponent InMesh)
    {
        const auto& FaceSpec = _Config.Face;
        if (ck::EnsureIfNot(InMesh.DoesSocketExist(FaceSpec.Bone),
            f"[Steward] [{_BodyNode.ToString()}] the body mesh has no [{FaceSpec.Bone}] bone for the eyes"))
        { return; }

        auto FaceNode = utils_scene_node::CreateAndAttachToUnrealMesh(_BodyNode, InMesh, FaceSpec.Bone, FaceSpec.Offset);
        utils_handle::Set_DebugName(FaceNode.H(), n"Steward.Face");
        auto Face = FaceNode.As_Transform();

        auto EyesSlot = ck::INDEX_NONE();
        if (utils_net::Get_CanExecuteCosmeticEvents(Face))
        {
            EyesSlot = SetUpEyesSlot(InMesh, FaceSpec.EyesSlot);

            auto GazeSpec = FMars_Gaze_Spec();
            GazeSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
            GazeSpec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
            GazeSpec.RangeCm = _Config.Gaze.RangeCm;
            GazeSpec.ConeHalfAngleDeg = _Config.Gaze.ConeHalfAngleDeg;
            utils_gaze::Add(Face, GazeSpec);
        }

        _Eyes = utils_eyes::Add(Face, _Config.Eyes);
        if (ck::IsValid(_Eyes) && EyesSlot != ck::INDEX_NONE())
        { _Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(InMesh, EyesSlot)); }
    }

    // Puts the eye-plate look on the body's eye slot and returns the slot's index. INDEX_NONE where nothing can render
    // (a headless boot has no compiled look, and CkUsf warns about every one it is asked for), and - after an ensure -
    // when the body mesh has no such slot or the MarsEyePlate look master is not generated; the eyes then have logic
    // but nothing to draw on.
    private int32 SetUpEyesSlot(USkeletalMeshComponent InMesh, FName InSlotName)
    {
        if (FApp::CanEverRender() == false)
        { return ck::INDEX_NONE(); }

        const auto SlotIndex = InMesh.GetMaterialIndex(InSlotName);
        if (ck::EnsureIfNot(SlotIndex != ck::INDEX_NONE(),
            f"[Steward] [{_BodyNode.ToString()}] the body mesh has no [{InSlotName}] material slot for the eyes - re-export it from build_steward.py"))
        { return ck::INDEX_NONE(); }

        auto LookMaster = utils_usf::Get_LookMasterMaterial(utils_eyes::Look_EyePlate());
        if (ck::EnsureIfNot(ck::IsValid(LookMaster),
            "[Steward] the MarsEyePlate look master is not generated - run Ck_Usf_GenerateLooks MarsEyePlate"))
        { return ck::INDEX_NONE(); }

        InMesh.SetMaterial(SlotIndex, LookMaster);
        return SlotIndex;
    }
}
