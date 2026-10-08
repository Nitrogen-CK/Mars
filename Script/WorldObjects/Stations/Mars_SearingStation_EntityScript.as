// The searing station: a table (width along local Y, depth along local X) with a stove slab and a burner on top, and on
// the burner the modelled frying pan, which swirls while operated and which the operator's look tilts and, flicked up,
// tosses. The pan node carries an Implement (the tilt, the lift and the swirl); under it, on a node yawed so the handle
// points at the operator, sit the pan mesh (a NoCollision visual) and its kinematic triangle-mesh body, the one collision
// of the pan. The Searing feature lives on the station entity and its own state machine (UMars_SmState_Searing_Idle)
// reads the operator. The pan starts empty: a CookingFeed on the same entity holds the raw platter on the table's left (six
// raw cubes), and its station-feed tasks turn the operator's add-food press into a left-hand transfer that this script
// presents (the glove node, the slot cubes, the cube in the glove) and whose release the Searing kernel admits as a piece
// (a dynamic body on its own entity, worn here as a meat cube). This script builds the nodes and, every frame, dresses the
// pan, every cube and the oil from the Searing state. While operating, the right glove holds the pan handle (riding the
// tilt and the toss) and the left follows the feed node, resting in front of the platter between transfers.
//
// Per piece: its own cube, its own cook state and Custom Primitive Data (from that piece's face sears only, never another's),
// its own seared burst. Aggregate (the pan material has ONE meat footprint): the footprint, and so the oil pool and the FX
// riding the footprint node, follows the most recently admitted piece that lies on the pan (Cooking or Ready); with none on
// the pan there is no pool and the footprint stays where it was. The oil trail lags that footprint, and the sizzle ramp
// follows the kernel's aggregate sizzle (full while any cooking piece sizzles; a hiss while only seared faces lie on the
// hot pan). Face values are never averaged across pieces.
struct FMars_SearingStation_PieceVisual
{
    FMars_CookingFeed_PieceId Id;
    // The piece entity: its cube dies with it.
    FCk_Handle Entity;
    FCk_Handle_UnrealComponent Part;
    // This piece's look; a lost piece keeps its last one.
    FMars_CookState CookState;
}

class UMars_SearingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Searing_Spec Searing;

    // The pan's tilt and lift; its Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Implement_Spec Implement;

    // The raw platter's stock and the transfer's timing; its slot capacity and release node are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    private const float64 TableWidth = 140.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the table edge.
    private const float64 StandGap = 43.0;
    // The operating view, pitched hard onto the pan from ViewGap uu off the table edge and ViewAboveStove uu over the stove
    // top. It lives in the station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -54.0f;
    private const float64 ViewGap = 38.0;
    private const float64 ViewAboveStove = 71.0;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    private const float64 StoveSize = 50.0;
    private const float64 StoveHeight = 4.0;
    private const float64 StoveX = 0.0;
    // Engine cylinder scales (100 uu across and tall): a burner ring 36 across and 2 tall on the slab.
    private const float64 BurnerRadiusScale = 0.36;
    private const float64 BurnerHeightScale = 0.02;
    // The pan rests clear of the burner ring so a tilt does not cut into the blockout stove; a stove prop or a held lift
    // while operated decides the final rest.
    private const float64 PanHoverAboveBurner = 7.0;

    // The pan, the cube and the oil pool as cooking_spec.py authors them (FOOD_LIBRARY.md), in the meshes' own centimetres;
    // the pan and every oil length are multiplied by PanScale on this station (see the design for why not 1).
    private const float32 PanScale = 2.5f;
    // The cube is a fifth larger than the art's ratio to the pan (the maintainer's call), so it has its own scale; the pool
    // parameters below follow the cube's half extent so the oil still hugs it.
    private const float32 CubeScale = 3.0f;
    private const float32 PanRimRadius = 14.5f;
    private const float32 PanRimHeight = 4.6f;
    private const float32 PanUndersideDepth = 0.3f;
    private const float32 CubeHalf = 2.0f;
    // The pool as ratios of the cube's half extent h in pan cm (mars_cooking_ue.py LOOKDEV_POOL_NOTE): the footprint radius
    // is h * sqrt(2) * 0.9; Pool Radius, Pool Margin, Pool Blend, Simmer Width and Contact Softness are 1.1 / 0.6 / 0.5 /
    // 0.4 / 0.4 h.
    private const float32 FootprintPerHalf = 1.41421356f * 0.9f;
    private const float32 PoolRadiusPerHalf = 1.1f;
    private const float32 PoolMarginPerHalf = 0.6f;
    private const float32 PoolBlendPerHalf = 0.5f;
    private const float32 SimmerWidthPerHalf = 0.4f;
    private const float32 ContactSoftnessPerHalf = 0.4f;
    // The handle grip, in pan cm: the near end of the grip sweep (x 19.7..34.2, z 5.8..8.4 behind the rim along +X); a
    // glove further out along the handle sits right under the operating camera and fills the view.
    private const FVector HandleGripLocal = FVector(21.0, 0.0, 6.0);
    private const float32 HandleGripPitchDegrees = 10.2f;
    // Oiled: the steak's friction combines with this one as sqrt(a * b).
    private const float32 PanFriction = 0.15f;
    private const float32 PanRestitution = 0.1f;
    // The oil level above the cooking surface, where the beads and the splatter live.
    private const float32 OilLevel = 0.1f;

    // The swirl while operated: the pan's centripetal pull (w^2 r) beats the combined friction's mu g, so the steak glides.
    private const float32 SwirlRadius = 4.0f;
    private const float32 SwirlHz = 1.5f;
    // The swirl on the oiled pan breaks a gliding steak's contact for just over 0.1 s now and then; a longer grace keeps it
    // on the pan (and the sizzle steady) through those gaps.
    private const float32 SteakContactGraceSeconds = 0.15f;

    // The dressing: the pan material's driven group, the oil trail behind the cube, the sizzle ramp and the fond.
    private const float32 OilAmountHot = 0.7f;
    private const float32 OilAmountCold = 0.6f;
    private const float32 SizzleFull = 1.0f;
    // A seared face still hisses a little.
    private const float32 SizzleSearedFace = 0.4f;
    private const float32 SizzleRiseRate = 2.0f;
    private const float32 SizzleFallRate = 1.0f;
    private const float32 FondStart = 0.1f;
    private const float32 FondRate = 0.02f;
    private const float32 TrailLagSeconds = 0.25f;
    private const float32 OilCoatOnPan = 0.7f;
    private const float32 OilCoatOffPan = 0.3f;
    // Per second toward the target.
    private const float32 OilCoatRate = 1.0f;

    // The oil beads (OilBubbles_Mars_NS): one box over the whole pool, lengths in art cm (times PanScale).
    private const float32 BubbleRate = 25.0f;
    // The box half extent per cube half extent (the art's 3.5 cm around its 2 cm half cube).
    private const float32 BubbleOuterPerHalf = 1.75f;
    private const float32 BubbleStartDepth = 0.3f;
    private const float32 BubbleRadiusMin = 0.12f;
    private const float32 BubbleRadiusMax = 0.25f;
    private const float32 BubbleLifetimeMin = 0.6f;
    private const float32 BubbleLifetimeMax = 1.0f;
    private const float32 BubbleWobble = 0.05f;
    private const float32 BubbleRise = 0.5f;
    private const FLinearColor OilColour = FLinearColor(0.22f, 0.1f, 0.02f, 1.0f);

    // The oil splatter (OilSplatter_Mars_NS), lengths in art cm (times PanScale).
    private const float32 SplatterRate = 14.0f;
    private const float32 SplatterBursts = 3.0f;
    private const float32 SplatterFlingMin = 2.0f;
    private const float32 SplatterFlingMax = 8.0f;
    private const float32 SplatterSizeMin = 0.15f;
    private const float32 SplatterSizeMax = 0.4f;
    private const float32 SplatterLife = 2.0f;
    private const float32 SplatterArc = 0.8f;
    private const FLinearColor SplatterColour = FLinearColor(0.1f, 0.045f, 0.012f, 1.0f);
    // The beads run while the sizzle ramp is above this.
    private const float32 FxActiveThreshold = 0.05f;
    // uu the steak must move before the footprint node is written again.
    private const float64 k_FootprintWriteTolerance = 0.01;

    // The pan's cooking look, set once on its dynamic instance.
    private const float32 LookSeasoning = 0.25f;
    private const float32 LookCarbonSpecks = 0.2f;
    private const float32 LookOilOpacity = 0.7f;
    private const float32 LookPoolWobble = 0.5f;
    private const float32 LookPoolEdgeSoftness = 0.15f;
    private const float32 LookSimmerCell = 0.6f;
    private const float32 LookSimmerDensity = 0.85f;
    private const float32 LookSimmerRimDarken = 0.95f;

    // A palm's thickness: the glove's grip bone above what its palm rests on.
    private const float64 PalmLift = 2.5;

    // The raw platter on the table's left (-Y): a slab with RawSlotRows x RawSlotColumns raw cubes (rows along X, away from
    // the operator; columns along Y), and the free glove's rest in front of it.
    private const int32 RawSlotRows = 3;
    private const int32 RawSlotColumns = 2;
    private const float64 RawSlotPitch = 13.0;
    private const float64 PlatterCentreY = -54.0;
    private const float64 PlatterHeight = 2.0;
    private const float64 PlatterMargin = 2.0;
    private const FVector FeedRestLocal = FVector(-30.0, -56.0, 0.0);
    // The release node over the pan: this far above the rim plus a cube's half extent, so a released cube clears the rim.
    private const float64 ReleaseClearance = 4.0;

    // The state label above the table's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 44.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const FLinearColor k_StoveColor = FLinearColor(0.22f, 0.22f, 0.24f, 1.0f);
    private const FLinearColor k_BurnerHot = FLinearColor(0.9f, 0.3f, 0.1f, 1.0f);
    private const FLinearColor k_BurnerCold = FLinearColor(0.3f, 0.3f, 0.3f, 1.0f);

    private const int32 k_SearedBurstBehavior = 13; // SparksBurst
    private const float32 SearedBurstSize = 0.35f;
    private const float32 SearedBurstColorIntensity = 0.8f;
    private const float32 SearedBurstPlaybackSpeed = 1.6f;

    private FCk_Handle_Transform _Root;
    // Searing as exposed, with the steak and pan sizes and the nodes set (DoConstruct); what the feature and the visuals read.
    private FMars_Searing_Spec _SearingSpec;
    private FCk_Handle_Searing _SearingHandle;
    private FCk_Handle_SceneNode _PanNode;
    // Under the pan node, yawed so the mesh's handle (+X) points at the operator: the pan mesh, its body and the footprint
    // node live in this frame, which is therefore the frame of Get_PiecePanLocal and of the pan material's parameters.
    private FCk_Handle_SceneNode _PanMeshNode;
    private FCk_Handle_Implement _PanImplement;
    private FCk_Handle_JoltBody _PanBaseBody;
    private FCk_Handle_UnrealComponent _BurnerPart;
    private FCk_Handle_UnrealComponent _PanPart;
    // At the steak's pan-local XY on the cooking surface, unit scale: the oil FX ride it.
    private FCk_Handle_SceneNode _FootprintNode;
    private FCk_Handle_UnrealComponent _BubblesPart;
    private FCk_Handle_UnrealComponent _SplatterPart;
    // The right glove's grip: the pan handle, under the pan node so it rides the tilt and the toss.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip (Station.Node.Feed): the presentation moves it through each transfer.
    private FCk_Handle_SceneNode _FeedHandNode;
    // Under the pan mesh node, over the rim: where a carried piece is released.
    private FCk_Handle_Transform _ReleaseNode;
    // One raw cube per platter slot, and the one riding the glove (hidden unless a piece is carried).
    private TArray<FCk_Handle_UnrealComponent> _RawSlotParts;
    private FCk_Handle_UnrealComponent _CarryProxyPart;
    private FCk_Handle_CookingFeed _FeedHandle;
    private FMars_StationFeed_Presentation _FeedPresentation;
    // One per piece entity still alive, in admission order.
    private TArray<FMars_SearingStation_PieceVisual> _PieceVisuals;
    private FCk_Handle_UnrealComponent _Label;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    private FCk_Handle_Timer _DressingTick;

    // The entity script is a UObject, not a fragment, so it may hold the components. Each is null until its hosted
    // component exists.
    private UMaterialInstanceDynamic _PanMaterial;
    private UNiagaraComponent _Bubbles;
    private UNiagaraComponent _Splatter;
    private bool _BubblesActive = false;
    private bool _SplatterActive = false;
    private UNiagaraComponent _SearedBurst;

    // The dressing's own lag state, advanced every frame whether or not the components exist (the footprint node moves
    // under nullrhi too).
    // Art cm in the pan mesh's frame: (x, y, radius, 0); radius 0 while no cube rests on the pan.
    private FVector4 _Footprint = FVector4(0.0, 0.0, 0.0, 0.0);
    private FVector2D _Trail = FVector2D(0.0, 0.0);
    // The footprint node's last written offset (it is created at the origin): an idle station writes nothing.
    private FVector _WrittenFootprint = FVector::ZeroVector;
    private float32 _SizzleRamp = 0.0f;
    private float32 _Fond = FondStart;

    // The base composes the transform, the visuals and nodes (AddVisuals: the pan node and its body) and the Station
    // (Configure_Spec, grips on the registered nodes); the pan Implement and the minigame need them, so they come after.
    // The Searing signals are bound here, not at begin play, so no piece's visuals can miss its OnPieceAdded.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the pan radius from it. The steak is the cube mesh and the pan is the pan
        // mesh, so the exposed spec cannot size them.
        _SearingSpec = Searing;
        _SearingSpec.Steak.ContactGraceSeconds = SteakContactGraceSeconds;
        _SearingSpec.Steak.HalfSize = CubeHalf * CubeScale;
        _SearingSpec.Loss.PanRadius = PanRimRadius * PanScale;

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to sear on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected pan spec already ensured in utils_implement::Add. The swirl is tuned to this pan's geometry, so it is
        // set here rather than in the struct's defaults.
        auto PanSpec = Implement;
        PanSpec.Orbit = FMars_Implement_OrbitSpec(SwirlRadius, SwirlHz);
        PanSpec.Nodes = FMars_Implement_Nodes(_PanNode);
        _PanImplement = utils_implement::Add(_PanNode.H(), PanSpec);
        if (ck::Is_NOT_Valid(_PanImplement))
        { return Flow; }

        // A rejected Searing spec already ensured in utils_searing::Add.
        _SearingSpec.Nodes = FMars_Searing_Nodes(_PanImplement, _PanBaseBody);
        _SearingHandle = utils_searing::Add(InHandle, _SearingSpec);
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return Flow; }

        // The label is recomputed every dressing tick (it reads the feed too), so no signal refreshes it.
        _SearingHandle.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
        _SearingHandle.BindTo_OnPieceAdded(FMars_Delegate_Searing_OnPieceAdded(this, n"OnPieceAdded"));
        _SearingHandle.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));

        // A rejected feed spec already ensured in utils_cooking_feed::Add; the station still sears without a platter.
        auto FeedSpec = Feed;
        FeedSpec.Supply.SlotCapacity = _FeedPresentation.Geometry.SlotsLocal.Num();
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode);
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_BurnerPart))
        { utils_unreal_component::BindTo_OnAdded(_BurnerPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_PanPart))
        { utils_unreal_component::BindTo_OnAdded(_PanPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPanPartAdded")); }

        if (ck::IsValid(_BubblesPart))
        { utils_unreal_component::BindTo_OnAdded(_BubblesPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxPartAdded")); }

        if (ck::IsValid(_SplatterPart))
        { utils_unreal_component::BindTo_OnAdded(_SplatterPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxPartAdded")); }

        for (const auto& Part : _RawSlotParts)
        {
            if (ck::IsValid(Part))
            { utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnRawPartAdded")); }
        }

        if (ck::IsValid(_CarryProxyPart))
        { utils_unreal_component::BindTo_OnAdded(_CarryProxyPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnRawPartAdded")); }

        Refresh_All();
    }

    // The oil FX and the pan are hosted components: they die with their entities. Only the seared burst is spawned loose.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_SearingHandle))
        {
            _SearingHandle.UnbindFrom_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
            _SearingHandle.UnbindFrom_OnPieceAdded(FMars_Delegate_Searing_OnPieceAdded(this, n"OnPieceAdded"));
            _SearingHandle.UnbindFrom_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));
        }

        _FeedPresentation.Clear(FCk_Handle());
        // The cubes are hosted on the piece entities and die with them; only the records go.
        _PieceVisuals.Empty();

        _PanMaterial = nullptr;
        _Bubbles = nullptr;
        _Splatter = nullptr;
        _BubblesActive = false;
        _SplatterActive = false;

        if (ck::IsValid(_SearedBurst))
        { _SearedBurst.DestroyComponent(); }

        _SearedBurst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the handle node wraps the right glove around the handle, the feed node lays
        // the left glove palm down (at rest in front of the platter, and through each transfer).
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Feed, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(TableDepth * 0.5 + ViewGap), 0.0, Get_StoveTop() + ViewAboveStove)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "SearSteakPrompt", "Sear steak"),
            NSLOCTEXT("MarsInteraction", "SearingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Searing_Idle;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(TableDepth * 0.5 + ProbePadding, TableWidth * 0.5 + ProbePadding, TableHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube and cylinder are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        auto CubeMesh = engine::load::Cube();
        const auto StoveTop = Get_StoveTop();

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5), FVector(TableDepth, TableWidth, TableHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"SearingStation_Table"));

        auto Stove = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, TableHeight + StoveHeight * 0.5), FVector(StoveSize, StoveSize, StoveHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::NoCollision, n"SearingStation_Stove");
        Stove.PrimaryColor = TOptional<FLinearColor>(k_StoveColor);
        InRoot.Add_MeshPart(this, Stove);

        auto Burner = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, StoveTop + BurnerHeightScale * 50.0),
                FVector(BurnerRadiusScale, BurnerRadiusScale, BurnerHeightScale)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"SearingStation_Burner");
        Burner.PrimaryColor = TOptional<FLinearColor>(k_BurnerCold);
        _BurnerPart = InRoot.Add_MeshPart(this, Burner);

        AddPan(InRoot);
        AddOilFx();
        AddPlatter(InRoot);

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, StoveTop + LabelHeight)));
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Feed, _FeedHandNode.As_Transform()));
    }

    // The pan node is the centre of the cooking surface (the mesh's pivot), its underside resting on the burner; the
    // Implement (composed in DoConstruct) writes its offset, so its own frame stays the operator's (the tilt's axes).
    // Everything of the pan hangs off one child yawed 180 degrees, so the mesh's handle (+X) points at the operator and
    // every pan-local quantity (Get_PiecePanLocal, the footprint node's offset, the material's Meat Footprint) is in one
    // frame, the mesh's own: the pan mesh (its own two material instances), the kinematic triangle-mesh body of the same
    // mesh (the only collision under the pan: a moving baked part would re-bake every frame, and a static body never
    // imparts velocity), the footprint node and the handle's grip node (the glove rides the tilt and the toss). The pan
    // part and the footprint node are tagged so a test can read the dressing back.
    private void AddPan(FCk_Handle_Transform& InRoot)
    {
        const auto Scale = float64(PanScale);

        _PanNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, Get_BurnerTop() + PanHoverAboveBurner + PanUndersideDepth * Scale)));
        auto PanTransform = _PanNode.As_Transform();

        _PanMeshNode = utils_scene_node::Create(PanTransform, FTransform(FRotator(0.0, 180.0, 0.0), FVector::ZeroVector));
        auto PanMeshTransform = _PanMeshNode.As_Transform();

        _PanPart = PanMeshTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(Scale, Scale, Scale)),
            assets::load::FryPan_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_Pan"));
        if (ck::IsValid(_PanPart))
        { utils_entity_tag::Add(_PanPart, n"TAG_MarsSearingPan"); }

        auto PanBodySpec = FMars_Searing_PanBodySpec(assets::FryPan_Mars_SM(), PanScale);
        PanBodySpec.Friction = PanFriction;
        PanBodySpec.Restitution = PanRestitution;
        _PanBaseBody = utils_searing::Add_PanBody(_PanMeshNode, PanBodySpec);

        _FootprintNode = utils_scene_node::Create(PanMeshTransform, FTransform::Identity);
        utils_entity_tag::Add(_FootprintNode, n"TAG_MarsSearingFootprint");

        // Grip frame (X across the palm toward the index finger, Z out of the palm), in the mesh's frame: along the handle
        // toward the pan (-X, descending toward it), palm facing the operator's left (the mesh's +Y) - a handshake grip.
        const auto PitchRadians = Math::DegreesToRadians(float64(HandleGripPitchDegrees));
        const auto HandleDirection = FVector(-Math::Cos(PitchRadians), 0.0, -Math::Sin(PitchRadians));
        _HandleGripNode = utils_scene_node::Create(PanMeshTransform,
            FTransform(FRotator::MakeFromXZ(HandleDirection, FVector::RightVector), HandleGripLocal * Scale)).As_Transform();

        // Over the pan's centre, clear of the rim by a cube's half extent and ReleaseClearance: it tilts and tosses with the
        // pan, so a release lands where the pan is.
        const auto ReleaseZ = float64(PanRimHeight) * Scale + float64(CubeHalf * CubeScale) + ReleaseClearance;
        _ReleaseNode = utils_scene_node::Create(PanMeshTransform, FTransform(FVector(0.0, 0.0, ReleaseZ))).As_Transform();
    }

    // The raw platter: a slab on the table's left with one raw cube per slot (each on its RawSlot node, tagged so a test can
    // find them), the feed node the left glove follows (at rest in front of the platter; palm down, fingers forward: grip
    // frame X across the palm toward the index finger, Z out of the palm) and the cube that rides that glove, in its palm,
    // hidden until a piece is grasped. The presentation's geometry is authored here, in the station frame.
    private void AddPlatter(FCk_Handle_Transform& InRoot)
    {
        const auto CubeExtent = float64(CubeHalf * CubeScale);
        const auto PlatterTop = TableHeight + PlatterHeight;
        const auto PlatterDepth = float64(RawSlotRows) * RawSlotPitch + PlatterMargin * 2.0;
        const auto PlatterWidth = float64(RawSlotColumns) * RawSlotPitch + PlatterMargin * 2.0;

        auto Platter = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, PlatterCentreY, TableHeight + PlatterHeight * 0.5),
                FVector(PlatterDepth, PlatterWidth, PlatterHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::NoCollision, n"SearingStation_Platter");
        Platter.PrimaryColor = TOptional<FLinearColor>(k_StoveColor);
        InRoot.Add_MeshPart(this, Platter);

        const auto HandRotation = FQuat(FRotator::MakeFromXZ(FVector::RightVector, -FVector::UpVector));
        auto& Geometry = _FeedPresentation.Geometry;
        Geometry.RestLocal = FTransform(HandRotation, FVector(FeedRestLocal.X, FeedRestLocal.Y, TableHeight + PalmLift));
        // The piece sits under the palm, world-aligned: a palm's thickness and its half extent along the glove's Z.
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(), FVector(0.0, 0.0, PalmLift + CubeExtent));
        Geometry.SlotsLocal.Empty();

        const auto CubeScale3D = FVector(float64(CubeScale), float64(CubeScale), float64(CubeScale));
        for (int32 Row = 0; Row < RawSlotRows; ++Row)
        {
            for (int32 Column = 0; Column < RawSlotColumns; ++Column)
            {
                const auto X = (float64(Row) - float64(RawSlotRows - 1) * 0.5) * RawSlotPitch;
                const auto Y = PlatterCentreY + (float64(Column) - float64(RawSlotColumns - 1) * 0.5) * RawSlotPitch;
                const auto SlotLocal = FTransform(FVector(X, Y, PlatterTop + CubeExtent));
                Geometry.SlotsLocal.Add(SlotLocal);

                auto SlotNode = utils_scene_node::Create(InRoot, SlotLocal).As_Transform();
                auto Part = SlotNode.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, CubeScale3D),
                    assets::load::MeatCube_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_RawSlot"));
                if (ck::IsValid(Part))
                { utils_entity_tag::Add(Part, n"TAG_MarsSearingRawSlot"); }

                _RawSlotParts.Add(Part);
            }
        }

        _FeedHandNode = utils_scene_node::Create(InRoot, Geometry.RestLocal);
        _FeedPresentation.HandNode = _FeedHandNode;
        _FeedPresentation.WrittenHand = Geometry.RestLocal;

        auto HandTransform = _FeedHandNode.As_Transform();
        _CarryProxyPart = HandTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(Geometry.HeldLocal.GetRotation(), Geometry.HeldLocal.GetLocation(), CubeScale3D),
            assets::load::MeatCube_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_CarriedPiece"));
        if (ck::IsValid(_CarryProxyPart))
        { utils_entity_tag::Add(_CarryProxyPart, n"TAG_MarsSearingCarriedPiece"); }
    }

    // The beads and the splatter, hosted on the footprint node (unit scale: Niagara would inherit a scaled parent's scale).
    // Created inactive; the dressing tick runs them.
    private void AddOilFx()
    {
        _BubblesPart = AddFx(assets::load::OilBubbles_Mars_NS(), n"SearingStation_OilBubbles");
        _SplatterPart = AddFx(assets::load::OilSplatter_Mars_NS(), n"SearingStation_OilSplatter");
    }

    private FCk_Handle_UnrealComponent AddFx(UNiagaraSystem InSystem, FName InDebugName)
    {
        auto Archetype = NewObject(this, UNiagaraComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetAsset(InSystem);
        Archetype.SetAutoActivate(false);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(_FootprintNode, ComponentParams);
    }

    // A piece's look: the meat cube at its own scale on the piece entity (Jolt owns the entity's pose; the kernel never
    // writes it), its Custom Primitive Data written from that piece's own cook state. Tagged so a test can read it back.
    private void AddPieceVisuals(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto PieceTransform = InPiece.As_Transform();
        const auto Scale = float64(CubeScale);

        auto Visual = FMars_SearingStation_PieceVisual();
        Visual.Id = InPieceId;
        Visual.Entity = InPiece;
        Visual.Part = PieceTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(Scale, Scale, Scale)),
            assets::load::MeatCube_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_Steak"));
        _PieceVisuals.Add(Visual);

        if (ck::Is_NOT_Valid(Visual.Part))
        { return; }

        utils_entity_tag::Add(Visual.Part, n"TAG_MarsSearingSteak");
        utils_unreal_component::BindTo_OnAdded(Visual.Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPiecePartAdded"));
    }

    // The state label above the table's far edge, yawed to face the operator. Its text is set once the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(FText::FromString("cold"));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"SearingStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Searing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // The Advance_ steps update the lag state and the footprint node (under nullrhi too); the Apply_ steps write the
    // components and skip any that does not exist yet.
    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Advance_Feed(DeltaSeconds);
        Advance_Footprint(DeltaSeconds);
        Advance_Sizzle(DeltaSeconds);
        Advance_PieceVisuals(DeltaSeconds);
        Apply_PanMaterial();
        Apply_PieceCpd();
        Apply_OilFx();
        Refresh_Label();
    }

    // The feed's glove node, pose override and carried piece follow the feed; the raw cubes show what the platter still
    // holds (the reserved one until it is grasped) and the glove's cube shows while a piece is carried.
    private void Advance_Feed(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_FeedHandle))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Operator = _Root.H().As_Station().Get_Operator();
        _FeedPresentation.Advance(FMars_StationFeed_Frame(_FeedHandle, Operator, RootWorld, InDeltaSeconds));

        for (int32 Slot = 0; Slot < _RawSlotParts.Num(); ++Slot)
        { Set_PartVisible(_RawSlotParts[Slot], _FeedPresentation.Get_IsSlotVisible(_FeedHandle, Slot)); }

        Set_PartVisible(_CarryProxyPart, _FeedPresentation.CarriedPiece.IsSet());
    }

    // Skips a part that was left out or whose component does not exist yet.
    private void Set_PartVisible(const FCk_Handle_UnrealComponent& InPart, bool InVisible)
    {
        if (ck::Is_NOT_Valid(InPart))
        { return; }

        auto Component = Cast<USceneComponent>(utils_unreal_component::Get_Component(InPart));
        if (ck::Is_NOT_Valid(Component) || Component.IsVisible() == InVisible)
        { return; }

        Component.SetVisibility(InVisible);
    }

    // The aggregate footprint (see the file header): the pan-local XY (in art cm, the pan material's units) of the most
    // recently admitted piece lying on the pan, with the cube's radius; no such piece = radius 0 (no pool hugs a flying or
    // absent cube) and the footprint stays where it was. The trail lags it by TrailLagSeconds.
    private void Advance_Footprint(float32 InDeltaSeconds)
    {
        const auto Scale = float64(PanScale);
        auto Local = FVector(_Footprint.X * Scale, _Footprint.Y * Scale, 0.0);
        auto HasPool = false;
        const auto PieceId = TryGet_FootprintPiece();
        if (PieceId.IsSet())
        {
            Local = _SearingHandle.Get_PiecePanLocal(PieceId.GetValue());
            HasPool = true;
        }

        _Footprint = FVector4(Local.X / Scale, Local.Y / Scale, HasPool ? float64(Get_CubeFootprint()) : 0.0, 0.0);

        const auto Alpha = 1.0 - Math::Exp(-float64(InDeltaSeconds) / float64(TrailLagSeconds));
        _Trail = FVector2D(_Trail.X + (_Footprint.X - _Trail.X) * Alpha, _Trail.Y + (_Footprint.Y - _Trail.Y) * Alpha);

        const auto FootprintLocation = FVector(Local.X, Local.Y, 0.0);
        if (FootprintLocation.Distance(_WrittenFootprint) <= k_FootprintWriteTolerance)
        { return; }

        utils_scene_node::Request_UpdateOffset(_FootprintNode,
            FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, FootprintLocation)));
        _WrittenFootprint = FootprintLocation;
    }

    // The newest piece (admission order) that is not lost and lies on the pan; unset when none does.
    private TOptional<FMars_CookingFeed_PieceId> TryGet_FootprintPiece() const
    {
        const auto Ids = _SearingHandle.Get_PieceIds();
        for (int32 Index = Ids.Num() - 1; Index >= 0; --Index)
        {
            if (Get_IsLiveOnPan(Ids[Index]))
            { return TOptional<FMars_CookingFeed_PieceId>(Ids[Index]); }
        }

        return TOptional<FMars_CookingFeed_PieceId>();
    }

    private bool Get_IsLiveOnPan(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return _SearingHandle.Get_PieceStatus(InPieceId) != EMars_Searing_PieceStatus::Lost
            && _SearingHandle.Get_PieceContact(InPieceId) == EMars_Searing_Contact::OnPan;
    }

    // Full while the kernel's aggregate sizzle is on, a hiss while only seared faces lie on the hot pan, silent otherwise;
    // the fond builds while it sizzles.
    private void Advance_Sizzle(float32 InDeltaSeconds)
    {
        const auto IsSizzling = _SearingHandle.Get_Sizzle() == EMars_Searing_Sizzle::Sizzling;
        auto Target = 0.0f;
        if (IsSizzling)
        { Target = SizzleFull; }
        else if (_SearingHandle.Get_IsHot() && Get_IsAnySearedFaceOnPan())
        { Target = SizzleSearedFace; }

        const auto Rate = Target > _SizzleRamp ? SizzleRiseRate : SizzleFallRate;
        _SizzleRamp = MoveToward(_SizzleRamp, Target, Rate * InDeltaSeconds);

        if (IsSizzling)
        { _Fond = Math::Min(1.0f, _Fond + FondRate * InDeltaSeconds); }
    }

    private bool Get_IsAnySearedFaceOnPan() const
    {
        const auto Ids = _SearingHandle.Get_PieceIds();
        for (const auto& PieceId : Ids)
        {
            if (Get_IsLiveOnPan(PieceId) && _SearingHandle.Get_IsDownFaceSeared(PieceId))
            { return true; }
        }

        return false;
    }

    // Each piece's cook state from its own sears. A record whose piece the kernel no longer holds (destroyed at the end of
    // its linger, or reset) or whose entity is gone is dropped (its cube dies with the entity); a lost piece keeps its last
    // cook state.
    private void Advance_PieceVisuals(float32 InDeltaSeconds)
    {
        const auto IsHot = _SearingHandle.Get_IsHot();
        for (int32 Index = _PieceVisuals.Num() - 1; Index >= 0; --Index)
        {
            auto Visual = _PieceVisuals[Index];
            if (ck::Is_NOT_Valid(Visual.Entity) || _SearingHandle.Get_HasPiece(Visual.Id) == false)
            {
                _PieceVisuals.RemoveAt(Index);
                continue;
            }

            if (_SearingHandle.Get_PieceStatus(Visual.Id) == EMars_Searing_PieceStatus::Lost)
            { continue; }

            auto SearSum = 0.0f;
            for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
            {
                const auto Sear = _SearingHandle.Get_FaceSear(Visual.Id, EMars_Searing_Face(Face));
                Visual.CookState.FaceSear[Face] = Sear;
                SearSum += Sear;
            }

            Visual.CookState.Penetration = Math::Min(1.0f, SearSum);
            Visual.CookState.Shape = SearSum / float32(utils_searing::k_FaceCount);

            const auto OnHotPan = IsHot && _SearingHandle.Get_PieceContact(Visual.Id) == EMars_Searing_Contact::OnPan;
            Visual.CookState.OilCoat = MoveToward(Visual.CookState.OilCoat, OnHotPan ? OilCoatOnPan : OilCoatOffPan,
                OilCoatRate * InDeltaSeconds);
            _PieceVisuals[Index] = Visual;
        }
    }

    // The driven group on the pan's dynamic instance, in the pan mesh's own cm.
    private void Apply_PanMaterial()
    {
        if (Resolve_PanMaterial() == false)
        { return; }

        _PanMaterial.SetScalarParameterValue(n"Oil Amount", _SearingHandle.Get_IsHot() ? OilAmountHot : OilAmountCold);
        _PanMaterial.SetScalarParameterValue(n"Sizzle", _SizzleRamp);
        _PanMaterial.SetScalarParameterValue(n"Fond", _Fond);
        _PanMaterial.SetVectorParameterValue(n"Meat Footprint",
            FLinearColor(float32(_Footprint.X), float32(_Footprint.Y), float32(_Footprint.Z), 0.0f));
        _PanMaterial.SetVectorParameterValue(n"Oil Trail", FLinearColor(float32(_Trail.X), float32(_Trail.Y), 0.0f, 0.0f));
    }

    // Every piece's cube with its own cook state, once its component exists.
    private void Apply_PieceCpd()
    {
        for (const auto& Visual : _PieceVisuals)
        { Write_PieceCpd(Visual); }
    }

    private void Write_PieceCpd(const FMars_SearingStation_PieceVisual& InVisual)
    {
        if (ck::Is_NOT_Valid(InVisual.Part))
        { return; }

        auto Cube = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InVisual.Part));
        if (ck::Is_NOT_Valid(Cube))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Cube, InVisual.CookState);
    }

    // The beads run while the sizzle ramp is up, at a rate that follows it; the splatter only while the kernel sizzles.
    private void Apply_OilFx()
    {
        Resolve_OilFx();

        if (ck::IsValid(_Bubbles))
        {
            _Bubbles.SetVariableFloat(n"SpawnRate", BubbleRate * _SizzleRamp);
            _BubblesActive = Set_FxActive(_Bubbles, _BubblesActive, _SizzleRamp > FxActiveThreshold);
        }

        if (ck::IsValid(_Splatter))
        {
            const auto IsSizzling = _SearingHandle.Get_Sizzle() == EMars_Searing_Sizzle::Sizzling;
            _SplatterActive = Set_FxActive(_Splatter, _SplatterActive, IsSizzling);
        }
    }

    // Activate(true) restarts the system, so it runs only on an off -> on edge. Returns the new state.
    private bool Set_FxActive(UNiagaraComponent InFx, bool InWasActive, bool InActive)
    {
        if (InActive == InWasActive)
        { return InWasActive; }

        if (InActive)
        { InFx.Activate(true); }
        else
        { InFx.Deactivate(); }

        return InActive;
    }

    // InValue moved toward InTarget by at most InMaxStep.
    private float32 MoveToward(float32 InValue, float32 InTarget, float32 InMaxStep) const
    {
        if (InValue < InTarget)
        { return Math::Min(InTarget, InValue + InMaxStep); }

        return Math::Max(InTarget, InValue - InMaxStep);
    }

    // The pan part's slot-0 dynamic instance, created (and given the cooking look) the first time the component exists.
    private bool Resolve_PanMaterial()
    {
        if (ck::IsValid(_PanMaterial))
        { return true; }

        if (ck::Is_NOT_Valid(_PanPart))
        { return false; }

        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_PanPart));
        if (ck::Is_NOT_Valid(Mesh))
        { return false; }

        _PanMaterial = Mesh.CreateDynamicMaterialInstance(0);
        if (ck::Is_NOT_Valid(_PanMaterial))
        { return false; }

        Apply_PanLook();
        return true;
    }

    private void Apply_PanLook()
    {
        _PanMaterial.SetScalarParameterValue(n"Seasoning", LookSeasoning);
        _PanMaterial.SetScalarParameterValue(n"Carbon Specks", LookCarbonSpecks);
        _PanMaterial.SetScalarParameterValue(n"Oil Opacity", LookOilOpacity);
        _PanMaterial.SetScalarParameterValue(n"Pool Wobble", LookPoolWobble);
        _PanMaterial.SetScalarParameterValue(n"Pool Edge Softness", LookPoolEdgeSoftness);
        _PanMaterial.SetScalarParameterValue(n"Simmer Cell", LookSimmerCell);
        _PanMaterial.SetScalarParameterValue(n"Simmer Density", LookSimmerDensity);
        _PanMaterial.SetScalarParameterValue(n"Simmer Rim Darken", LookSimmerRimDarken);

        const auto Half = Get_CubeHalfInPanCm();
        _PanMaterial.SetScalarParameterValue(n"Pool Radius", PoolRadiusPerHalf * Half);
        _PanMaterial.SetScalarParameterValue(n"Pool Margin", PoolMarginPerHalf * Half);
        _PanMaterial.SetScalarParameterValue(n"Pool Blend", PoolBlendPerHalf * Half);
        _PanMaterial.SetScalarParameterValue(n"Simmer Width", SimmerWidthPerHalf * Half);
        _PanMaterial.SetScalarParameterValue(n"Contact Softness", ContactSoftnessPerHalf * Half);
    }

    // The cube's half extent in the pan mesh's cm (the pan material's units): the pool is sized from it.
    private float32 Get_CubeHalfInPanCm() const
    {
        return CubeHalf * CubeScale / PanScale;
    }

    // The footprint radius in the pan mesh's cm.
    private float32 Get_CubeFootprint() const
    {
        return Get_CubeHalfInPanCm() * FootprintPerHalf;
    }

    // Each FX component gets its static parameters and is stopped the first time it exists (from its OnAdded or, if that
    // fired before the bind, from the tick).
    private void Resolve_OilFx()
    {
        if (ck::Is_NOT_Valid(_Bubbles) && ck::IsValid(_BubblesPart))
        {
            _Bubbles = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(_BubblesPart));
            if (ck::IsValid(_Bubbles))
            {
                Apply_BubbleParameters(_Bubbles);
                _Bubbles.Deactivate();
                _BubblesActive = false;
            }
        }

        if (ck::Is_NOT_Valid(_Splatter) && ck::IsValid(_SplatterPart))
        {
            _Splatter = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(_SplatterPart));
            if (ck::IsValid(_Splatter))
            {
                Apply_SplatterParameters(_Splatter);
                _Splatter.Deactivate();
                _SplatterActive = false;
            }
        }
    }

    // One box over the whole pool around the cube (the cube hides what spawns under it); the oil surface is the
    // footprint node's Z 0 plus OilLevel.
    private void Apply_BubbleParameters(UNiagaraComponent InBubbles)
    {
        const auto Extent = float64(2.0f * BubbleOuterPerHalf * Get_CubeHalfInPanCm() * PanScale);
        InBubbles.SetVariableVec2(n"SpawnExtent", FVector2D(Extent, Extent));
        InBubbles.SetVariableFloat(n"SpawnRate", 0.0f);
        InBubbles.SetVariableFloat(n"SurfaceZ", OilLevel * PanScale);
        InBubbles.SetVariableFloat(n"StartDepth", BubbleStartDepth * PanScale);
        InBubbles.SetVariableFloat(n"BubbleRadiusMin", BubbleRadiusMin * PanScale);
        InBubbles.SetVariableFloat(n"BubbleRadiusMax", BubbleRadiusMax * PanScale);
        InBubbles.SetVariableFloat(n"LifetimeMin", BubbleLifetimeMin);
        InBubbles.SetVariableFloat(n"LifetimeMax", BubbleLifetimeMax);
        InBubbles.SetVariableFloat(n"WobbleAmplitude", BubbleWobble * PanScale);
        InBubbles.SetVariableFloat(n"RiseFraction", BubbleRise);
        InBubbles.SetVariableLinearColor(n"LiquidColour", OilColour);
    }

    // Flung from the cube's footprint edge on the oil surface.
    private void Apply_SplatterParameters(UNiagaraComponent InSplatter)
    {
        InSplatter.SetVariableFloat(n"SplatterRate", SplatterRate);
        InSplatter.SetVariableFloat(n"BurstsPerSecond", SplatterBursts);
        InSplatter.SetVariableFloat(n"SplatterRadius", Get_CubeFootprint() * PanScale);
        InSplatter.SetVariableFloat(n"SurfaceZ", OilLevel * PanScale);
        InSplatter.SetVariableFloat(n"FlingMin", SplatterFlingMin * PanScale);
        InSplatter.SetVariableFloat(n"FlingMax", SplatterFlingMax * PanScale);
        InSplatter.SetVariableFloat(n"SplatterSizeMin", SplatterSizeMin * PanScale);
        InSplatter.SetVariableFloat(n"SplatterSizeMax", SplatterSizeMax * PanScale);
        InSplatter.SetVariableFloat(n"SplatterLife", SplatterLife);
        InSplatter.SetVariableFloat(n"SplatterArc", SplatterArc);
        InSplatter.SetVariableLinearColor(n"SplatterColour", SplatterColour);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station visuals
    //----------------------------------------------------------------------------------------------------------------------

    private float64 Get_StoveTop() const
    {
        return TableHeight + StoveHeight;
    }

    private float64 Get_BurnerTop() const
    {
        return Get_StoveTop() + BurnerHeightScale * 100.0;
    }

    private void Refresh_All()
    {
        Refresh_Burner();
        Refresh_Label();
    }

    private void Refresh_Burner()
    {
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return; }

        _BurnerPart.Paint_MeshPart(_SearingHandle.Get_IsHot() ? k_BurnerHot : k_BurnerCold);
    }

    // Rewritten only when the text changes.
    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_SearingHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        const auto Label = Get_StateLabel();
        const auto LabelText = Label.ToString();
        if (LabelText == _LabelText)
        { return; }

        _LabelText = LabelText;
        Text.SetText(Label);
    }

    // What the label reads: "cold" off the burner; once the platter is spent, no transfer is under way and nothing still
    // cooks, the batch is all accounted for; otherwise the batch so far and what is left raw.
    private FText Get_StateLabel() const
    {
        if (_SearingHandle.Get_IsHot() == false)
        { return FText::FromString("cold"); }

        const auto Summary = _SearingHandle.Get_Summary();
        const auto HasFeed = ck::IsValid(_FeedHandle);
        const auto Raw = HasFeed ? _FeedHandle.Get_Available() : 0;
        const auto IsFeeding = HasFeed && _FeedHandle.Get_IsBusy();

        if (Raw == 0 && IsFeeding == false && Summary.Cooking == 0)
        { return FText::FromString(f"all accounted for: {Summary.Ready} ready, {Summary.Lost} lost"); }

        return FText::FromString(f"{Summary.Ready}/{Summary.Admitted} ready · {Summary.Lost} lost · {Raw} raw");
    }

    // One reused burst component: spawned at the first seared face whose template is ready, then moved to the piece whose
    // face seared and re-activated. Null under nullrhi.
    private void Play_SearedBurst(const FMars_CookingFeed_PieceId& InPieceId)
    {
        if (ck::Is_NOT_Valid(_SearingHandle) || _SearingHandle.Get_HasPiece(InPieceId) == false)
        { return; }

        const auto Piece = _SearingHandle.Get_PieceEntity(InPieceId);
        if (ck::Is_NOT_Valid(Piece))
        { return; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(Piece.As_Transform());

        if (ck::IsValid(_SearedBurst))
        {
            _SearedBurst.SetWorldLocation(Location);
            _SearedBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_SearedBurstBehavior) == false)
        { return; }

        _SearedBurst = utils_particles::Spawn_BehaviorAtLocation(k_SearedBurstBehavior, Location, FRotator::ZeroRotator);
        if (ck::IsValid(_SearedBurst))
        { utils_particles::Request_ApplyTuningValues(_SearedBurst, SearedBurstSize, SearedBurstColorIntensity, 1.0f, SearedBurstPlaybackSpeed); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_All();
    }

    UFUNCTION()
    private void OnPanPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Resolve_PanMaterial();
    }

    UFUNCTION()
    private void OnFxPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Resolve_OilFx();
    }

    // A raw cube (on the platter or in the glove) wears the raw cook state; the dressing tick sets its visibility.
    UFUNCTION()
    private void OnRawPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Cube = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Cube))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Cube, FMars_CookState());
        if (InHandle == _CarryProxyPart)
        { Cube.SetVisibility(false); }
    }

    // Writes that piece's cook state once (raw at admission), so a cube never shows a default for a frame.
    UFUNCTION()
    private void OnPiecePartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        for (const auto& Visual : _PieceVisuals)
        {
            if (Visual.Part == InHandle)
            {
                Write_PieceCpd(Visual);
                return;
            }
        }
    }

    UFUNCTION()
    private void OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        if (InHeat == EMars_Searing_Heat::Hot)
        { _Fond = FondStart; }

        Refresh_Burner();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        AddPieceVisuals(InPieceId, InPiece);
    }

    UFUNCTION()
    private void OnFaceSeared(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace)
    {
        Play_SearedBurst(InPieceId);
    }
}
