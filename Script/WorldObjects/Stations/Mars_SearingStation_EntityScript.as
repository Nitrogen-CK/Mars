// The searing station: a table (width along local Y, depth along local X) with a stove slab and a burner on top, and on
// the burner the modelled frying pan, which swirls while operated and which the operator's look tilts and, flicked up,
// tosses. The pan node carries an Implement (the tilt, the lift and the swirl); under it, on a node yawed so the handle
// points at the operator, sit the pan mesh (a NoCollision visual) and its kinematic triangle-mesh body, the one collision
// of the pan. The Searing feature lives on the station entity and its own state machine (UMars_SmState_Searing_Idle)
// reads the operator. Two platter docks sit on the table: the raw platter (left, -Y) the feed draws from and the finished
// tray (right, +Y) the take-out fills. The pan starts empty: a CookingFeed on the same entity draws the pieces of the docked
// raw platter, and its station-feed tasks turn the operator's add-food press into a left-hand transfer that this script
// presents (the glove node and the cube in the glove; the hand reaches for the reserved piece where it lies) and whose
// release the Searing kernel admits (the piece itself, wearing its own display, on a dynamic body). This script builds the
// nodes and the docks and, every frame, dresses the pan, the oil and every piece's record from the Searing state. While
// operating, the right glove holds the pan handle (riding the tilt and the toss) and the left follows the feed node,
// resting in front of the raw platter between transfers.
//
// Per piece: its own cook state (from that piece's face sears only, never another's), its own seared burst and its own oil
// pool, sized from its own extents. The pan material has k_PoolSlots meat footprints and oil trails; the pieces
// that lie on the pan (Cooking or Ready) fill them in admission order and an unused slot has radius 0 (no pool). Each
// piece's trail lags its own footprint, and a piece that leaves the pan keeps its last footprint while its slot goes dark.
// The beads' box covers every piece on the pan; the footprint node, and the splatter on it, follows the most recently
// admitted piece that lies on the pan and stays where it was with none there. The sizzle ramp follows the kernel's
// aggregate sizzle (full while any cooking piece sizzles; a hiss while only seared faces lie on the hot pan). Face values
// are never averaged across pieces. The sizzle loop plays from the pan while the ramp is up, at the ramp's volume.

// Whether a piece's visual holds one of the pan material's oil pools.
enum EMars_SearingStation_Pool
{
    None,
    Pooled
}

// The station's record of one admitted piece. The piece wears its own display; the station adds no part to it.
struct FMars_SearingStation_PieceVisual
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // This piece's look; a lost piece keeps its last one.
    UPROPERTY()
    FMars_CookState CookState;

    // The look last sent to the piece's display.
    UPROPERTY()
    FMars_CookState Written;

    // Art cm in the pan mesh's frame (the pan material's units): where the piece last lay on the pan, and its oil trail
    // lagging that. A piece off the pan keeps both.
    UPROPERTY()
    FVector2D Footprint;

    UPROPERTY()
    FVector2D Trail;

    // Pooled while it lies on the pan and is not lost: only then does it fill a pool slot and widen the beads' box.
    UPROPERTY()
    EMars_SearingStation_Pool Pool = EMars_SearingStation_Pool::None;
}

class UMars_SearingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Searing_Spec Searing;

    // The pan's tilt and lift; its Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Implement_Spec Implement;

    // The transfer's timing and release motion; its release node is set here. The stock is the feed's source platter.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    // The raw platter brings meat, no more pieces than the pan takes (an unset MaxPieces is the Searing spec's
    // Supply.MaxPieces); the finished tray docks empty.
    UPROPERTY(EditDefaultsOnly, Category = "Docks")
    FMars_Station_DockPolicies Docks;
    default Docks.Input.Kind = FGameplayTagQuery::MakeQuery_MatchTag(GameplayTags::Food_Meat);
    default Docks.Output.RequireEmpty = TOptional<bool>(true);

    private const float64 TableWidth = 140.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the table edge.
    private const float64 StandGap = 43.0;
    // The operating view: the eye sits ViewDistance uu from the pan's rest pivot along the CameraPitch line, so the pan
    // centre is the centre of the screen by construction (the reference: the pan fills the middle of the frame, seen
    // steeply from above, the handle and the glove at the bottom). It lives in the station frame (Camera.ViewLocal), so
    // the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -58.0f;
    private const float64 ViewDistance = 99.0;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    // The hearth (Hearth_Mars_SM + EmberBed_Mars_SM, pivot at the centre of the underside, on the table top at StoveX): a
    // 56 cm chiselled slab HearthSlabHeight tall, an iron fire bowl, and a trivet whose ring (radius HearthTrivetRingRadius,
    // top at HearthTrivetTop above the table: the mesh's SOCKET_Pan) carries the pan. SOCKET_Flame is HearthFlameHeight up,
    // inside the bowl above the coals with a clear 30 cm column to the pan: a flame Niagara system attaches there. The
    // bellows (dressing) sits with its nozzle tip at the hearth's SOCKET_Bellows, pointing into the bowl.
    private const float64 StoveX = 0.0;
    private const float64 HearthSlabHeight = 6.0;
    private const float64 HearthTrivetTop = 20.0;
    private const float64 HearthTrivetRingRadius = 22.0;
    private const float64 HearthFlameHeight = 8.0;
    private const FVector BellowsLocal = FVector(0.0, 34.0, 6.0);
    // The pan rests on the trivet ring; a tilt pivots on the ring (the pan Implement's Tilt.RestRadius), so no hover is
    // needed to keep a tilted pan out of the iron. A held lift while operated decides any further rise.
    private const float64 PanHoverAboveBurner = 0.0;

    // The pan and the oil pool as cooking_spec.py authors them (FOOD_LIBRARY.md), in the meshes' own centimetres; the pan
    // and every oil length are multiplied by PanScale on this station (see the design for why not 1).
    private const float32 PanScale = 2.5f;
    private const float32 PanRimRadius = 14.5f;
    private const float32 PanRimHeight = 4.6f;
    private const float32 PanUndersideDepth = 0.3f;
    // The meat cube riding the glove through a transfer (MeatCube_Mars_SM, a 2 cm half cube in the art) at its own scale:
    // the hand mimes the transfer with it, and the release node clears the rim by its half extent.
    private const float32 CarriedCubeHalf = 2.0f;
    private const float32 CarriedCubeScale = 3.0f;
    // The pool as ratios of a piece's half extent h in pan cm (mars_cooking_ue.py LOOKDEV_POOL_NOTE): the footprint radius
    // is h * sqrt(2) * 0.9; Pool Radius, Pool Margin, Pool Blend, Simmer Width and Contact Softness are 1.1 / 0.6 / 0.5 /
    // 0.4 / 0.4 h. A piece's h is the mean of its two horizontal half extents as it was admitted (a cube's own half).
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
    // The pan material's Meat Footprint / Oil Trail pairs (slot 0 unsuffixed, then 1..5): one pool per piece the Searing
    // spec's Supply.MaxPieces lets onto the pan (6 by default); DoConstruct ensures it allows no more.
    private const int32 k_PoolSlots = 6;
    private const float32 OilCoatOnPan = 0.7f;
    private const float32 OilCoatOffPan = 0.3f;
    // Per second toward the target.
    private const float32 OilCoatRate = 1.0f;

    // The oil beads (OilBubbles_Mars_NS): one box over every pool, lengths in art cm (times PanScale).
    private const float32 BubbleRate = 25.0f;
    // The box half extent around one piece per half extent h (the art's 3.5 cm around its 2 cm half cube); the spread of
    // the pieces on the pan widens it.
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
    // The beads run, and the sizzle loop plays, while the sizzle ramp is above this.
    private const float32 FxActiveThreshold = 0.05f;
    // The sizzle loop (FryingPanSizzle_Looping_Cue, which carries its own close-range attenuation and sound class) plays at
    // the ramp times SizzleSoundVolume; its volume is rewritten only past SizzleSoundVolumeTolerance. The ramp's rise and
    // fall are its fades.
    private const float32 SizzleSoundVolume = 1.0f;
    private const float32 SizzleSoundVolumeTolerance = 0.01f;
    // uu the steak must move before the footprint node (or the beads' node or box) is written again.
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

    // The docks on the table top (Z is the table's): the raw platter on the left (-Y), the free glove's rest in front of it;
    // the finished tray on the right (+Y), nearer the operator than the bellows (which runs from Y 34 to the table's edge
    // along X 0) and clear of the pan's rim.
    private const FVector InputDockLocal = FVector(0.0, -54.0, 0.0);
    private const FVector OutputDockLocal = FVector(-25.0, 54.0, 0.0);
    private const FVector FeedRestLocal = FVector(-30.0, -56.0, 0.0);
    // The release node over the pan: this far above the rim plus the carried cube's half extent, so a release clears the rim.
    private const float64 ReleaseClearance = 4.0;

    // The state label above the table's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 44.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    // The ember bed's emissive Strength (Ember_Mars_MI on Emissive_Mars_M): glowing coals when hot, a dull bed when cold.
    private const float32 EmberStrengthHot = 8.0f;
    private const float32 EmberStrengthCold = 0.4f;

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
    private FCk_Handle_UnrealComponent _EmberPart;
    private UMaterialInstanceDynamic _EmberMaterial;
    private FCk_Handle_UnrealComponent _PanPart;
    // At the newest piece's pan-local XY on the cooking surface, unit scale: the splatter rides it.
    private FCk_Handle_SceneNode _FootprintNode;
    // At the middle of every piece on the pan, on the cooking surface, unit scale: the beads ride it.
    private FCk_Handle_SceneNode _BubblesNode;
    private FCk_Handle_UnrealComponent _BubblesPart;
    private FCk_Handle_UnrealComponent _SplatterPart;
    // The right glove's grip: the pan handle, under the pan node so it rides the tilt and the toss.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip (Station.Node.Feed): the presentation moves it through each transfer.
    private FCk_Handle_SceneNode _FeedHandNode;
    // Under the pan mesh node, over the rim: where a carried piece is released.
    private FCk_Handle_Transform _ReleaseNode;
    // The cube riding the glove (hidden unless a piece is carried): the hand mimes the transfer, the piece itself
    // teleports at its admission.
    private FCk_Handle_UnrealComponent _CarryProxyPart;
    private FCk_Handle_CookingFeed _FeedHandle;
    private FMars_StationFeed_Presentation _FeedPresentation;
    private FCk_Handle_PlatterDock _InputDock;
    // The label reads it: without a tray, a take-out has nowhere to go.
    private FCk_Handle_PlatterDock _OutputDock;
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

    // The pan material's pool slot names, slot 0 first (DoConstruct builds them once).
    private TArray<FName> _FootprintParameterNames;
    private TArray<FName> _TrailParameterNames;

    // The dressing's own lag state, advanced every frame whether or not the components exist (the nodes move under nullrhi
    // too); each piece's footprint and trail live on its visual.
    // The footprint node's and the beads' node's last written offsets (both are created at the origin): an idle station
    // writes nothing.
    private FVector _WrittenFootprint = FVector::ZeroVector;
    private FVector _WrittenBubblesCentre = FVector::ZeroVector;
    // uu: how far apart the pieces on the pan lie (their footprints' bounding box), and the bead box size last written.
    private FVector2D _BubbleSpread = FVector2D(0.0, 0.0);
    private FVector2D _WrittenBubbleExtent = FVector2D(0.0, 0.0);
    // Pan cm: the half extent h the shared pool look (the material's pool scalars, the beads' box, the splatter's ring) is
    // sized for: the largest piece that lies on the pan; it keeps its last value while none does (0 before the first).
    private float32 _PoolHalf = 0.0f;
    // The _PoolHalf the pan material's pool scalars and the splatter's ring were last written for; unset until written.
    private TOptional<float32> _MaterialPoolHalf;
    private TOptional<float32> _SplatterPoolHalf;
    private float32 _SizzleRamp = 0.0f;
    private float32 _Fond = FondStart;

    // The sizzle loop: local only, spawned on the pan mesh's component the first time the pan sizzles (so it rides the tilt
    // and the toss), then played and stopped with the ramp. Unset until the playing loop's volume is first written.
    private USoundBase _SizzleSound;
    private UAudioComponent _SizzleAudio;
    private TOptional<float32> _WrittenSizzleVolume;

    // The base composes the transform, the visuals and nodes (AddVisuals: the pan node and its body) and the Station
    // (Configure_Spec, grips on the registered nodes); the pan Implement and the minigame need them, so they come after.
    // The Searing signals are bound here, not at begin play, so no piece's visuals can miss its OnPieceAdded.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the pan radius from it. The pan is the pan mesh, so the exposed spec cannot
        // size it.
        _SearingSpec = Searing;
        _SearingSpec.Piece.ContactGraceSeconds = SteakContactGraceSeconds;
        _SearingSpec.Loss.PanRadius = PanRimRadius * PanScale;
        // A piece past the material's last pool slot would sear without any oil around it.
        ck::EnsureIfNot(_SearingSpec.Supply.MaxPieces <= k_PoolSlots,
            f"[SearingStation] lets {_SearingSpec.Supply.MaxPieces} pieces onto the pan but its material has only {k_PoolSlots} pools");
        Build_PoolParameterNames();

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to sear on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected pan spec already ensured in utils_implement::Add. The swirl is tuned to this pan's geometry, so it is
        // set here rather than in the struct's defaults.
        auto PanSpec = Implement;
        PanSpec.Orbit = FMars_Implement_OrbitSpec(SwirlRadius, SwirlHz);
        // The pan rests on the trivet ring: a tilt pivots on it (the node rises by ring radius x sin tilt), so the low side of
        // the base rolls along the iron instead of cutting through the hearth.
        PanSpec.Tilt.RestRadius = float32(HearthTrivetRingRadius);
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
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode);
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);
        Add_Docks();

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_EmberPart))
        { utils_unreal_component::BindTo_OnAdded(_EmberPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_PanPart))
        { utils_unreal_component::BindTo_OnAdded(_PanPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPanPartAdded")); }

        if (ck::IsValid(_BubblesPart))
        { utils_unreal_component::BindTo_OnAdded(_BubblesPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxPartAdded")); }

        if (ck::IsValid(_SplatterPart))
        { utils_unreal_component::BindTo_OnAdded(_SplatterPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxPartAdded")); }

        if (ck::IsValid(_CarryProxyPart))
        { utils_unreal_component::BindTo_OnAdded(_CarryProxyPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnCarryProxyAdded")); }

        Refresh_All();
    }

    // The oil FX and the pan are hosted components: they die with their entities. Only the seared burst and the sizzle loop
    // are spawned loose.
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
        // The pieces wear their own displays; only the records go.
        _PieceVisuals.Empty();

        _PanMaterial = nullptr;
        _Bubbles = nullptr;
        _Splatter = nullptr;
        _BubblesActive = false;
        _SplatterActive = false;

        if (ck::IsValid(_SearedBurst))
        { _SearedBurst.DestroyComponent(); }

        _SearedBurst = nullptr;

        if (ck::IsValid(_SizzleAudio))
        {
            _SizzleAudio.Stop();
            _SizzleAudio.DestroyComponent();
        }

        _SizzleAudio = nullptr;
        _WrittenSizzleVolume.Reset();
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
        // Back along the pitched view line from the pan's rest pivot, so the pan is dead centre on screen.
        const auto PitchRadians = Math::DegreesToRadians(float64(-CameraPitch));
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(StoveX - ViewDistance * Math::Cos(PitchRadians), 0.0, Get_PanRestZ() + ViewDistance * Math::Sin(PitchRadians))));
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
        const auto StoveTop = Get_StoveTop();
        const auto HearthLocal = FVector(StoveX, 0.0, TableHeight);

        // The station props (station_spec.py): the prep table (pivot at its floor contact), the hearth and its ember bed
        // (both pivot at the hearth's underside centre, on the table top), the bellows (pivot at its nozzle tip).
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            assets::load::PrepTable_Mars_SM(), nullptr, collision::profile::BlockAll, n"SearingStation_Table"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, HearthLocal),
            assets::load::Hearth_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_Hearth"));

        _EmberPart = InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, HearthLocal),
            assets::load::EmberBed_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_Embers"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, HearthLocal + BellowsLocal),
            assets::load::Bellows_Mars_SM(), nullptr, collision::profile::NoCollision, n"SearingStation_Bellows"));

        // The flame socket: a flame Niagara system goes on this node (+Z up, clear air to the pan through the trivet bars).
        auto FlameNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, HearthLocal + FVector(0.0, 0.0, HearthFlameHeight)));
        utils_entity_tag::Add(FlameNode, n"TAG_MarsSearingFlame");

        AddPan(InRoot);
        AddOilFx();
        _SizzleSound = assets::load::FryingPanSizzle_Looping_Cue();
        AddFeedHand(InRoot);

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

        _PanNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, Get_PanRestZ())));
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
        _BubblesNode = utils_scene_node::Create(PanMeshTransform, FTransform::Identity);

        // A right-hand handshake grip on the handle, which descends toward the pan (-X) in the mesh's frame: palm facing the
        // operator's left (the mesh's +Y), fingers curling down round the handle square to it, the hand leading to the pan.
        const auto PitchRadians = Math::DegreesToRadians(float64(HandleGripPitchDegrees));
        const auto HandleDirection = FVector(-Math::Cos(PitchRadians), 0.0, -Math::Sin(PitchRadians));
        const auto HandleFingers = HandleDirection.CrossProduct(FVector::RightVector);
        _HandleGripNode = utils_scene_node::Create(PanMeshTransform,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, HandleFingers, FVector::RightVector),
                HandleGripLocal * Scale)).As_Transform();

        // Over the pan's centre, clear of the rim by the carried cube's half extent and ReleaseClearance: it tilts and tosses
        // with the pan, so a release lands where the pan is.
        const auto ReleaseZ = float64(PanRimHeight) * Scale + float64(CarriedCubeHalf * CarriedCubeScale) + ReleaseClearance;
        _ReleaseNode = utils_scene_node::Create(PanMeshTransform, FTransform(FVector(0.0, 0.0, ReleaseZ))).As_Transform();
    }

    // The feed node the left glove follows (at rest in front of the raw platter's dock, palm down, fingers forward) and the
    // cube that rides that glove, in its palm, hidden until a piece is grasped. The docked raw platter is the stock's only
    // visual. The presentation's geometry is authored here, in the station frame.
    private void AddFeedHand(FCk_Handle_Transform& InRoot)
    {
        const auto CubeExtent = float64(CarriedCubeHalf * CarriedCubeScale);
        const auto HandRotation = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        auto& Geometry = _FeedPresentation.Geometry;
        Geometry.RestLocal = FTransform(HandRotation, FVector(FeedRestLocal.X, FeedRestLocal.Y, TableHeight + PalmLift));
        // The piece sits under the palm, world-aligned: a palm's thickness and its half extent out of the palm.
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(), FVector(0.0, 0.0, PalmLift + CubeExtent));

        const auto CubeScale3D = FVector(float64(CarriedCubeScale), float64(CarriedCubeScale), float64(CarriedCubeScale));
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

    // The beads on their own node (over every piece) and the splatter on the footprint node (the newest piece), both unit
    // scale: Niagara would inherit a scaled parent's scale. Created inactive; the dressing tick runs them.
    private void AddOilFx()
    {
        _BubblesPart = AddFx(_BubblesNode, assets::load::OilBubbles_Mars_NS(), n"SearingStation_OilBubbles");
        _SplatterPart = AddFx(_FootprintNode, assets::load::OilSplatter_Mars_NS(), n"SearingStation_OilSplatter");
    }

    private FCk_Handle_UnrealComponent AddFx(FCk_Handle_SceneNode& InNode, UNiagaraSystem InSystem, FName InDebugName)
    {
        auto Archetype = NewObject(this, UNiagaraComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetAsset(InSystem);
        Archetype.SetAutoActivate(false);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(InNode, ComponentParams);
    }

    // The two docks on the table top, children of the root (they die with the station), lifted so a docked platter's
    // underside rests on the top. A rejected spec already ensured in utils_platter_dock::Create.
    private void Add_Docks()
    {
        auto InputPolicy = Docks.Input;
        if (InputPolicy.MaxPieces.IsSet() == false)
        { InputPolicy.MaxPieces = TOptional<int32>(_SearingSpec.Supply.MaxPieces); }

        const auto DockLift = FVector(0.0, 0.0, TableHeight + constants_platter::k_FloorAboveBase);
        auto InputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input, InputPolicy,
            FTransform(FRotator::ZeroRotator, InputDockLocal + DockLift));
        InputSpec.Name = FText::FromString("raw platter");
        InputSpec.KindRejectedText = FText::FromString("Meat only");
        _InputDock = utils_platter_dock::Create(_Root, InputSpec);

        auto OutputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Output, Docks.Output,
            FTransform(FRotator::ZeroRotator, OutputDockLocal + DockLift));
        OutputSpec.Name = FText::FromString("finished tray");
        _OutputDock = utils_platter_dock::Create(_Root, OutputSpec);
    }

    // A piece's record: the piece wears its own display (whoever made the piece dressed it); Jolt owns its pose. The cook
    // state starts as the piece arrived with it, and the display gets it at once.
    private void AddPieceVisuals(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto Visual = FMars_SearingStation_PieceVisual();
        Visual.Id = InPieceId;
        Visual.Entity = InPiece;
        Visual.Piece = InPiece.As_FoodPiece();
        Visual.CookState = Visual.Piece.Get_CookState();
        if (Visual.Entity.Is_RuntimeMeshDisplay())
        {
            utils_cookstate::Request_Write(Visual.Entity.As_RuntimeMeshDisplay(), Visual.CookState);
            Visual.Written = Visual.CookState;
        }

        _PieceVisuals.Add(Visual);
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
        Advance_Pools(DeltaSeconds);
        Advance_PoolHalf();
        Advance_FootprintNode();
        Advance_BubblesNode();
        Advance_Sizzle(DeltaSeconds);
        Advance_PieceVisuals(DeltaSeconds);
        Apply_PanMaterial();
        Apply_OilFx();
        Apply_SizzleSound();
        Refresh_Label();
    }

    // The feed's glove node, pose override and carried piece follow the feed; the glove's cube shows while a piece is
    // carried.
    private void Advance_Feed(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_FeedHandle))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Operator = _Root.H().As_Station().Get_Operator();
        _FeedPresentation.Advance(FMars_StationFeed_Frame(_FeedHandle, Operator, RootWorld, InDeltaSeconds));

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

    // Every piece's pool (see the file header): a piece that lies on the pan and is not lost has its footprint at its
    // pan-local XY (in art cm, the pan material's units); one off the pan (flying, lost, or gone from the kernel and about
    // to be dropped) keeps its last footprint and fills no slot, so no pool hugs a flying or absent piece. Each trail lags its
    // own footprint by TrailLagSeconds.
    private void Advance_Pools(float32 InDeltaSeconds)
    {
        const auto Scale = float64(PanScale);
        const auto Alpha = 1.0 - Math::Exp(-float64(InDeltaSeconds) / float64(TrailLagSeconds));
        for (int32 Index = 0; Index < _PieceVisuals.Num(); ++Index)
        {
            auto Visual = _PieceVisuals[Index];
            const auto Pooled = _SearingHandle.Get_HasPiece(Visual.Id) && Get_IsLiveOnPan(Visual.Id);
            Visual.Pool = Pooled ? EMars_SearingStation_Pool::Pooled : EMars_SearingStation_Pool::None;
            if (Pooled)
            {
                const auto Local = _SearingHandle.Get_PiecePanLocal(Visual.Id);
                Visual.Footprint = FVector2D(Local.X / Scale, Local.Y / Scale);
            }

            Visual.Trail = FVector2D(Visual.Trail.X + (Visual.Footprint.X - Visual.Trail.X) * Alpha,
                Visual.Trail.Y + (Visual.Footprint.Y - Visual.Trail.Y) * Alpha);
            _PieceVisuals[Index] = Visual;
        }
    }

    // The shared pool look follows the largest piece on the pan; with none there it stays as it was.
    private void Advance_PoolHalf()
    {
        auto Largest = 0.0f;
        for (const auto& Visual : _PieceVisuals)
        {
            if (Visual.Pool == EMars_SearingStation_Pool::Pooled)
            { Largest = Math::Max(Largest, Get_PoolHalf(Visual.Id)); }
        }

        if (Largest > 0.0f)
        { _PoolHalf = Largest; }
    }

    // The piece's h in the pan mesh's cm (the pan material's units): the mean of its two horizontal half extents as it was
    // admitted. The kernel read them from its mesh, so a cut piece pools as its own size.
    private float32 Get_PoolHalf(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        const auto HalfExtents = _SearingHandle.Get_PieceHalfExtents(InPieceId);
        return float32((HalfExtents.X + HalfExtents.Y) * 0.5) / PanScale;
    }

    // The splatter's node follows the newest piece on the pan; with none there it stays where it was.
    private void Advance_FootprintNode()
    {
        const auto PieceId = TryGet_FootprintPiece();
        if (PieceId.IsSet() == false)
        { return; }

        const auto Local = _SearingHandle.Get_PiecePanLocal(PieceId.GetValue());
        _WrittenFootprint = Write_NodeOffset(_FootprintNode, FVector(Local.X, Local.Y, 0.0), _WrittenFootprint);
    }

    // The beads' node sits at the middle of the footprints of every piece on the pan and their spread widens the bead box;
    // with none there both stay as they were.
    private void Advance_BubblesNode()
    {
        auto Min = FVector2D(0.0, 0.0);
        auto Max = FVector2D(0.0, 0.0);
        auto OnPanCount = 0;
        for (const auto& Visual : _PieceVisuals)
        {
            if (Visual.Pool == EMars_SearingStation_Pool::None)
            { continue; }

            if (OnPanCount == 0)
            {
                Min = Visual.Footprint;
                Max = Visual.Footprint;
            }
            else
            {
                Min = FVector2D(Math::Min(Min.X, Visual.Footprint.X), Math::Min(Min.Y, Visual.Footprint.Y));
                Max = FVector2D(Math::Max(Max.X, Visual.Footprint.X), Math::Max(Max.Y, Visual.Footprint.Y));
            }

            OnPanCount += 1;
        }

        if (OnPanCount == 0)
        { return; }

        const auto Scale = float64(PanScale);
        _BubbleSpread = FVector2D((Max.X - Min.X) * Scale, (Max.Y - Min.Y) * Scale);
        const auto Centre = FVector((Min.X + Max.X) * 0.5 * Scale, (Min.Y + Max.Y) * 0.5 * Scale, 0.0);
        _WrittenBubblesCentre = Write_NodeOffset(_BubblesNode, Centre, _WrittenBubblesCentre);
    }

    // Moves InNode to InOffset (pan mesh frame) unless it is within k_FootprintWriteTolerance of InWritten, the offset
    // last written; returns the offset now written.
    private FVector Write_NodeOffset(FCk_Handle_SceneNode& InNode, FVector InOffset, FVector InWritten)
    {
        if (InOffset.Distance(InWritten) <= k_FootprintWriteTolerance)
        { return InWritten; }

        utils_scene_node::Request_UpdateOffset(InNode,
            FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, InOffset)));
        return InOffset;
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

    // The loop plays while the ramp is above FxActiveThreshold, at the ramp's volume, and stops at once under it (near silent
    // by then). It plays again whenever it should be and is not, so a voice the engine dropped comes back. It waits for the
    // pan mesh's component, and nothing spawns where there is no audio device.
    private void Apply_SizzleSound()
    {
        if (_SizzleRamp <= FxActiveThreshold)
        {
            if (ck::IsValid(_SizzleAudio) && _SizzleAudio.IsPlaying())
            { _SizzleAudio.Stop(); }

            _WrittenSizzleVolume.Reset();
            return;
        }

        const auto Volume = _SizzleRamp * SizzleSoundVolume;
        if (ck::Is_NOT_Valid(_SizzleAudio))
        {
            _SizzleAudio = Spawn_SizzleAudio(Volume);
            _WrittenSizzleVolume = Volume;
            return;
        }

        if (_SizzleAudio.IsPlaying() == false)
        {
            _SizzleAudio.SetVolumeMultiplier(Volume);
            _SizzleAudio.Play();
            _WrittenSizzleVolume = Volume;
            return;
        }

        if (_WrittenSizzleVolume.IsSet() && Math::Abs(Volume - _WrittenSizzleVolume.GetValue()) <= SizzleSoundVolumeTolerance)
        { return; }

        _SizzleAudio.SetVolumeMultiplier(Volume);
        _WrittenSizzleVolume = Volume;
    }

    // Kept after it stops (a loop never completes) and destroyed in DoEndPlay. Null until the pan mesh's component exists,
    // and under -nosound.
    private UAudioComponent Spawn_SizzleAudio(float32 InVolume) const
    {
        if (ck::Is_NOT_Valid(_SizzleSound) || ck::Is_NOT_Valid(_PanPart))
        { return nullptr; }

        auto Pan = Cast<USceneComponent>(utils_unreal_component::Get_Component(_PanPart));
        if (ck::Is_NOT_Valid(Pan))
        { return nullptr; }

        const auto StopWhenAttachedToDestroyed = true;
        const auto AutoDestroy = false;
        const auto Pitch = 1.0f;
        const auto StartTime = 0.0f;
        return Gameplay::SpawnSoundAttached(_SizzleSound, Pan, NAME_None, FVector::ZeroVector, FRotator::ZeroRotator,
            EAttachLocation::KeepRelativeOffset, StopWhenAttachedToDestroyed, InVolume, Pitch, StartTime, nullptr, nullptr, AutoDestroy);
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

    // Each piece's cook state from its own sears. A record whose piece the kernel no longer holds (taken out, or destroyed at
    // the end of its linger) or whose entity is gone is dropped; a lost piece keeps its last cook state.
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
            Write_PieceCpd(Visual);
            _PieceVisuals[Index] = Visual;
        }
    }

    // The display follows the look on its edges, never per frame: a write once any float has moved by the threshold since
    // the last one. A piece without a display (a bare test piece) is legal and gets none.
    private void Write_PieceCpd(FMars_SearingStation_PieceVisual& InVisual)
    {
        if (InVisual.Entity.Is_RuntimeMeshDisplay() == false)
        { return; }

        if (utils_cookstate::Get_HasMovedBeyond(InVisual.Written, InVisual.CookState, constants_cookstate::k_WriteThreshold) == false)
        { return; }

        utils_cookstate::Request_Write(InVisual.Entity.As_RuntimeMeshDisplay(), InVisual.CookState);
        InVisual.Written = InVisual.CookState;
    }

    // The driven group on the pan's dynamic instance, in the pan mesh's own cm: the pieces on the pan fill the pool slots
    // in admission order, each with its footprint (x, y, its own footprint radius) and its trail; every other slot keeps
    // its xy and gets radius 0. The shared pool scalars follow _PoolHalf, rewritten only when it changes.
    private void Apply_PanMaterial()
    {
        if (Resolve_PanMaterial() == false)
        { return; }

        _PanMaterial.SetScalarParameterValue(n"Oil Amount", _SearingHandle.Get_IsHot() ? OilAmountHot : OilAmountCold);
        _PanMaterial.SetScalarParameterValue(n"Sizzle", _SizzleRamp);
        _PanMaterial.SetScalarParameterValue(n"Fond", _Fond);
        Apply_PoolScalars();

        auto Slot = 0;
        for (const auto& Visual : _PieceVisuals)
        {
            if (Visual.Pool == EMars_SearingStation_Pool::None || Slot >= k_PoolSlots)
            { continue; }

            const auto Radius = Get_PoolHalf(Visual.Id) * FootprintPerHalf;
            _PanMaterial.SetVectorParameterValue(_FootprintParameterNames[Slot],
                FLinearColor(float32(Visual.Footprint.X), float32(Visual.Footprint.Y), Radius, 0.0f));
            _PanMaterial.SetVectorParameterValue(_TrailParameterNames[Slot],
                FLinearColor(float32(Visual.Trail.X), float32(Visual.Trail.Y), 0.0f, 0.0f));
            Slot += 1;
        }

        while (Slot < k_PoolSlots)
        {
            const auto Footprint = _PanMaterial.GetVectorParameterValue(_FootprintParameterNames[Slot]);
            _PanMaterial.SetVectorParameterValue(_FootprintParameterNames[Slot], FLinearColor(Footprint.R, Footprint.G, 0.0f, 0.0f));
            Slot += 1;
        }
    }

    // Pool Radius, Pool Margin, Pool Blend, Simmer Width and Contact Softness: one value each for every pool, so they follow
    // the largest piece on the pan.
    private void Apply_PoolScalars()
    {
        if (_MaterialPoolHalf.IsSet() && Math::Abs(_MaterialPoolHalf.GetValue() - _PoolHalf) <= float32(k_FootprintWriteTolerance))
        { return; }

        _PanMaterial.SetScalarParameterValue(n"Pool Radius", PoolRadiusPerHalf * _PoolHalf);
        _PanMaterial.SetScalarParameterValue(n"Pool Margin", PoolMarginPerHalf * _PoolHalf);
        _PanMaterial.SetScalarParameterValue(n"Pool Blend", PoolBlendPerHalf * _PoolHalf);
        _PanMaterial.SetScalarParameterValue(n"Simmer Width", SimmerWidthPerHalf * _PoolHalf);
        _PanMaterial.SetScalarParameterValue(n"Contact Softness", ContactSoftnessPerHalf * _PoolHalf);
        _MaterialPoolHalf = _PoolHalf;
    }

    // "Meat Footprint" / "Oil Trail" for slot 0 (the names the material had before it had slots), then "Meat Footprint 1" /
    // "Oil Trail 1" up to k_PoolSlots - 1.
    private void Build_PoolParameterNames()
    {
        _FootprintParameterNames.Empty();
        _TrailParameterNames.Empty();
        _FootprintParameterNames.Add(n"Meat Footprint");
        _TrailParameterNames.Add(n"Oil Trail");
        for (int32 Slot = 1; Slot < k_PoolSlots; ++Slot)
        {
            _FootprintParameterNames.Add(FName(f"Meat Footprint {Slot}"));
            _TrailParameterNames.Add(FName(f"Oil Trail {Slot}"));
        }
    }

    // The beads run while the sizzle ramp is up, at a rate that follows it; the splatter only while the kernel sizzles.
    private void Apply_OilFx()
    {
        Resolve_OilFx();

        if (ck::IsValid(_Bubbles))
        {
            Write_BubbleExtent(_Bubbles);
            _Bubbles.SetVariableFloat(n"SpawnRate", BubbleRate * _SizzleRamp);
            _BubblesActive = Set_FxActive(_Bubbles, _BubblesActive, _SizzleRamp > FxActiveThreshold);
        }

        if (ck::IsValid(_Splatter))
        {
            Write_SplatterRadius(_Splatter);
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

    // The oil surface is the beads' node's Z 0 plus OilLevel; the box (Write_BubbleExtent) follows the pieces.
    private void Apply_BubbleParameters(UNiagaraComponent InBubbles)
    {
        _WrittenBubbleExtent = FVector2D(0.0, 0.0);
        Write_BubbleExtent(InBubbles);
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

    // One box over every pool (the pieces hide what spawns under them): the box around the largest piece, widened by the
    // pieces' spread. Written only when it changes.
    private void Write_BubbleExtent(UNiagaraComponent InBubbles)
    {
        const auto Single = float64(2.0f * BubbleOuterPerHalf * _PoolHalf * PanScale);
        const auto Extent = FVector2D(Single + _BubbleSpread.X, Single + _BubbleSpread.Y);
        if (Math::Abs(Extent.X - _WrittenBubbleExtent.X) <= k_FootprintWriteTolerance
            && Math::Abs(Extent.Y - _WrittenBubbleExtent.Y) <= k_FootprintWriteTolerance)
        { return; }

        InBubbles.SetVariableVec2(n"SpawnExtent", Extent);
        _WrittenBubbleExtent = Extent;
    }

    // Flung from the footprint edge on the oil surface (Write_SplatterRadius sizes the ring).
    private void Apply_SplatterParameters(UNiagaraComponent InSplatter)
    {
        _SplatterPoolHalf.Reset();
        Write_SplatterRadius(InSplatter);
        InSplatter.SetVariableFloat(n"SplatterRate", SplatterRate);
        InSplatter.SetVariableFloat(n"BurstsPerSecond", SplatterBursts);
        InSplatter.SetVariableFloat(n"SurfaceZ", OilLevel * PanScale);
        InSplatter.SetVariableFloat(n"FlingMin", SplatterFlingMin * PanScale);
        InSplatter.SetVariableFloat(n"FlingMax", SplatterFlingMax * PanScale);
        InSplatter.SetVariableFloat(n"SplatterSizeMin", SplatterSizeMin * PanScale);
        InSplatter.SetVariableFloat(n"SplatterSizeMax", SplatterSizeMax * PanScale);
        InSplatter.SetVariableFloat(n"SplatterLife", SplatterLife);
        InSplatter.SetVariableFloat(n"SplatterArc", SplatterArc);
        InSplatter.SetVariableLinearColor(n"SplatterColour", SplatterColour);
    }

    // The ring a footprint of the largest piece on the pan makes; written only when _PoolHalf changes.
    private void Write_SplatterRadius(UNiagaraComponent InSplatter)
    {
        if (_SplatterPoolHalf.IsSet() && Math::Abs(_SplatterPoolHalf.GetValue() - _PoolHalf) <= float32(k_FootprintWriteTolerance))
        { return; }

        InSplatter.SetVariableFloat(n"SplatterRadius", _PoolHalf * FootprintPerHalf * PanScale);
        _SplatterPoolHalf = _PoolHalf;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station visuals
    //----------------------------------------------------------------------------------------------------------------------

    // The hearth slab's top (the label and the view key off it).
    private float64 Get_StoveTop() const
    {
        return TableHeight + HearthSlabHeight;
    }

    // The trivet ring's top: the pan's rest (the hearth's SOCKET_Pan).
    private float64 Get_BurnerTop() const
    {
        return TableHeight + HearthTrivetTop;
    }

    // The pan pivot (the centre of its cooking surface) at rest: the underside on the ring, plus any hover.
    private float64 Get_PanRestZ() const
    {
        return Get_BurnerTop() + PanHoverAboveBurner + PanUndersideDepth * float64(PanScale);
    }

    private void Refresh_All()
    {
        Refresh_Burner();
        Refresh_Label();
    }

    // The ember bed glows with the heat: its slot 0 gets a dynamic instance once the component exists (OnPartAdded).
    private void Refresh_Burner()
    {
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return; }

        if (ck::Is_NOT_Valid(_EmberMaterial))
        {
            auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_EmberPart));
            if (ck::Is_NOT_Valid(Mesh))
            { return; }

            _EmberMaterial = Mesh.CreateDynamicMaterialInstance(0);
            if (ck::Is_NOT_Valid(_EmberMaterial))
            { return; }
        }

        _EmberMaterial.SetScalarParameterValue(n"Strength", _SearingHandle.Get_IsHot() ? EmberStrengthHot : EmberStrengthCold);
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

    // What the label reads: "cold" off the burner; once something was admitted, the raw platter is spent, no transfer is
    // under way and nothing still cooks, the batch is all accounted for (taken out counts); otherwise the batch so far and
    // what is left raw ("no platter" without one docked). A second line says when no tray is docked to take out onto.
    private FText Get_StateLabel() const
    {
        if (_SearingHandle.Get_IsHot() == false)
        { return FText::FromString("cold"); }

        const auto Summary = _SearingHandle.Get_Summary();
        const auto HasFeed = ck::IsValid(_FeedHandle);
        const auto IsSourced = HasFeed && _FeedHandle.Get_IsSourced();
        const auto Raw = IsSourced ? _FeedHandle.Get_Available() : 0;
        const auto IsFeeding = HasFeed && _FeedHandle.Get_IsBusy();
        const FString TrayLine = Get_HasTray() ? "" : "\nno tray: dock one to take out";

        if (Summary.Admitted > 0 && Raw == 0 && IsFeeding == false && Summary.Cooking == 0)
        { return FText::FromString(f"all accounted for: {Summary.Ready} ready · {Summary.TakenOut} taken out · {Summary.Lost} lost{TrayLine}"); }

        const FString RawText = IsSourced ? f"{Raw} raw" : "no platter";
        return FText::FromString(f"{Summary.Ready}/{Summary.Admitted} ready · {Summary.Lost} lost · {Summary.TakenOut} taken out · {RawText}{TrayLine}");
    }

    private bool Get_HasTray() const
    {
        return ck::IsValid(_OutputDock) && ck::IsValid(_OutputDock.Get_Platter());
    }

    // One reused burst component: spawned at the first seared face whose template is ready, then moved to the middle of the
    // piece whose face seared (a cut piece's origin is not its middle) and re-activated. Null under nullrhi.
    private void Play_SearedBurst(const FMars_CookingFeed_PieceId& InPieceId)
    {
        if (ck::Is_NOT_Valid(_SearingHandle) || _SearingHandle.Get_HasPiece(InPieceId) == false)
        { return; }

        const auto Piece = _SearingHandle.Get_PieceEntity(InPieceId);
        if (ck::Is_NOT_Valid(Piece))
        { return; }

        const auto Location = _SearingHandle.Get_PieceCentre(InPieceId);

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

    // The glove's cube wears the raw cook state and starts hidden; the dressing tick sets its visibility.
    UFUNCTION()
    private void OnCarryProxyAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Cube = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Cube))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Cube, FMars_CookState());
        Cube.SetVisibility(false);
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
