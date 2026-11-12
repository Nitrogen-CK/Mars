// The server loads a meat slab onto the platter (step 1 once it froze, with its ride), then has the subject hold the
// platter (step 2). The client, once its platter is Held by the subject and its Input dock offers Place, asks for the Place
// through the dock's Act; step 3 once the platter arrived on the Input dock. At step 3 the client's dock holds the item,
// its slab rides its own platter at step 1's offset, and the slab's world pose is that offset under its own platter's
// root, Carried by its own Input dock, within 0.05 cm.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AClientPlacesAPlatterOfFood
class UCk_AutoTest_Net_PlatterDock_AClientPlacesAPlatterOfFood : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 257000.0;

    private FCk_Handle _Slab;

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
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        Hold_Platter(Get_PlatterWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Publish_Location(2, FVector::ZeroVector);
        Await_Arrived(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Publish_Location(3, FVector::ZeroVector);
        End_DockServer(f"docked=[{Get_DockedFault(_InputDock)}] {Describe_Counts()} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 2)
        {
            WaitUntil(n"Is_PlaceOffered", n"OnPlaceOffered", k_SlowPolls);
            return;
        }

        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        const auto CarriedCm = ck::IsValid(Piece) ? Get_CarriedError(Piece, Slot) : -1.0;
        const auto DockedFault = Get_DockedFault(_InputDock);
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the client's Input dock holds the platter's item");
        Assert_True(Fault.IsEmpty(), f"the client's slab rides its platter at step 1's offset ({Fault})");
        Assert_True(CarriedCm >= 0.0 && CarriedCm <= k_CarriedToleranceCm, f"the client's slab sits at that offset under its platter's root (off by {CarriedCm} cm)");
        Assert_True(DockedFault.IsEmpty(), f"the client's platter is Carried by its own Input dock ({DockedFault})");
        End_DockClient(f"rides=[{Fault}] carriedCm={CarriedCm} docked=[{DockedFault}] {Describe_Counts()} {Describe_DockEvents()}");
    }

    UFUNCTION()
    private void Is_PlaceOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HeldFault().IsEmpty() && _InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Place);
    }

    UFUNCTION()
    private void OnPlaceOffered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Act(_InputDock, EMars_PlatterDock_Action::Place);
        Await_Step(3);
    }
}
