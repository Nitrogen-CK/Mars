struct FMars_Platter_LoadRefused
{
    FCk_Handle_FoodPiece Piece;
    EMars_Platter_LoadRefusal Refusal = EMars_Platter_LoadRefusal::Full;

    FMars_Platter_LoadRefused() {}

    FMars_Platter_LoadRefused(FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        Piece = InPiece;
        Refusal = InRefusal;
    }
}

// What one drain did, broadcast once every request is applied.
struct FMars_Platter_Drain
{
    FCk_Handle_Platter Platter;
    bool Cleared = false;
    TArray<FCk_Handle_FoodPiece> Unloaded;
    // Pending loads this drain's Unloads dropped: a second Unload of one of them is the same request.
    TArray<FCk_Handle_FoodPiece> Dropped;
    TArray<FMars_Platter_LoadRefused> Refused;
}

// Drains Clear -> Unload -> Load, then broadcasts Cleared, Unloaded, LoadRefused. An accepted Load is only reserved here
// (membership stamped, slot reserved, a body asked to go Kinematic); UMars_Processor_Platter_Load commits it and broadcasts
// OnLoaded. It is also the platter's only teardown listener: the pieces it holds, landed or pending, end with it. It never
// writes a FoodPiece fragment.
class UMars_Processor_Platter_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Platter_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Platter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Platter_Requests& InRequests,
                       FMars_Fragment_Platter& InState)
    {
        auto Drain = FMars_Platter_Drain();
        Drain.Platter = InHandle.As_Platter();

        const auto HasClear = InRequests.ClearRequests.Num() > 0;
        TArray<FMars_Request_Platter_Unload> UnloadRequests = InRequests.UnloadRequests;
        TArray<FMars_Request_Platter_Load> LoadRequests = InRequests.LoadRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Platter.Request_TryRemove(FMars_Fragment_Platter_Requests);

        if (HasClear)
        { Apply_Clear(Drain, InState); }

        for (const auto& Request : UnloadRequests)
        { Apply_Unload(Drain, InState, Request); }

        for (const auto& Request : LoadRequests)
        { Apply_Load(Drain, InState, Request); }

        Broadcast(Drain);
    }

    private void Apply_Clear(FMars_Platter_Drain& InDrain, FMars_Fragment_Platter& InState)
    {
        auto Destroyed = 0;
        for (int32 Index = 0; Index < InState.Slots.Num(); ++Index)
        {
            if (End_Piece(InState.Slots[Index]))
            { ++Destroyed; }

            InState.Slots[Index] = FCk_Handle_FoodPiece();
        }

        for (const auto& Pending : InState.Pending)
        {
            if (End_Piece(Pending.Piece))
            { ++Destroyed; }
        }

        InState.Pending.Empty();
        InDrain.Cleared = true;

        ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] cleared: {Destroyed} piece(s) destroyed");
    }

    // A pending load of the piece never landed: it is dropped without a signal. A landed piece leaves its slot where it is.
    // A piece this drain already unloaded or dropped is the same request again: a traced no-op.
    private void Apply_Unload(FMars_Platter_Drain& InDrain, FMars_Fragment_Platter& InState, const FMars_Request_Platter_Unload& InRequest)
    {
        auto Piece = InRequest.Piece;
        if (InDrain.Unloaded.Contains(Piece) || InDrain.Dropped.Contains(Piece))
        {
            ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] [{Piece.ToString()}] was already unloaded in this drain: one unload");
            return;
        }

        const auto IsHeldHere = Piece.TryGet_Platter() == InDrain.Platter;
        if (ck::EnsureIfNot(IsHeldHere, f"[Platter] [{InDrain.Platter.ToString()}] does not hold [{Piece.ToString()}]"))
        { return; }

        for (int32 Index = 0; Index < InState.Pending.Num(); ++Index)
        {
            if (InState.Pending[Index].Piece != Piece)
            { continue; }

            InState.Pending.RemoveAt(Index);
            Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
            InDrain.Dropped.Add(Piece);
            ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] dropped the pending load of [{Piece.ToString()}]");
            return;
        }

        const auto Slot = Piece.Get_PlatterSlot().GetValue();
        Piece.Request_TryRemove(FMars_Fragment_Platter_Arrival);

        FCk_Handle PieceEntity = Piece;
        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        InState.Slots[Slot] = FCk_Handle_FoodPiece();
        Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
        InDrain.Unloaded.Add(Piece);

        ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] unloaded [{Piece.ToString()}] from slot {Slot} ({InDrain.Platter.Get_Occupancy()} taken)");
    }

    private void Apply_Load(FMars_Platter_Drain& InDrain, FMars_Fragment_Platter& InState, const FMars_Request_Platter_Load& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto Refusal = Get_LoadRefusal(InDrain.Platter, Piece);
        if (Refusal.IsSet())
        {
            ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] refused [{Piece.ToString()}]: {Refusal.GetValue() :n}");
            InDrain.Refused.Add(FMars_Platter_LoadRefused(Piece, Refusal.GetValue()));
            return;
        }

        const auto Slot = InDrain.Platter.TryGet_FirstFreeSlot().GetValue();

        auto& Membership = Piece.AddOrGet_Fragment(FMars_Fragment_Platter_Membership);
        Membership.Platter = InDrain.Platter;
        Membership.Slot = Slot;

        InState.Pending.Add(FMars_Platter_PendingLoad(Piece, Slot, InRequest.ArriveFrom));
        Watch_Teardown(InDrain.Platter);

        // The Load processor re-asks once the body is added: the handler drops a request that reaches it before.
        FCk_Handle PieceEntity = Piece;
        if (PieceEntity.Is_JoltBody())
        {
            auto Body = PieceEntity.As_JoltBody();
            if (utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
            { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic)); }
        }

        ck::Trace(f"[Platter] [{InDrain.Platter.ToString()}] accepted [{Piece.ToString()}] for slot {Slot}: it lands once Ready and still");
    }

    private TOptional<EMars_Platter_LoadRefusal> Get_LoadRefusal(const FCk_Handle_Platter& InPlatter, const FCk_Handle_FoodPiece& InPiece)
    {
        if (Get_IsGone(InPiece))
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::Gone); }

        const auto Holder = InPiece.TryGet_Platter();
        if (Holder == InPlatter)
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::AlreadyHeld); }

        if (ck::IsValid(Holder))
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::HeldElsewhere); }

        const auto Status = InPiece.Get_Status();
        if (Status == EMars_FoodPiece_Status::Cutting)
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::Cutting); }

        if (Status == EMars_FoodPiece_Status::Failed)
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::Failed); }

        if (InPlatter.TryGet_FirstFreeSlot().IsSet() == false)
        { return TOptional<EMars_Platter_LoadRefusal>(EMars_Platter_LoadRefusal::Full); }

        return TOptional<EMars_Platter_LoadRefusal>();
    }

    // Unbinding first keeps the watch single across loads.
    private void Watch_Teardown(const FCk_Handle_Platter& InPlatter)
    {
        FCk_Handle Platter = InPlatter;
        Platter.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnPlatterBeginDestroy"));
        Platter.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnPlatterBeginDestroy"));
    }

    // Takes the piece off the ledger's books and destroys it; false for a piece already gone.
    private bool End_Piece(const FCk_Handle_FoodPiece& InPiece)
    {
        if (Get_IsGone(InPiece))
        { return false; }

        auto Piece = InPiece;
        Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
        utils_entity_lifetime::Request_DestroyEntity(Piece);
        return true;
    }

    private bool Get_IsGone(const FCk_Handle_FoodPiece& InPiece)
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    private void Broadcast(FMars_Platter_Drain& InDrain)
    {
        auto Platter = InDrain.Platter;

        if (InDrain.Cleared && Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
        { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnCleared.Broadcast(Platter); }

        for (const auto& Piece : InDrain.Unloaded)
        {
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnUnloaded.Broadcast(Platter, Piece); }
        }

        for (const auto& Refused : InDrain.Refused)
        {
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadRefused.Broadcast(Platter, Refused.Piece, Refused.Refusal); }
        }
    }

    // The pieces the platter holds, landed or pending, end with it: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnPlatterBeginDestroy(FCk_Handle InPlatter)
    {
        auto PlatterEntity = InPlatter;
        if (PlatterEntity.Has_Fragment(FMars_Fragment_Platter) == false)
        { return; }

        const auto State = PlatterEntity.Get_Fragment(FMars_Fragment_Platter);
        auto Destroyed = 0;
        for (const auto& Piece : State.Slots)
        {
            if (End_Piece(Piece))
            { ++Destroyed; }
        }

        for (const auto& Pending : State.Pending)
        {
            if (End_Piece(Pending.Piece))
            { ++Destroyed; }
        }

        ck::Trace(f"[Platter] [{PlatterEntity.ToString()}] destroyed: {Destroyed} piece(s) destroyed with it");
    }
}
