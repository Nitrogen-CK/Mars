// The server's subject holds a meat slab (step 1), and step 2 follows once the platter froze it; 1.5 s later the server
// waits until the subject's overflow holds the platter's item and its mount settled, then reports step 3 with the slab's
// offset. At step 1 the client deposits its slab, as in a client's deposit; at step 2 its slab rides at the report and it
// fires the pickup cue at its copy of the platter for its subject. At step 3 its platter is Held by its subject on its own
// hand node, and its slab rides it, its world pose the reported offset under its own platter root.
// Surface: Ck.Platter.Net.AS_Platter_AClientLoadsAPlatterAndCarriesItAway
class UCk_AutoTest_Net_Platter_AClientLoadsAPlatterAndCarriesItAway : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 269000.0;

    private FCk_Handle _Food;
    // Client: the deposited piece.
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
        Hold_FoodWhenReady(_Food);
    }

    protected void On_ServerFoodHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        Await_Frozen(1, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(2);
        WaitSeconds(k_StepSeconds, n"OnServerAwaitCarry");
    }

    UFUNCTION()
    private void OnServerAwaitCarry(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerCarried", n"OnServerCarried", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCarried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldItem = Get_PlatterWorldItem();
        const auto Overflow = _Carrier.Hotbar.Get_ItemAt(_Carrier.Hotbar.Get_OverflowIndex());
        auto Result = OutResult;
        Result.Set(Overflow == WorldItem.Get_Item() && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnServerCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Rides(3);
        End_PlatterServer(f"{Describe_Counts()} {Describe_Signals()} {Describe_PlatterLedger()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_ClientHoldsFood", n"OnClientHoldsFood", k_SlowPolls);
            return;
        }

        const auto Slot = Get_PlatterReport().Slot0;
        if (InStep == 2)
        {
            const auto Fault = Get_RideFault(_Piece, Slot);
            Assert_True(Fault.IsEmpty(), f"the client's slab rides at the report ({Fault})");
            utils_cue_generic::Request_ExecuteCue(Get_PlatterWorldItem(), GameplayTags::Cue_Mars_WorldItem_PickUp,
                FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
            Await_Step(3);
            return;
        }

        const auto HeldFault = Get_HeldFault();
        const auto RideFault = Get_RideFault(_Piece, Slot);
        const auto CarriedCm = Get_CarriedError(_Piece, Slot);
        Assert_True(HeldFault.IsEmpty(), f"the client's platter is Held by its subject on its own hand node ({HeldFault})");
        Assert_True(RideFault.IsEmpty(), f"the client's slab rides its platter ({RideFault})");
        Assert_True(CarriedCm <= k_CarriedToleranceCm, f"the client's slab is at the reported offset under its own platter root (off by {CarriedCm} cm)");
        End_PlatterClient(f"held=[{HeldFault}] ride=[{RideFault}] carriedCm={CarriedCm} {Describe_Counts()} {Describe_PlatterLedger()}");
    }

    UFUNCTION()
    private void Is_ClientHoldsFood(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(Get_SelectedFoodPiece()));
    }

    UFUNCTION()
    private void OnClientHoldsFood(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = Get_SelectedFoodPiece();
        Deposit();
        Await_Step(2);
    }
}
