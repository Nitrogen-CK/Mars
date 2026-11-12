// The server asks its platter to load a meat slab and, in the continuation of the load's OnLoadAccepted, moves the slab's
// item into the subject's stow target; step 1 follows once its platter's occupancy reads 0, and the server holds 3 s. It
// raised OnLoaded never. The client samples every frame from the first frame its slab has a replicated holder or its item
// is in its subject's hotbar until one second after step 1: in none of those frames is its slab a child of its platter's
// root. At the end its slab is Carried or Held by its subject and its platter reads nothing held or on its books.
// Surface: Ck.Platter.Net.AS_Platter_AFoodTakenWhileItSettlesIsNotPulledBackOnTheClient
class UCk_AutoTest_Net_Platter_AFoodTakenWhileItSettlesIsNotPulledBackOnTheClient : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 266000.0;
    private const float32 k_HoldSeconds = 3.0f;

    private FCk_Handle _Food;
    private bool _HasTaken = false;
    // Client: its slab, whether it samples, and what the samples saw.
    private FCk_Handle_FoodPiece _Piece;
    private bool _IsSampling = false;
    private bool _HasEndedSampling = false;
    private int32 _Samples = 0;
    private int32 _OnRootFrames = 0;
    private FString _FirstOnRoot;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            Await_Step(1);
        }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        _Platter.BindTo_OnLoadAccepted(FMars_Delegate_Platter_OnLoadAccepted(this, n"OnServerLoadAccepted"));
        WaitUntil(n"Is_ServerFoodReady", n"OnServerFoodReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFoodReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Food) && Get_IsCarrierReady(_Carrier));
    }

    UFUNCTION()
    private void OnServerFoodReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Platter.Request_Load(FMars_Request_Platter_Load(_Food.As_FoodPiece()));
        WaitUntil(n"Is_ServerEmptied", n"OnServerEmptied", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLoadAccepted(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (_HasTaken)
        { return; }

        _HasTaken = true;
        Stow(_Food.As_WorldItem());
    }

    UFUNCTION()
    private void Is_ServerEmptied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_HasTaken && _Platter.Get_Occupancy() == 0);
    }

    UFUNCTION()
    private void OnServerEmptied(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Loaded, 0, "the server's platter raised OnLoaded never");
        End_PlatterServer(f"{Describe_Counts()} mount={_Food.As_WorldItem().Get_Mount() :n} {Describe_Signals()}");
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (_HasEndedSampling || Try_FindPlatter() == false)
        { return; }

        if (ck::Is_NOT_Valid(_Piece))
        { _Piece = Find_FoodPieceNear(_FloorTop); }

        if (Get_IsLive(_Piece) == false)
        { return; }

        if (_IsSampling == false)
        {
            FCk_Handle Entity = _Piece;
            const auto WorldItem = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
            const auto Item = ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() ? WorldItem.Get_Item() : FCk_Handle_Item();
            const auto IsInHotbar = ck::IsValid(Item) && _Carrier.Hotbar.TryGet_SlotIndexOf(Item).IsSet();
            _IsSampling = ck::IsValid(_Piece.TryGet_ReplicatedHolder()) || IsInHotbar;
        }

        if (_IsSampling == false)
        { return; }

        ++_Samples;
        if (Get_IsOnPlatterRoot(_Piece))
        {
            if (_OnRootFrames == 0)
            { _FirstOnRoot = f"frame {_SampleFrame}: holder=[{_Piece.TryGet_ReplicatedHolder().ToString()}] ride={_Piece.TryGet_ReplicatedRide().IsSet()} parent=[{Get_Parent(_Piece).ToString()}]"; }

            ++_OnRootFrames;
        }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _HasEndedSampling = true;
        Assert_True(_Samples > 0, "the client sampled its slab");
        Assert_Equals_Int(_OnRootFrames, 0, f"the client's slab was a child of its platter's root in no sampled frame ({_FirstOnRoot})");
        Assert_True(Get_IsLive(_Piece), "the client finds its slab");
        if (Get_IsLive(_Piece) == false)
        {
            End_PlatterClient("no slab");
            return;
        }

        FCk_Handle Entity = _Piece;
        const auto WorldItem = Entity.As_WorldItem();
        const auto Mount = WorldItem.Get_Mount();
        const auto IsCarried = Mount == EMars_WorldItem_Mount::Carried || Mount == EMars_WorldItem_Mount::Held;
        Assert_True(IsCarried && WorldItem.Get_Carrier() == Get_SubjectEntity(), f"the client's slab is Carried or Held by its subject (mount {Mount :n})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the client's platter reads nothing held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the client's platter reads nothing on its books");
        End_PlatterClient(f"samples={_Samples} onRootFrames={_OnRootFrames} mount={Mount :n} {Describe_Counts()}");
    }
}
