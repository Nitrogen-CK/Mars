// A rat den (Stone Arch candidate): the assembly. The root is the den frame (+X out of the opening, origin on the floor at
// the front plane). It hangs the stone shell and recess (one static mesh, complex-as-simple collision so the portal stays
// open; the shell carries the Ck.Jolt.NoBake component tag, so it never enters the Jolt static world and the ground field
// under it stays the floor's - its open faces would otherwise bake as open ground and strand the rats at the portal
// stands) and an independently placed paired eye plate in the black recess, composes the RatDen kernel and the Eyes on the
// plate (the SHARED MarsEyePlate look: the plate mesh wears it), and shows the eyes Wide with blink and look while the kernel
// says a resident is hidden (OnEyesChanged), black (strength 0) while vacant. Headless (no renderer) it composes the kernel
// and the eyes' logic with no meshes.
// The assembly's own fragment on the den root: a weak pointer back to its entity script (automation reads the shell through
// it; nothing in the kernel reads it).
struct FMars_Fragment_RatDen_Assembly
{
    UPROPERTY()
    TWeakObjectPtr<UMars_RatDen_EntityScript> Script;
}

class UMars_RatDen_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_RatDen_Spec Spec;

    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // The shell's collision profile. BlockAll by default; a review court whose ground field must not bake the open shell
    // (its faces bake as open ground and close the portal stands) spawns it with NoCollision.
    UPROPERTY(ExposeOnSpawn)
    FName ShellCollisionProfile = collision::profile::BlockAll;

    // Builds the stone shell even where nothing renders (automation bakes a ground field with the real shell present).
    UPROPERTY(ExposeOnSpawn)
    bool BuildShellHeadless = false;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> DenMesh = TSoftObjectPtr<UStaticMesh>(
        FSoftObjectPath("/Game/ArtCandidates/PantryRat/R02/Props/PantryRat_R02_Den_Mars_SM.PantryRat_R02_Den_Mars_SM"));

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> EyePlateMesh = TSoftObjectPtr<UStaticMesh>(
        FSoftObjectPath("/Game/ArtCandidates/PantryRat/R02/Props/PantryRat_R02_DenEyePlate_Mars_SM.PantryRat_R02_DenEyePlate_Mars_SM"));

    // The plate in the den frame: 2 cm proud of the recess's back plane (45 cm behind the front plane), centred at 22 cm.
    UPROPERTY()
    FTransform EyePlateOffset = FTransform(FRotator::ZeroRotator, FVector(-43.0, 0.0, 22.0));

    private FCk_Handle_RatDen _Den;
    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_UnrealComponent _Shell;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"RatDen");

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        auto Plate = FCk_Handle_UnrealComponent();
        if (WithVisuals && FApp::CanEverRender())
        { Plate = BuildLook(Root); }
        else if (WithVisuals && BuildShellHeadless)
        { BuildShell(Root); }

        auto Composed = Spec;
        Composed.Parts.EyePlate = Plate;
        _Den = utils_rat_den::Add(InHandle, Composed);
        if (ck::Is_NOT_Valid(_Den))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Assembly = FMars_Fragment_RatDen_Assembly();
        Assembly.Script = this;
        InHandle.Add_Fragment(Assembly);

        auto Face = utils_scene_node::Create(Root, EyePlateOffset).As_Transform();
        utils_handle::Set_DebugName(Face.H(), n"RatDen.Face");

        auto EyesSpec = FMars_Eyes_Spec();
        EyesSpec.Style = Get_ShownStyle();
        EyesSpec.Blink = FMars_Eyes_BlinkSpec();
        EyesSpec.Look = FMars_Eyes_LookSpec();
        EyesSpec.Plate = Plate;
        _Eyes = utils_eyes::Add(Face, EyesSpec);

        _Den.BindTo_OnEyesChanged(FMars_Delegate_RatDen_OnEyesChanged(this, n"OnEyesChanged"));
        Apply_Eyes(_Den.Get_EyesShown());
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    FCk_Handle_RatDen Get_Den() const
    {
        return _Den;
    }

    // The stone shell's component (invalid until it is added; never built headless unless BuildShellHeadless).
    FCk_Handle_UnrealComponent Get_Shell() const
    {
        return _Shell;
    }

    private FCk_Handle_UnrealComponent BuildLook(FCk_Handle_Transform& InRoot)
    {
        BuildShell(InRoot);

        UStaticMesh PlateAsset = EyePlateMesh.IsNull() ? nullptr : System::LoadAsset_Blocking(EyePlateMesh);
        if (ck::Is_NOT_Valid(PlateAsset))
        {
            Warning(f"[RatDen] the eye plate [{EyePlateMesh.ToSoftObjectPath().ToString()}] is not loadable: the den shows no eyes");
            return FCk_Handle_UnrealComponent();
        }

        auto PlatePart = FMars_MeshPart(EyePlateOffset, PlateAsset, nullptr, collision::profile::NoCollision, n"RatDen_EyePlate");
        PlatePart.CastShadow = false;
        return InRoot.Add_MeshPart(this, PlatePart);
    }

    // The shell as Add_MeshPart builds a part (Movable, its own scene node), plus the NoBake tag on the archetype: the hosted
    // component is instanced from it, and the tag must be there when the component is added (the Automatic bake runs then).
    private void BuildShell(FCk_Handle_Transform& InRoot)
    {
        UStaticMesh ShellMesh = DenMesh.IsNull() ? nullptr : System::LoadAsset_Blocking(DenMesh);
        if (ck::Is_NOT_Valid(ShellMesh))
        {
            Warning(f"[RatDen] the den mesh [{DenMesh.ToSoftObjectPath().ToString()}] is not loadable: the den draws no shell");
            return;
        }

        auto Node = utils_scene_node::Create(InRoot, FTransform::Identity);
        auto Archetype = NewObject(this, UStaticMeshComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(ShellMesh);
        Archetype.SetCollisionProfileName(ShellCollisionProfile);
        // The CkJolt bake filter's default exclusion tag (CkJolt_ProjectSettings.cpp), honoured by the Automatic static-world
        // bake of a hosted component; the tag the drip dressing and still water use (Mars_DripAssets.as utils_drip::k_JoltNoBakeTag).
        Archetype.ComponentTags.AddUnique(n"Ck.Jolt.NoBake");
        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"RatDen_Shell");
        _Shell = utils_unreal_component::Add(Node.H(), Params);
    }

    UFUNCTION()
    private void OnEyesChanged(FCk_Handle_RatDen InDen, bool InShown, int32 InEyeSlot)
    {
        Apply_Eyes(InShown);
    }

    // Shown: the Wide style at its own strength; vacant: the same cells at strength 0, which the plate draws black.
    private void Apply_Eyes(bool InShown)
    {
        if (ck::Is_NOT_Valid(_Eyes))
        { return; }

        auto Style = Get_ShownStyle();
        if (InShown == false)
        { Style.EmissiveStrength = 0.0f; }

        _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(Style));
    }

    private FMars_Eyes_StyleDef Get_ShownStyle() const
    {
        return utils_eyes::Style_Wide().Def;
    }
}
