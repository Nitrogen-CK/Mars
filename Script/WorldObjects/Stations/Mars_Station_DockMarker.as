namespace constants_dock_marker
{
    // The small tray's footprint (PrepTray_Mars_SM, 26 x 30 outer), 0.4 cm thick.
    const float64 k_WidthCm = 26.0;
    const float64 k_DepthCm = 30.0;
    const float64 k_ThicknessCm = 0.4;

    // The slab's top stands this far proud of the surface a docked tray rests on, which it otherwise sinks into: a face
    // coplanar with the table top flickers. The marker has no collision, so it never lifts the tray.
    const float64 k_TopAboveSurfaceCm = 0.05;
}

// A station's dock marker: a thin ProtoGrid slab where a docked tray rests, hosted under the dock's node so the dock's
// focus outline (its owner and that owner's lifetime dependents) draws it. The dock's node sits
// constants_platter::k_FloorAboveBase above the surface.
mixin FCk_Handle_UnrealComponent Add_Marker(const FCk_Handle_PlatterDock& Self, UObject InOuter, FName InDebugName)
{
    auto Node = Self.Get_Node();
    const auto TopLocal = -constants_platter::k_FloorAboveBase + constants_dock_marker::k_TopAboveSurfaceCm;
    const auto Size = FVector(constants_dock_marker::k_WidthCm, constants_dock_marker::k_DepthCm, constants_dock_marker::k_ThicknessCm);
    const auto Local = FTransform(FRotator::ZeroRotator,
        FVector(0.0, 0.0, TopLocal - constants_dock_marker::k_ThicknessCm * 0.5), Size * 0.01);

    return Node.Add_MeshPart(InOuter, FMars_MeshPart(Local, engine::load::Cube(),
        assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, InDebugName));
}
