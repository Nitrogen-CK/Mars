// Commits the platter's pending loads, oldest first, each once its piece can be attached: Ready (it has the metrics the slot
// pose needs) and, with a body, added and reading Kinematic (utils_jolt_body::Get_MotionType is the mirror the SetMotionType
// handler stamps; attaching a Dynamic body would fight the Jolt writeback, while a Kinematic one follows the ECS transform).
// A piece destroyed while pending is dropped silently; one whose import failed is refused Failed.
//
// The commit attaches the piece to the platter root at its slot pose, or, for a load with ArriveFrom, at ArriveFrom's offset
// with an Arrival that lerps it in.
class UMars_Processor_Platter_Load : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Platter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Platter& InState)
    {
        if (InState.Pending.Num() == 0)
        { return; }

        auto Platter = InHandle.As_Platter();
        const TArray<FMars_Platter_PendingLoad> Pending = InState.Pending;
        TArray<FMars_Platter_PendingLoad> StillPending;
        TArray<FMars_Platter_LoadRefused> Refused;
        TArray<FMars_Platter_PendingLoad> Landed;

        for (const auto& Entry : Pending)
        {
            auto Piece = Entry.Piece;
            if (ck::Is_NOT_Valid(Piece) || utils_entity_lifetime::Get_IsPendingDestroy(Piece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            {
                if (ck::IsValid(Piece))
                { Piece.Request_TryRemove(FMars_Fragment_Platter_Membership); }

                ck::Trace(f"[Platter] [{Platter.ToString()}] dropped the pending load of [{Piece.ToString()}]: it was destroyed");
                continue;
            }

            const auto Status = Piece.Get_Status();
            if (Status == EMars_FoodPiece_Status::Failed)
            {
                Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
                Refused.Add(FMars_Platter_LoadRefused(Piece, EMars_Platter_LoadRefusal::Failed));
                ck::Trace(f"[Platter] [{Platter.ToString()}] refused [{Piece.ToString()}]: its import failed while pending");
                continue;
            }

            if (Status != EMars_FoodPiece_Status::Ready || Get_IsStill(Piece) == false)
            {
                StillPending.Add(Entry);
                continue;
            }

            Commit(Platter, InState, Entry);
            Landed.Add(Entry);
        }

        InState.Pending = StillPending;

        Broadcast(Platter, Landed, Refused);
    }

    // No body, or a body added and reading Kinematic. The SetMotionType handler drops a request that reaches it before the
    // body is added, so it is asked again until the mirror reads Kinematic; a duplicate after the switch is a no-op.
    private bool Get_IsStill(const FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle PieceEntity = InPiece;
        if (PieceEntity.Is_JoltBody() == false)
        { return true; }

        auto Body = PieceEntity.As_JoltBody();
        if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return false; }

        if (utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic)
        { return true; }

        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        return false;
    }

    // utils_scene_node::Add never re-parents an attached node, and only the platter attaches a piece: a piece that is already
    // a scene node is a defect, detached (immediate, keeps the world pose) before the attach.
    private void Commit(FCk_Handle_Platter& InPlatter, FMars_Fragment_Platter& InState, const FMars_Platter_PendingLoad& InEntry)
    {
        auto Piece = InEntry.Piece;
        FCk_Handle PlatterEntity = InPlatter;
        FCk_Handle PieceEntity = Piece;

        auto Root = PlatterEntity.As_Transform();
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(Root);
        const auto Spec = InPlatter.Get_Spec();
        const auto ToOffset = utils_platter::Get_SlotPose(utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry()), Spec.SlotsLocal[InEntry.Slot]);

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::Is_NOT_Valid(Node), f"[Platter] [{Piece.ToString()}] is already attached"))
        { utils_scene_node::Request_Detach(Node); }

        const auto IsArriving = InEntry.ArriveFrom.IsSet() && Spec.ArriveSeconds > 0.0f;
        const auto FromOffset = IsArriving ? InEntry.ArriveFrom.GetValue().GetRelativeTransform(RootWorld) : ToOffset;

        auto PieceTransform = PieceEntity.As_Transform();
        utils_scene_node::Add(PieceTransform, Root, FromOffset);

        if (IsArriving)
        {
            auto& Arrival = Piece.AddOrGet_Fragment(FMars_Fragment_Platter_Arrival);
            Arrival.FromOffset = FromOffset;
            Arrival.ToOffset = ToOffset;
            Arrival.Duration = Spec.ArriveSeconds;
            Arrival.Elapsed = 0.0f;
        }

        InState.Slots[InEntry.Slot] = Piece;

        ck::Trace(f"[Platter] [{InPlatter.ToString()}] loaded [{Piece.ToString()}] into slot {InEntry.Slot}, arriving: {IsArriving}");
    }

    private void Broadcast(FCk_Handle_Platter& InPlatter, const TArray<FMars_Platter_PendingLoad>& InLanded, const TArray<FMars_Platter_LoadRefused>& InRefused)
    {
        for (const auto& Entry : InLanded)
        {
            if (InPlatter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { InPlatter.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoaded.Broadcast(InPlatter, Entry.Piece, Entry.Slot); }
        }

        for (const auto& Refused : InRefused)
        {
            if (InPlatter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { InPlatter.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadRefused.Broadcast(InPlatter, Refused.Piece, Refused.Refusal); }
        }
    }
}

// Lerps a loaded piece's scene-node offset from FromOffset to ToOffset with OutCubic over Duration, then removes the Arrival
// fragment. Exactly ONE Request_UpdateOffset per frame: the scene-node request handler assigns the whole offset.
class UMars_Processor_Platter_Arrive : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Platter_Arrival;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Platter_Arrival& InArrival)
    {
        auto Node = InHandle.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Node), f"[Platter] Arrival on [{InHandle.ToString()}], which is not a scene node - dropped"))
        {
            InHandle.Request_TryRemove(FMars_Fragment_Platter_Arrival);
            return;
        }

        InArrival.Elapsed += float32(InDeltaT.Get_Seconds());

        // Snapshot before a possible remove: InArrival is invalid once Request_TryRemove returns.
        const auto From = InArrival.FromOffset;
        const auto To = InArrival.ToOffset;
        const auto Duration = InArrival.Duration;
        const auto Elapsed = InArrival.Elapsed;

        const float32 Alpha = Duration <= 0.0f ? 1.0f : Math::Min(1.0f, Elapsed / Duration);
        const float32 Remaining = 1.0f - Alpha;
        const float32 Eased = 1.0f - Remaining * Remaining * Remaining;

        const auto Offset = Alpha >= 1.0f ? To : utils_world_item::Blend(From, To, Eased);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));

        if (Alpha >= 1.0f)
        { InHandle.Request_TryRemove(FMars_Fragment_Platter_Arrival); }
    }
}
