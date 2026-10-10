// A dock outlines with its marker: the cutting station draws each dock's marker (a thin ProtoGrid slab) as a mesh part under
// the dock's own node, so the marker's host entity is a lifetime descendant of the dock entity (the focus outline claims
// the interactable's owner and its lifetime dependents) and sits where a docked tray's underside rests. Isolated origin
// (21600, -9000, -30000).
class UMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(21600.0, -9000.0, -30000.0);

    // The marker component's host entity under each dock, found once the components exist (they are created
    // asynchronously).
    private FCk_Handle _InputMarkerHost;
    private UStaticMeshComponent _InputMarker;
    private FCk_Handle _OutputMarkerHost;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("each dock's marker component exists", n"Check_MarkersFound", 0, 5.0f);
        Add_Step("the input marker is hosted under the input dock, at its floor", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_MarkersFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _InputMarker = Find_Marker(_InputDock, _InputMarkerHost);
        UStaticMeshComponent OutputMarker = Find_Marker(_OutputDock, _OutputMarkerHost);

        auto Res = OutResult;
        Res.Set(ck::IsValid(_InputMarker) && ck::IsValid(OutputMarker));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle InputDockEntity = _InputDock;
        Assert_True(Get_IsLifetimeDescendant(_InputMarkerHost, InputDockEntity), "the input marker's host is a lifetime descendant of the input dock");

        FCk_Handle OutputDockEntity = _OutputDock;
        Assert_True(Get_IsLifetimeDescendant(_OutputMarkerHost, OutputDockEntity), "the output marker's host is a lifetime descendant of the output dock");
        Assert_False(Get_IsLifetimeDescendant(_InputMarkerHost, OutputDockEntity), "the input marker is not the output dock's");

        Assert_True(_InputMarker.GetStaticMesh() == engine::load::Cube(), "the marker is the engine cube");
        Assert_True(_InputMarker.GetCollisionEnabled() == ECollisionEnabled::NoCollision, "the marker has no collision");

        // The dock's node sits the tray's base above the table top; the slab's top stands just proud of the table.
        const auto DockWorld = utils_transform::Get_EntityCurrentTransform(_InputDock.Get_Node());
        const auto MarkerTop = _InputMarker.GetWorldLocation().Z + constants_dock_marker::k_ThicknessCm * 0.5;
        const auto ExpectedTop = DockWorld.GetLocation().Z - constants_platter::k_FloorAboveBase + constants_dock_marker::k_TopAboveSurfaceCm;
        Assert_True(Math::Abs(MarkerTop - ExpectedTop) <= 0.01, f"the marker's top lies at the dock's floor ({MarkerTop} vs {ExpectedTop})");
    }

    // The ProtoGrid-interactable static mesh component hosted somewhere under InDock's lifetime subtree; null when none
    // exists yet. OutHost is the entity it was found on.
    private UStaticMeshComponent Find_Marker(const FCk_Handle_PlatterDock& InDock, FCk_Handle& OutHost) const
    {
        FCk_Handle DockEntity = InDock;
        TArray<FCk_Handle> Frontier;
        Frontier.Add(DockEntity);
        for (int32 Index = 0; Index < Frontier.Num(); ++Index)
        {
            auto Entity = Frontier[Index];
            for (auto Component : utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent))
            {
                auto Mesh = Cast<UStaticMeshComponent>(Component);
                if (ck::IsValid(Mesh) && Mesh.GetMaterial(0) == assets::load::ProtoGrid_Interactable_Mars_MI())
                {
                    OutHost = Entity;
                    return Mesh;
                }
            }

            for (auto Dependent : Entity.Get_LifetimeDependents())
            {
                if (ck::IsValid(Dependent))
                { Frontier.Add(Dependent); }
            }
        }

        return nullptr;
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
