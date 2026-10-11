// The tick's coat-stage edges, broadcast once the whole tick applied (so a handler reads the written state). In parallel.
struct FMars_Batter_TickEdges
{
    TArray<FMars_CookingFeed_PieceId> StageIds;
    TArray<EMars_Batter_CoatStage> Stages;
}

// Every frame, in order: each piece's immersion eases toward the bowl's state (fully under while Dipped, at rest otherwise)
// over Coat.DipSeconds; a fully immersed piece in a Dipped bowl coats at 1 / Coat.CoatSeconds per second up to 1 (never
// down); its offset under the bowl node follows its immersion (written past a small change only); then the station's
// take-out readout (every fully coated piece, written on change). Coat-stage edges are broadcast last. The clock is the
// frame's time clamped to k_MaxStepSeconds: headless and deterministic, whoever operates.
class UMars_Processor_Batter_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Batter_HandleRequests");

    // A hitch must not dip a piece or run its coat a whole step in one frame.
    private const float32 k_MaxStepSeconds = 0.1f;
    // A piece's offset is rewritten only past this much change (cm).
    private const float64 k_OffsetWriteTolerance = 0.01;

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

        auto Edges = FMars_Batter_TickEdges();
        const auto Target = InState.Bowl == EMars_Batter_Bowl::Dipped ? 1.0f : 0.0f;
        // A zero DipSeconds arrives at once.
        const auto Step = Spec.Coat.DipSeconds > 0.0f ? DeltaSeconds / Spec.Coat.DipSeconds : 1.0f;
        for (int32 Index = 0; Index < InState.Pieces.Num(); ++Index)
        {
            auto Piece = InState.Pieces[Index];

            // A piece whose entity is gone is going with a station torn down around it.
            if (ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            Piece.Immersion = Target > Piece.Immersion ? Math::Min(Target, Piece.Immersion + Step) : Math::Max(Target, Piece.Immersion - Step);
            if (InState.Bowl == EMars_Batter_Bowl::Dipped && Piece.Immersion >= 1.0f && Piece.Coat < 1.0f)
            { Piece.Coat = Math::Min(1.0f, Piece.Coat + DeltaSeconds / Spec.Coat.CoatSeconds); }

            const auto Stage = utils_batter::Get_CoatStage(Piece.Coat);
            if (Stage != Piece.Stage)
            {
                Piece.Stage = Stage;
                Edges.StageIds.Add(Piece.Id);
                Edges.Stages.Add(Stage);
            }

            Write_Offset(Spec.Bowl, Piece);
            InState.Pieces[Index] = Piece;
        }

        utils_cooking_feed::Write_Takeable(InHandle, utils_batter::Get_Takeable(InState.Pieces));
        Broadcast(Batter, Edges);
    }

    private void Write_Offset(const FMars_Batter_BowlSpec& InBowl, const FMars_Batter_PieceState& InPiece)
    {
        auto Entity = InPiece.Entity;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto Offset = utils_batter::Get_PieceOffset(InBowl, InPiece);
        if ((utils_scene_node::Get_Offset(Node).GetLocation() - Offset.GetLocation()).Size() <= k_OffsetWriteTolerance)
        { return; }

        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
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
