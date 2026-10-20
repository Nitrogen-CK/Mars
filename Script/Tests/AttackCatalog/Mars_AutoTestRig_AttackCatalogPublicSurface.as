// Public framework probes own their Explicit receipt streams. They never install these actions in the crawler's
// game attack fragment, so the production resolver cannot acknowledge the probe's evidence before it is inspected.
struct FMars_TESTONLY_AttackCatalog_Accepts
{
    int32 Count = 0;
    FCk_ProceduralAction_Receipt Latest;
    int64 ContentRevision = 0;
    bool ContentChanged = false;
    float64 LastClipTime = 0.0;
}

// One front leg the probe claims through a claw slot.
struct FMars_TESTONLY_AttackCatalog_Claw
{
    FCk_Handle_ProceduralLeg Leg;
    FName LegId;
    FName Slot;
}

struct FMars_TESTONLY_AttackCatalog_Stream
{
    FCk_Handle_ProceduralAction Action;
    FCk_ProceduralAction_Identity Identity;
    int64 Cursor = 0;
    bool TerminalSeen = false;
    FCk_ProceduralAction_Result Result;
    FMars_TESTONLY_AttackCatalog_Accepts Accepted;
}

UCLASS(Abstract)
class UMars_AutoTestRig_AttackCatalogPublicSurface : UMars_AutoTestRig_CrawlerMelee
{
    UPROPERTY()
    protected UCk_ProceduralAction_Data _ProbeClip;

    protected TArray<FMars_TESTONLY_AttackCatalog_Claw> _ProbeClaws;
    protected TArray<FCk_ProceduralAction_SlotBinding> _ProbeBindings;
    protected TArray<FName> _ProbeLimbIds;

    protected void Spawn_ProbeCrawler(FCk_Handle InHandle)
    {
        auto Spec = Make_ArmedCrawlerSpec(6);
        Spec.Layout = EMars_Crawler_Layout::Spider;
        Wear_ReferenceLoadout(Spec, EMars_Crawler_AttackClipKind::Pincer);
        _ProbeClip = Get_ReferenceClip(Spec.Layout, EMars_Crawler_AttackClipKind::Pincer);
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_SettleSteps();
        Add_Step_WaitUntil("the pincer has two available claws and trusted support", n"Check_ProbeStance", k_SlowPolls, 0);
    }

    UFUNCTION()
    protected void Check_ProbeStance(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = Get_IsClawStanceReady();
        if (Ready)
        {
            const auto Legs = Get_FrontLegs();
            _ProbeClaws.Reset();
            _ProbeBindings.Reset();
            _ProbeLimbIds.Reset();
            for (int32 Index = 0; Index < Legs.Num(); ++Index)
            {
                auto Claw = FMars_TESTONLY_AttackCatalog_Claw();
                Claw.Leg = Legs[Index];
                Claw.LegId = utils_procedural_leg::Get_Id(Legs[Index]);
                Claw.Slot = Index == 0 ? utils_crawler::Get_RightClawSlotId() : utils_crawler::Get_LeftClawSlotId();
                _ProbeClaws.Add(Claw);
                _ProbeBindings.Add(FCk_ProceduralAction_SlotBinding(Claw.Slot, Claw.LegId));
                _ProbeLimbIds.Add(Claw.LegId);
            }
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    protected FMars_TESTONLY_AttackCatalog_Stream Create_ProbeAction(FCk_Handle InScope, UCk_ProceduralAction_Data InClip)
    {
        auto Stream = FMars_TESTONLY_AttackCatalog_Stream();
        auto Play = FCk_ProceduralAction_PlaySpec(Make_SoftClip(InClip));
        Play.Set_SlotBindings(_ProbeBindings);
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        auto Owner = InScope;
        Stream.Action = utils_procedural_action::Create_FromClip(Owner, _Crawler.Get_ActionPlayer(), Play);
        if (ck::Is_NOT_Valid(Stream.Action))
        {
            FinishFailure("the public probe could not create its action");
            return Stream;
        }
        Stream.Identity = Stream.Action.Get_Identity();
        Assert_True(Stream.Identity.Get_Value() > 0 && Stream.Action.Get_State() == ECk_ProceduralAction_State::PendingAdmission,
            "the valid loaded pincer reserves an identity before asynchronous acquisition");
        return Stream;
    }

    protected bool Drain_ProbeStream(FMars_TESTONLY_AttackCatalog_Stream& InOutStream)
    {
        if (InOutStream.TerminalSeen)
        { return true; }
        if (InOutStream.Identity.Get_Value() == 0)
        {
            FinishFailure("the probe has no receipt identity");
            return false;
        }

        auto Player = _Crawler.Get_ActionPlayer();
        // Bounded drain. Each cursor advances only to the last record actually returned, including HasMore pages.
        for (int32 PageIndex = 0; PageIndex < 4; ++PageIndex)
        {
            const auto Page = Player.Read_Receipts(InOutStream.Identity, InOutStream.Cursor, 16);
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap ||
                Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired ||
                Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor ||
                Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
            {
                FinishFailure(f"the explicit probe stream failed: {Page.Get_Result() :n}");
                return false;
            }
            for (const auto& Record : Page.Get_Records())
            {
                if (Record.Get_Identity().Get_Value() != InOutStream.Identity.Get_Value())
                {
                    FinishFailure("a probe receipt named another action");
                    return false;
                }
                if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
                {
                    const auto Receipt = Record.Get_Receipt();
                    if (Receipt.Get_HasAcceptedPose() == false)
                    {
                        FinishFailure("an AcceptedPose record carried no accepted pose");
                        return false;
                    }
                    const auto Revision = Receipt.Get_Stamp().Get_ContentRevision();
                    if (InOutStream.Accepted.Count == 0)
                    { InOutStream.Accepted.ContentRevision = Revision; }
                    InOutStream.Accepted.ContentChanged = InOutStream.Accepted.ContentChanged ||
                        Revision != InOutStream.Accepted.ContentRevision;
                    ++InOutStream.Accepted.Count;
                    InOutStream.Accepted.Latest = Receipt;
                    InOutStream.Accepted.LastClipTime = Receipt.Get_Interval().Get_ToTime().Get_Seconds();
                }
                else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
                {
                    // Save before acknowledgement can release the action and retained identity.
                    InOutStream.Result = Record.Get_Result();
                    InOutStream.TerminalSeen = true;
                }
            }
            InOutStream.Cursor = Page.Get_LastStreamSequence();
            if (Page.Get_Records().Num() > 0)
            {
                Player.Request_ConsumeReceipts(FCk_Request_ProceduralActionPlayer_ConsumeReceipts(
                    InOutStream.Identity, InOutStream.Cursor));
            }
            if (InOutStream.TerminalSeen || Page.Get_HasMore() == false)
            { break; }
        }
        return true;
    }

    protected bool Get_IsProbeReleased(const FMars_TESTONLY_AttackCatalog_Stream& InStream) const
    {
        if (InStream.TerminalSeen == false)
        { return false; }
        for (const auto& Identity : _Crawler.Get_ActionPlayer().Get_RetainedReceiptIdentities())
        {
            if (Identity.Get_Value() == InStream.Identity.Get_Value())
            { return false; }
        }
        FCk_Handle ActionEntity = InStream.Action;
        return ck::Is_NOT_Valid(ActionEntity) ||
            utils_entity_lifetime::Get_IsPendingDestroy(ActionEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    protected bool Get_AreProbeControlsDefault() const
    {
        for (const auto Id : _ProbeLimbIds)
        {
            if (_Crawler.Get_Articulation().Get_LimbControl(Id).Get_State() != ECk_ProceduralLimbControl_State::Default)
            { return false; }
        }
        return _ProbeLimbIds.Num() == 2 &&
            _Crawler.Get_Articulation().Get_Health() == ECk_ProceduralArticulation_Health::Operational;
    }

    protected void Assert_ProbeDidNotEnterGameCombat()
    {
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "direct framework probes emitted no game damage request");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle,
            "a direct framework action does not admit a game attack");
        // Entry reuse cooldown and future OnAttackAdmitted semantics do not exist yet; C05/C09 must prove them later.
    }
}
