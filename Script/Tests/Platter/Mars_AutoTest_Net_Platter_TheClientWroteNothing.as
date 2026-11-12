// The server loads a meat slab (step 1 once it froze) while a mushroom lies beside the platter, then watches 6 s. At step 1
// the client reads its ledger and asks its own copy to unload its slab, load its mushroom and mount: 1.5 s later its
// ledger is unchanged, its slab still rides at the report, its mushroom has no holder, no platter and no scene-node
// parent, no food copy near the test's X is a Jolt body, its held list reads empty and its platter raised no signal. At
// the end the server still holds one frozen slab at its step-1 offset, raised OnLoaded once and OnUnloaded never, and its
// mushroom has no holder.
// Surface: Ck.Platter.Net.AS_Platter_TheClientWroteNothing
class UCk_AutoTest_Net_Platter_TheClientWroteNothing : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 238000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FCk_Handle _Slab;
    private FCk_Handle _Mushroom;
    // Client: the ledger as it stood when it asked, and what it asked about.
    private FMars_Fragment_Platter_Net _LedgerBefore;
    private bool _HadLedger = false;
    private FCk_Handle_FoodPiece _ClientSlab;
    private FCk_Handle_FoodPiece _ClientMushroom;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        _Mushroom = Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slot = Get_PlatterReport().Slot0;
        const auto Slab = _Slab.As_FoodPiece();
        const auto Offset = Get_Offset(Slab);
        const auto OffsetCm = Offset.GetLocation().Distance(Slot.RideLocation);
        const auto IsMushroomFree = Get_IsFoodReady(_Mushroom) && ck::Is_NOT_Valid(_Mushroom.As_FoodPiece().TryGet_Holder());

        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the server's platter still holds one frozen piece");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the server's platter has one piece on its books");
        Assert_True(Get_IsOnPlatterRoot(Slab) && OffsetCm <= k_RideToleranceCm, f"the server's slab is at its step-1 offset (off by {OffsetCm} cm)");
        Assert_Equals_Int(_Loaded, 1, "the server raised OnLoaded once");
        Assert_Equals_Int(_Unloaded, 0, "the server raised no OnUnloaded");
        Assert_True(IsMushroomFree, "the server's mushroom has no holder");
        End_PlatterServer(f"{Describe_Counts()} offsetCm={OffsetCm} mushroomFree={IsMushroomFree} {Describe_Signals()}");
    }

    // This machine's whole food near the test's X whose kind holds InKind; invalid when none does.
    protected FCk_Handle_FoodPiece Find_FoodOfKind(FGameplayTag InKind)
    {
        for (const auto& Food : Get_FoodPiecesNear(_FloorTop))
        {
            if (Food.Get_Kind().HasTag(InKind))
            { return Food; }
        }

        return FCk_Handle_FoodPiece();
    }

    protected bool Get_IsLedgerEqual(FMars_Fragment_Platter_Net InA, FMars_Fragment_Platter_Net InB)
    {
        if (InA.HeldCount != InB.HeldCount || InA.Occupancy != InB.Occupancy || InA.Wholeness != InB.Wholeness
            || InA.PieceKinds.Num() != InB.PieceKinds.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.PieceKinds.Num(); ++Index)
        {
            const auto& A = InA.PieceKinds[Index];
            const auto& B = InB.PieceKinds[Index];
            if (A.HasAllExact(B) == false || B.HasAllExact(A) == false)
            { return false; }
        }

        return true;
    }

    protected int32 Get_JoltFoodCount()
    {
        auto Count = 0;
        for (auto Entity : Get_FoodEntitiesNear(_FloorTop))
        {
            if (Entity.Is_JoltBody())
            { ++Count; }
        }

        return Count;
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Ledger = utils_platter::TryGet_Ledger(_Platter);
        _HadLedger = Ledger.IsSet();
        if (_HadLedger)
        { _LedgerBefore = Ledger.GetValue(); }

        _ClientSlab = Find_PieceById(Get_PlatterReport().Slot0.Id);
        _ClientMushroom = Find_FoodOfKind(GameplayTags::Food_Vegetable);
        Assert_True(Get_IsLive(_ClientSlab) && Get_IsLive(_ClientMushroom), "the client finds its slab and its mushroom");
        if (Get_IsLive(_ClientSlab) == false || Get_IsLive(_ClientMushroom) == false)
        {
            End_PlatterClient("no slab or mushroom");
            return;
        }

        _Platter.Request_Unload(FMars_Request_Platter_Unload(_ClientSlab));
        _Platter.Request_Load(FMars_Request_Platter_Load(_ClientMushroom));
        _Platter.Request_SetMounted(FMars_Request_Platter_SetMounted(EMars_Platter_Mounting::Mounted));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = utils_platter::TryGet_Ledger(_Platter);
        const auto IsLedgerSame = _HadLedger && Ledger.IsSet() && Get_IsLedgerEqual(_LedgerBefore, Ledger.GetValue());
        const auto Fault = Get_RideFault(_ClientSlab, Get_PlatterReport().Slot0);
        const auto Jolts = Get_JoltFoodCount();
        const auto Signals = _Loaded + _Accepted + _Refused + _Unloaded;

        Assert_True(IsLedgerSame, f"the client's ledger is unchanged (had one: {_HadLedger})");
        Assert_True(Fault.IsEmpty(), f"the client's slab still rides at the report ({Fault})");
        Assert_True(ck::Is_NOT_Valid(_ClientMushroom.TryGet_Holder()), "the client's mushroom has no local holder");
        Assert_True(ck::Is_NOT_Valid(_ClientMushroom.TryGet_Platter()), "the client's mushroom has no platter");
        Assert_True(ck::Is_NOT_Valid(Get_Parent(_ClientMushroom)), f"the client's mushroom has no scene-node parent (got [{Get_Parent(_ClientMushroom).ToString()}])");
        Assert_Equals_Int(Jolts, 0, "no food copy near the test's X is a Jolt body");
        Assert_Equals_Int(_Platter.Get_Held().Num(), 0, "the client's held list reads empty");
        Assert_Equals_Int(Signals, 0, f"the client's platter raised no signal ({Describe_Signals()})");
        End_PlatterClient(f"ledgerSame={IsLedgerSame} rides=[{Fault}] mushroomHolder=[{_ClientMushroom.TryGet_Holder().ToString()}] jolts={Jolts} heldList={_Platter.Get_Held().Num()} {Describe_Counts()} {Describe_Signals()}");
    }
}
