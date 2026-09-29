// Applies a dropped or thrown item's launch velocity once its Jolt body actually exists.
//
// JoltBody setup is deferred by at least one frame (FProcessor_JoltBody_Setup batches the AddBodies pass), so a
// velocity request issued from DoConstruct would be drained against a body that has not been added and silently do
// nothing. Get_IsBodyAdded is the gate.
class UMars_Processor_WorldItem_Launch : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_PendingLaunch;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_WorldItem_PendingLaunch& InPending)
    {
        auto Body = InHandle.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Body))
        {
            InHandle.Request_TryRemove(FMars_Fragment_WorldItem_PendingLaunch);
            return;
        }

        // Still waiting on the batched AddBodies pass - try again next frame.
        if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return; }

        // Snapshot before the remove: Request_TryRemove is immediate (entt swap-and-pop), so the fragment reference is
        // dangling the moment it returns.
        const auto Linear = InPending.LinearVelocity;
        const auto AngularDeg = InPending.AngularVelocityDeg;

        InHandle.Request_TryRemove(FMars_Fragment_WorldItem_PendingLaunch);

        utils_jolt_body::Request_SetLinearVelocity(Body,
            FCk_Request_JoltBody_SetLinearVelocity(Linear));

        // Jolt angular velocity is radians/s; the launch is authored in degrees/s.
        const auto AngularRad = FVector(
            Math::DegreesToRadians(AngularDeg.X),
            Math::DegreesToRadians(AngularDeg.Y),
            Math::DegreesToRadians(AngularDeg.Z));

        utils_jolt_body::Request_SetAngularVelocity(Body,
            FCk_Request_JoltBody_SetAngularVelocity(AngularRad));
    }
}
