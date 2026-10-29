// Tests the production projection through real Gate requests and signals, not a replicated GameState or UI mock.
// No bodies or global state: an isolated child gate proves default/reset, invalid IDs, late snapshots and idempotence.
class UMars_AutoTest_CampMissionGate_ProjectsOnlyCommittedCatalogServices : UCk_AutoTest_Base
{
    private FCk_Handle_Gate _Gate;
    private UMars_ServiceCatalog _Catalog;
    private FMars_CampPartyState _Party;
    private int32 _Edges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Catalog = Cast<UMars_ServiceCatalog>(NewObject(this, UMars_ServiceCatalog));
        auto Service = Cast<UMars_ServiceDefinition>(NewObject(this, UMars_ServiceDefinition));
        Service.Id = n"Mission";
        Service.Destination = assets::Sandbox_Mars_MAP();
        _Catalog.Services.Add(Service);
        auto MissingWorld = Cast<UMars_ServiceDefinition>(NewObject(this, UMars_ServiceDefinition));
        MissingWorld.Id = n"MissingWorld";
        _Catalog.Services.Add(MissingWorld);

        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Owner, FTransform(FVector(0.0, 0.0, -82000.0)), ECk_Replication::DoesNotReplicate);
        _Gate = utils_gate::Add(Root, FMars_Gate_Spec());
        _Gate.BindTo_OnOpenChanged(FMars_Delegate_Gate_OnOpenChanged(this, n"OnOpenChanged"));

        Add_Step("empty, invalid and missing-world selections stay closed", n"Step_ClosedProjection");
        Add_Step_WaitSeconds("invalid requests have drained", 0.1f);
        Add_Step("no opening edge without a commit", n"Step_AssertClosed");
        Add_Step("reconcile a previously committed snapshot", n"Step_ValidSnapshot");
        Add_Step_WaitUntil("the committed mission opens", n"Check_Open", 0, 0);
        Add_Step("repeat a valid snapshot", n"Step_RepeatSnapshot");
        Add_Step_WaitSeconds("duplicate requests have drained", 0.1f);
        Add_Step("one opening edge", n"Step_AssertOneEdge");
        Add_Step("unknown selected id closes", n"Step_InvalidSnapshot");
        Add_Step_WaitUntil("invalid selection closes", n"Check_Closed", 0, 0);
        Add_Step("select the mission again", n"Step_ValidSnapshot");
        Add_Step_WaitUntil("opens again", n"Check_Open", 0, 0);
        Add_Step("a fresh party reset clears the gate", n"Step_Reset");
        Add_Step_WaitUntil("reset closes", n"Check_Closed", 0, 0);
        Add_Step("two opens and two closes", n"Step_AssertFourEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ClosedProjection(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Gate, "gate exists");
        Assert_False(_Gate.Get_IsOpen(), "closed by default");
        Assert_True(utils_camp_mission_gate::Get_Position(_Party, nullptr) == EMars_Gate_Position::Closed, "no catalog is closed");
        Assert_True(utils_camp_mission_gate::Get_Position(_Party, _Catalog) == EMars_Gate_Position::Closed, "no selection is closed");
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
        _Party.ServiceId = n"Unknown";
        Assert_True(utils_camp_mission_gate::Get_Position(_Party, _Catalog) == EMars_Gate_Position::Closed, "unknown selection is closed");
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
        _Party.ServiceId = n"MissingWorld";
        Assert_True(utils_camp_mission_gate::Get_Position(_Party, _Catalog) == EMars_Gate_Position::Closed, "a catalog entry without destination is closed");
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
    }

    UFUNCTION()
    private void Step_AssertClosed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Gate.Get_IsOpen(), "invalid selections leave it closed");
        Assert_Equals_Int(_Edges, 0, "no spurious opening edge");
    }

    UFUNCTION()
    private void Step_ValidSnapshot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Party.ServiceId = n"Mission";
        _Party.Revision += 1;
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
    }

    UFUNCTION()
    private void Step_RepeatSnapshot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
        // Departing is still the same committed mission; it must not slam the gate on the departing party.
        _Party.Departure = EMars_PartyDeparture::Departing;
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
    }

    UFUNCTION()
    private void Step_AssertOneEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gate.Get_IsOpen(), "repeated or departing snapshot remains open");
        Assert_Equals_Int(_Edges, 1, "idempotent projection broadcasts only one opening");
    }

    UFUNCTION()
    private void Step_InvalidSnapshot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Party.ServiceId = n"Unknown";
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Party = FMars_CampPartyState();
        utils_camp_mission_gate::Request_Project(_Gate, _Party, _Catalog);
    }

    UFUNCTION()
    private void Check_Open(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Gate.Get_IsOpen());
    }

    UFUNCTION()
    private void Check_Closed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Gate.Get_IsOpen() == false);
    }

    UFUNCTION()
    private void Step_AssertFourEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Assert_Equals_Int(_Edges, 4, "valid, invalid, valid, reset produce four edges"); }

    UFUNCTION()
    private void OnOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition)
    { ++_Edges; }
}
