// The tick's coat-stage edges, broadcast once the whole tick applied (so a handler reads the written state). In parallel.
struct FMars_Batter_TickEdges
{
    TArray<FMars_CookingFeed_PieceId> StageIds;
    TArray<EMars_Batter_CoatStage> Stages;
}

// What a follow raises once it wrote this machine's rows: the rows that went, then the rows announced. In parallel.
struct FMars_Batter_FollowEdges
{
    TArray<FMars_CookingFeed_PieceId> TakenOutIds;
    TArray<FCk_Handle_FoodPiece> TakenOutPieces;
    TArray<FMars_CookingFeed_PieceId> AddedIds;
    TArray<FCk_Handle> AddedPieces;
}

// Every frame, in order: each piece's immersion eases toward the bowl's state (fully under while Dipped, at rest otherwise)
// over Coat.DipSeconds; a fully immersed piece in a Dipped bowl coats at 1 / Coat.CoatSeconds per second up to 1 (never
// down); its offset under the bowl node follows its immersion (written past a small change only); then the station's
// take-out readout (every fully coated piece, written on change), then the ledger is published. Coat-stage edges are
// broadcast last. The clock is the frame's time clamped to k_MaxStepSeconds: headless and deterministic, whoever operates.
//
// Without authority the tick only shows, from the ledger (Follow): this machine's rows follow the ledger's, each eases
// toward the ledger's bowl by the same law, this machine's own copy of each piece hangs under its own bowl node at its
// slot, and OnPieceAdded / OnPieceTakenOut are raised as a piece's row shows up here and goes. It coats nothing, writes no
// readout and raises no coat stage.
class UMars_Processor_Batter_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Batter_HandleRequests");

    // A hitch must not dip a piece or run its coat a whole step in one frame.
    private const float32 k_MaxStepSeconds = 0.1f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Batter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Batter& InState)
    {
        auto Batter = InHandle.As_Batter();
        const auto Spec = Batter.Get_Spec();
        const auto DeltaSeconds = Math::Min(float32(InDeltaT.Get_Seconds()), k_MaxStepSeconds);
        const auto Step = FMars_Batter_EaseStep(DeltaSeconds, Spec.Coat.DipSeconds);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            Follow(Batter, Step);
            return;
        }

        auto Edges = FMars_Batter_TickEdges();
        for (int32 Index = 0; Index < InState.Pieces.Num(); ++Index)
        {
            auto Piece = InState.Pieces[Index];

            // A piece whose entity is gone is going with a station torn down around it.
            if (ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            Piece.Immersion = utils_batter::Ease_Immersion(Piece.Immersion, InState.Bowl, Step);
            if (InState.Bowl == EMars_Batter_Bowl::Dipped && Piece.Immersion >= 1.0f && Piece.Coat < 1.0f)
            { Piece.Coat = Math::Min(1.0f, Piece.Coat + DeltaSeconds / Spec.Coat.CoatSeconds); }

            const auto Stage = utils_batter::Get_CoatStage(Piece.Coat);
            if (Stage != Piece.Stage)
            {
                Piece.Stage = Stage;
                Edges.StageIds.Add(Piece.Id);
                Edges.Stages.Add(Stage);
            }

            utils_batter::Write_PieceOffset(Spec.Bowl, Piece);
            InState.Pieces[Index] = Piece;
        }

        utils_cooking_feed::Write_Takeable(InHandle, utils_batter::Get_Takeable(InState.Pieces));
        utils_batter::Publish(Batter, FMars_Batter_Answers());
        Broadcast(Batter, Edges);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Without authority
    //----------------------------------------------------------------------------------------------------------------------

    // The bowl as the ledger says it stands, once a frame, in order: rows, immersion, slots, then the announcements. It works
    // on a copy of this machine's rows and writes them back before it raises anything: no fragment reference is held across
    // an attach or a broadcast.
    private void Follow(FCk_Handle_Batter& InBatter, const FMars_Batter_EaseStep& InStep)
    {
        const auto Spec = InBatter.Get_Spec();
        const auto Ledger = InBatter.Get_Fragment(FMars_Fragment_Batter_Net);
        const auto Previous = InBatter.Get_Fragment(FMars_Fragment_Batter_Local).Rows;

        // Rows: one per ledger row, in its order; a row the ledger no longer has is gone.
        TArray<FMars_Batter_LocalRow> Rows;
        for (const auto& LedgerRow : Ledger.Pieces)
        {
            const auto Index = utils_batter::Find_LocalRowIndex(Previous, LedgerRow.Id);
            if (Index >= 0)
            { Rows.Add(Previous[Index]); }
            else
            {
                auto Row = FMars_Batter_LocalRow();
                Row.Id = LedgerRow.Id;
                Rows.Add(Row);
            }
        }

        auto Edges = FMars_Batter_FollowEdges();
        for (const auto& Row : Previous)
        {
            if (utils_batter::Find_RowIndex(Ledger.Pieces, Row.Id) < 0)
            { Let_Go(Spec, Row, Edges); }
        }

        for (int32 Index = 0; Index < Rows.Num(); ++Index)
        {
            auto Row = Rows[Index];
            Row.Immersion = utils_batter::Ease_Immersion(Row.Immersion, Ledger.Bowl, InStep);
            Seat(Spec, Ledger.Pieces[Index], Row);
            Announce(Ledger.Pieces[Index], Row, Edges);
            Rows[Index] = Row;
        }

        InBatter.Get_Fragment(FMars_Fragment_Batter_Local).Rows = Rows;
        Broadcast_Follow(InBatter, Edges);
    }

    // A row the ledger dropped: this machine's copy comes off its bowl node (only while that node still holds it), and an
    // announced row is said taken out.
    private void Let_Go(const FMars_Batter_Spec& InSpec, const FMars_Batter_LocalRow& InRow, FMars_Batter_FollowEdges& OutEdges)
    {
        auto Attached = InRow.Attached;
        if (ck::IsValid(Attached))
        {
            auto Node = Attached.As_SceneNode(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Node) && utils_scene_node::Get_Parent(Node) == InSpec.Nodes.Bowl)
            { utils_scene_node::Request_Detach(Node); }
        }

        if (InRow.Announce != EMars_Batter_Announce::Announced)
        { return; }

        OutEdges.TakenOutIds.Add(InRow.Id);
        OutEdges.TakenOutPieces.Add(ck::IsValid(Attached) ? Attached.As_FoodPiece(ECk_SanityCheck::UnChecked) : FCk_Handle_FoodPiece());
    }

    // This machine's copy of the row's piece under its own bowl node at its slot and immersion: attached once it is a Ready
    // FoodPiece here (detached first from whatever holds it), its offset written by the tick's own rule after that. A piece
    // not here yet is tried again next frame.
    private void Seat(const FMars_Batter_Spec& InSpec, const FMars_Batter_PieceRow& InLedgerRow, FMars_Batter_LocalRow& InOutRow)
    {
        auto Entity = InLedgerRow.Piece;
        if (utils_foodpiece::Get_IsLiveEntity(Entity) == false || Entity.Is_Transform() == false)
        { return; }

        const auto Piece = Entity.As_FoodPiece(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Piece) || Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return; }

        auto State = FMars_Batter_PieceState();
        State.Id = InLedgerRow.Id;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Slot = InLedgerRow.Slot;
        State.Immersion = InOutRow.Immersion;

        if (InOutRow.Attached == Entity)
        {
            utils_batter::Write_PieceOffset(InSpec.Bowl, State);
            return;
        }

        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        auto PieceTransform = Entity.As_Transform();
        auto BowlNode = InSpec.Nodes.Bowl;
        utils_scene_node::Add(PieceTransform, BowlNode, utils_batter::Get_PieceOffset(InSpec.Bowl, State));
        InOutRow.Attached = Entity;
    }

    // A row whose piece is a FoodPiece here and not gone is announced once; a piece that never becomes one here is never
    // announced.
    private void Announce(const FMars_Batter_PieceRow& InLedgerRow, FMars_Batter_LocalRow& InOutRow, FMars_Batter_FollowEdges& OutEdges)
    {
        if (InOutRow.Announce == EMars_Batter_Announce::Announced)
        { return; }

        const auto Entity = InLedgerRow.Piece;
        if (utils_foodpiece::Get_IsLiveEntity(Entity) == false || Entity.Is_FoodPiece() == false)
        { return; }

        InOutRow.Announce = EMars_Batter_Announce::Announced;
        OutEdges.AddedIds.Add(InOutRow.Id);
        OutEdges.AddedPieces.Add(Entity);
    }

    // Handlers keep the station's piece records: scope the script world to the station's, and read the signals fragment again
    // for every broadcast.
    private void Broadcast_Follow(FCk_Handle_Batter& InBatter, const FMars_Batter_FollowEdges& InEdges)
    {
        if (InEdges.TakenOutIds.Num() == 0 && InEdges.AddedIds.Num() == 0)
        { return; }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InBatter));
        for (int32 Index = 0; Index < InEdges.TakenOutIds.Num(); ++Index)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceTakenOut.Broadcast(InBatter, InEdges.TakenOutIds[Index], InEdges.TakenOutPieces[Index]); }
        }

        for (int32 Index = 0; Index < InEdges.AddedIds.Num(); ++Index)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceAdded.Broadcast(InBatter, InEdges.AddedIds[Index], InEdges.AddedPieces[Index]); }
        }
    }

    private void Broadcast(FCk_Handle_Batter& InBatter, const FMars_Batter_TickEdges& InEdges)
    {
        for (int32 Index = 0; Index < InEdges.StageIds.Num(); ++Index)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
            { return; }

            InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnCoatStage.Broadcast(InBatter, InEdges.StageIds[Index], InEdges.Stages[Index]);
        }
    }
}
