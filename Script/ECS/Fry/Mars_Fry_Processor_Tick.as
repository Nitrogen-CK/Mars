// What every step of one Fry's tick reads: the kernel, its spec, the frame's real time, and the station, basket and scoop
// frames as of the last transform update.
struct FMars_Fry_Frame
{
    FCk_Handle_Fry Fry;
    FMars_Fry_Spec Spec;
    float32 DeltaSeconds = 0.0f;
    FTransform RootWorld;
    FTransform BasketWorld;
    FTransform ScoopWorld;
}

// One piece's edges this frame, broadcast once the whole tick applied (so a handler reads the written state).
struct FMars_Fry_PieceEvents
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle Entity;
    // Set when the whereabouts changed: where it was; To is where it is now, HopStart where its hop (if any) started.
    TOptional<EMars_Fry_Whereabouts> From;
    EMars_Fry_Whereabouts To = EMars_Fry_Whereabouts::Airborne;
    EMars_Fry_Whereabouts HopStart = EMars_Fry_Whereabouts::Oil;
    // In parallel: each face that crossed a stage this frame and the stage it reached.
    TArray<EMars_Searing_Face> StageFaces;
    TArray<EMars_Fry_HeatStage> Stages;
    bool Drained = false;
}

// Every frame, in order: the oil's buoyancy and drag on every piece in it (wherever it is, the basket's whereabouts never
// matter), then each live piece in admission order: its whereabouts (edges, counted in the tally), the heat of its faces
// below the oil line while it is in the oil or on the scoop (stage edges), and its drain while it rests on the basket floor
// inside the basket; then the lingering lost bodies age (and are destroyed at Zones.LingerSeconds), the frying time, and the
// pieces' edges last. The skimmer moves itself (an Implement); Jolt owns every piece's pose; the kernel reads it back through
// the entity transform and only pushes on it. Nothing is ever spawned here: pieces arrive only through AddPiece.
class UMars_Processor_Fry_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // CkJolt steps a fixed 60 Hz at most four times per frame and drops the rest, so a frame's buoyancy impulse covers at
    // most this much simulated time: a long frame (a hitch) must not hand a piece the whole frame's worth of lift.
    private const float32 k_MaxPhysicsStepSeconds = 4.0f / 60.0f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fry);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Fry& InState)
    {
        auto Frame = FMars_Fry_Frame();
        Frame.Fry = InHandle.As_Fry();
        Frame.Spec = Frame.Fry.Get_Spec();
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Frame.RootWorld = Frame.Fry.Get_RootWorld();
        Frame.BasketWorld = Frame.Fry.Get_BasketWorld();
        Frame.ScoopWorld = Frame.Fry.Get_ScoopWorld();

        Advance_Buoyancy(Frame, InState);

        TArray<FMars_Fry_PieceEvents> Events;
        for (int32 Index = 0; Index < InState.Pieces.Num(); ++Index)
        {
            auto Piece = InState.Pieces[Index];
            // A lost piece only lingers; a piece whose entity is gone is going with a station torn down around it.
            if (Piece.Whereabouts == EMars_Fry_Whereabouts::Lost || ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            auto PieceEvents = FMars_Fry_PieceEvents();
            PieceEvents.Id = Piece.Id;
            PieceEvents.Entity = Piece.Entity;

            Advance_Whereabouts(Frame, Piece, PieceEvents);
            Advance_Heat(Frame, Piece, PieceEvents);
            Advance_Drain(Frame, Piece, PieceEvents);
            InState.Pieces[Index] = Piece;

            Count_Edge(Frame, InState, PieceEvents);
            Events.Add(PieceEvents);
        }

        Advance_Lingering(Frame, InState);
        Advance_Tally(Frame, InState);
        Broadcast_PieceEvents(Frame, Events);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Physics
    //----------------------------------------------------------------------------------------------------------------------

    // Every piece not lost whose body reaches below the oil line inside the pot is lifted by the oil it displaces and dragged
    // by it, both scaled by its immersion, whatever its whereabouts (a piece on a dipped scoop floats off it). Applied as an
    // impulse of force x frame time: CkJolt hands a force to Jolt's accumulator, which only the next fixed physics step
    // consumes, so a per-frame force is lost or summed whenever frames and steps do not pair one to one.
    private void Advance_Buoyancy(FMars_Fry_Frame& InFrame, FMars_Fragment_Fry& InState)
    {
        if (InFrame.DeltaSeconds <= 0.0f)
        { return; }

        const auto Up = InFrame.RootWorld.GetRotation().GetUpVector();
        const auto& Oil = InFrame.Spec.Oil;
        const auto& PieceSpec = InFrame.Spec.Piece;
        const auto Mass = float64(PieceSpec.MassKg);
        const auto StepSeconds = Math::Min(InFrame.DeltaSeconds, k_MaxPhysicsStepSeconds);

        for (const auto& Piece : InState.Pieces)
        {
            if (Piece.Whereabouts == EMars_Fry_Whereabouts::Lost || ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            const auto Centre = Get_RootLocal(InFrame, Piece.Entity);
            if (float32(Centre.Size2D()) > InFrame.Spec.Zones.PotRadius)
            { continue; }

            const auto Immersion = utils_fry::Get_Immersion(float32(Centre.Z), PieceSpec.HalfSize, Oil.SurfaceZ);
            if (Immersion <= 0.0f)
            { continue; }

            auto Body = Piece.Body;
            const auto Velocity = utils_jolt_body::Get_LinearVelocity(Body);
            const auto Force = Up * (Mass * float64(Oil.BuoyancyAccel * Immersion)) - Velocity * (Mass * float64(Oil.Drag * Immersion));
            utils_jolt_body::Request_AddImpulse(Body, FCk_Request_JoltBody_AddImpulse(Force * float64(StepSeconds)));
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Piece lifecycle
    //----------------------------------------------------------------------------------------------------------------------

    // First match wins: Lost (terminal: below the floor, or outside the pot below its rim and off the basket's footprint),
    // Skimmer (resting on the scoop disc and inside the bowl, wherever the scoop is: a carried piece over the basket is still
    // on the skimmer), DrainBasket (inside the basket interior), Oil (its bottom below the oil line within the pot), else
    // Airborne. The last whereabouts other than Airborne is remembered (where a hop started); leaving the basket resets the
    // drain, a drained piece's too.
    private void Advance_Whereabouts(FMars_Fry_Frame& InFrame, FMars_Fry_PieceState& InPiece, FMars_Fry_PieceEvents& OutEvents)
    {
        const auto& Spec = InFrame.Spec;
        const auto& Zones = Spec.Zones;
        const auto HalfSize = Spec.Piece.HalfSize;
        const auto PieceWorld = utils_transform::Get_EntityCurrentLocation(InPiece.Entity.As_Transform());
        const auto Root = InFrame.RootWorld.InverseTransformPosition(PieceWorld);
        const auto BasketLocal = InFrame.BasketWorld.InverseTransformPosition(PieceWorld);
        const auto InsidePot = float32(Root.Size2D()) <= Zones.PotRadius;
        const auto Resting = InPiece.Entity.As_Resting();

        auto To = EMars_Fry_Whereabouts::Airborne;
        if (float32(Root.Z) < Zones.FloorZ
            || (InsidePot == false && float32(Root.Z) < Zones.RimZ && utils_fry::Get_IsOverBasketFootprint(Spec.Basket, BasketLocal) == false))
        { To = EMars_Fry_Whereabouts::Lost; }
        else if (Resting.Get_IsRestingOn(Spec.Nodes.ScoopBody)
            && utils_fry::Get_IsInsideBowl(Spec.Scoop, InFrame.ScoopWorld.InverseTransformPosition(PieceWorld), HalfSize))
        { To = EMars_Fry_Whereabouts::Skimmer; }
        else if (utils_fry::Get_IsInsideBasket(Spec.Basket, BasketLocal, HalfSize))
        { To = EMars_Fry_Whereabouts::DrainBasket; }
        else if (float32(Root.Z) - HalfSize < Spec.Oil.SurfaceZ && InsidePot)
        { To = EMars_Fry_Whereabouts::Oil; }

        const auto From = InPiece.Whereabouts;
        if (To == From)
        { return; }

        OutEvents.From = From;
        OutEvents.To = To;
        OutEvents.HopStart = InPiece.LastHome;

        InPiece.Whereabouts = To;
        if (To != EMars_Fry_Whereabouts::Airborne)
        { InPiece.LastHome = To; }

        if (From == EMars_Fry_Whereabouts::DrainBasket)
        {
            InPiece.Drain = EMars_Fry_Drain::NotDraining;
            InPiece.DrainSeconds = 0.0f;
        }

        if (To == EMars_Fry_Whereabouts::Lost)
        { InPiece.LingerSeconds = 0.0f; }

        ck::Trace(f"[Fry] [{InFrame.Fry.ToString()}] piece {utils_cooking_feed::Get_PieceName(InPiece.Id)}: {From :n} -> {To :n} at root {Root}");
    }

    // A lost piece keeps simulating as a lingering body; at Zones.LingerSeconds it leaves the array and its entity is
    // destroyed. Nothing replaces it.
    private void Advance_Lingering(FMars_Fry_Frame& InFrame, FMars_Fragment_Fry& InState)
    {
        for (int32 Index = InState.Pieces.Num() - 1; Index >= 0; --Index)
        {
            auto Piece = InState.Pieces[Index];
            if (Piece.Whereabouts != EMars_Fry_Whereabouts::Lost)
            { continue; }

            Piece.LingerSeconds += InFrame.DeltaSeconds;
            if (Piece.LingerSeconds < InFrame.Spec.Zones.LingerSeconds)
            {
                InState.Pieces[Index] = Piece;
                continue;
            }

            InState.Pieces.RemoveAt(Index);

            // Already gone with a station torn down around it.
            if (ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            ck::Trace(f"[Fry] [{InFrame.Fry.ToString()}] destroyed lost piece {utils_cooking_feed::Get_PieceName(Piece.Id)} [{Piece.Entity.ToString()}]");
            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }

    // The tally counts an ejection when a hop that started in the drain basket lands anywhere else (a hop back into the
    // basket is not one), a catch when a hop lands on the scoop, a retrieval when the scoop lifts a piece out of the oil, and
    // every lost piece.
    private void Count_Edge(FMars_Fry_Frame& InFrame, FMars_Fragment_Fry& InState, const FMars_Fry_PieceEvents& InEvents)
    {
        if (InEvents.From.IsSet() == false)
        { return; }

        const auto From = InEvents.From.GetValue();
        const auto To = InEvents.To;

        if (From == EMars_Fry_Whereabouts::Airborne && To != EMars_Fry_Whereabouts::DrainBasket
            && InEvents.HopStart == EMars_Fry_Whereabouts::DrainBasket)
        { InState.Tally.Ejections += 1; }

        if (From == EMars_Fry_Whereabouts::Airborne && To == EMars_Fry_Whereabouts::Skimmer)
        { InState.Tally.Catches += 1; }

        if (From == EMars_Fry_Whereabouts::Oil && To == EMars_Fry_Whereabouts::Skimmer)
        { InState.Tally.Retrievals += 1; }

        if (To == EMars_Fry_Whereabouts::Lost)
        {
            InState.Tally.Lost += 1;
            ck::Trace(f"[Fry] [{InFrame.Fry.ToString()}] lost piece {utils_cooking_feed::Get_PieceName(InEvents.Id)} "
                + f"[{InEvents.Entity.ToString()}] (lost {InState.Tally.Lost})");
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Ledger
    //----------------------------------------------------------------------------------------------------------------------

    // Every face of a piece in the oil or on the scoop whose centre is below the oil line heats toward golden (1) over
    // GoldenSeconds, then toward overdone (2) over OverdoneSeconds; each crossing reports once. The basket, a carried scoop
    // and the air never heat.
    private void Advance_Heat(FMars_Fry_Frame& InFrame, FMars_Fry_PieceState& InPiece, FMars_Fry_PieceEvents& OutEvents)
    {
        if (InPiece.Whereabouts != EMars_Fry_Whereabouts::Oil && InPiece.Whereabouts != EMars_Fry_Whereabouts::Skimmer)
        { return; }

        const auto& Heat = InFrame.Spec.Heat;
        const auto HalfSize = InFrame.Spec.Piece.HalfSize;
        const auto SurfaceZ = InFrame.Spec.Oil.SurfaceZ;
        const auto PieceRoot = utils_transform::Get_EntityCurrentTransform(InPiece.Entity.As_Transform()).GetRelativeTransform(InFrame.RootWorld);

        for (int32 FaceIndex = 0; FaceIndex < utils_searing::k_FaceCount; ++FaceIndex)
        {
            const auto Face = EMars_Searing_Face(FaceIndex);
            if (utils_fry::Get_FaceCentreZ(PieceRoot, Face, HalfSize) >= SurfaceZ)
            { continue; }

            const auto Before = InPiece.FaceHeat[FaceIndex];
            const auto After = Before < 1.0f
                ? Math::Min(1.0f, Before + InFrame.DeltaSeconds / Heat.GoldenSeconds)
                : Math::Min(2.0f, Before + InFrame.DeltaSeconds / Heat.OverdoneSeconds);
            InPiece.FaceHeat[FaceIndex] = After;

            const auto Stage = utils_fry::Get_HeatStage(After);
            if (int32(Stage) <= int32(InPiece.ReportedStage[FaceIndex]))
            { continue; }

            InPiece.ReportedStage[FaceIndex] = Stage;
            OutEvents.StageFaces.Add(Face);
            OutEvents.Stages.Add(Stage);
        }
    }

    // A piece in the drain basket that rests on its floor (its Resting's grace, Receiver.SupportGraceSeconds, rides out a
    // sleeping or a hopping contact) drains: NotDraining becomes Draining and accrues; at Receiver.DrainSeconds it is
    // Drained, once. One in the basket but not supported holds its progress; crossing the basket's volume in the air never
    // starts it. Leaving the basket resets it (Advance_Whereabouts).
    private void Advance_Drain(FMars_Fry_Frame& InFrame, FMars_Fry_PieceState& InPiece, FMars_Fry_PieceEvents& OutEvents)
    {
        if (InPiece.Whereabouts != EMars_Fry_Whereabouts::DrainBasket || InPiece.Drain == EMars_Fry_Drain::Drained)
        { return; }

        if (InPiece.Entity.As_Resting().Get_IsRestingOn(InFrame.Spec.Nodes.BasketBody) == false)
        { return; }

        InPiece.Drain = EMars_Fry_Drain::Draining;
        InPiece.DrainSeconds += InFrame.DeltaSeconds;
        if (InPiece.DrainSeconds < InFrame.Spec.Receiver.DrainSeconds)
        { return; }

        InPiece.Drain = EMars_Fry_Drain::Drained;
        OutEvents.Drained = true;
    }

    // Seconds while any piece is in the oil.
    private void Advance_Tally(FMars_Fry_Frame& InFrame, FMars_Fragment_Fry& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (Piece.Whereabouts == EMars_Fry_Whereabouts::Oil)
            {
                InState.Tally.Seconds += InFrame.DeltaSeconds;
                return;
            }
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Broadcasts
    //----------------------------------------------------------------------------------------------------------------------

    // Per piece, in admission order: whereabouts, face stages, drained, lost.
    private void Broadcast_PieceEvents(FMars_Fry_Frame& InFrame, const TArray<FMars_Fry_PieceEvents>& InEvents)
    {
        for (const auto& Event : InEvents)
        {
            const auto PieceName = utils_cooking_feed::Get_PieceName(Event.Id);
            for (int32 Index = 0; Index < Event.Stages.Num(); ++Index)
            { ck::Trace(f"[Fry] [{InFrame.Fry.ToString()}] piece {PieceName} face {utils_searing::Get_FaceName(Event.StageFaces[Index])} {Event.Stages[Index] :n}"); }

            if (Event.Drained)
            { ck::Trace(f"[Fry] [{InFrame.Fry.ToString()}] piece {PieceName} drained"); }
        }

        if (InFrame.Fry.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
        { return; }

        // The signals fragment is fetched per broadcast: a handler may compose fragments while it runs.
        auto Fry = InFrame.Fry;
        for (const auto& Event : InEvents)
        {
            if (Event.From.IsSet())
            { Fry.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceWhereaboutsChanged.Broadcast(Fry, Event.Id, Event.From.GetValue(), Event.To); }

            for (int32 Index = 0; Index < Event.Stages.Num(); ++Index)
            { Fry.Get_Fragment(FMars_Fragment_Fry_Signals).OnFaceHeatStage.Broadcast(Fry, Event.Id, Event.StageFaces[Index], Event.Stages[Index]); }

            if (Event.Drained)
            { Fry.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceDrained.Broadcast(Fry, Event.Id); }

            if (Event.From.IsSet() && Event.To == EMars_Fry_Whereabouts::Lost)
            { Fry.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceLost.Broadcast(Fry, Event.Id, Event.Entity); }
        }
    }

    private FVector Get_RootLocal(const FMars_Fry_Frame& InFrame, FCk_Handle InEntity) const
    {
        const auto PieceWorld = utils_transform::Get_EntityCurrentLocation(InEntity.As_Transform());
        return InFrame.RootWorld.InverseTransformPosition(PieceWorld);
    }
}
