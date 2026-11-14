namespace utils_searing
{
    // utils_foodpiece::k_FaceCount (the owner: FoodPiece is the lower kernel), repeated because an AngelScript namespace
    // constant cannot be initialized from another file's.
    const int32 k_FaceCount = 6;
    const int32 k_SearSignalSteps = 10;
    // The cooking surface's height in the pan body's frame: the pan node sits at the centre of that surface (the pan mesh's
    // pivot), so a piece is judged relative to Z 0.
    const float32 k_PanSurfaceZ = 0.0f;
    // The pan body's mass: see Add_PanBody.
    const float32 k_PanBodyMassKg = 1.0f;
    // How long a new down face must stay down on the pan before it is the resting face (a flip): a tumbling cube passes
    // other faces down for a frame or two, and neither the liftoff nor the first contact shows the face it settles on.
    const float32 k_FaceSettleSeconds = 0.1f;

    // Composes the minigame on InHandle (the station entity; the feature does not need the Station feature), and the
    // station's admission inbox and take-out readout. The spec's Nodes are built by the caller: Nodes.Pan is the
    // Implement on the pan node (the kernel makes it Driven while hot and forwards the looks to it), and a piece counts
    // as on the pan only while it rests on Nodes.PanBaseBody. The pan starts empty: pieces arrive only through the
    // station's inbox (utils_cooking_feed::Request_Admit); an empty first drain starts its watch of the station's
    // queue. A rejected spec or a missing node ensures and returns an invalid handle. The two replicated ledgers are
    // composed on every machine (a copy without authority reads the kernel and follows the pan through them); a ledger
    // that arrived before is the state this copy was born into, and it has then taken it.
    FCk_Handle_Searing Add(FCk_Handle& InHandle, FMars_Searing_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Searing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Searing(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Pan) && ck::IsValid(InSpec.Nodes.PanBaseBody),
            f"[Searing] [{InHandle.ToString()}] needs a pan implement and a pan base body"))
        { return FCk_Handle_Searing(); }

        auto Params = FMars_Fragment_Searing_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Searing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Searing());
        InHandle.Add_Fragment(FMars_Fragment_Searing_Requests());
        utils_cooking_feed::Add_Admission(InHandle);
        utils_cooking_feed::Add_TakeOut(InHandle);

        // A ledger already here can only have been put here by its replicated application: this copy was born into it,
        // has taken that state, and the mirror's first pass shows it as it stands; each ledger is its own application.
        auto Local = FMars_Fragment_Searing_Local();
        if (InHandle.Has_Fragment(FMars_Fragment_Searing_Net))
        { Local.InitialState = EMars_Net_InitialState::Taken; }
        else
        { InHandle.Add_Fragment(FMars_Fragment_Searing_Net(), ECk_Replication::Replicates); }

        if (InHandle.Has_Fragment(FMars_Fragment_Searing_PanNet))
        { Local.PanInitialState = EMars_Net_InitialState::Taken; }
        else
        { InHandle.Add_Fragment(FMars_Fragment_Searing_PanNet(), ECk_Replication::Replicates); }

        // The mirror compares what arrives against the ledger this machine composed.
        Local.Last = TOptional<FMars_Fragment_Searing_Net>(FMars_Fragment_Searing_Net());
        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Searing_NeedsMirror());
        return InHandle.As_Searing();
    }

    // The kinematic pan body on its own child node at the pan node's origin (a body needs its own entity). The body is
    // created after its mesh preloads: callers that need it read utils_jolt_body::Get_IsBodyAdded. A rejected spec ensures
    // and returns an invalid handle.
    FCk_Handle_JoltBody Add_PanBody(FCk_Handle_SceneNode& InPanNode, const FMars_Searing_PanBodySpec& InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Searing] [{InPanNode.ToString()}] rejected the pan body spec: {Validation.Get_Error()}"))
        { return FCk_Handle_JoltBody(); }

        auto BodyNode = utils_scene_node::Create(InPanNode.As_Transform(), FTransform::Identity);

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::StaticMeshAsset);
        BodySpec.Set_StaticMesh(InSpec.Mesh);
        BodySpec.Set_ShapeScale(FVector(InSpec.Scale, InSpec.Scale, InSpec.Scale));
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        // Jolt asserts a positive mass even on a kinematic body, and a mesh shape computes none; the value is never used.
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_PanBodyMassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(InSpec.Friction);
        BodySpec.Set_Restitution(InSpec.Restitution);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(BodyNode.H(), BodySpec);
    }

    // The index of the piece carrying InPieceId (lingering lost ones included); -1 = none. Internal to the kernel: callers
    // outside it address pieces by identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Searing_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The index of the piece whose entity is InPiece (lingering lost ones included); -1 = none.
    int32 Find_PieceIndexByHandle(const TArray<FMars_Searing_PieceState>& InPieces, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Piece == InPiece)
            { return Index; }
        }

        return -1;
    }

    // Pieces not Lost (cooking or ready).
    int32 Get_LivePieceCount(const TArray<FMars_Searing_PieceState>& InPieces)
    {
        auto Count = 0;
        for (const auto& Piece : InPieces)
        {
            if (Piece.Status != EMars_Searing_PieceStatus::Lost)
            { Count += 1; }
        }

        return Count;
    }

    int32 Get_SearedFaceCount(const TArray<float32>& InFaceSear)
    {
        auto Count = 0;
        for (const auto Sear : InFaceSear)
        {
            if (Sear >= 1.0f)
            { Count += 1; }
        }

        return Count;
    }

    // How far the piece may reach from its middle sideways, whatever its rotation about the vertical (conservative).
    float64 Get_RadialExtent(const FVector& InHalfExtents)
    {
        return InHalfExtents.GetMax();
    }

    // The mean of the piece's two half extents across the pan with InDownFace on it (the axis through that face stands
    // up): what its footprint spans. A cube's is its own half whatever face is down; a cut half standing on its end covers
    // less of the pan than lying flat.
    float64 Get_FootprintHalf(const FVector& InHalfExtents, EMars_FoodPiece_Face InDownFace)
    {
        const auto Normal = utils_foodpiece::Get_FaceNormal(InDownFace);
        if (Math::Abs(Normal.X) > 0.5)
        { return (InHalfExtents.Y + InHalfExtents.Z) * 0.5; }

        if (Math::Abs(Normal.Y) > 0.5)
        { return (InHalfExtents.X + InHalfExtents.Z) * 0.5; }

        return (InHalfExtents.X + InHalfExtents.Y) * 0.5;
    }

    bool Get_IsSameLedger(const FMars_Fragment_Searing_Net& InA, const FMars_Fragment_Searing_Net& InB)
    {
        if (InA.Heat != InB.Heat || InA.Sizzle != InB.Sizzle || InA.Counts.Flips != InB.Counts.Flips
            || InA.Counts.Losses != InB.Counts.Losses || InA.Counts.TakenOut != InB.Counts.TakenOut
            || InA.Pieces.Num() != InB.Pieces.Num() || InA.TakeOutRefusalSerial != InB.TakeOutRefusalSerial
            || InA.LastTakeOutRefusal != InB.LastTakeOutRefusal)
        { return false; }

        for (int32 Index = 0; Index < InA.Pieces.Num(); ++Index)
        {
            const auto& A = InA.Pieces[Index];
            const auto& B = InB.Pieces[Index];
            if (A.Id.Get_IsSame(B.Id) == false || A.Piece != B.Piece || A.Status != B.Status || A.Contact != B.Contact
                || A.RestingFace != B.RestingFace || Get_IsSameSears(A.FaceSear, B.FaceSear) == false)
            { return false; }
        }

        return true;
    }

    bool Get_IsSameSears(const TArray<float32>& InA, const TArray<float32>& InB)
    {
        if (InA.Num() != InB.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.Num(); ++Index)
        {
            if (InA[Index] != InB[Index])
            { return false; }
        }

        return true;
    }

    // The kernel's ledger a machine without authority reads it through, rebuilt from the live state and what the caller
    // announced: written and marked dirty only when a field or a row differs. Called only by the kernel's processors on the
    // authority, by the drain once after its last apply and by the tick after its readout. Reads the state through the
    // handle.
    void Publish(FCk_Handle_Searing& InSearing, const FMars_Searing_Answers& InAnswers)
    {
        const auto State = InSearing.Get_Fragment(FMars_Fragment_Searing);
        const auto Ledger = InSearing.Get_Fragment(FMars_Fragment_Searing_Net);
        auto Next = Ledger;
        Next.Heat = State.Heat;
        Next.Sizzle = State.Sizzle;
        Next.Counts.Flips = State.Tally.Flips;
        Next.Counts.Losses = State.Tally.Losses;
        Next.Counts.TakenOut = State.Tally.TakenOut;

        Next.Pieces.Empty();
        for (const auto& Piece : State.Pieces)
        { Next.Pieces.Add(Make_PieceRow(Piece)); }

        if (InAnswers.TakeOutRefusals.Num() > 0)
        {
            Next.TakeOutRefusalSerial += InAnswers.TakeOutRefusals.Num();
            Next.LastTakeOutRefusal = InAnswers.TakeOutRefusals.Last();
        }

        if (Get_IsSameLedger(Next, Ledger))
        { return; }

        InSearing.Get_Fragment(FMars_Fragment_Searing_Net) = Next;
        FCk_Handle Entity = InSearing;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Searing_Net);
    }

    // The pan's command, written and marked dirty only when the pacer says it is worth sending (utils_implement::
    // Advance_CommandPacer). Called only by the kernel's tick on the authority, after Publish.
    void Publish_Pan(FCk_Handle_Searing& InSearing, float32 InDeltaSeconds)
    {
        const auto Command = InSearing.Get_Pan().Get_Command();
        auto Pacer = InSearing.Get_Fragment(FMars_Fragment_Searing_Local).PanPacer;
        const auto IsDue = utils_implement::Advance_CommandPacer(Pacer, Command, InDeltaSeconds);
        InSearing.Get_Fragment(FMars_Fragment_Searing_Local).PanPacer = Pacer;
        if (IsDue == false)
        { return; }

        InSearing.Get_Fragment(FMars_Fragment_Searing_PanNet).Pan = Command;
        FCk_Handle Entity = InSearing;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Searing_PanNet);
    }

    // A piece as the ledger carries it: its sears floored to a tenth (a client's sear reads up to a tenth behind, never
    // ahead), exactly 1 once seared.
    FMars_Searing_PieceRow Make_PieceRow(const FMars_Searing_PieceState& InPiece)
    {
        auto Row = FMars_Searing_PieceRow();
        Row.Id = InPiece.Id;
        Row.Piece = InPiece.Entity;
        Row.Status = InPiece.Status;
        Row.Contact = InPiece.Contact;
        Row.RestingFace = InPiece.RestingFace;
        for (const auto Sear : InPiece.FaceSear)
        { Row.FaceSear.Add(Sear >= 1.0f ? 1.0f : float32(Math::FloorToInt(Sear * float32(k_SearSignalSteps))) / float32(k_SearSignalSteps)); }

        return Row;
    }

    // The ledger row carrying InPieceId; -1 = none.
    int32 Find_RowIndex(const TArray<FMars_Searing_PieceRow>& InRows, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InRows.Num(); ++Index)
        {
            if (InRows[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The cook state InPiece's sear makes of InSeed (the state the piece arrived with): the sears are the pan's; every
    // other channel is the seed's.
    FMars_FoodPiece_CookState Get_CookState(const FMars_Searing_PieceState& InPiece, const FMars_FoodPiece_CookState& InSeed)
    {
        auto CookState = InSeed;
        CookState.Sear = InPiece.FaceSear;
        return CookState;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Searing_Spec Get_Spec(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing_Params).Spec;
}

// The kernel's replicated ledger as this machine has it: what a machine without authority reads the kernel through.
mixin FMars_Fragment_Searing_Net Get_Ledger(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing_Net);
}

// The pan's replicated command as this machine has it: what a machine without authority's pan follows.
mixin FMars_Fragment_Searing_PanNet Get_PanLedger(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing_PanNet);
}

// Without authority the getters below that read the kernel's state read the replicated ledger instead (and this machine's
// own copies of the pieces): the live state is the authority's.
mixin bool Get_ReadsLedger(const FCk_Handle_Searing& Self)
{
    return utils_net::Get_HasAuthority(Self) == false;
}

mixin bool Get_IsHot(const FCk_Handle_Searing& Self)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_Fragment(FMars_Fragment_Searing_Net).Heat == EMars_Searing_Heat::Hot; }

    return Self.Get_Fragment(FMars_Fragment_Searing).Heat == EMars_Searing_Heat::Hot;
}

// The Implement the pan node carries.
mixin FCk_Handle_Implement Get_Pan(const FCk_Handle_Searing& Self)
{
    return Self.Get_Spec().Nodes.Pan;
}

// FRotator(Pitch, 0, Roll), degrees, on top of the pan's rest rotation.
mixin FRotator Get_PanTilt(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Tilt();
}

mixin float32 Get_PanLift(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Lift();
}

// The pan base body's world transform as of the last transform update.
mixin FTransform Get_PanBaseWorld(const FCk_Handle_Searing& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Spec().Nodes.PanBaseBody.As_Transform());
}

mixin FVector Get_PanUp(const FCk_Handle_Searing& Self)
{
    return Self.Get_PanBaseWorld().GetRotation().GetUpVector();
}

// Aggregate over every piece.
mixin EMars_Searing_Sizzle Get_Sizzle(const FCk_Handle_Searing& Self)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_Fragment(FMars_Fragment_Searing_Net).Sizzle; }

    return Self.Get_Fragment(FMars_Fragment_Searing).Sizzle;
}

// Without authority: the ledger's counts, with Seconds 0 (the clock stays with the authority).
mixin FMars_Searing_Tally Get_Tally(const FCk_Handle_Searing& Self)
{
    if (Self.Get_ReadsLedger() == false)
    { return Self.Get_Fragment(FMars_Fragment_Searing).Tally; }

    const auto& Counts = Self.Get_Fragment(FMars_Fragment_Searing_Net).Counts;
    auto Tally = FMars_Searing_Tally();
    Tally.Flips = Counts.Flips;
    Tally.Losses = Counts.Losses;
    Tally.TakenOut = Counts.TakenOut;
    return Tally;
}

// Admitted = Cooking + Ready (on the pan) + Lost + TakenOut (since the last reset; a lost piece stays counted after its
// body is destroyed). Without authority the same rule over the ledger's rows and counts.
mixin FMars_Searing_Summary Get_Summary(const FCk_Handle_Searing& Self)
{
    auto Summary = FMars_Searing_Summary();
    if (Self.Get_ReadsLedger())
    {
        const auto& Ledger = Self.Get_Fragment(FMars_Fragment_Searing_Net);
        for (const auto& Row : Ledger.Pieces)
        {
            if (Row.Status == EMars_Searing_PieceStatus::Cooking)
            { Summary.Cooking += 1; }
            else if (Row.Status == EMars_Searing_PieceStatus::Ready)
            { Summary.Ready += 1; }
        }

        Summary.Lost = Ledger.Counts.Losses;
        Summary.TakenOut = Ledger.Counts.TakenOut;
        Summary.Admitted = Summary.Cooking + Summary.Ready + Summary.Lost + Summary.TakenOut;
        return Summary;
    }

    const auto& State = Self.Get_Fragment(FMars_Fragment_Searing);
    for (const auto& Piece : State.Pieces)
    {
        if (Piece.Status == EMars_Searing_PieceStatus::Cooking)
        { Summary.Cooking += 1; }
        else if (Piece.Status == EMars_Searing_PieceStatus::Ready)
        { Summary.Ready += 1; }
    }

    Summary.Lost = State.Tally.Losses;
    Summary.TakenOut = State.Tally.TakenOut;
    Summary.Admitted = Summary.Cooking + Summary.Ready + Summary.Lost + Summary.TakenOut;
    return Summary;
}

// The Ready pieces a TakeOut without a named piece would hand back: the station's take-out readout as the Tick last wrote
// it, or its replicated count without authority.
mixin int32 Get_TakeableCount(const FCk_Handle_Searing& Self)
{
    return utils_cooking_feed::Get_TakeableCount(Self);
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece on the pan in admission order, the lingering lost ones included.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Searing& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    if (Self.Get_ReadsLedger())
    {
        for (const auto& Row : Self.Get_Fragment(FMars_Fragment_Searing_Net).Pieces)
        { Ids.Add(Row.Id); }

        return Ids;
    }

    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Searing).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

// From admission until the piece is taken out or destroyed (a lost one, at the end of its linger).
mixin bool Get_HasPiece(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    if (Self.Get_ReadsLedger())
    { return utils_searing::Find_RowIndex(Self.Get_Fragment(FMars_Fragment_Searing_Net).Pieces, InPieceId) >= 0; }

    return utils_searing::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Searing).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state. Without authority it is built from the
// ledger's row (its sears a tenth behind at most) and this machine's copy of the piece.
mixin FMars_Searing_PieceState Get_PieceState(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_LedgerPieceState(InPieceId); }

    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Searing).Pieces;
    const auto Index = utils_searing::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Searing] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} on the pan)"))
    { return FMars_Searing_PieceState(); }

    return Pieces[Index];
}

// The row's id, status, contact, resting face and sears; its Entity and Piece the row's handle (invalid while it has not
// replicated here); its CentreLocal and HalfExtents from this copy's mesh metrics, as the authority reads them at admission,
// once it is a Ready food piece here (zero before); no body.
mixin FMars_Searing_PieceState Get_LedgerPieceState(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Rows = Self.Get_Fragment(FMars_Fragment_Searing_Net).Pieces;
    const auto Index = utils_searing::Find_RowIndex(Rows, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Searing] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} in its ledger ({Rows.Num()} on the pan)"))
    { return FMars_Searing_PieceState(); }

    const auto Row = Rows[Index];
    auto State = FMars_Searing_PieceState();
    State.Id = Row.Id;
    State.Entity = Row.Piece;
    State.Status = Row.Status;
    State.Contact = Row.Contact;
    State.RestingFace = Row.RestingFace;
    State.FaceSear = Row.FaceSear;
    if (ck::IsValid(Row.Piece))
    { State.Piece = Row.Piece.As_FoodPiece(ECk_SanityCheck::UnChecked); }

    if (ck::IsValid(State.Piece) && utils_foodpiece::Get_IsLiveEntity(Row.Piece) && State.Piece.Get_Status() == EMars_FoodPiece_Status::Ready)
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(State.Piece.Get_Geometry());
        State.CentreLocal = utils_foodpiece::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_foodpiece::Get_BoundsHalfExtents(Metrics);
    }

    return State;
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

mixin FCk_Handle_FoodPiece Get_PieceHandle(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Piece;
}

// Half the piece's bounds along its own axes, as read at admission.
mixin FVector Get_PieceHalfExtents(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).HalfExtents;
}

// The middle of the piece's bounds in the world; zero once its entity is gone.
mixin FVector Get_PieceCentre(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    if (ck::Is_NOT_Valid(Piece.Entity))
    { return FVector::ZeroVector; }

    const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Piece.Entity.As_Transform());
    return PieceWorld.TransformPosition(Piece.CentreLocal);
}

mixin FCk_Handle_JoltBody Get_PieceBody(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Body;
}

mixin EMars_Searing_PieceStatus Get_PieceStatus(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Status;
}

mixin EMars_Searing_Contact Get_PieceContact(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Contact;
}

// The piece's cook state as the pan would hand it back now: its sears so far.
mixin FMars_FoodPiece_CookState Get_PieceCookState(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    // A copy without authority can still hold the row of a piece that ended this frame: its sears then start from raw.
    const auto Base = utils_foodpiece::Get_IsLiveEntity(Piece.Piece) ? Piece.Piece.Get_CookState() : FMars_FoodPiece_CookState();
    return utils_searing::Get_CookState(Piece, Base);
}

// 0 raw .. 1 seared.
mixin float32 Get_FaceSear(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_FoodPiece_Face InFace)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    const auto Index = int32(InFace);
    if (Piece.FaceSear.IsValidIndex(Index) == false)
    { return 0.0f; }

    return Piece.FaceSear[Index];
}

mixin int32 Get_SearedFaceCount(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_searing::Get_SearedFaceCount(Self.Get_PieceState(InPieceId).FaceSear);
}

// The middle of the piece's bounds in the pan base body's frame (the cooking surface is at Z = utils_searing::k_PanSurfaceZ);
// zero once its entity is gone.
mixin FVector Get_PiecePanLocal(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Entity = Self.Get_PieceEntity(InPieceId);
    if (ck::Is_NOT_Valid(Entity))
    { return FVector::ZeroVector; }

    return Self.Get_PanBaseWorld().InverseTransformPosition(Self.Get_PieceCentre(InPieceId));
}

// The piece face pointing most against the pan's up; NegZ once its entity is gone.
mixin EMars_FoodPiece_Face Get_DownFace(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Entity = Self.Get_PieceEntity(InPieceId);
    if (ck::Is_NOT_Valid(Entity))
    { return EMars_FoodPiece_Face::NegZ; }

    const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    return utils_foodpiece::Get_DownFace(PieceWorld.GetRotation(), Self.Get_PanUp());
}

// The piece's footprint half on the pan now (utils_searing::Get_FootprintHalf over its own half extents and its down face).
mixin float64 Get_PieceFootprintHalf(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_searing::Get_FootprintHalf(Self.Get_PieceHalfExtents(InPieceId), Self.Get_DownFace(InPieceId));
}

mixin bool Get_IsDownFaceSeared(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_FaceSear(InPieceId, Self.Get_DownFace(InPieceId)) >= 1.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Look(FCk_Handle_Searing& Self, const FMars_Request_Searing_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.LookRequests.Add(InRequest);
}

mixin void Request_SetHeat(FCk_Handle_Searing& Self, const FMars_Request_Searing_SetHeat& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.SetHeatRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Searing& Self, const FMars_Request_Searing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_TakeOut(FCk_Handle_Searing& Self, const FMars_Request_Searing_TakeOut& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.TakeOutRequests.Add(InRequest);
}

mixin void Request_Readopt(FCk_Handle_Searing& Self, const FMars_Request_Searing_Readopt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.ReadoptRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnHeatChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPanContactChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPanContactChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSearProgress.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSearProgress.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnFaceSeared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceReady(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceReady(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceLost InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSizzleChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSizzleChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceTakenOut(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceTakenOut InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceTakenOut.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceTakenOut(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceTakenOut InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceTakenOut.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnAdmissionRefused(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnAdmissionRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnAdmissionRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAdmissionRefused(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnAdmissionRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnAdmissionRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTakeOutRefused(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnTakeOutRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnTakeOutRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTakeOutRefused(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnTakeOutRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnTakeOutRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
