// Lerps a scene-node-attached world item's offset from FromOffset to ToOffset with OutCubic over Duration, then removes
// the Arrival fragment.
//
// Exactly ONE Request_UpdateOffset per frame: the scene-node request handler assigns the whole offset, so separate
// location / rotation / scale requests (utils_tween::Create_TweenSceneNodeOffsetTransform) clobber each other.
class UMars_Processor_WorldItem_Arrive : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
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
        const auto From = InArrival.FromOffset;
        const auto To = InArrival.ToOffset;
        const auto Duration = InArrival.Duration;
        const auto Elapsed = InArrival.Elapsed;

        const float32 Alpha = Duration <= 0.0f ? 1.0f : Math::Min(1.0f, Elapsed / Duration);
        const float32 Remaining = 1.0f - Alpha;
        const float32 Eased = 1.0f - Remaining * Remaining * Remaining;

        const auto Offset = Alpha >= 1.0f ? To : utils_world_item::Blend(From, To, Eased);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));

        if (Alpha >= 1.0f)
        { InHandle.Request_TryRemove(FMars_Fragment_WorldItem_Arrival); }
    }
}
