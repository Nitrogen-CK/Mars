// The server loads a meat slab onto the platter (step 1 once it froze), docks the platter on the Input dock and, once it
// arrived, reports the rides again with the platter root's location in the dock node's frame (step 2). At step 2 the
// client's slab rides its own platter at the report, its world pose is that offset under its platter's root, and its
// platter is Carried by its own Input dock with its root where the server's sits on its dock, within 0.05 cm.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ADockedPileRidesOnTheClient
class UCk_AutoTest_Net_PlatterDock_ADockedPileRidesOnTheClient : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 243000.0;

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
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        const auto PlatterInDock = Get_PlatterInDock(_InputDock);
        Publish_RidesAndLocation(2, PlatterInDock);
        End_DockServer(f"docked=[{Get_DockedFault(_InputDock)}] platterInDock={PlatterInDock} {Describe_Counts()} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_PlatterReport();
        const auto Slot = Report.Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        const auto CarriedCm = ck::IsValid(Piece) ? Get_CarriedError(Piece, Slot) : -1.0;
        const auto DockedFault = Get_DockedFault(_InputDock);
        const auto PlatterOffDockCm = Get_PlatterInDock(_InputDock).Distance(Report.Location);

        Assert_True(Fault.IsEmpty(), f"the client's slab rides its platter at the report ({Fault})");
        Assert_True(CarriedCm >= 0.0 && CarriedCm <= k_CarriedToleranceCm, f"the client's slab sits at that offset under its platter's root (off by {CarriedCm} cm)");
        Assert_True(DockedFault.IsEmpty(), f"the client's platter is Carried by its own Input dock ({DockedFault})");
        Assert_True(PlatterOffDockCm <= k_CarriedToleranceCm, f"the client's platter root sits on its dock node as the server's does (off by {PlatterOffDockCm} cm)");
        End_DockClient(f"rides=[{Fault}] carriedCm={CarriedCm} docked=[{DockedFault}] platterOffDockCm={PlatterOffDockCm} {Describe_Counts()} {Describe_DockEvents()}");
    }
}
