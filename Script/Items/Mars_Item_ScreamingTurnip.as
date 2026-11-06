// Every Screaming Turnip asset path, in one place. The Phase C candidate is swapped in (2026-11-06): the proxy hull and the
// beds are the R01 statics; the skeletal mesh and clips are loaded only once the asset registry knows them.
namespace constants_screaming_turnip_assets
{
    const FString k_Root = "/Game/ArtCandidates/ScreamingTurnip/R01";

    // The neutral collision hull (Phase C3, the x3.0 asset), authored at size with its pivot at the skeletal mesh's root (the
    // taproot tip; the hull's centre sits (0.992, 0, 20.25) from it: manifest gameplay_numbers.hull_centre_offset_from_root). Its Grip_L / Grip_R sockets are not read: the definition declares
    // Grip.Points, which win (UMars_WorldItem_EntityScript::Resolve_GripPoints).
    TSoftObjectPtr<UStaticMesh> CollisionProxy_R01()
    { return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(k_Root + "/Meshes/ScreamingTurnip_R01_Collision_Mars_SM.ScreamingTurnip_R01_Collision_Mars_SM")); }

    // The item's static proxy: its body shape and pickup fit (bounds centred on the hull, not its pivot).
    TSoftObjectPtr<UStaticMesh> Proxy()
    { return CollisionProxy_R01(); }

    // The hull is authored at size.
    const FVector k_ProxyScale = FVector::OneVector;

    TSoftObjectPtr<USkeletalMesh> SkeletalMesh()
    { return TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(k_Root + "/Meshes/ScreamingTurnip_R01_Mars_SK.ScreamingTurnip_R01_Mars_SK")); }

    // InClip is the clip stem (ROOT_QuietIdle, SRC_Idle, ...).
    TSoftObjectPtr<UAnimSequence> Clip(const FString& InClip)
    {
        const auto Name = f"ScreamingTurnip_R01_{InClip}_Mars_ANIM";
        return TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(f"{k_Root}/Animation/{Name}.{Name}"));
    }

    // Whether InPath is a known asset, asked of the asset registry so that a candidate Phase C has not saved yet is never
    // loaded (a failed load logs an error, which fails a headless test).
    bool Get_IsKnownAsset(const FSoftObjectPath& InPath)
    {
        return AssetRegistry::GetAssetByObjectPath(InPath).GetSoftObjectPath().IsValid();
    }

    // The pull's clips, authored at 0.2 s (SRC_Grip: the stalks compress at the HarvestGrip points) and 0.5 s (SRC_Tug: the
    // stalks stretch up to the full strain), stretched by the bed to span its Grip and Tug seconds; SRC_Cancel (0.23 s)
    // eases the full strain back to the planted rest (manifest clips).
    const FString k_Clip_Grip = "SRC_Grip";
    const FString k_Clip_Tug = "SRC_Tug";
    const FString k_Clip_Cancel = "SRC_Cancel";
    const FString k_Clip_PlantedIdle = "SRC_Idle";

    // The skeletal mesh's leaf-stalk sockets on the crown bone (manifest sockets.HarvestGrip_R / _L): the bed's pull grip
    // nodes ride them through the pull's clips.
    const FName k_HarvestGripSocket_R = n"HarvestGrip_R";
    const FName k_HarvestGripSocket_L = n"HarvestGrip_L";

    // The warning's first clip: from Dormant (QuietIdle) the full Anticipate; out of the recovery the tired one, which starts
    // on ROOT_RecoveryIdle's first pose and ends on ROOT_Inhale's (manifest clip_contract.hard_cuts).
    const FString k_Clip_Anticipate = "ROOT_Anticipate";
    const FString k_Clip_AnticipateTired = "ROOT_AnticipateTired";

    // Null while Phase C's skeletal mesh is not saved.
    USkeletalMesh TryLoad_SkeletalMesh()
    {
        const auto Path = SkeletalMesh();
        if (Get_IsKnownAsset(Path.ToSoftObjectPath()) == false)
        { return nullptr; }

        return System::LoadAsset_Blocking(Path);
    }

    // Null while Phase C's InClip is not saved.
    UAnimSequence TryLoad_Clip(const FString& InClip)
    {
        const auto Path = Clip(InClip);
        if (Get_IsKnownAsset(Path.ToSoftObjectPath()) == false)
        { return nullptr; }

        return System::LoadAsset_Blocking(Path);
    }

    // The planted bed and the harvested one: pivot at the soil-line centre, 72 x 72 cm, Z -10.2 .. +2.06 (manifest
    // gameplay_numbers.bed).
    TSoftObjectPtr<UStaticMesh> Bed_R01()
    { return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(k_Root + "/Meshes/TurnipBed_R01_Mars_SM.TurnipBed_R01_Mars_SM")); }

    TSoftObjectPtr<UStaticMesh> BedEmpty_R01()
    { return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(k_Root + "/Meshes/TurnipBedEmpty_R01_Mars_SM.TurnipBedEmpty_R01_Mars_SM")); }

    TSoftObjectPtr<UStaticMesh> Bed()
    { return Bed_R01(); }

    TSoftObjectPtr<UStaticMesh> BedEmpty()
    { return BedEmpty_R01(); }

    // The beds are authored at size.
    const FVector k_BedScale = FVector::OneVector;

    // The skeletal mesh's offset under the item's root: none, the proxy hull's pivot is the skeletal root.
    const FTransform k_SkeletalOffset = FTransform::Identity;

    // The gloves' grip points on the skeletal mesh, from its root (the landmarks Grip_L / Grip_R at the x3.0 size, Unreal
    // axes: the bulb surface 12 cm up the taproot axis, |y| 11.82; manifest gameplay_numbers.k_GripLocation_R / _L). The root is held turned to face its holder (HeldOffset yaws it
    // 180), so the right glove takes the landmark on the root's -Y flank (its Grip_L) and the left the +Y one, each turned
    // by the same yaw: points x HeldOffset are the gloves' hold of the outward-facing root, unchanged in the hand frame.
    // The definition places them through k_SkeletalOffset.
    const FVector k_GripLocation_R = FVector(0.0, -11.82, 12.0);
    const FVector k_GripLocation_L = FVector(0.0, 11.82, 12.0);
    const FRotator k_GripRotation = FRotator(0.0, 180.0, 0.0);

    // The held root faces its holder: the mouth (+X) turned back toward the camera, so the holder sees the warning.
    const FRotator k_HeldRotation = FRotator(0.0, 180.0, 0.0);

    // The planted root's offset under the bed's root (the soil-line centre): sunk 28.8 cm, the soil line on the skeletal
    // mesh (its root at the taproot tip; manifest gameplay_numbers.k_PlantedOffset). The planted stand-in hull takes the
    // same offset.
    const FTransform k_PlantedOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -28.8));

    // Where the gloves take the planted root's leaf stalks for the pull, from the skeletal root (the crown sockets
    // HarvestGrip_R / HarvestGrip_L at their bind pose: 2.4 cm up the stems of leaf_02 / leaf_05, Unreal axes; manifest
    // sockets.HarvestGrip_R / _L root_relative_ue_cm). The bed places them through k_PlantedOffset.
    const FVector k_HarvestGripLocation_R = FVector(-1.522, 4.683, 38.035);
    const FVector k_HarvestGripLocation_L = FVector(-1.522, -4.683, 38.035);

    // The held root's place in the hand frame: the hull centre where the 16 cm candidate's was (13.669, 0, -5.25), so the
    // 48 cm root's root goes 25.5 cm under the hands (manifest gameplay_numbers.HeldOffset_location; PIE run-03 kept it).
    const FVector k_HeldLocation = FVector(14.661, 0.0, -25.5);
}

// The Screaming Turnip: a two-handed persistent world item whose body carries the ScreamingTurnip kernel
// (UMars_ScreamingTurnip_EntityScript). The static proxy is its body and pickup fit, the declared Grip.Points the gloves'
// grips; the animated skeletal mesh only draws it.
asset Mars_ItemDef_ScreamingTurnip of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Screaming Turnip"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = constants_screaming_turnip_assets::Proxy();
    Presentation.Visual.MeshScale = constants_screaming_turnip_assets::k_ProxyScale;
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    // The placeholder's colour (the bulb's magenta); the skeletal mesh hides the proxy once it loads.
    Presentation.Visual.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.85, 0.25, 0.6, 1.0));
    // The gloves cup it from below.
    Presentation.Grip.Pose = EMars_HandGripPose::Cradle;
    Presentation.Grip.Layout = EMars_HandGripLayout::Cradle;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    // Each glove on a lower flank of the bulb at the landmark table's grip points, turned with the held root (k_GripRotation:
    // in the hand frame the grip stays palm up, the index side forward), placed through the skeletal mesh's offset
    // (Grip.Points; the item root's frame).
    Presentation.Grip.Points.Right = TOptional<FTransform>(
        FTransform(constants_screaming_turnip_assets::k_GripRotation, constants_screaming_turnip_assets::k_GripLocation_R) * constants_screaming_turnip_assets::k_SkeletalOffset);
    Presentation.Grip.Points.Left = TOptional<FTransform>(
        FTransform(constants_screaming_turnip_assets::k_GripRotation, constants_screaming_turnip_assets::k_GripLocation_L) * constants_screaming_turnip_assets::k_SkeletalOffset);
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    // Stowed and not selected it rides ON the Back point, as the Cookbook does (CarryOffset identity). A whole food's
    // (-35, 0, -25) is for a joint centred on its pivot: under this root's base pivot it put the root on the floor behind
    // the chef (PIE run-01, F8).
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    Presentation.Mounting.CargoOffset = FTransform::Identity;
    // A cradle hold under the hands (the proxy's pivot is its base, the taproot tip), turned to face the holder.
    Presentation.Mounting.HeldOffset = FTransform(constants_screaming_turnip_assets::k_HeldRotation, constants_screaming_turnip_assets::k_HeldLocation);
    // Read only by an item without a Mesh (Mars_WorldItem_Utils.as:391 / :406): the proxy hull's bounds drive this one's
    // probe. The hull's bounding radius 15.02 + 5 cm (manifest gameplay_numbers.PickupProbeRadius_suggestion).
    Presentation.WorldItem.PickupProbeRadius = 21.0f;
    Presentation.WorldItem.ScriptClass = UMars_ScreamingTurnip_EntityScript;
    _ItemTraits.Add(Presentation);

    // The blockout default (mars_items::Add_BlockoutTraits).
    _ItemTraits.Add(Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable)));
}

namespace mars_items
{
    UCk_InventoryItem_Definition ScreamingTurnip() { return Mars_ItemDef_ScreamingTurnip; }
}
