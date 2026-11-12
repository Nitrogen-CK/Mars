// The server loads a meat slab (step 1 once it froze), unloads it and, once its OnUnloaded fired, moves its root 200 cm
// along X (step 2 with that location). On the client the piece has no replicated holder, no scene-node parent and no ride
// parent, its root is within 1 cm of the reported location, and the platter reads nothing held or on its books.
// Surface: Ck.Platter.Net.AS_Platter_AnUnloadedPieceTakesTheAuthoritysPoseAgain
class UCk_AutoTest_Net_Platter_AnUnloadedPieceTakesTheAuthoritysPoseAgain : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 233000.0;
    private const float64 k_MoveCm = 200.0;
    private const float64 k_LocationToleranceCm = 1.0;
    private const int32 k_MoveFrames = 3;

    private FCk_Handle _Food;
    private FGuid _FoodId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(2); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Load_WhenReady(_Food, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitSeconds(k_StepSeconds, n"OnServerUnload");
    }

    UFUNCTION()
    private void OnServerUnload(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Platter.Request_Unload(FMars_Request_Platter_Unload(_Food.As_FoodPiece()));
        WaitUntil(n"Is_ServerUnloaded", n"OnServerUnloaded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerUnloaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Unloaded >= 1);
    }

    UFUNCTION()
    private void OnServerUnloaded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Root = _Food.As_Transform();
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(Get_RootLocation(_Food) + FVector(k_MoveCm, 0.0, 0.0)));
        WaitFrames(k_MoveFrames, n"OnServerMoved");
    }

    UFUNCTION()
    private void OnServerMoved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Location = Get_RootLocation(_Food);
        Publish_Location(2, Location);
        End_PlatterServer(f"{Describe_Counts()} location={Location} {Describe_Signals()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_PlatterReport();
        const auto Piece = Find_PieceById(Report.Slot0.Id);
        Assert_True(Get_IsLive(Piece), "the client finds the unloaded piece");
        if (Get_IsLive(Piece) == false)
        {
            End_PlatterClient("no piece");
            return;
        }

        FCk_Handle Entity = Piece;
        const auto Distance = Get_RootLocation(Entity).Distance(Report.Location);
        Assert_True(ck::Is_NOT_Valid(Piece.TryGet_ReplicatedHolder()), "the client's piece has no replicated holder");
        Assert_True(ck::Is_NOT_Valid(Get_Parent(Piece)), f"the client's piece has no scene-node parent (got [{Get_Parent(Piece).ToString()}])");
        Assert_True(ck::Is_NOT_Valid(Piece.Get_RideParent()), "the client's piece has no ride parent");
        Assert_True(Distance <= k_LocationToleranceCm, f"the client's piece is at the authority's location (off by {Distance} cm)");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the client's platter reads nothing held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the client's platter reads nothing on its books");
        End_PlatterClient(f"offCm={Distance} parent=[{Get_Parent(Piece).ToString()}] {Describe_Counts()} {Describe_Signals()}");
    }
}
