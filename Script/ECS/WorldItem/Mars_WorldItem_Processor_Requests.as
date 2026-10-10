// Drains Carry, then Hold, then Release (each kind in queue order) for Persistent world items. Transitions are validated
// against Get_TargetMount, so a Carry and a Hold queued back to back are both legal; anything illegal, or a Transient
// item, is a caller bug.
//
// Carry / Hold never attach here: SetMotionType is deferred, so they write a PendingMount that
// UMars_Processor_WorldItem_Mount commits once the body reads Kinematic. Release commits immediately.
class UMars_Processor_WorldItem_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_WorldItem_Requests& InRequests,
                       FMars_Fragment_WorldItem& InState)
    {
        auto Self = InHandle.As_WorldItem();

        TArray<FMars_Request_WorldItem_Carry> CarryRequests = InRequests.CarryRequests;
        TArray<FMars_Request_WorldItem_Hold> HoldRequests = InRequests.HoldRequests;
        TArray<FMars_Request_WorldItem_Release> ReleaseRequests = InRequests.ReleaseRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_WorldItem_Requests);

        for (const auto& Request : CarryRequests)
        {
            auto Mount = FMars_WorldItem_MountRequest(EMars_WorldItem_Mount::Carried, Request.Carrier,
                FMars_WorldItem_MountOverride(Request.Point, Request.Offset));
            Mount.Arrive = Request.Arrive;
            HandleMountRequest(Self, InState, Mount);
        }

        for (const auto& Request : HoldRequests)
        {
            auto Mount = FMars_WorldItem_MountRequest(EMars_WorldItem_Mount::Held, Request.Carrier, FMars_WorldItem_MountOverride());
            Mount.Arrive = Request.Arrive;
            HandleMountRequest(Self, InState, Mount);
        }

        for (const auto& Request : ReleaseRequests)
        { HandleReleaseRequest(Self, InState, Request); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Carry / Hold
    //--------------------------------------------------------------------------------------------------------------------------

    //   Carry: World | Held -> Carried
    //   Hold:  Carried      -> Held
    // InRequest names the mount and the carrier; its attach node and offset are resolved here, from InRequest.Override where
    // a Carry set them, else from the definition.
    private void HandleMountRequest(FCk_Handle_WorldItem& InWorldItem,
                                    FMars_Fragment_WorldItem& InState,
                                    const FMars_WorldItem_MountRequest& InRequest)
    {
        const auto TargetMount = InWorldItem.Get_TargetMount();
        const auto IsCarry = InRequest.Mount == EMars_WorldItem_Mount::Carried;
        const auto IsLegal = IsCarry
            ? (TargetMount == EMars_WorldItem_Mount::World || TargetMount == EMars_WorldItem_Mount::Held)
            : TargetMount == EMars_WorldItem_Mount::Carried;

        if (DoEnsureLegal(InWorldItem, InRequest.Mount, IsLegal) == false)
        { return; }

        const auto Override = InRequest.Override;
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(InWorldItem);
        const auto PointTag = IsCarry ? (Override.Point.IsSet() ? Override.Point.GetValue() : Presentation.Mounting.CarryPoint)
                                      : GameplayTags::AttachPoint_Mars_Hand;

        auto AttachPoints = InRequest.Carrier.As_AttachPoints(ECk_SanityCheck::UnChecked);
        const auto HasPoint = ck::IsValid(AttachPoints) && AttachPoints.Has_AttachPoint(PointTag);
        if (ck::EnsureIfNot(HasPoint,
            f"[WorldItem] Mount [{InRequest.Mount :n}] of [{InWorldItem.ToString()}]: carrier [{InRequest.Carrier.ToString()}] publishes no attach point [{PointTag.ToString()}]"))
        { return; }

        auto Pickup = InState.Pickup;
        if (ck::IsValid(Pickup))
        { Pickup.Request_SetEnableDisable(FMars_Request_Interactable_SetEnableDisable(ECk_EnableDisable::Disable)); }

        auto Body = InState.Body;
        if (ck::IsValid(Body) && utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
        {
            utils_jolt_body::Request_SetMotionType(Body,
                FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        }

        auto Mount = FMars_Fragment_WorldItem_PendingMount(InRequest.Mount, InRequest.Carrier);
        Mount.Node = AttachPoints.Get_AttachPoint(PointTag);
        Mount.Offset = IsCarry ? (Override.Offset.IsSet() ? Override.Offset.GetValue() : Presentation.Mounting.CarryOffset)
                               : Presentation.Mounting.HeldOffset;
        Mount.Arrive = InRequest.Arrive;
        Mount.RequestedAtSeconds = System::GetGameTimeInSeconds();

        auto& Pending = InWorldItem.AddOrGet_Fragment(FMars_Fragment_WorldItem_PendingMount);
        Pending = Mount;
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Release
    //--------------------------------------------------------------------------------------------------------------------------

    // Carried | Held -> World: detach (immediate, keeps the world pose), body back to Dynamic and its own collision profile
    // plus a PendingLaunch, transfer the item back into the holder, re-enable the pickup.
    private void HandleReleaseRequest(FCk_Handle_WorldItem& InWorldItem,
                                      FMars_Fragment_WorldItem& InState,
                                      const FMars_Request_WorldItem_Release& InRequest)
    {
        const auto TargetMount = InWorldItem.Get_TargetMount();
        const auto IsLegal = TargetMount == EMars_WorldItem_Mount::Carried || TargetMount == EMars_WorldItem_Mount::Held;
        if (DoEnsureLegal(InWorldItem, EMars_WorldItem_Mount::World, IsLegal) == false)
        { return; }

        auto Source = InRequest.SourceInventory;
        const auto CanReturn = ck::IsValid(Source) && ck::IsValid(InRequest.Item);
        if (ck::EnsureIfNot(CanReturn,
            f"[WorldItem] Release of [{InWorldItem.ToString()}] has no source inventory or item to return to the holder - skipped"))
        { return; }

        InWorldItem.Request_TryRemove(FMars_Fragment_WorldItem_PendingMount);
        InWorldItem.Request_TryRemove(FMars_Fragment_WorldItem_Arrival);

        auto SceneNode = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SceneNode))
        { utils_scene_node::Request_Detach(SceneNode); }

        // The launch processor waits for the body to read Dynamic before applying the velocity.
        auto Body = InState.Body;
        if (ck::IsValid(Body))
        {
            utils_jolt_body::Request_SetMotionType(Body,
                FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
            utils_jolt_body::Request_SetCollisionProfile(Body,
                FCk_Request_JoltBody_SetCollisionProfile(InState.BodyProfile),
                FCk_Delegate_Request_OnCompleted(this, n"OnOwnProfileRestored"));

            auto& Launch = InWorldItem.AddOrGet_Fragment(FMars_Fragment_WorldItem_PendingLaunch);
            Launch.LinearVelocity = InRequest.LinearVelocity;
            Launch.AngularVelocityDeg = InRequest.AngularVelocityDeg;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InState.Holder),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnReleaseAdoptComplete"));

        auto Pickup = InState.Pickup;
        if (ck::IsValid(Pickup))
        { Pickup.Request_SetEnableDisable(FMars_Request_Interactable_SetEnableDisable(ECk_EnableDisable::Enable)); }

        const auto PrevMount = InState.Mount;
        InState.Mount = EMars_WorldItem_Mount::World;
        InState.Carrier = FCk_Handle();

        Broadcast_MountChanged(InWorldItem, PrevMount, EMars_WorldItem_Mount::World);
    }

    UFUNCTION()
    private void OnReleaseAdoptComplete(FCk_Handle_Inventory InSource,
                                        FCk_Handle_Item InItem,
                                        FCk_Handle_Inventory InTarget,
                                        int32 InCount,
                                        FCk_Handle_Item InNewItemInTarget,
                                        ECk_Inventory_OperationResult_Transfer InResult)
    {
        // A failed return leaves a pickable body in the world whose holder is empty.
        ck::EnsureIfNot(InResult == ECk_Inventory_OperationResult_Transfer::Success,
            f"[WorldItem] Returning [{InItem.ToString()}] from [{InSource.ToString()}] to its holder [{InTarget.ToString()}] failed with [{InResult :n}]");
    }

    // The body has no profile read-back: the completed request is the record (the body is the world item's own entity).
    UFUNCTION()
    private void OnOwnProfileRestored(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        auto Owner = InRequestOwner;
        if (InResult != ECk_Request_OperationResult::Succeeded || ck::Is_NOT_Valid(Owner) || Owner.Has_Fragment(FMars_Fragment_WorldItem) == false)
        { return; }

        auto& State = Owner.Get_Fragment(FMars_Fragment_WorldItem);
        State.AppliedBodyProfile = TOptional<FName>(State.BodyProfile);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------------------------------------------------------

    private bool DoEnsureLegal(FCk_Handle_WorldItem& InWorldItem, EMars_WorldItem_Mount InNewMount, bool InIsLegal) const
    {
        const auto Persistence = InWorldItem.Get_Persistence();
        const auto TargetMount = InWorldItem.Get_TargetMount();
        const auto IsPersistent = Persistence == EMars_WorldItem_Persistence::Persistent;

        if (ck::EnsureIfNot(IsPersistent && InIsLegal,
            f"[WorldItem] Illegal move to [{InNewMount :n}] on [{InWorldItem.ToString()}]: mount [{TargetMount :n}], persistence [{Persistence :n}] - skipped"))
        { return false; }

        return true;
    }

    private void Broadcast_MountChanged(FCk_Handle_WorldItem& InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        if (InPrev == InNew)
        { return; }

        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Signals))
        { InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountChanged.Broadcast(InWorldItem, InPrev, InNew); }
    }
}
