// A dock outlines with its marker: the cutting station draws each dock's marker (a thin ProtoGrid slab) as a mesh part under
// the dock's own node, so the marker's host entity is a lifetime descendant of the dock entity (the focus outline claims
// the interactable's owner and its lifetime dependents) and sits where a docked tray's underside rests. The markers are
// searched for over the whole station, so a marker hosted on the station root (or under the wrong dock) fails the
// hosting asserts rather than the wait. Isolated origin (21600, -9000, -30000).
class UMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(21600.0, -9000.0, -30000.0);
    // The cutting station draws one marker per dock and no other ProtoGrid-interactable mesh.
    private const int32 k_ExpectedMarkers = 2;

    // Every marker component under the station and, in parallel, the entity hosting it. Found once the components exist
    // (they are created asynchronously).
    private TArray<UStaticMeshComponent> _Markers;
    private TArray<FCk_Handle> _MarkerHosts;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the station hosts its two marker components", n"Check_MarkersFound", k_SlowPolls, 0);
        Add_Step("each dock hosts exactly one marker, at its floor, and none sits outside a dock", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_MarkersFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Collect_Markers();

        auto Res = OutResult;
        Res.Set(_Markers.Num() >= k_ExpectedMarkers);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Markers.Num(), k_ExpectedMarkers, "the station hosts one marker per dock and no other");

        FCk_Handle InputDockEntity = _InputDock;
        FCk_Handle OutputDockEntity = _OutputDock;
        int32 InputIndex = -1;
        int32 UnderInput = 0;
        int32 UnderOutput = 0;
        for (int32 Index = 0; Index < _MarkerHosts.Num(); ++Index)
        {
            const auto UnderInputDock = Get_IsLifetimeDescendant(_MarkerHosts[Index], InputDockEntity);
            const auto UnderOutputDock = Get_IsLifetimeDescendant(_MarkerHosts[Index], OutputDockEntity);
            Assert_True(UnderInputDock || UnderOutputDock,
                f"marker {Index} ({_MarkerHosts[Index].ToString()}) is hosted under a dock, not elsewhere on the station");

            if (UnderInputDock)
            {
                UnderInput++;
                InputIndex = Index;
            }

            if (UnderOutputDock)
            { UnderOutput++; }
        }

        Assert_Equals_Int(UnderInput, 1, "exactly one marker is hosted under the input dock");
        Assert_Equals_Int(UnderOutput, 1, "exactly one marker is hosted under the output dock");
        if (InputIndex < 0)
        { return; }

        const auto InputMarker = _Markers[InputIndex];
        Assert_True(InputMarker.GetStaticMesh() == engine::load::Cube(), "the marker is the engine cube");
        Assert_True(InputMarker.GetCollisionEnabled() == ECollisionEnabled::NoCollision, "the marker has no collision");

        // The dock's node sits the tray's base above the table top; the slab's top stands just proud of the table.
        const auto DockWorld = utils_transform::Get_EntityCurrentTransform(_InputDock.Get_Node());
        const auto MarkerTop = InputMarker.GetWorldLocation().Z + constants_dock_marker::k_ThicknessCm * 0.5;
        const auto ExpectedTop = DockWorld.GetLocation().Z - constants_platter::k_FloorAboveBase + constants_dock_marker::k_TopAboveSurfaceCm;
        Assert_True(Math::Abs(MarkerTop - ExpectedTop) <= 0.01, f"the marker's top lies at the dock's floor ({MarkerTop} vs {ExpectedTop})");
    }

    // Every ProtoGrid-interactable static mesh component anywhere in the station's lifetime subtree, with its host.
    private void Collect_Markers()
    {
        _Markers.Reset();
        _MarkerHosts.Reset();

        FCk_Handle StationEntity = _Station;
        TArray<FCk_Handle> Frontier;
        Frontier.Add(StationEntity);
        for (int32 Index = 0; Index < Frontier.Num(); ++Index)
        {
            auto Entity = Frontier[Index];
            for (auto Component : utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent))
            {
                auto Mesh = Cast<UStaticMeshComponent>(Component);
                if (ck::IsValid(Mesh) && Mesh.GetMaterial(0) == assets::load::ProtoGrid_Interactable_Mars_MI())
                {
                    _Markers.Add(Mesh);
                    _MarkerHosts.Add(Entity);
                }
            }

            for (auto Dependent : Entity.Get_LifetimeDependents())
            {
                if (ck::IsValid(Dependent))
                { Frontier.Add(Dependent); }
            }
        }
    }

    // The walk stops at the world's transient entity: it is every chain's root and has no owner.
    private bool Get_IsLifetimeDescendant(const FCk_Handle& InEntity, const FCk_Handle& InAncestor) const
    {
        const auto Root = ck::TransientEntity();
        auto Entity = InEntity;
        for (int32 Depth = 0; Depth < 16 && ck::IsValid(Entity) && Entity != Root; ++Depth)
        {
            if (Entity == InAncestor)
            { return true; }

            Entity = utils_entity_lifetime::Get_LifetimeOwner(Entity);
        }

        return false;
    }
}
