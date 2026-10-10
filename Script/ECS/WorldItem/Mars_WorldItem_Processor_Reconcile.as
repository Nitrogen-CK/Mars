// Every pass, a Persistent world item follows the inventory its item lives in (utils_world_item::Resolve_Target): its own
// holder is World, the selected slot of its carrier's hotbar is Held, any other mounting inventory is Carried on that
// inventory's owner. A world item whose item, or whose item's carrier, is gone or ending ends itself: the item dies with
// its inventory, and its body with it.
//
// A target that differs from the committed mount, with no mount pending and no arrival in flight, becomes a PendingMount
// that UMars_Processor_WorldItem_Mount commits once the body reads Kinematic; it takes the next mount's arrival
// (Request_ArriveNextMount) when one is fresh. Only a release brings an item home and commits World; a home it reached any
// other way ensures and commits World here. Nothing is reconciled while a release waits on its transfer.
class UMars_Processor_WorldItem_Reconcile : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_HandleRequests");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Mount");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_WorldItem& InState)
    {
        if (InState.Item.IsSet() == false || utils_world_item::Get_IsEnding(InHandle))
        { return; }

        auto Self = InHandle.As_WorldItem();
        const auto Resolution = utils_world_item::Resolve_Target(Self);
        if (Resolution.Placement == EMars_WorldItem_Placement::ItemGone)
        {
            End(Self, f"its item [{InState.Item.GetValue().ToString()}] is gone");
            return;
        }

        if (Resolution.Placement == EMars_WorldItem_Placement::CarrierGone)
        {
            End(Self, f"the inventory holding its item [{Resolution.Inventory.ToString()}] or that inventory's owner is gone");
            return;
        }

        // A release waiting on its transfer commits World from the transfer's answer.
        if (Self.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease))
        { return; }

        if (Resolution.Placement == EMars_WorldItem_Placement::Unmountable)
        {
            Report_Unmountable(Self, InState, Resolution);
            return;
        }

        InState.ReportedUnmountedIn.Reset();

        if (Self.Has_Fragment(FMars_Fragment_WorldItem_PendingMount) || Self.Has_Fragment(FMars_Fragment_WorldItem_Arrival))
        { return; }

        const auto& Target = Resolution.Target;
        if (utils_world_item::Get_IsSameMount(Target, InState.Committed))
        { return; }

        if (Target.Mount == EMars_WorldItem_Mount::World)
        {
            ck::EnsureIfNot(false,
                f"[WorldItem] [{Self.ToString()}] is back in its holder without a release (mount [{InState.Committed.Mount :n}]): committed World without a launch");
            utils_world_item::Commit_World(Self, TOptional<FMars_Fragment_WorldItem_PendingLaunch>(), FCk_Delegate_Request_OnCompleted());
            return;
        }

        Request_MountTo(Self, InState, Target);
    }

    // The mount waits for the body to read Kinematic (the Mount processor attaches it then); the pickup holds its Mounted
    // claim while the item rides anything (the World commit releases it).
    private void Request_MountTo(FCk_Handle_WorldItem& InWorldItem, FMars_Fragment_WorldItem& InState, const FMars_WorldItem_MountTarget& InTarget)
    {
        auto AttachPoints = InTarget.Carrier.As_AttachPoints();

        auto Pickup = InState.Pickup;
        if (ck::IsValid(Pickup))
        { Pickup.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Mounted)); }

        auto Body = InState.Body;
        if (ck::IsValid(Body) && utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
        { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic)); }

        auto Mount = FMars_Fragment_WorldItem_PendingMount();
        Mount.Target = InTarget;
        Mount.Node = AttachPoints.Get_AttachPoint(InTarget.Point);
        Mount.RequestedAtSeconds = System::GetGameTimeInSeconds();

        if (InState.NextArrive.IsSet())
        {
            const auto Next = InState.NextArrive.GetValue();
            InState.NextArrive.Reset();

            const auto AgeSeconds = System::GetGameTimeInSeconds() - Next.StampedAtSeconds;
            if (AgeSeconds <= constants_world_item::k_ArriveFromMaxAgeSeconds)
            {
                Mount.Arrive = TOptional<FMars_WorldItem_ArriveSpec>(Next.Arrive);
                Mount.RequestedAtSeconds = Next.StampedAtSeconds;
            }
        }

        auto& Pending = InWorldItem.AddOrGet_Fragment(FMars_Fragment_WorldItem_PendingMount);
        Pending = Mount;
    }

    // The item dies with its inventory: its body goes too, detached first so it never rides a node on its way out.
    private void End(FCk_Handle_WorldItem& InWorldItem, const FString& InWhy)
    {
        auto SceneNode = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SceneNode))
        { utils_scene_node::Request_Detach(SceneNode); }

        FCk_Handle Entity = InWorldItem;
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    // An inventory with no mount marker (or a carrier without the attach point) holding a Persistent item is a composition
    // defect; it is reported once per placement and the world item stays where it is.
    private void Report_Unmountable(FCk_Handle_WorldItem& InWorldItem, FMars_Fragment_WorldItem& InState, const FMars_WorldItem_Resolution& InResolution)
    {
        const auto AlreadyReported = InState.ReportedUnmountedIn.IsSet() && InState.ReportedUnmountedIn.GetValue() == InResolution.Inventory;
        if (AlreadyReported)
        { return; }

        InState.ReportedUnmountedIn = TOptional<FCk_Handle_Inventory>(InResolution.Inventory);
        ck::EnsureIfNot(false,
            f"[WorldItem] [{InWorldItem.ToString()}]'s item sits in [{InResolution.Inventory.ToString()}], which names no mount its owner publishes: it stays where it is");
    }
}
