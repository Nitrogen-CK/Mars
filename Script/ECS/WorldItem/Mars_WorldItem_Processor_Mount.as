// Commits a PendingMount (written by UMars_Processor_WorldItem_Reconcile) once the body can be scene-node-attached, then
// broadcasts OnMountChanged.
//
// Gate: no body, OR the body is added and reads Kinematic (utils_jolt_body::Get_MotionType is the mirror the
// SetMotionType handler stamps). Attaching while the body still reads Dynamic would fight the Jolt writeback; a Kinematic
// body follows the ECS transform (FTag_JoltBody_KinematicFromECS -> FProcessor_JoltBody_KinematicPush), so once attached
// nothing else moves it. A body whose setup failed, or that is still setting up after
// constants_world_item::k_BodySetupBudgetPasses passes, has nothing to make Kinematic: the mount commits without it (an
// ensure names the body's setup), as a bodiless item's does.
//
// The attach keeps the current world pose (the relative transform to the attach point), and an Arrival lerps the offset
// to the mount offset, so the item visibly travels to the back / hand / dock instead of snapping; a mount whose arrival
// has no travel attaches at the offset and broadcasts OnMountSettled at once (the Arrive processor broadcasts it at the end
// of a travel). Before the attach the body takes its retained mounted profile (QueryOnly by default): a
// kinematic item travelling through, then resting against, its carrier's capsule would shove the character every step. A
// release restores the body's own profile.
class UMars_Processor_WorldItem_Mount : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_HandleRequests");
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
        auto MountsWithBody = ck::IsValid(Body);
        if (MountsWithBody)
        {
            const auto SetupState = utils_jolt_body::Get_SetupState(Body);
            if (SetupState == ECk_JoltBody_SetupState::Failed)
            {
                ck::EnsureIfNot(false, f"[WorldItem] Mount of [{InHandle.ToString()}]: its body failed setup ({utils_jolt_body::Get_SetupFailure(Body) :n}: {utils_jolt_body::Get_SetupDiagnostic(Body)}) - it mounts without the body");
                MountsWithBody = false;
            }
            else if (SetupState == ECk_JoltBody_SetupState::Pending)
            {
                // Still waiting on the batched AddBodies pass - try again next frame, within the budget.
                InPending.WaitedPasses += 1;
                if (InPending.WaitedPasses <= constants_world_item::k_BodySetupBudgetPasses)
                { return; }

                ck::EnsureIfNot(false, f"[WorldItem] Mount of [{InHandle.ToString()}]: its body is still setting up after {InPending.WaitedPasses} passes ({utils_jolt_body::Get_SetupDiagnostic(Body)}) - it mounts without the body");
                MountsWithBody = false;
            }
            else if (utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
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
        const auto Target = InPending.Target;
        auto Node = InPending.Node;
        const auto Arrive = InPending.Arrive;
        const auto RequestedAtSeconds = InPending.RequestedAtSeconds;

        Self.Request_TryRemove(FMars_Fragment_WorldItem_PendingMount);

        if (ck::EnsureIfNot(ck::IsValid(Node),
            f"[WorldItem] Mount of [{Self.ToString()}]: the attach point went away before the body read Kinematic - skipped"))
        { return; }

        const auto PrevMount = InState.Committed.Mount;
        InState.Committed = Target;

        auto Root = InHandle.As_Transform();
        const auto WorldNow = utils_transform::Get_EntityCurrentTransform(Root);
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(Node);
        const auto FromOffset = WorldNow.GetRelativeTransform(NodeWorld);

        if (MountsWithBody)
        {
            utils_jolt_body::Request_SetCollisionProfile(Body,
                FCk_Request_JoltBody_SetCollisionProfile(Self.Get_Fragment(FMars_Fragment_WorldItem_Params).MountedBodyProfile),
                FCk_Delegate_Request_OnCompleted(this, n"OnMountedProfileApplied"));
        }

        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(Self);

        // The time this mount waited (the body turning Kinematic) comes off a delayed arrival's schedule.
        auto Spec = FMars_WorldItem_ArriveSpec(0.0f, ck::IsValid(Presentation) ? Presentation.Mounting.ArriveSeconds : 0.0f, ECk_TweenEasing::OutCubic);
        if (Arrive.IsSet())
        { Spec = utils_world_item::Get_ArriveSpecAfter(Arrive.GetValue(), float32(System::GetGameTimeInSeconds() - RequestedAtSeconds)); }

        const auto HasTravel = Spec.Seconds > 0.0f || Spec.DelaySeconds > 0.0f;

        // utils_scene_node::Add never re-parents an attached node: detach first (immediate, removes the SceneNode
        // fragments, keeps the world pose).
        auto SceneNode = InHandle.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SceneNode))
        { utils_scene_node::Request_Detach(SceneNode); }

        utils_scene_node::Add(Root, Node, HasTravel ? FromOffset : Target.Offset);

        if (HasTravel)
        {
            auto& Arrival = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Arrival);
            Arrival.FromOffset = FromOffset;
            Arrival.ToOffset = Target.Offset;
            Arrival.Duration = Spec.Seconds;
            Arrival.DelaySeconds = Spec.DelaySeconds;
            Arrival.Easing = Spec.Easing;
            Arrival.Elapsed = 0.0f;
        }

        // InState is not read past this line: a listener may add a fragment to the world item.
        if (Self.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
        { return; }

        if (PrevMount != Target.Mount)
        { Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountChanged.Broadcast(Self, PrevMount, Target.Mount); }

        if (HasTravel == false && Self.Has_Fragment(FMars_Fragment_WorldItem_Signals))
        { Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountSettled.Broadcast(Self, Target.Mount, Target.Carrier); }
    }

    // The body has no profile read-back: the completed request is the record (the body is the world item's own entity).
    UFUNCTION()
    private void OnMountedProfileApplied(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        auto Owner = InRequestOwner;
        if (InResult != ECk_Request_OperationResult::Succeeded || ck::Is_NOT_Valid(Owner) || Owner.Has_Fragment(FMars_Fragment_WorldItem) == false)
        { return; }

        auto& State = Owner.Get_Fragment(FMars_Fragment_WorldItem);
        State.AppliedBodyProfile = TOptional<FName>(Owner.Get_Fragment(FMars_Fragment_WorldItem_Params).MountedBodyProfile);
    }
}
