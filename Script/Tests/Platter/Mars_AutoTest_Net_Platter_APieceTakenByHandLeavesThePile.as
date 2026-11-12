// The server loads a meat slab (step 1 once it froze), then transfers the slab's item into the subject's stow target, the
// kernel path of a pickup (step 2 once its platter reads nothing held). On the client the food is Carried or Held by the
// subject, its scene-node parent is not its platter's root, it has no ride parent and no replicated holder, and the platter
// reads nothing held or on its books. The client logs which arrived first: the food's mount or its free ledger.
// Surface: Ck.Platter.Net.AS_Platter_APieceTakenByHandLeavesThePile
class UCk_AutoTest_Net_Platter_APieceTakenByHandLeavesThePile : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 234000.0;

    private FCk_Handle _Food;
    // Client: the food once found, and the sampled frames its mount left World and its ledger went free (-1 until then).
    private FCk_Handle_FoodPiece _Piece;
    private int32 _MountFrame = -1;
    private int32 _FreeFrame = -1;

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
        Load_WhenReady(_Food, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitSeconds(k_StepSeconds, n"OnServerTake");
    }

    UFUNCTION()
    private void OnServerTake(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCarrierReady(_Carrier), "the server's carrier is ready");
        Stow(_Food.As_WorldItem());
        WaitUntil(n"Is_ServerTaken", n"OnServerTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Platter.Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void OnServerTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Rides(2);
        End_PlatterServer(f"{Describe_Counts()} mount={_Food.As_WorldItem().Get_Mount() :n} {Describe_Signals()}");
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (Get_PlatterReport().Step < 1)
        { return; }

        if (ck::Is_NOT_Valid(_Piece))
        { _Piece = Find_PieceById(Get_PlatterReport().Slot0.Id); }

        if (Get_IsLive(_Piece) == false)
        { return; }

        FCk_Handle Entity = _Piece;
        auto WorldItem = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (_MountFrame < 0 && ck::IsValid(WorldItem) && WorldItem.Get_Mount() != EMars_WorldItem_Mount::World)
        { _MountFrame = _SampleFrame; }

        if (_FreeFrame < 0 && ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder()))
        { _FreeFrame = _SampleFrame; }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Await_Step(2);
            return;
        }

        const auto Piece = Find_PieceById(Get_PlatterReport().Slot0.Id);
        Assert_True(Get_IsLive(Piece), "the client finds the taken food");
        if (Get_IsLive(Piece) == false)
        {
            End_PlatterClient("no piece");
            return;
        }

        FCk_Handle Entity = Piece;
        const auto WorldItem = Entity.As_WorldItem();
        const auto Mount = WorldItem.Get_Mount();
        const auto IsCarried = Mount == EMars_WorldItem_Mount::Carried || Mount == EMars_WorldItem_Mount::Held;
        Assert_True(IsCarried && WorldItem.Get_Carrier() == Get_SubjectEntity(), f"the client's food is Carried or Held by the subject (mount {Mount :n})");
        Assert_True(Get_IsOnPlatterRoot(Piece) == false, "the client's food is no child of its platter's root");
        Assert_True(ck::Is_NOT_Valid(Piece.Get_RideParent()), "the client's food has no ride parent");
        Assert_True(ck::Is_NOT_Valid(Piece.TryGet_ReplicatedHolder()), "the client's food has no replicated holder");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the client's platter reads nothing held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the client's platter reads nothing on its books");

        FString First = "same frame";
        if (_MountFrame >= 0 && (_FreeFrame < 0 || _MountFrame < _FreeFrame))
        { First = "mount"; }
        else if (_FreeFrame >= 0 && (_MountFrame < 0 || _FreeFrame < _MountFrame))
        { First = "free ledger"; }

        End_PlatterClient(f"mount={Mount :n} parent=[{Get_Parent(Piece).ToString()}] first={First} mountFrame={_MountFrame} freeFrame={_FreeFrame} {Describe_Counts()} {Describe_Signals()}");
    }
}
