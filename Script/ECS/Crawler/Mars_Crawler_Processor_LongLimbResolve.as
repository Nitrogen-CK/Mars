// Optional game demonstration on a dedicated articulation. It does not participate in the crawler body jab.
// One owner supplies a target sphere and a scoped limb action; this observer owns receipt consumption and dedup.
struct FMars_Fragment_Crawler_LongLimbDemo
{
    UPROPERTY()
    FCk_Handle_ProceduralArticulation Subject;

    UPROPERTY()
    FCk_Handle_ProceduralActionPlayer Player;

    UPROPERTY()
    FCk_Handle_ProceduralAction Action;

    UPROPERTY()
    FCk_Handle ActionScope;

    UPROPERTY()
    FCk_Handle_Transform Target;

    UPROPERTY()
    FCk_Handle TargetHurtbox;

    UPROPERTY()
    FCk_Handle_DamageDealer Dealer;

    UPROPERTY()
    float32 Damage = 15.0f;

    UPROPERTY()
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Blunt;

    // None means an explicitly owner-open manual demonstration. A named clip window uses receipt windows.
    UPROPERTY()
    FName WindowId;

    UPROPERTY()
    FMars_Crawler_LongLimbReceiptState Receipt;

    UPROPERTY()
    int64 ReceiptCursor = 0;

    UPROPERTY()
    bool ConsumePending = false;

    UPROPERTY()
    int64 PendingConsumeCursor = 0;

    UPROPERTY()
    bool TerminalSeen = false;

    UPROPERTY()
    FCk_ProceduralAction_Result TerminalResult;

    UPROPERTY()
    bool StreamReleased = false;

    UPROPERTY()
    bool CancelIssued = false;

    UPROPERTY()
    int32 WindowGeneration = 1;

    UPROPERTY()
    bool ZeroBoundaryProcessed = false;

    UPROPERTY()
    int32 CommittedGeneration = 0;

    UPROPERTY()
    int32 GeometryOverlapCount = 0;

    UPROPERTY()
    int32 DamageCandidateCount = 0;

    UPROPERTY()
    int32 DamageRequestCount = 0;

    UPROPERTY()
    int32 WorldQueryCount = 0;

    UPROPERTY()
    int32 AcceptedReceiptCount = 0;

    UPROPERTY()
    int32 EvaluatedSampleCount = 0;

    UPROPERTY()
    int32 EvaluatedOnlyHitCount = 0;

    UPROPERTY()
    int32 MaxObservedSegmentCount = 0;

    UPROPERTY()
    float64 MaxRequestedAcceptedErrorCm = 0.0;

    UPROPERTY()
    float64 MaxAcceptedReachCm = 0.0;

    UPROPERTY()
    float64 MinFirstSegmentHeightCm = 1000000.0;

    UPROPERTY()
    float64 MaxFirstSegmentHeightCm = -1000000.0;

    UPROPERTY()
    bool WindowClosed = false;

    UPROPERTY()
    FString Failure;
}

namespace utils_crawler_long_limb_demo
{
    // The explicit sphere is centered on its damage zone's entity. A separately supplied
    // transform cannot lend its collision history to another target's hurtbox.
    bool Get_IsTargetBindingValid(FCk_Handle_Transform InTarget, FCk_Handle InHurtbox)
    {
        FCk_Handle TargetEntity = InTarget;
        if (ck::Is_NOT_Valid(TargetEntity) || ck::Is_NOT_Valid(InHurtbox) ||
            utils_entity_lifetime::Get_IsPendingDestroy(TargetEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) ||
            utils_entity_lifetime::Get_IsPendingDestroy(InHurtbox, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }
        const auto Zone = utils_hit_zone::TryGet_Zone(InHurtbox);
        FCk_Handle ZoneEntity = Zone;
        return ck::IsValid(Zone) && ZoneEntity == TargetEntity && Zone.Get_IsEnabled() &&
            Zone.Get_Hurtboxes().Contains(InHurtbox);
    }

    bool Attach(FCk_Handle& InOwner, FCk_Handle_ProceduralArticulation InSubject,
        FCk_Handle_ProceduralActionPlayer InPlayer, FCk_Handle_ProceduralAction InAction,
        FCk_Handle InScope, FCk_Handle_Transform InTarget, FCk_Handle InHurtbox,
        const FMars_Crawler_LongLimbSpec& InSpec, FName InWindowId = NAME_None)
    {
        FCk_Handle PlayerOwner = InPlayer;
        FCk_Handle SubjectOwner = InSubject;
        if (ck::Is_NOT_Valid(InOwner) || ck::Is_NOT_Valid(InSubject) || ck::Is_NOT_Valid(InPlayer) ||
            ck::Is_NOT_Valid(InAction) || ck::Is_NOT_Valid(InScope) || ck::Is_NOT_Valid(InTarget) ||
            InOwner != PlayerOwner || InOwner != SubjectOwner ||
            Get_IsTargetBindingValid(InTarget, InHurtbox) == false ||
            InOwner.Has_Fragment(FMars_Fragment_Crawler_LongLimbDemo))
        { return false; }
        auto Demo = FMars_Fragment_Crawler_LongLimbDemo();
        if (utils_crawler_long_limb_receipt::Begin(Demo.Receipt, InSpec,
            InAction.Get_Identity(), 1) == false)
        { return false; }
        Demo.Subject = InSubject;
        Demo.Player = InPlayer;
        Demo.Action = InAction;
        Demo.ActionScope = InScope;
        Demo.Target = InTarget;
        Demo.TargetHurtbox = InHurtbox;
        Demo.WindowId = InWindowId;
        InOwner.Add_Fragment(Demo);
        return true;
    }
}

class UMars_Processor_Crawler_LongLimbResolve : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Overlap";
    default _RunAfter.Add(n"FProcessor_Probe_Setup");
    default _RunAfter.Add(n"FProcessor_Probe_HandleRequests");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateShape");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform_LinearCast");

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
        FMars_Fragment_Crawler_LongLimbDemo& InDemo)
    {
        if (InDemo.StreamReleased ||
            utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }
        if (ck::Is_NOT_Valid(InDemo.Player))
        { Close(InDemo, "Player disappeared before terminal consumption"); return; }
        if (ck::Is_NOT_Valid(InDemo.Subject) || ck::Is_NOT_Valid(InDemo.Target))
        { Close(InDemo, "Subject or target disappeared"); }
        if (utils_crawler_long_limb_demo::Get_IsTargetBindingValid(InDemo.Target, InDemo.TargetHurtbox) == false)
        { Close(InDemo, "Target sphere and hurtbox no longer identify the same live damage zone"); }

        // Capture the target once when this actual subject revision becomes visible in the overlap group.
        // A later target move at the same revision cannot rewrite that observation.
        const auto Revision = ck::IsValid(InDemo.Subject) ? InDemo.Subject.Get_SettledRevision() : 0;
        if (InDemo.Receipt.Closed == false && Revision > 0 &&
            (InDemo.Receipt.TargetHistory.IsEmpty() ||
            Revision > InDemo.Receipt.TargetHistory.Last().SubjectPoseRevision))
        {
            const auto Center = utils_transform::Get_EntityCurrentLocation(InDemo.Target);
            if (utils_crawler_long_limb_receipt::ObserveTarget(InDemo.Receipt, Revision, Center) == false)
            { Close(InDemo, "Target observation is malformed"); return; }
        }
        if (InDemo.ConsumePending)
        { return; }

        const auto Page = InDemo.Player.Read_Receipts(InDemo.Receipt.Identity, InDemo.ReceiptCursor, 16);
        if (InDemo.TerminalSeen && ck::Is_NOT_Valid(InDemo.Action) &&
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired)
        {
            // A destroyed action scope has no live handle to release. The store expires its
            // terminal stream only after owner removal and acknowledgement of every record.
            InDemo.StreamReleased = true;
            return;
        }
        if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
        { Close(InDemo, "Receipt stream has a gap or expired"); }

        for (const auto& Record : Page.Get_Records())
        {
            if (Record.Get_Identity().Get_Value() != InDemo.Receipt.Identity.Get_Value())
            { Close(InDemo, "Receipt identity changed"); continue; }
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose &&
                InDemo.WindowClosed == false)
            { Accept(InHandle, InDemo, Record.Get_Receipt()); }
            else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::WindowsClosed)
            { InDemo.WindowClosed = true; }
            else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
            {
                InDemo.WindowClosed = true;
                InDemo.TerminalSeen = true;
                InDemo.TerminalResult = Record.Get_Result();
            }
        }

        if (Page.Get_Records().IsEmpty() == false)
        {
            InDemo.PendingConsumeCursor = Page.Get_LastStreamSequence();
            InDemo.ConsumePending = true;
            utils_procedural_action_player::Request_ConsumeReceipts(InDemo.Player,
                FCk_Request_ProceduralActionPlayer_ConsumeReceipts(InDemo.Receipt.Identity,
                    InDemo.PendingConsumeCursor),
                FCk_Delegate_Request_OnCompleted(this, n"OnConsumed"));
        }
        else if (InDemo.TerminalSeen)
        { Release(InDemo); }
    }

    private void Accept(FCk_Handle InOwner, FMars_Fragment_Crawler_LongLimbDemo& InDemo,
        const FCk_ProceduralAction_Receipt& InReceipt)
    {
        if (InDemo.Receipt.Closed)
        { return; }
        const auto FromTime = InReceipt.Get_Interval().Get_FromTime();
        const auto ToTime = InReceipt.Get_Interval().Get_ToTime();
        if (InDemo.WindowId.IsNone() == false && InDemo.ZeroBoundaryProcessed == false &&
            FromTime.Get_Seconds() == 0.0)
        {
            for (const auto& Event : InReceipt.Get_Interval().Get_Events())
            {
                if (Event.Get_Time().Get_Seconds() != 0.0)
                { continue; }
                InDemo.ZeroBoundaryProcessed = true;
                if (Event.Get_Id() == InDemo.WindowId &&
                    Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowEnter)
                { ++InDemo.WindowGeneration; }
            }
        }
        auto WindowActive = InDemo.WindowId.IsNone();
        if (WindowActive == false)
        {
            for (const auto& Window : InReceipt.Get_Interval().Get_Windows())
            { WindowActive = WindowActive || Window == InDemo.WindowId; }
        }

        // Even outside a hit window, accept and validate chain continuity for the next interval.
        const auto Geometry = utils_crawler_long_limb_receipt::ResolveAccepted(InDemo.Receipt, InReceipt, WindowActive);
        if (Geometry.Valid == false)
        { Close(InDemo, Geometry.Failure); return; }
        ++InDemo.AcceptedReceiptCount;
        InDemo.EvaluatedSampleCount += InReceipt.Get_IntermediateSamples().Num();
        for (const auto& Limb : InReceipt.Get_CurrentPose().Get_Limbs())
        {
            if (Limb.Get_Id() != InDemo.Receipt.Spec.LimbId)
            { continue; }
            InDemo.MaxObservedSegmentCount = Math::Max(InDemo.MaxObservedSegmentCount,
                Limb.Get_Segments().Num());
            InDemo.MaxRequestedAcceptedErrorCm = Math::Max(InDemo.MaxRequestedAcceptedErrorCm,
                (Limb.Get_RequestedEndpoint().GetLocation() -
                    Limb.Get_AcceptedEndpoint().GetLocation()).Size());
            const auto RootLocation = InReceipt.Get_CurrentPose().Get_RootFrame().GetLocation();
            InDemo.MaxAcceptedReachCm = Math::Max(InDemo.MaxAcceptedReachCm,
                (Limb.Get_AcceptedEndpoint().GetLocation() - RootLocation).Size());
            if (Limb.Get_Segments().IsEmpty() == false)
            {
                const auto Height = Limb.Get_Segments()[0].GetLocation().Z - RootLocation.Z;
                InDemo.MinFirstSegmentHeightCm = Math::Min(InDemo.MinFirstSegmentHeightCm, Height);
                InDemo.MaxFirstSegmentHeightCm = Math::Max(InDemo.MaxFirstSegmentHeightCm, Height);
            }
        }
        if (Geometry.SeedOnly || WindowActive == false || InDemo.CommittedGeneration == InDemo.WindowGeneration)
        { ApplyEndEvents(InDemo, InReceipt, ToTime); return; }

        const auto WorldResolution = utils_crawler_long_limb_world::Resolve(InOwner, Geometry,
            InDemo.Receipt.Spec.TargetRadiusCm);
        InDemo.GeometryOverlapCount += WorldResolution.GeometryOverlapCount;
        InDemo.WorldQueryCount += WorldResolution.WorldQueryCount;
        if (WorldResolution.Valid == false)
        { Close(InDemo, WorldResolution.Failure); return; }
        if (WorldResolution.TargetHit == false)
        { ApplyEndEvents(InDemo, InReceipt, ToTime); return; }

        if (WorldResolution.EndpointOnlyMissedTarget)
        { ++InDemo.EvaluatedOnlyHitCount; }

        ++InDemo.DamageCandidateCount;
        InDemo.CommittedGeneration = InDemo.WindowGeneration;
        if (ck::IsValid(InDemo.Dealer) && ck::IsValid(InDemo.TargetHurtbox) &&
            InDemo.Damage > 0.0f && InDemo.DamageType.IsValid())
        {
            auto Event = utils_damage_dealer::Make_Event(InDemo.Dealer, InDemo.Damage, InDemo.DamageType);
            InDemo.Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(InDemo.TargetHurtbox, Event));
            ++InDemo.DamageRequestCount;
        }
        ApplyEndEvents(InDemo, InReceipt, ToTime);
    }

    private void ApplyEndEvents(FMars_Fragment_Crawler_LongLimbDemo& InDemo,
        const FCk_ProceduralAction_Receipt& InReceipt, FCk_Time InToTime)
    {
        if (InDemo.WindowId.IsNone())
        { return; }
        for (const auto& Event : InReceipt.Get_Interval().Get_Events())
        {
            if (Event.Get_Id() == InDemo.WindowId && Event.Get_Time() == InToTime &&
                Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowEnter &&
                !(InToTime.Get_Seconds() == 0.0 && InDemo.ZeroBoundaryProcessed))
            { ++InDemo.WindowGeneration; }
        }
    }

    private void Close(FMars_Fragment_Crawler_LongLimbDemo& InDemo, FString InReason)
    {
        InDemo.WindowClosed = true;
        InDemo.Receipt.Closed = true;
        if (InDemo.Failure.IsEmpty())
        { InDemo.Failure = InReason; }
        FCk_Handle ActionEntity = InDemo.Action;
        if (InDemo.CancelIssued == false && ck::IsValid(ActionEntity) &&
            utils_entity_lifetime::Get_IsPendingDestroy(ActionEntity,
                ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false &&
            InDemo.Action.Get_State() != ECk_ProceduralAction_State::Finished)
        {
            InDemo.CancelIssued = true;
            InDemo.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
        }
    }

    UFUNCTION()
    private void OnConsumed(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        if (ck::Is_NOT_Valid(InRequestOwner) ||
            InRequestOwner.Has_Fragment(FMars_Fragment_Crawler_LongLimbDemo) == false)
        { return; }
        auto& Demo = InRequestOwner.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        if (Demo.ConsumePending == false)
        { return; }
        Demo.ConsumePending = false;
        if (InResult != ECk_Request_OperationResult::Succeeded)
        { Close(Demo, "Receipt acknowledgement failed"); return; }
        Demo.ReceiptCursor = Demo.PendingConsumeCursor;
        if (Demo.TerminalSeen)
        { Release(Demo); }
    }

    private void Release(FMars_Fragment_Crawler_LongLimbDemo& InDemo)
    {
        if (InDemo.StreamReleased || InDemo.TerminalSeen == false)
        { return; }
        if (ck::Is_NOT_Valid(InDemo.Action))
        {
            if (InDemo.Player.Read_Receipts(InDemo.Receipt.Identity, InDemo.ReceiptCursor, 1).Get_Result() ==
                ECk_ProceduralAction_ReadResult::StreamExpired)
            { InDemo.StreamReleased = true; }
            return;
        }
        if (InDemo.Action.Get_State() != ECk_ProceduralAction_State::Finished)
        { return; }
        FCk_Handle ActionEntity = InDemo.Action;
        if (utils_entity_lifetime::Get_IsPendingDestroy(ActionEntity,
            ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
        { InDemo.Action.Request_Release(FCk_Request_ProceduralAction_Release()); }
        if (ck::IsValid(InDemo.ActionScope) &&
            utils_entity_lifetime::Get_IsPendingDestroy(InDemo.ActionScope,
                ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
        { utils_entity_lifetime::Request_DestroyEntity(InDemo.ActionScope); }
        InDemo.StreamReleased = true;
    }
}
