class UMars_Processor_Anchor_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Anchor_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Anchor);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Anchor_Requests& InRequests,
                       FMars_Fragment_Anchor& InAnchorComp)
    {
        auto Self = InHandle.As_Anchor();
        const auto ClearRequests = InRequests.Clear;
        const auto ResolveRequests = InRequests.Resolve;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Anchor_Requests);

        for (int32 Index = 0; Index < ClearRequests.Num(); ++Index)
        {
            if (ck::IsValid(InAnchorComp.Spawned))
            { utils_entity_lifetime::Request_DestroyEntity(InAnchorComp.Spawned); }

            InAnchorComp.Spawned = FCk_Handle();
            InAnchorComp.State = EMars_Anchor_State::Cleared;
            InAnchorComp.RowIndex.Reset();
            InAnchorComp.Role = EMars_Anchor_Role::None;
        }

        for (const auto& Request : ResolveRequests)
        {
            if (InAnchorComp.State == EMars_Anchor_State::Spawned)
            {
                LogDisplay(f"Anchor {Self.Get_AnchorId().ToString()} is already resolved");
                continue;
            }

            auto Table = Self.Get_Table();
            if (ck::EnsureIfNot(ck::IsValid(Table), f"[Anchor] [{Self.Get_AnchorId().ToString()}] has no loadable table"))
            { continue; }

            if (ck::EnsureIfNot(Request.RowIndex >= 0 && Request.RowIndex < Table.Rows.Num(),
                f"[Anchor] [{Self.Get_AnchorId().ToString()}] row {Request.RowIndex} is outside its table ({Table.Rows.Num()} rows)"))
            { continue; }

            const auto Row = Table.Rows[Request.RowIndex];
            InAnchorComp.Spawned = FCk_Handle();
            if (Row.Script != nullptr)
            {
                auto Pending = utils_entity_script::Request_SpawnEntity(
                    InHandle, Row.Script, FMars_Anchor_SpawnParams(Self.Get_Transform(), Request.Context));
                InAnchorComp.Spawned = Pending.Get_EntityUnderConstruction();
            }

            InAnchorComp.State = EMars_Anchor_State::Spawned;
            InAnchorComp.Role = Request.Role;
            InAnchorComp.RowIndex = TOptional<int32>(Request.RowIndex);

            if (Self.Has_Fragment(FMars_Fragment_Anchor_Signals))
            { Self.Get_Fragment(FMars_Fragment_Anchor_Signals).OnResolved.Broadcast(Self, Request.RowIndex); }
        }
    }
}
