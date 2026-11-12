// The server loads a meat slab (step 1 once it froze); step 2 follows once the subject's hotbar holds the slab's item and
// its platter reads nothing held. At step 1 the client waits until its slab rides and fires the pickup cue at its copy of
// the slab for its subject. At step 2 its subject's hotbar holds the item, its slab is no child of its platter's root and
// has no ride parent, and its platter reads nothing held or on its books.
// Surface: Ck.Platter.Net.AS_Platter_AClientTakesAFoodOffThePlatter
class UCk_AutoTest_Net_Platter_AClientTakesAFoodOffThePlatter : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 265000.0;

    private FCk_Handle _Food;
    // Client: its copy of the slab once it rides.
    private FCk_Handle_FoodPiece _Piece;

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
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Load_WhenReady(_Food, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitUntil(n"Is_ServerTaken", n"OnServerTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Item = _Food.As_WorldItem().Get_Item();
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.TryGet_SlotIndexOf(Item).IsSet() && _Platter.Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void OnServerTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Location(2, FVector::ZeroVector);
        End_PlatterServer(f"{Describe_Counts()} mount={_Food.As_WorldItem().Get_Mount() :n} {Describe_Signals()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_ClientSlabRides", n"OnClientSlabRides", k_SlowPolls);
            return;
        }

        FCk_Handle Entity = _Piece;
        const auto Item = Entity.As_WorldItem().Get_Item();
        Assert_True(_Carrier.Hotbar.TryGet_SlotIndexOf(Item).IsSet(), "the client's subject's hotbar holds the slab's item");
        Assert_True(Get_IsOnPlatterRoot(_Piece) == false, "the client's slab is no child of its platter's root");
        Assert_True(ck::Is_NOT_Valid(_Piece.Get_RideParent()), "the client's slab has no ride parent");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the client's platter reads nothing held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the client's platter reads nothing on its books");
        End_PlatterClient(f"mount={Entity.As_WorldItem().Get_Mount() :n} parent=[{Get_Parent(_Piece).ToString()}] {Describe_Counts()}");
    }

    UFUNCTION()
    private void Is_ClientSlabRides(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Slot = Get_PlatterReport().Slot0;
        _Piece = Find_PieceById(Slot.Id);
        auto Result = OutResult;
        Result.Set(Get_RideFault(_Piece, Slot).IsEmpty());
    }

    UFUNCTION()
    private void OnClientSlabRides(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = _Piece;
        utils_cue_generic::Request_ExecuteCue(Entity.As_WorldItem(), GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Await_Step(2);
    }
}
