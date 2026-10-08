// The deep fryer station's assembly: the stone vat of oil centred on the origin, the swing-arm post on the far rim (+X)
// with the arm and its wire basket lowered into the oil, the round skimmer resting on the near-left rim, and the oil
// surface (OilSurface_Mars_SM, the 1 m VAT disc scaled to the cavity) at the oil level. The operator stands StandGap uu
// off the vat's -X face facing +X, left glove flat on the near rim. Layout numbers: station_spec.py PROPS and
// D:\Repo\Content\Cooking\export\stations\FryerStation_Layout.json (operator at -X, vat axis at the origin, floor z 0).
// No frying kernel yet (GAMEPLAY_HANDOFF_PROMPT.md, "Deep fryer station"): this is the assembly layer only, so the Fry
// feature can take the arm (hinge at ArmHingeLocal, lowered / raised pitches) and the basket when it lands.
class UMars_FryerStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    // FryerVat_Mars_SM: outer radius 62, inner 48, rim top 76, cavity floor 40, oil level 66.
    private const float64 VatOuterRadius = 62.0;
    private const float64 VatInnerRadius = 48.0;
    private const float64 VatRimTop = 76.0;
    private const float64 OilLevel = 66.0;
    // The OilSurface disc is 1 m across: scale it to the cavity.
    private const float64 OilDiscScale = VatInnerRadius / 50.0;
    // Close in: the capsule (radius 39) stands almost touching the vat.
    private const float64 StandGap = 45.0;
    private const float64 ProbePadding = 6.0;

    // The post stands on the far rim (the vat's SOCKET_ArmPost); the arm pivots at the post's SOCKET_Hinge (27 up the post)
    // about its local Y: pitch ArmPitchLowered sinks the basket under the oil, ArmPitchRaised hangs it over the oil to drain.
    private const FVector ArmPostLocal = FVector(54.0, 0.0, 76.0);
    private const FVector ArmHingeLocal = FVector(54.0, 0.0, 103.0);
    private const float64 ArmPitchLowered = 18.914;
    private const float64 ArmPitchRaised = -34.0;
    // The basket (pivot at the centre of its inner floor, long axis along its local X) hangs level from the arm's
    // SOCKET_Hang; lowered, its floor is 13 under the oil and its rim 4.6 above it. Yawed -90 so its long side runs
    // along the rim as on the concept board.
    private const FVector BasketLoweredLocal = FVector(0.0, 0.0, 53.0);
    private const FVector BasketRaisedLocal = FVector(2.292, 0.0, 105.605);
    private const float64 BasketYaw = -90.0;
    // The skimmer (pivot at the lowest point of its bowl, handle along its local +X) leans in the rim notch at the vat's
    // SOCKET_SkimmerRest, bowl over the oil.
    private const FVector SkimmerRestLocal = FVector(-24.042, -24.042, 68.689);
    private const FRotator SkimmerRestRotation = FRotator(-4.0, -135.0, 0.0);

    // The left glove flat on the near rim, a palm's thickness above the stone.
    private const float64 RimGripInset = 8.0;
    private const float64 PalmLift = 2.5;

    private FCk_Handle_Transform _RimGripNode;

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(VatOuterRadius + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "FryPrompt", "Fry"),
            NSLOCTEXT("MarsInteraction", "FryerStationInUsePrompt", "In use"));
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        const auto Half = VatOuterRadius + ProbePadding;
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(Half, Half, VatRimTop * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, VatRimTop * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            assets::load::FryerVat_Mars_SM(), nullptr, collision::profile::BlockAll, n"FryerStation_Vat"));

        auto Oil = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, OilLevel), FVector(OilDiscScale, OilDiscScale, 1.0)),
            assets::load::OilSurface_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryerStation_Oil");
        Oil.CastShadow = false;
        InRoot.Add_MeshPart(this, Oil);

        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, ArmPostLocal),
            assets::load::FryerArmPost_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryerStation_ArmPost"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator(ArmPitchLowered, 0.0, 0.0), ArmHingeLocal),
            assets::load::FryerArm_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryerStation_Arm"));

        // The basket keeps its own collision (floor + four walls) so fried pieces with physics collect in it.
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator(0.0, BasketYaw, 0.0), BasketLoweredLocal),
            assets::load::FryerBasket_Mars_SM(), nullptr, collision::profile::BlockAll, n"FryerStation_Basket"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(SkimmerRestRotation, SkimmerRestLocal),
            assets::load::FryerSkimmer_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryerStation_Skimmer"));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): a left hand flat on the rim with its
        // fingers forward has its index side to the right (+Y) and its palm down (-Z).
        _RimGripNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::MakeFromXZ(FVector::RightVector, -FVector::UpVector),
                FVector(-(VatOuterRadius - RimGripInset), -(VatInnerRadius * 0.5), VatRimTop + PalmLift))).As_Transform();
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _RimGripNode));
    }
}
