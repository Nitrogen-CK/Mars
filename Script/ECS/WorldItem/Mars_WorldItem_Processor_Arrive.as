// Holds a scene-node-attached world item's offset at FromOffset for DelaySeconds, then lerps it to ToOffset with Easing
// over Duration, then removes the Arrival fragment; a World-mode world item has then settled on its mount
// (OnMountSettled). With FromWorld set the start is re-read against the parent every pass, so a parent that moves under
// the travelling item (the hand's lateral snapping on an equip) never displaces where it set out from; KeepFrom anchors
// a no-travel spawn there in one pass and ends the arrival.
//
// Exactly ONE Request_UpdateOffset per frame: the scene-node request handler assigns the whole offset, so separate
// location / rotation / scale requests (utils_tween::Create_TweenSceneNodeOffsetTransform) clobber each other.
class UMars_Processor_WorldItem_Arrive : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_HandleRequests");
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_Arrival;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_WorldItem_Arrival& InArrival)
    {
        auto Node = InHandle.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Node),
            f"[WorldItem] Arrival on [{InHandle.ToString()}], which is not a scene node - dropped"))
        {
            InHandle.Request_TryRemove(FMars_Fragment_WorldItem_Arrival);
            return;
        }

        InArrival.Elapsed += float32(InDeltaT.Get_Seconds());

        // Snapshot before a possible remove: InArrival is invalid once Request_TryRemove returns.
        auto From = InArrival.FromOffset;
        const auto To = InArrival.ToOffset;
        const auto Duration = InArrival.Duration;
        const auto Elapsed = InArrival.Elapsed - InArrival.DelaySeconds;
        const auto Easing = InArrival.Easing;
        const auto KeepFrom = InArrival.KeepFrom;

        if (InArrival.FromWorld.IsSet())
        {
            const auto ParentWorld = utils_transform::Get_EntityCurrentTransform(utils_scene_node::Get_Parent(Node));
            From = InArrival.FromWorld.GetValue().GetRelativeTransform(ParentWorld);
        }

        if (KeepFrom)
        {
            utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(From));
            InHandle.Request_TryRemove(FMars_Fragment_WorldItem_Arrival);
            return;
        }

        // Still where it set out from (the gloves' grip), re-anchored while the parent moves.
        if (Elapsed < 0.0f)
        {
            if (InArrival.FromWorld.IsSet())
            { utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(From)); }

            return;
        }

        const float32 Alpha = Duration <= 0.0f ? 1.0f : Math::Min(1.0f, Elapsed / Duration);
        const float32 Eased = utils_tween::Get_EasedProgress(Easing, FCk_FloatRange_0to1(Alpha));

        const auto Offset = Alpha >= 1.0f ? To : utils_world_item::Blend(From, To, Eased);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));

        if (Alpha < 1.0f)
        { return; }

        InHandle.Request_TryRemove(FMars_Fragment_WorldItem_Arrival);

        auto Self = InHandle.As_WorldItem();
        if (Self.Get_Mode() != EMars_WorldItem_Mode::World || Self.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
        { return; }

        const auto Committed = Self.Get_Fragment(FMars_Fragment_WorldItem).Committed;
        Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountSettled.Broadcast(Self, Committed.Mount, Committed.Carrier);
    }
}
