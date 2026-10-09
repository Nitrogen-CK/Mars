//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SearingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Searing";
    RequiredFragments.Add(FMars_Feature_Searing);
    Description = "A searing minigame on a station: adopted food pieces (dynamic bodies keyed by their feed identity) on a hot pan (a kinematic body the operator's look tilts and lifts); each piece's face on the pan sears";
}
struct FMars_Feature_Searing {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// A piece's six faces, by their outward normal in the piece's own frame. int32(Face) indexes the sear ledger.
enum EMars_Searing_Face
{
    PosX,
    NegX,
    PosY,
    NegY,
    PosZ,
    NegZ
}

enum EMars_Searing_Heat
{
    Cold,
    Hot
}

enum EMars_Searing_Sizzle
{
    Quiet,
    Sizzling
}

// A piece resting on the pan base (and over the disc), or not.
enum EMars_Searing_Contact
{
    Airborne,
    OnPan
}

// Cooking: on its way to six seared faces. Ready: six faces seared; it stays on the pan, inert, until it is taken out (a
// spill still loses it). Lost: it left the pan; its body lingers until Loss.LingerSeconds, then it is destroyed. Nothing
// replaces it.
enum EMars_Searing_PieceStatus
{
    Cooking,
    Ready,
    Lost
}

// How many bodies the pan takes at once (lost pieces that still linger do not count). The feed's own stock is the real
// limit; this refuses a body a misbehaving caller would add past it.
struct FMars_Searing_SupplySpec
{
    UPROPERTY()
    int32 MaxPieces = 6;

    FMars_Searing_SupplySpec() {}

    FMars_Searing_SupplySpec(int32 InMaxPieces)
    {
        MaxPieces = InMaxPieces;
    }
}

struct FMars_Searing_CookSpec
{
    // Seconds of contact with a hot pan that sear one face from raw to done.
    UPROPERTY()
    float32 SecondsPerFace = 3.0f;

    FMars_Searing_CookSpec() {}

    FMars_Searing_CookSpec(float32 InSecondsPerFace)
    {
        SecondsPerFace = InSecondsPerFace;
    }
}

// The surface of the body an adopted piece is given (its shape is the piece's own mesh, its mass the piece's own).
// Friction combines with the pan's as sqrt(a * b): 0.6 on an oiled pan's 0.15 gives 0.3, so a resting piece starts
// sliding past a 17-degree tilt (into the pan's lip) and glides on a pan swirling a few uu at 1.5 Hz.
struct FMars_Searing_PieceSpec
{
    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.15f;

    UPROPERTY()
    float32 LinearDamping = 0.05f;

    UPROPERTY()
    float32 AngularDamping = 0.15f;

    // How long a piece counts as resting on the pan after its last contact with the base (its Resting's grace). A piece
    // gliding on a swirling, oiled pan can lose contact for a moment without leaving it.
    UPROPERTY()
    float32 ContactGraceSeconds = 0.1f;

    FMars_Searing_PieceSpec() {}

    FMars_Searing_PieceSpec(float32 InFriction, float32 InRestitution, float32 InLinearDamping, float32 InAngularDamping)
    {
        Friction = InFriction;
        Restitution = InRestitution;
        LinearDamping = InLinearDamping;
        AngularDamping = InAngularDamping;
    }
}

// The pan's disc, where a piece counts as on it and beyond which it is lost; how long a lost body keeps flying and
// bouncing before it is destroyed.
struct FMars_Searing_LossSpec
{
    UPROPERTY()
    float32 PanRadius = 34.0f;

    UPROPERTY()
    float32 LingerSeconds = 2.5f;

    FMars_Searing_LossSpec() {}

    FMars_Searing_LossSpec(float32 InPanRadius, float32 InLingerSeconds)
    {
        PanRadius = InPanRadius;
        LingerSeconds = InLingerSeconds;
    }
}

// The pan's collision: the pan mesh itself (a triangle mesh; no simple collision on the asset, so CkJolt cooks the
// triangles), kinematic under the pan node so the node's motion moves it and gives it velocity. The mesh's own
// centimetres are multiplied by Scale at build time (a live body never rescales). Oiled: a piece's friction combines with
// Friction as sqrt(a * b).
struct FMars_Searing_PanBodySpec
{
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    float32 Scale = 1.0f;

    UPROPERTY()
    float32 Friction = 0.15f;

    UPROPERTY()
    float32 Restitution = 0.1f;

    FMars_Searing_PanBodySpec() {}

    FMars_Searing_PanBodySpec(TSoftObjectPtr<UStaticMesh> InMesh, float32 InScale)
    {
        Mesh = InMesh;
        Scale = InScale;
    }
}

// No mesh means no pan; a non-positive scale collapses it; a negative friction or a restitution outside [0, 1] is unphysical.
mixin FMars_Validation Validate(const FMars_Searing_PanBodySpec& Self)
{
    if (Self.Mesh.IsNull())
    { return FMars_Validation("Searing pan body has no Mesh"); }

    if (Self.Scale <= 0.0f)
    { return FMars_Validation(f"Searing pan body has a non-positive Scale [{Self.Scale}]"); }

    if (Self.Friction < 0.0f)
    { return FMars_Validation(f"Searing pan body has a negative Friction [{Self.Friction}]"); }

    if (Self.Restitution < 0.0f || Self.Restitution > 1.0f)
    { return FMars_Validation(f"Searing pan body has Restitution [{Self.Restitution}] outside [0, 1]"); }

    return FMars_Validation();
}

// Built by the placing script before Add: the pan is an Implement already composed on the pan node (the kernel drives it
// from the heat and forwards the looks to it), and PanBaseBody is the kinematic pan body (the pan mesh) under that node
// whose contacts count as "on the pan".
struct FMars_Searing_Nodes
{
    UPROPERTY()
    FCk_Handle_Implement Pan;

    UPROPERTY()
    FCk_Handle_JoltBody PanBaseBody;

    FMars_Searing_Nodes() {}

    FMars_Searing_Nodes(FCk_Handle_Implement InPan, FCk_Handle_JoltBody InPanBaseBody)
    {
        Pan = InPan;
        PanBaseBody = InPanBaseBody;
    }
}

struct FMars_Searing_Spec
{
    UPROPERTY()
    FMars_Searing_SupplySpec Supply;

    UPROPERTY()
    FMars_Searing_CookSpec Cook;

    UPROPERTY()
    FMars_Searing_PieceSpec Piece;

    UPROPERTY()
    FMars_Searing_LossSpec Loss;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Searing_Nodes Nodes;

    FMars_Searing_Spec() {}

    FMars_Searing_Spec(
        FMars_Searing_SupplySpec InSupply,
        FMars_Searing_CookSpec InCook,
        FMars_Searing_PieceSpec InPiece,
        FMars_Searing_LossSpec InLoss)
    {
        Supply = InSupply;
        Cook = InCook;
        Piece = InPiece;
        Loss = InLoss;
    }
}

// A pan that takes no piece, a face that never sears, a body surface outside the physical range, a contact that drops at
// once or a pan with no disc each make the minigame unplayable.
mixin FMars_Validation Validate(const FMars_Searing_Spec& Self)
{
    if (Self.Supply.MaxPieces <= 0)
    { return FMars_Validation(f"Searing has a non-positive Supply.MaxPieces [{Self.Supply.MaxPieces}]"); }

    if (Self.Cook.SecondsPerFace <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Cook.SecondsPerFace [{Self.Cook.SecondsPerFace}]"); }

    if (Self.Piece.Friction < 0.0f)
    { return FMars_Validation(f"Searing has a negative Piece.Friction [{Self.Piece.Friction}]"); }

    if (Self.Piece.Restitution < 0.0f || Self.Piece.Restitution > 1.0f)
    { return FMars_Validation(f"Searing has Piece.Restitution [{Self.Piece.Restitution}] outside [0, 1]"); }

    if (Self.Piece.LinearDamping < 0.0f)
    { return FMars_Validation(f"Searing has a negative Piece.LinearDamping [{Self.Piece.LinearDamping}]"); }

    if (Self.Piece.AngularDamping < 0.0f)
    { return FMars_Validation(f"Searing has a negative Piece.AngularDamping [{Self.Piece.AngularDamping}]"); }

    if (Self.Piece.ContactGraceSeconds <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Piece.ContactGraceSeconds [{Self.Piece.ContactGraceSeconds}]"); }

    if (Self.Loss.PanRadius <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Loss.PanRadius [{Self.Loss.PanRadius}]"); }

    if (Self.Loss.LingerSeconds < 0.0f)
    { return FMars_Validation(f"Searing has a negative Loss.LingerSeconds [{Self.Loss.LingerSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Searing_Params
{
    UPROPERTY()
    FMars_Searing_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// One adopted piece, keyed by the feed identity it arrived with (an array index is never identity). Its entity is the food
// piece's own (the kernel's guest: it keeps its lifetime) and carries the dynamic body and a Resting on the pan base body.
// Its geometry is read once, at admission, from its mesh's metrics: a cut piece's origin need not be its middle.
struct FMars_Searing_PieceState
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

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
    // pose request or teleport lands, so the Tick judges nothing about it until it is there (utils_searing::Get_HasArrived).
    UPROPERTY()
    TOptional<FVector> Arriving;

    // How long the piece has been arriving; past utils_searing::k_ArrivalMaxSeconds it is judged where it is.
    UPROPERTY()
    float32 ArrivingSeconds = 0.0f;

    // Six, 0 raw .. 1 seared, clamped, seeded from the piece's cook state; indexed by int32(EMars_Searing_Face).
    UPROPERTY()
    TArray<float32> FaceSear;

    // The face that last counted as resting on the pan (NegZ at admission: a piece arrives flat); a change is a flip.
    UPROPERTY()
    EMars_Searing_Face RestingFace = EMars_Searing_Face::NegZ;

    // How long another face has been down while on the pan; it becomes the resting face at k_FaceSettleSeconds.
    UPROPERTY()
    float32 CandidateSeconds = 0.0f;

    UPROPERTY()
    EMars_Searing_Contact Contact = EMars_Searing_Contact::Airborne;

    UPROPERTY()
    EMars_Searing_PieceStatus Status = EMars_Searing_PieceStatus::Cooking;

    // The last tenth OnSearProgress reported for this piece's face on the pan; -1 forces the next report.
    UPROPERTY()
    int32 LastProgressStep = -1;

    // Lost only: seconds since the loss; the piece is removed and its entity destroyed at Loss.LingerSeconds.
    UPROPERTY()
    float32 LingerSeconds = 0.0f;
}

struct FMars_Searing_Tally
{
    // Hot while any piece is Cooking, since the last reset.
    UPROPERTY()
    float32 Seconds = 0.0f;

    // Changes of the face a cooking piece rests on (a new down face held for utils_searing::k_FaceSettleSeconds), all pieces.
    UPROPERTY()
    int32 Flips = 0;

    UPROPERTY()
    int32 Losses = 0;

    // Pieces handed back by TakeOut.
    UPROPERTY()
    int32 TakenOut = 0;
}

// Every piece on the pan is Cooking or Ready, and every piece lost or taken out since the last reset stays counted
// (a reset keeps the pan's pieces): Admitted = Cooking + Ready + Lost + TakenOut.
struct FMars_Searing_Summary
{
    UPROPERTY()
    int32 Admitted = 0;

    UPROPERTY()
    int32 Cooking = 0;

    UPROPERTY()
    int32 Ready = 0;

    UPROPERTY()
    int32 Lost = 0;

    UPROPERTY()
    int32 TakenOut = 0;
}

// Written only by the Searing processors (and Add). The station SM, the feed bridge and the operator only issue requests.
struct FMars_Fragment_Searing
{
    // In admission order. Lost pieces stay while they linger (one array, one identity space).
    UPROPERTY()
    TArray<FMars_Searing_PieceState> Pieces;

    UPROPERTY()
    FMars_Searing_Tally Tally;

    UPROPERTY()
    EMars_Searing_Heat Heat = EMars_Searing_Heat::Cold;

    // Aggregate over every piece.
    UPROPERTY()
    EMars_Searing_Sizzle Sizzle = EMars_Searing_Sizzle::Quiet;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A SetHeat that changed it; a Reset that found it Hot. Station-level: no piece.
delegate void FMars_Delegate_Searing_OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat);
event void FMars_Delegate_Searing_OnHeatChanged_MC(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat);

// The answer to every AddPiece: Accepted (the piece is on the pan's books; OnPieceAdded follows) or Rejected with a reason
// (the piece is left as it was).
delegate void FMars_Delegate_Searing_OnPieceAdmission(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);
event void FMars_Delegate_Searing_OnPieceAdmission_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);

// An adopted piece is on the pan's books (its body requested or switched back to Dynamic, not yet moving): the placing
// script adds its visuals here.
delegate void FMars_Delegate_Searing_OnPieceAdded(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Searing_OnPieceAdded_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

// One piece's OnPan <-> Airborne edges (the toss and the landing).
delegate void FMars_Delegate_Searing_OnPanContactChanged(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Contact InContact);
event void FMars_Delegate_Searing_OnPanContactChanged_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Contact InContact);

// Quantized at tenths, for one piece's face on the pan.
delegate void FMars_Delegate_Searing_OnSearProgress(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, float32 InAlpha);
event void FMars_Delegate_Searing_OnSearProgress_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, float32 InAlpha);

delegate void FMars_Delegate_Searing_OnFaceSeared(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace);
event void FMars_Delegate_Searing_OnFaceSeared_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace);

// A piece's sixth seared face: that piece is Ready (the others keep cooking). InTally is the kernel's tally at that moment.
delegate void FMars_Delegate_Searing_OnPieceReady(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FMars_Searing_Tally InTally);
event void FMars_Delegate_Searing_OnPieceReady_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FMars_Searing_Tally InTally);

// A piece left the pan; InPiece lingers and is destroyed later. Nothing replaces it.
delegate void FMars_Delegate_Searing_OnPieceLost(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Searing_OnPieceLost_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

// Edge only, aggregate: Sizzling while Hot and any cooking piece lies on the pan on a face not yet seared.
delegate void FMars_Delegate_Searing_OnSizzleChanged(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle);
event void FMars_Delegate_Searing_OnSizzleChanged_MC(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle);

// A TakeOut handed InPiece back: off the pan's books, its cook state written, its body Kinematic. Control loads it where it
// goes next.
delegate void FMars_Delegate_Searing_OnPieceTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_Searing_OnPieceTakenOut_MC(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);

struct FMars_Fragment_Searing_Signals
{
    FMars_Delegate_Searing_OnHeatChanged_MC OnHeatChanged;
    FMars_Delegate_Searing_OnPieceAdmission_MC OnPieceAdmission;
    FMars_Delegate_Searing_OnPieceAdded_MC OnPieceAdded;
    FMars_Delegate_Searing_OnPanContactChanged_MC OnPanContactChanged;
    FMars_Delegate_Searing_OnSearProgress_MC OnSearProgress;
    FMars_Delegate_Searing_OnFaceSeared_MC OnFaceSeared;
    FMars_Delegate_Searing_OnPieceReady_MC OnPieceReady;
    FMars_Delegate_Searing_OnPieceLost_MC OnPieceLost;
    FMars_Delegate_Searing_OnSizzleChanged_MC OnSizzleChanged;
    FMars_Delegate_Searing_OnPieceTakenOut_MC OnPieceTakenOut;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// One drained InputIntents look delta (degrees; X yaw right+, Y pitch down+). Forwarded to the pan while hot.
struct FMars_Request_Searing_Look
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_Searing_Look() {}

    FMars_Request_Searing_Look(FVector InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// Last wins within a drain.
struct FMars_Request_Searing_SetHeat
{
    UPROPERTY()
    EMars_Searing_Heat Heat = EMars_Searing_Heat::Cold;

    FMars_Request_Searing_SetHeat() {}

    FMars_Request_Searing_SetHeat(EMars_Searing_Heat InHeat)
    {
        Heat = InHeat;
    }
}

// Resets the pan (level, idle), chills it and zeroes the tally; every piece stays on the pan with its sear (the player's
// food is theirs). Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Searing_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Searing_Reset() {}
}

// Hands pieces back, each with its cook state written and its body Kinematic, answered by OnPieceTakenOut per piece. Piece
// set: that piece, if it is on the pan and not lost; unset: every Ready piece in admission order. MaxPieces set: at most
// that many leave.
struct FMars_Request_Searing_TakeOut
{
    UPROPERTY()
    TOptional<FCk_Handle_FoodPiece> Piece;

    UPROPERTY()
    TOptional<int32> MaxPieces;

    FMars_Request_Searing_TakeOut() {}

    FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece> InPiece, TOptional<int32> InMaxPieces)
    {
        Piece = InPiece;
        MaxPieces = InMaxPieces;
    }
}

// One released piece to adopt (Release.Piece), answered by OnPieceAdmission. Rejected (the piece left as it was) while the
// pan body is not yet in the simulation, when the release names no live piece, a piece not Ready, one already on the pan,
// one still on its platter or still attached, when a piece on the pan (lingering lost ones included) already carries the
// Id, or when Supply.MaxPieces live pieces are on it. A cold pan accepts (it just does not sear).
struct FMars_Request_Searing_AddPiece
{
    UPROPERTY()
    FMars_CookingFeed_Release Release;

    FMars_Request_Searing_AddPiece() {}

    FMars_Request_Searing_AddPiece(FMars_CookingFeed_Release InRelease)
    {
        Release = InRelease;
    }
}

// Applied Reset -> SetHeat -> TakeOut -> AddPiece -> Look, so a reset and the first heat, pieces and looks of a new session
// can share a drain, and a take-out frees its place before the next admission.
struct FMars_Fragment_Searing_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Searing_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_SetHeat> SetHeatRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_TakeOut> TakeOutRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_AddPiece> AddPieceRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_Look> LookRequests;
}
