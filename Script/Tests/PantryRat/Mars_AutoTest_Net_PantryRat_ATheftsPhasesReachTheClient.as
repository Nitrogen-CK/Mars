// The server's court emerges one rat, which steals the Monk's Rind out of the pack's cargo slot 1 and flees with it:
// its claim is accepted once, one transfer, the Rind alone in its pocket, the slot empty. The client's copy shows the
// theft's phases in order (it inspects, tells, takes and flees, each change following the last) and reads loaded from
// the phase alone; it resolves no claim and issues no transfer.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ATheftsPhasesReachTheClient
class UCk_AutoTest_Net_PantryRat_ATheftsPhasesReachTheClient : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(681000.0, 0.0, 5000.0);
    private const FString k_Row = "ATheftsPhasesReachTheClient";
    private const float32 k_TheftSeconds = 20.0f;

    private int32 _TheftStartFrame = -1;
    private float64 _TheftStartSeconds = 0.0;
    private float64 _TheftSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _TheftStartFrame = int32(utils_time::Get_FrameCounter());
        _TheftStartSeconds = Get_RowWorldSeconds();
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::FleeWithLoot);
        Until.MaxSeconds = TOptional<float32>(k_TheftSeconds);
        Wait_RowRatUntil(Until, n"OnServerFled");
    }

    UFUNCTION()
    private void OnServerFled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _TheftSeconds = Get_RowWorldSeconds() - _TheftStartSeconds;
        Wait_RowSampling(k_ComposeSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"theft=[from {_TheftStartFrame} seconds {_TheftSeconds}] {Describe_CourtFrames()}";
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Extra);
            FinishFailure("the server's rat was gone before it asserted");
            return;
        }

        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::Observe);
        Expected.Add(EMars_PantryRat_Phase::Inspect);
        Expected.Add(EMars_PantryRat_Phase::ClaimTell);
        Expected.Add(EMars_PantryRat_Phase::ClaimTransfer);
        Expected.Add(EMars_PantryRat_Phase::CarryMountPending);
        Expected.Add(EMars_PantryRat_Phase::FleeWithLoot);
        auto Slot = _RowPackEntity.As_Backpack().Get_CargoSlot(1);
        Assert_True(_RowRat.Get_LastClaimResult() == EMars_PantryRat_ClaimResult::Accepted, "the server's claim was accepted");
        Assert_Equals_Int(_RowRat.Get_ClaimTransfersIssued(), 1, "the server's rat issued one transfer");
        Assert_True(_RowRat.Get_IsLoaded(), "the server's rat is loaded");
        Assert_Equals_Int(_RowRat.Get_Pocket().Get_NumItems(), 1, "the server's pocket holds one item");
        Assert_True(_RowRat.Get_Loot() == _RowCheeseItem, "the server's pocket holds the Rind");
        Assert_False(ck::IsValid(Slot.Get_Item()), "the server's cargo slot 1 is empty");
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the server's rat recorded the theft's phases in order");
        Assert_Equals_Int(_RatClaimSignals, 1, "the server's rat resolved its claim once");
        Hold_RatServerRow(k_Row, Extra);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::RecordedPhase, EMars_PantryRat_Phase::FleeWithLoot), n"OnClientFled");
    }

    UFUNCTION()
    private void OnClientFled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = Describe_ClientItems();
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Extra);
            FinishFailure("the client's rat was gone before it asserted");
            return;
        }

        Assert_True(Get_IsTheftInOrder(), "the client's rat showed Inspect, ClaimTell, ClaimTransfer or CarryMountPending, FleeWithLoot in order");
        Assert_True(Get_IsRatRecordChained(), "each of the client's changes starts where the one before ended");
        Assert_True(_RowRat.Get_IsLoaded(), "the client's rat reads loaded");
        Assert_Equals_Int(_RatClaimSignals, 0, "the client's rat resolved no claim");
        Assert_Equals_Int(_RowRat.Get_ClaimTransfersIssued(), 0, "the client's rat issued no transfer");
        Finish_RatRow(k_Row, Extra);
    }

    private bool Get_IsTheftInOrder() const
    {
        auto Next = 0;
        for (const auto& Change : _RatChanges)
        {
            const auto To = Change.To;
            if (Next == 0 && To == EMars_PantryRat_Phase::Inspect)
            { Next = 1; }
            else if (Next == 1 && To == EMars_PantryRat_Phase::ClaimTell)
            { Next = 2; }
            else if (Next == 2 && (To == EMars_PantryRat_Phase::ClaimTransfer || To == EMars_PantryRat_Phase::CarryMountPending))
            { Next = 3; }
            else if (Next == 3 && To == EMars_PantryRat_Phase::FleeWithLoot)
            { Next = 4; }
        }

        return Next == 4;
    }

    // The client's pack copy's slot 1, and the Rind's world items in the client's world and the nearest to its rat.
    private FString Describe_ClientItems()
    {
        auto SlotText = "noPack";
        if (Get_IsRowPackFound() && Get_IsRowEnding(_RowPack) == false)
        { SlotText = f"{ck::IsValid(_RowPack.Get_CargoSlot(1).Get_Item())}"; }

        auto Rinds = 0;
        auto Nearest = -1.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsRowEnding(Candidate) || Candidate.Is_WorldItem() == false)
            { continue; }

            if (Candidate.As_WorldItem().Get_Definition() != mars_items::MonksRind())
            { continue; }

            Rinds += 1;
            if (Get_IsRowRatGone())
            { continue; }

            const auto Distance = (Get_RowRootLocation(Candidate) - _RowRat.Get_Location()).Size();
            Nearest = Nearest < 0.0 ? Distance : Math::Min(Nearest, Distance);
        }

        return f"clientItems=[packSlot1Held {SlotText} rinds {Rinds} nearestToRat {Nearest}]";
    }
}
