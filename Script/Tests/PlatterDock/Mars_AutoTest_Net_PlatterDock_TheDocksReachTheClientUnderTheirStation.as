// The server spawns the test station and reports once its docks have composed. On the client both docks are lifetime
// children of its copy of the station and scene-node children of its root at their mount offsets, with their roles, empty,
// each with an interactable.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_TheDocksReachTheClientUnderTheirStation
class UCk_AutoTest_Net_PlatterDock_TheDocksReachTheClientUnderTheirStation : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 240000.0;

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
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        Publish_Location(1, FVector::ZeroVector);
        End_DockServer(f"{Describe_ConstructFrames()} input=[{Get_DockFault(_InputDock, EMars_PlatterDock_Role::Input, constants_platter_dock_autotest::k_InputLocal)}]");
    }

    // Empty when InDock is InRole's dock of this machine's station, at InLocal under its root, empty, with an interactable.
    private FString Get_DockFault(FCk_Handle_PlatterDock InDock, EMars_PlatterDock_Role InRole, FVector InLocal)
    {
        if (ck::Is_NOT_Valid(InDock))
        { return "no dock"; }

        if (utils_entity_lifetime::Get_LifetimeOwner(InDock) != _Station)
        { return f"lifetime owner [{utils_entity_lifetime::Get_LifetimeOwner(InDock).ToString()}] is not the station"; }

        FCk_Handle Entity = InDock;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return "not a scene node"; }

        const FCk_Handle Parent = utils_scene_node::Get_Parent(Node);
        if (Parent != _Station)
        { return f"scene-node parent [{Parent.ToString()}] is not the station's root"; }

        const auto OffsetCm = utils_scene_node::Get_Offset(Node).GetLocation().Distance(InLocal);
        if (OffsetCm > k_MountToleranceCm)
        { return f"offset off by {OffsetCm} cm"; }

        if (InDock.Get_Role() != InRole)
        { return f"role {InDock.Get_Role() :n}"; }

        if (InDock.Get_IsOccupied())
        { return "occupied"; }

        if (ck::Is_NOT_Valid(InDock.Get_Interactable()))
        { return "no interactable"; }

        return "";
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto InputFault = Get_DockFault(_InputDock, EMars_PlatterDock_Role::Input, constants_platter_dock_autotest::k_InputLocal);
        const auto OutputFault = Get_DockFault(_OutputDock, EMars_PlatterDock_Role::Output, constants_platter_dock_autotest::k_OutputLocal);
        Assert_True(InputFault.IsEmpty(), f"the client's Input dock stands under its station ({InputFault})");
        Assert_True(OutputFault.IsEmpty(), f"the client's Output dock stands under its station ({OutputFault})");
        End_DockClient(f"input=[{InputFault}] output=[{OutputFault}] {Describe_DockEvents()}");
    }
}
