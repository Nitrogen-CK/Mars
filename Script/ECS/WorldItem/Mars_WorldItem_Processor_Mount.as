// Commits a Carry / Hold once the body can be scene-node-attached, then broadcasts OnMountChanged.
//
// Gate: no body, OR the body is added and reads Kinematic (utils_jolt_body::Get_MotionType is the mirror the
// SetMotionType handler stamps). Attaching while the body still reads Dynamic would fight the Jolt writeback; a Kinematic
// body follows the ECS transform (FTag_JoltBody_KinematicFromECS -> FProcessor_JoltBody_KinematicPush), so once attached
// nothing else moves it.
//
// The attach keeps the current world pose (the relative transform to the attach point), and an Arrival lerps the offset
// to the mount offset, so the item visibly travels to the back / hand instead of snapping. Before the attach the body stops
// colliding with pawns (constants_world_item::k_MountedBodyProfile): a kinematic item travelling through, then resting
// against, its carrier's capsule would shove the character every step. A Release restores the body's own profile.
class UMars_Processor_WorldItem_Mount : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_PendingMount;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_WorldItem_PendingMount& InPending,
                       FMars_Fragment_WorldItem& InState)
    {
        auto Body = InState.Body;
        if (ck::IsValid(Body))
        {
            // Still waiting on the batched AddBodies pass - try again next frame.
            if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
            { return; }

            if (utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
            {
                // The SetMotionType handler drops a request that reaches it before the body is added, so re-ask until
                // the mirror reads Kinematic. A duplicate that lands after the switch is a no-op in the handler.
                utils_jolt_body::Request_SetMotionType(Body,
                    FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
                return;
            }
        }

        auto Self = InHandle.As_WorldItem();

        // Snapshot before the remove: InPending is invalid once Request_TryRemove returns.
        const auto NewMount = InPending.Mount;
        const auto Carrier = InPending.Carrier;
        auto Node = InPending.Node;
        const auto Offset = InPending.Offset;
        const auto Arrive = InPending.Arrive;
        const auto RequestedAtSeconds = InPending.RequestedAtSeconds;

        Self.Request_TryRemove(FMars_Fragment_WorldItem_PendingMount);

        if (ck::EnsureIfNot(ck::IsValid(Node),
            f"[WorldItem] Mount of [{Self.ToString()}]: the attach point went away before the body read Kinematic - skipped"))
        { return; }

        const auto PrevMount = InState.Mount;
        InState.Mount = NewMount;
        InState.Carrier = Carrier;

        auto Root = InHandle.As_Transform();
        const auto WorldNow = utils_transform::Get_EntityCurrentTransform(Root);
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(Node);
        const auto FromOffset = WorldNow.GetRelativeTransform(NodeWorld);

        if (ck::IsValid(Body))
        {
            utils_jolt_body::Request_SetCollisionProfile(Body,
                FCk_Request_JoltBody_SetCollisionProfile(constants_world_item::k_MountedBodyProfile),
                FCk_Delegate_Request_OnCompleted(this, n"OnMountedProfileApplied"));
        }

        // utils_scene_node::Add never re-parents an attached node: detach first (immediate, removes the SceneNode
        // fragments, keeps the world pose).
        auto SceneNode = InHandle.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SceneNode))
        { utils_scene_node::Request_Detach(SceneNode); }

        utils_scene_node::Add(Root, Node, FromOffset);

        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(Self);

        // The time this mount waited (the body turning Kinematic) comes off a delayed arrival's schedule.
        auto Spec = FMars_WorldItem_ArriveSpec(0.0f, ck::IsValid(Presentation) ? Presentation.Mounting.ArriveSeconds : 0.0f, ECk_TweenEasing::OutCubic);
        if (Arrive.IsSet())
        { Spec = utils_world_item::Get_ArriveSpecAfter(Arrive.GetValue(), float32(System::GetGameTimeInSeconds() - RequestedAtSeconds)); }

        auto& Arrival = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Arrival);
        Arrival.FromOffset = FromOffset;
        Arrival.ToOffset = Offset;
        Arrival.Duration = Spec.Seconds;
        Arrival.DelaySeconds = Spec.DelaySeconds;
        Arrival.Easing = Spec.Easing;
        Arrival.Elapsed = 0.0f;

        if (PrevMount != NewMount && Self.Has_Fragment(FMars_Fragment_WorldItem_Signals))
        { Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountChanged.Broadcast(Self, PrevMount, NewMount); }
    }

    // The body has no profile read-back: the completed request is the record (the body is the world item's own entity).
    UFUNCTION()
    private void OnMountedProfileApplied(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        auto Owner = InRequestOwner;
        if (InResult != ECk_Request_OperationResult::Succeeded || ck::Is_NOT_Valid(Owner) || Owner.Has_Fragment(FMars_Fragment_WorldItem) == false)
        { return; }

        auto& State = Owner.Get_Fragment(FMars_Fragment_WorldItem);
        State.AppliedBodyProfile = TOptional<FName>(constants_world_item::k_MountedBodyProfile);
    }
}
