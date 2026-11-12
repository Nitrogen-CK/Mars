// The server loads a meat slab onto a large platter; once it froze its piece is a child of the platter's root and the
// server reports its offset. On the client the whole food rides its own copy of the platter at that offset, the platter
// reads one held and one on its books, and its list of held pieces reads empty (the lists are the authority's).
// Surface: Ck.Platter.Net.AS_Platter_ALoadedFoodRidesThePlatterOnTheClient
class UCk_AutoTest_Net_Platter_ALoadedFoodRidesThePlatterOnTheClient : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 230000.0;

    private FCk_Handle _Food;

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
        const auto Piece = _Food.As_FoodPiece();
        Assert_True(Get_IsOnPlatterRoot(Piece), "the server's piece is a child of its platter's root");
        Publish_Rides(1);
        End_PlatterServer(f"{Describe_Counts()} onRoot={Get_IsOnPlatterRoot(Piece)} {Describe_Signals()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        Assert_True(ck::IsValid(Piece) &&Piece.Get_IsWhole(), "the client's piece is the whole food");
        Assert_True(Fault.IsEmpty(), f"the client's whole food rides its platter at the report ({Fault})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the client's platter reads one held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the client's platter reads one on its books");
        Assert_Equals_Int(_Platter.Get_Held().Num(), 0, "the client's list of held pieces is empty");
        End_PlatterClient(f"rides=[{Fault}] errorCm={_RideErrorCm} errorDeg={_RideErrorDegrees} {Describe_Counts()} heldList={_Platter.Get_Held().Num()} {Describe_Signals()}");
    }
}
