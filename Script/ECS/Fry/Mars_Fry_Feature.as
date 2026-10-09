//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FryHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Fry";
    RequiredFragments.Add(FMars_Feature_Fry);
    Description = "A frying minigame on a station: admitted battered pieces (dynamic bodies keyed by their feed identity) that float, tumble and fry face by face below the oil line, a skimmer (a kinematic body) the operator dips, carries and pours, and a fixed drain basket outside the oil where a supported piece drains";
}
struct FMars_Feature_Fry {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Where a piece is, judged from its body's pose each frame. Lost is terminal: the piece lingers, then is destroyed.
enum EMars_Fry_Whereabouts
{
    Oil,
    Skimmer,
    Airborne,
    DrainBasket,
    Lost
}

// A face's heat: 0..1 Pale, 1..2 Golden, 2 Overdone.
enum EMars_Fry_HeatStage
{
    Pale,
    Golden,
    Overdone
}

// A piece's drain: NotDraining until it rests on the basket floor inside the basket; Draining while it accrues (held while it
// hops inside the basket); Drained at Receiver.DrainSeconds. Leaving the basket resets it to NotDraining, a Drained one too.
enum EMars_Fry_Drain
{
    NotDraining,
    Draining,
    Drained
}

// The skimmer's commanded pose: Carry level at carry height; Dip level below the oil line (under a floating piece), only
// with the whole bowl inside the pot; Pour tipped toward the operator's right at carry height, only with the whole bowl over
// the basket interior, so what it carries slides off into the basket below. Where a Dip becomes a Pour is the kernel's call.
enum EMars_Fry_Skim
{
    Carry,
    Dip,
    Pour
}

// The surface of the body an adopted piece is given (its shape is the piece's own mesh, its mass the piece's own).
struct FMars_Fry_PieceSpec
{
    UPROPERTY()
    float32 Friction = 0.5f;

    UPROPERTY()
    float32 Restitution = 0.2f;

    UPROPERTY()
    float32 LinearDamping = 0.1f;

    UPROPERTY()
    float32 AngularDamping = 0.4f;

    UPROPERTY()
    float32 GravityFactor = 1.0f;

    FMars_Fry_PieceSpec() {}

    FMars_Fry_PieceSpec(float32 InFriction, float32 InRestitution)
    {
        Friction = InFriction;
        Restitution = InRestitution;
    }
}

// How many bodies the kernel takes at once (lost pieces that still linger do not count). The feed's own stock is the real
// limit; this refuses a body a misbehaving caller would add past it.
struct FMars_Fry_SupplySpec
{
    UPROPERTY()
    int32 MaxPieces = 6;

    FMars_Fry_SupplySpec() {}

    FMars_Fry_SupplySpec(int32 InMaxPieces)
    {
        MaxPieces = InMaxPieces;
    }
}

// What utils_fry::Add_BasketBodies builds (a floor and four walls) and the interior the kernel tests a piece against: room
// for six pieces and their settling.
struct FMars_Fry_BasketSpec
{
    UPROPERTY()
    float32 InnerHalfX = 22.0f;

    UPROPERTY()
    float32 InnerHalfY = 26.0f;

    UPROPERTY()
    float32 WallHeight = 10.0f;

    UPROPERTY()
    float32 WallThickness = 1.2f;

    UPROPERTY()
    float32 FloorThickness = 1.5f;

    UPROPERTY()
    float32 Friction = 0.5f;

    UPROPERTY()
    float32 Restitution = 0.1f;

    FMars_Fry_BasketSpec() {}

    FMars_Fry_BasketSpec(
        float32 InInnerHalfX,
        float32 InInnerHalfY,
        float32 InWallHeight,
        float32 InWallThickness,
        float32 InFloorThickness)
    {
        InnerHalfX = InInnerHalfX;
        InnerHalfY = InInnerHalfY;
        WallHeight = InWallHeight;
        WallThickness = InWallThickness;
        FloorThickness = InFloorThickness;
    }
}

// What utils_fry::Add_ScoopBodies builds (a disc and a low lip), the bowl the kernel tests a piece against, and the
// skimmer's two lifts (uu above its implement's rest, which is the carry height the placing script parks it at).
struct FMars_Fry_ScoopSpec
{
    UPROPERTY()
    float32 BowlRadius = 11.0f;

    UPROPERTY()
    float32 LipHeight = 1.5f;

    UPROPERTY()
    float32 LipThickness = 1.0f;

    UPROPERTY()
    float32 DiscThickness = 1.0f;

    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.05f;

    // The lift while carrying (the rest).
    UPROPERTY()
    float32 CarryLift = 0.0f;

    // The lift while dipping: deep enough that the disc passes under a floating piece. The placing script sets it from its
    // own geometry.
    UPROPERTY()
    float32 DipLift = -42.0f;

    // Degrees of pitch toward the operator (the near lip down, the far side up: the skimmer turns about its handle) the
    // pour tips the scoop to: steep enough that a piece slides over the low lip. The skimmer's implement must be able to
    // tilt this far.
    UPROPERTY()
    float32 PourPitchDegrees = 55.0f;

    FMars_Fry_ScoopSpec() {}

    FMars_Fry_ScoopSpec(float32 InBowlRadius, float32 InLipHeight, float32 InLipThickness, float32 InDiscThickness)
    {
        BowlRadius = InBowlRadius;
        LipHeight = InLipHeight;
        LipThickness = InLipThickness;
        DiscThickness = InDiscThickness;
    }
}

// The oil line (a root-frame height the placing script sets) and the lift and drag it gives a piece, both scaled by how
// much of the piece is under it. A free piece floats with gravity / BuoyancyAccel of its height under the line: at 1500 that
// is 65 %, so about a third of it stays dry and an unattended piece leaves its top face pale.
struct FMars_Fry_OilSpec
{
    UPROPERTY()
    float32 SurfaceZ = 103.0f;

    // cm/s^2 at full immersion.
    UPROPERTY()
    float32 BuoyancyAccel = 1500.0f;

    // 1/s, linear in velocity, times the immersion.
    UPROPERTY()
    float32 Drag = 3.0f;

    FMars_Fry_OilSpec() {}

    FMars_Fry_OilSpec(float32 InSurfaceZ, float32 InBuoyancyAccel, float32 InDrag)
    {
        SurfaceZ = InSurfaceZ;
        BuoyancyAccel = InBuoyancyAccel;
        Drag = InDrag;
    }
}

// Seconds of a face under the oil from pale to golden, then from golden to overdone.
struct FMars_Fry_HeatSpec
{
    UPROPERTY()
    float32 GoldenSeconds = 6.0f;

    UPROPERTY()
    float32 OverdoneSeconds = 10.0f;

    FMars_Fry_HeatSpec() {}

    FMars_Fry_HeatSpec(float32 InGoldenSeconds, float32 InOverdoneSeconds)
    {
        GoldenSeconds = InGoldenSeconds;
        OverdoneSeconds = InOverdoneSeconds;
    }
}

// The pot (root frame): its radius about the root's Z axis, its rim height, the floor a lost piece lands on, and how long a
// lost body keeps flying and bouncing before it is destroyed.
struct FMars_Fry_ZoneSpec
{
    UPROPERTY()
    float32 PotRadius = 45.0f;

    UPROPERTY()
    float32 RimZ = 115.0f;

    UPROPERTY()
    float32 FloorZ = 30.0f;

    UPROPERTY()
    float32 LingerSeconds = 2.5f;

    FMars_Fry_ZoneSpec() {}

    FMars_Fry_ZoneSpec(float32 InPotRadius, float32 InRimZ, float32 InFloorZ)
    {
        PotRadius = InPotRadius;
        RimZ = InRimZ;
        FloorZ = InFloorZ;
    }
}

// The drain basket as a receiver: how long a piece must rest on its floor, inside it, to drain, and how long after its last
// contact with the floor it still counts as resting there (the piece's Resting grace: a sleeping or hopping contact).
struct FMars_Fry_ReceiverSpec
{
    UPROPERTY()
    float32 DrainSeconds = 1.5f;

    UPROPERTY()
    float32 SupportGraceSeconds = 0.1f;

    FMars_Fry_ReceiverSpec() {}

    FMars_Fry_ReceiverSpec(float32 InDrainSeconds, float32 InSupportGraceSeconds)
    {
        DrainSeconds = InDrainSeconds;
        SupportGraceSeconds = InSupportGraceSeconds;
    }
}

// Root-frame XY reach of the carried scoop's centre: the pot disc (Zones.PotRadius less the bowl and its lip, about the
// root's axis: the only region while dipped), a corridor box from the pot toward the basket, and the basket's interior
// footprint. Authored by the placing script from its geometry. The look moves the target CmPerLookDegree per degree.
struct FMars_Fry_ReachSpec
{
    UPROPERTY()
    FVector2D CorridorCentre = FVector2D(0.0, 32.0);

    UPROPERTY()
    FVector2D CorridorHalfExtent = FVector2D(22.0, 32.0);

    UPROPERTY()
    FVector2D BasketCentre = FVector2D(0.0, 90.0);

    UPROPERTY()
    FVector2D BasketHalfExtent = FVector2D(22.0, 26.0);

    UPROPERTY()
    float32 CmPerLookDegree = 1.6f;

    FMars_Fry_ReachSpec() {}
}

// Built by the placing script before Add: the skimmer Implement already composed (a Commanded slide the kernel steers, a
// commanded lift and tilt the skim sets; its node's rest frame axis-aligned with the station root), the scoop disc body (its
// frame raised to the disc's top is the scoop frame) and the basket floor body (its frame raised to the floor's top is the
// basket frame). A piece's Resting targets both bodies.
struct FMars_Fry_Nodes
{
    UPROPERTY()
    FCk_Handle_Implement Skimmer;

    UPROPERTY()
    FCk_Handle_JoltBody ScoopBody;

    UPROPERTY()
    FCk_Handle_JoltBody BasketBody;

    FMars_Fry_Nodes() {}

    FMars_Fry_Nodes(FCk_Handle_Implement InSkimmer, FCk_Handle_JoltBody InScoopBody, FCk_Handle_JoltBody InBasketBody)
    {
        Skimmer = InSkimmer;
        ScoopBody = InScoopBody;
        BasketBody = InBasketBody;
    }
}

struct FMars_Fry_Spec
{
    UPROPERTY()
    FMars_Fry_PieceSpec Piece;

    UPROPERTY()
    FMars_Fry_SupplySpec Supply;

    UPROPERTY()
    FMars_Fry_BasketSpec Basket;

    UPROPERTY()
    FMars_Fry_ScoopSpec Scoop;

    UPROPERTY()
    FMars_Fry_OilSpec Oil;

    UPROPERTY()
    FMars_Fry_HeatSpec Heat;

    UPROPERTY()
    FMars_Fry_ZoneSpec Zones;

    UPROPERTY()
    FMars_Fry_ReceiverSpec Receiver;

    UPROPERTY()
    FMars_Fry_ReachSpec Reach;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Fry_Nodes Nodes;
}

// A kernel that takes no piece, a basket or scoop with no size, a body surface outside the physical range, a skimmer whose
// dip is not below its carry or whose pour does not tip (or tips past a usable angle), a face that never goes golden, a pot
// too narrow for the bowl, a receiver that never drains or drops its contact at once, or a reach with no extent or no look
// each make the minigame unplayable.
mixin FMars_Validation Validate(const FMars_Fry_Spec& Self)
{
    if (Self.Supply.MaxPieces <= 0)
    { return FMars_Validation(f"Fry has a non-positive Supply.MaxPieces [{Self.Supply.MaxPieces}]"); }

    const auto& Piece = Self.Piece;
    if (Piece.Friction < 0.0f || Piece.LinearDamping < 0.0f || Piece.AngularDamping < 0.0f || Piece.GravityFactor < 0.0f)
    { return FMars_Validation("Fry has a negative Piece.Friction, LinearDamping, AngularDamping or GravityFactor"); }

    if (Piece.Restitution < 0.0f || Piece.Restitution > 1.0f)
    { return FMars_Validation(f"Fry has Piece.Restitution [{Piece.Restitution}] outside [0, 1]"); }

    const auto& Basket = Self.Basket;
    if (Basket.InnerHalfX <= 0.0f || Basket.InnerHalfY <= 0.0f || Basket.WallHeight <= 0.0f
        || Basket.WallThickness <= 0.0f || Basket.FloorThickness <= 0.0f)
    { return FMars_Validation(f"Fry has a non-positive basket size (InnerHalfX [{Basket.InnerHalfX}], InnerHalfY [{Basket.InnerHalfY}], WallHeight [{Basket.WallHeight}], WallThickness [{Basket.WallThickness}], FloorThickness [{Basket.FloorThickness}])"); }

    if (Basket.Friction < 0.0f || Basket.Restitution < 0.0f || Basket.Restitution > 1.0f)
    { return FMars_Validation(f"Fry has a basket Friction [{Basket.Friction}] below 0 or Restitution [{Basket.Restitution}] outside [0, 1]"); }

    const auto& Scoop = Self.Scoop;
    if (Scoop.BowlRadius <= 0.0f || Scoop.LipHeight <= 0.0f || Scoop.LipThickness <= 0.0f || Scoop.DiscThickness <= 0.0f)
    { return FMars_Validation(f"Fry has a non-positive scoop size (BowlRadius [{Scoop.BowlRadius}], LipHeight [{Scoop.LipHeight}], LipThickness [{Scoop.LipThickness}], DiscThickness [{Scoop.DiscThickness}])"); }

    if (Scoop.Friction < 0.0f || Scoop.Restitution < 0.0f || Scoop.Restitution > 1.0f)
    { return FMars_Validation(f"Fry has a scoop Friction [{Scoop.Friction}] below 0 or Restitution [{Scoop.Restitution}] outside [0, 1]"); }

    if (Scoop.DipLift >= Scoop.CarryLift)
    { return FMars_Validation(f"Fry has a scoop DipLift [{Scoop.DipLift}] not below its CarryLift [{Scoop.CarryLift}]"); }

    if (Scoop.PourPitchDegrees <= 0.0f || Scoop.PourPitchDegrees > 80.0f)
    { return FMars_Validation(f"Fry has a scoop PourPitchDegrees [{Scoop.PourPitchDegrees}] outside (0, 80]"); }

    if (Self.Oil.BuoyancyAccel <= 0.0f || Self.Oil.Drag < 0.0f)
    { return FMars_Validation(f"Fry has a non-positive Oil.BuoyancyAccel [{Self.Oil.BuoyancyAccel}] or a negative Oil.Drag [{Self.Oil.Drag}]"); }

    if (Self.Heat.GoldenSeconds <= 0.0f || Self.Heat.OverdoneSeconds <= 0.0f)
    { return FMars_Validation(f"Fry has a non-positive Heat.GoldenSeconds [{Self.Heat.GoldenSeconds}] or Heat.OverdoneSeconds [{Self.Heat.OverdoneSeconds}]"); }

    const auto& Zones = Self.Zones;
    if (Zones.PotRadius - Scoop.BowlRadius - Scoop.LipThickness <= 0.0f)
    { return FMars_Validation(f"Fry has a Zones.PotRadius [{Zones.PotRadius}] that leaves the scoop (BowlRadius [{Scoop.BowlRadius}] + LipThickness [{Scoop.LipThickness}]) no room to move"); }

    if (Zones.LingerSeconds < 0.0f)
    { return FMars_Validation(f"Fry has a negative Zones.LingerSeconds [{Zones.LingerSeconds}]"); }

    if (Self.Receiver.DrainSeconds <= 0.0f || Self.Receiver.SupportGraceSeconds <= 0.0f)
    { return FMars_Validation(f"Fry has a non-positive Receiver.DrainSeconds [{Self.Receiver.DrainSeconds}] or SupportGraceSeconds [{Self.Receiver.SupportGraceSeconds}]"); }

    const auto& Reach = Self.Reach;
    if (Reach.CorridorHalfExtent.X <= 0.0 || Reach.CorridorHalfExtent.Y <= 0.0
        || Reach.BasketHalfExtent.X <= 0.0 || Reach.BasketHalfExtent.Y <= 0.0)
    { return FMars_Validation(f"Fry has a non-positive Reach.CorridorHalfExtent [{Reach.CorridorHalfExtent}] or BasketHalfExtent [{Reach.BasketHalfExtent}]"); }

    if (Reach.CmPerLookDegree <= 0.0f)
    { return FMars_Validation(f"Fry has a non-positive Reach.CmPerLookDegree [{Reach.CmPerLookDegree}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Fry_Params
{
    UPROPERTY()
    FMars_Fry_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// One adopted piece, keyed by the feed identity it arrived with (an array index is never identity). Its entity is the food
// piece's own (the kernel's guest: it keeps its lifetime) and carries the dynamic body and a Resting on the scoop disc and
// the basket floor. Its geometry is read once, at admission, from its mesh's metrics.
struct FMars_Fry_PieceState
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    // The release's preset (which battered mesh the placing script dresses it as); the kernel never reads it.
    UPROPERTY()
    int32 PresetIndex = 0;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // The piece's entity, as a plain handle.
    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // The middle of the piece's bounds in its own frame.
    UPROPERTY()
    FVector CentreLocal = FVector::ZeroVector;

    // Half the piece's bounds along its own axes.
    UPROPERTY()
    FVector HalfExtents = FVector::ZeroVector;

    // The release location while the piece is still arriving: its transform reads where it was before admission until its
    // pose request or teleport lands, so the Tick neither judges nor pushes it until it is there
    // (utils_searing::Get_HasArrived).
    UPROPERTY()
    TOptional<FVector> Arriving;

    // How long the piece has been arriving; past utils_searing::k_ArrivalMaxSeconds it is judged where it is.
    UPROPERTY()
    float32 ArrivingSeconds = 0.0f;

    // Six, 0 pale .. 1 golden .. 2 overdone, seeded from the piece's sear; indexed by int32(EMars_Searing_Face).
    UPROPERTY()
    TArray<float32> FaceHeat;

    // Six, the last stage OnFaceHeatStage reported per face.
    UPROPERTY()
    TArray<EMars_Fry_HeatStage> ReportedStage;

    UPROPERTY()
    EMars_Fry_Whereabouts Whereabouts = EMars_Fry_Whereabouts::Airborne;

    // The last whereabouts other than Airborne (Oil at admission: a released piece is dropped over the oil): where a hop
    // started.
    UPROPERTY()
    EMars_Fry_Whereabouts LastHome = EMars_Fry_Whereabouts::Oil;

    UPROPERTY()
    EMars_Fry_Drain Drain = EMars_Fry_Drain::NotDraining;

    // Seconds rested on the basket floor inside the basket since the piece last came in (Draining only).
    UPROPERTY()
    float32 DrainSeconds = 0.0f;

    // Lost only: seconds since the loss; the piece is removed and its entity destroyed at Zones.LingerSeconds.
    UPROPERTY()
    float32 LingerSeconds = 0.0f;
}

struct FMars_Fry_Tally
{
    // Seconds any piece was in the oil, since the last reset.
    UPROPERTY()
    float32 Seconds = 0.0f;

    // Hops that started in the drain basket and landed anywhere else (knocked out of it).
    UPROPERTY()
    int32 Ejections = 0;

    // Hops that landed on the scoop.
    UPROPERTY()
    int32 Catches = 0;

    // Pieces the scoop lifted straight out of the oil.
    UPROPERTY()
    int32 Retrievals = 0;

    UPROPERTY()
    int32 Lost = 0;

    // Pieces handed back by TakeOut.
    UPROPERTY()
    int32 TakenOut = 0;
}

// Every piece in play is in exactly one whereabouts, and every piece lost or taken out since the last reset stays counted
// (a reset keeps the pieces in play): Admitted = InOil + OnSkimmer + Airborne + InBasket + Lost + TakenOut. Drained counts
// the InBasket pieces that drained. The face counts are over the pieces not Lost.
struct FMars_Fry_Summary
{
    UPROPERTY()
    int32 Admitted = 0;

    UPROPERTY()
    int32 InOil = 0;

    UPROPERTY()
    int32 OnSkimmer = 0;

    UPROPERTY()
    int32 Airborne = 0;

    UPROPERTY()
    int32 InBasket = 0;

    UPROPERTY()
    int32 Drained = 0;

    UPROPERTY()
    int32 Lost = 0;

    UPROPERTY()
    int32 TakenOut = 0;

    UPROPERTY()
    int32 PaleFaces = 0;

    UPROPERTY()
    int32 OverdoneFaces = 0;
}

// Written only by the Fry processors (and Add). The station SM, the feed bridge and the operator only issue requests.
struct FMars_Fragment_Fry
{
    // In admission order. Lost pieces stay while they linger (one array, one identity space).
    UPROPERTY()
    TArray<FMars_Fry_PieceState> Pieces;

    // The skimmer's drive: Driven while an operator holds it (looks and skims are taken), Idle otherwise.
    UPROPERTY()
    EMars_Implement_Drive Drive = EMars_Implement_Drive::Idle;

    // The skimmer's commanded pose; Carry whenever it is idle.
    UPROPERTY()
    EMars_Fry_Skim Skim = EMars_Fry_Skim::Carry;

    // Root-frame XY of the scoop's commanded centre, inside the reach.
    UPROPERTY()
    FVector2D SkimmerTarget = FVector2D::ZeroVector;

    // Root-frame XY of the scoop's centre at the skimmer's rest (its park). Written only by Add.
    UPROPERTY()
    FVector2D SkimmerPark = FVector2D::ZeroVector;

    UPROPERTY()
    FMars_Fry_Tally Tally;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A SetDrive that changed it; a Reset that found it Driven reports Idle.
delegate void FMars_Delegate_Fry_OnDriveChanged(FCk_Handle_Fry InFry, EMars_Implement_Drive InDrive);
event void FMars_Delegate_Fry_OnDriveChanged_MC(FCk_Handle_Fry InFry, EMars_Implement_Drive InDrive);

// The answer to every AddPiece: Accepted (the piece is in play; OnPieceAdded follows) or Rejected with a reason (the piece is
// left as it was).
delegate void FMars_Delegate_Fry_OnPieceAdmission(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);
event void FMars_Delegate_Fry_OnPieceAdmission_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);

// An adopted piece is in play (its body requested or switched back to Dynamic, not yet moving): the placing script adds its
// visuals here.
delegate void FMars_Delegate_Fry_OnPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Fry_OnPieceAdded_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

delegate void FMars_Delegate_Fry_OnPieceWhereaboutsChanged(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Fry_Whereabouts InFrom, EMars_Fry_Whereabouts InTo);
event void FMars_Delegate_Fry_OnPieceWhereaboutsChanged_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Fry_Whereabouts InFrom, EMars_Fry_Whereabouts InTo);

// A face crossing into Golden (heat 1) or Overdone (heat 2), once per crossing.
delegate void FMars_Delegate_Fry_OnFaceHeatStage(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, EMars_Fry_HeatStage InStage);
event void FMars_Delegate_Fry_OnFaceHeatStage_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, EMars_Fry_HeatStage InStage);

// A piece reached Receiver.DrainSeconds resting in the basket (again, after it was knocked out and came back).
delegate void FMars_Delegate_Fry_OnPieceDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId);
event void FMars_Delegate_Fry_OnPieceDrained_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId);

// A piece left the pot and the basket; InPiece lingers and is destroyed later. Nothing replaces it.
delegate void FMars_Delegate_Fry_OnPieceLost(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Fry_OnPieceLost_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

delegate void FMars_Delegate_Fry_OnSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim);
event void FMars_Delegate_Fry_OnSkimChanged_MC(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim);

// A TakeOut handed InPiece back: out of play, its cook state written, its body Kinematic. Control loads it where it goes
// next.
delegate void FMars_Delegate_Fry_OnPieceTakenOut(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_Fry_OnPieceTakenOut_MC(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);

struct FMars_Fragment_Fry_Signals
{
    FMars_Delegate_Fry_OnDriveChanged_MC OnDriveChanged;
    FMars_Delegate_Fry_OnPieceAdmission_MC OnPieceAdmission;
    FMars_Delegate_Fry_OnPieceAdded_MC OnPieceAdded;
    FMars_Delegate_Fry_OnPieceWhereaboutsChanged_MC OnPieceWhereaboutsChanged;
    FMars_Delegate_Fry_OnFaceHeatStage_MC OnFaceHeatStage;
    FMars_Delegate_Fry_OnPieceDrained_MC OnPieceDrained;
    FMars_Delegate_Fry_OnPieceLost_MC OnPieceLost;
    FMars_Delegate_Fry_OnSkimChanged_MC OnSkimChanged;
    FMars_Delegate_Fry_OnPieceTakenOut_MC OnPieceTakenOut;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// One drained InputIntents look delta (degrees; X yaw right+, Y pitch down+): moves the skimmer's target (look right +Y,
// look down -X) within the reach while Driven; dropped while Idle.
struct FMars_Request_Fry_Look
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_Fry_Look() {}

    FMars_Request_Fry_Look(FVector InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// Driven while the skimmer is in the operator's hand (the station's Operated enter); Idle drops looks and skims and carries.
// Last wins within a drain.
struct FMars_Request_Fry_SetDrive
{
    UPROPERTY()
    EMars_Implement_Drive Drive = EMars_Implement_Drive::Idle;

    FMars_Request_Fry_SetDrive() {}

    FMars_Request_Fry_SetDrive(EMars_Implement_Drive InDrive)
    {
        Drive = InDrive;
    }
}

// Carry: lift to carry, level. Dip (or a Pour asked for, judged as a Dip): with the whole bowl inside the pot it dips; with
// the whole bowl over the basket interior it pours; anywhere else (the corridor) it is a traced no-op. A traced no-op while
// Idle.
struct FMars_Request_Fry_Skim
{
    UPROPERTY()
    EMars_Fry_Skim Skim = EMars_Fry_Skim::Carry;

    FMars_Request_Fry_Skim() {}

    FMars_Request_Fry_Skim(EMars_Fry_Skim InSkim)
    {
        Skim = InSkim;
    }
}

// One released piece to adopt (Release.Piece), answered by OnPieceAdmission. Rejected (the piece left as it was) in a drain
// that also resets, while the scoop or basket body is not yet in the simulation, when the release names no live piece, a
// piece not Ready, one already in play, one still on its platter or still attached, when a piece (lingering lost ones
// included) already carries the Id, or when Supply.MaxPieces live pieces are in play.
struct FMars_Request_Fry_AddPiece
{
    UPROPERTY()
    FMars_CookingFeed_Release Release;

    FMars_Request_Fry_AddPiece() {}

    FMars_Request_Fry_AddPiece(FMars_CookingFeed_Release InRelease)
    {
        Release = InRelease;
    }
}

// Hands pieces back, each with its cook state written and its body Kinematic, answered by OnPieceTakenOut per piece. Piece
// set: that piece, if it is in play and not lost; unset: every Drained piece in admission order. MaxPieces set: at most
// that many leave.
struct FMars_Request_Fry_TakeOut
{
    UPROPERTY()
    TOptional<FCk_Handle_FoodPiece> Piece;

    UPROPERTY()
    TOptional<int32> MaxPieces;

    FMars_Request_Fry_TakeOut() {}

    FMars_Request_Fry_TakeOut(TOptional<FCk_Handle_FoodPiece> InPiece, TOptional<int32> InMaxPieces)
    {
        Piece = InPiece;
        MaxPieces = InMaxPieces;
    }
}

// Resets the skimmer (carry, level, at its park, idle) and zeroes the tally; every piece stays in play with its heat (the
// player's food is theirs). Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Fry_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fry_Reset() {}
}

// Applied Reset -> SetDrive -> TakeOut -> AddPiece -> Skim -> Look, so a reset and the first drive, pieces, dip and looks of
// a new session can share a drain (an AddPiece sharing a drain with a Reset is rejected), and a take-out frees its place
// before the next admission.
struct FMars_Fragment_Fry_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Fry_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Fry_SetDrive> SetDriveRequests;

    UPROPERTY()
    TArray<FMars_Request_Fry_TakeOut> TakeOutRequests;

    UPROPERTY()
    TArray<FMars_Request_Fry_AddPiece> AddPieceRequests;

    UPROPERTY()
    TArray<FMars_Request_Fry_Skim> SkimRequests;

    UPROPERTY()
    TArray<FMars_Request_Fry_Look> LookRequests;
}
