// The consume net tests' shared steps, on top of the hotbar rig's carrier: the carrier is composed on the subject on
// both machines with its hand 80 cm above the row's base and one bag slot, and each machine counts the
// OnSlotItemChanged its own hotbar raises. "Fed with X": the server seeds slot 0 with X and selects it; a machine is
// ready once its own HeldItem holds an item of X. "Eats": the one call the consume task makes
// (utils_held_item_use::Request_ConsumeFor on the subject and its held item). "Claims X": the consume cue fired
// straight at the subject, naming X. The server reads the tally of its copy of the subject.
UCLASS(Abstract)
class UMars_AutoTestRig_NetConsume : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 25.0f;

    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_ConsumeSettleSeconds = 1.0f;
    protected const FVector k_ConsumeHandFromBase = FVector(0.0, 0.0, 80.0);

    protected FVector _ConsumeBase = FVector::ZeroVector;
    protected int32 _ConsumeEnsuresAtStart = 0;
    protected int32 _SlotChanges = 0;
    protected int32 _SlotChangesAtMark = 0;

    protected void Begin_Consume(FVector InBase)
    {
        _ConsumeBase = InBase;
        _ConsumeEnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_HotbarCarrier(InBase + k_ConsumeHandFromBase, 1);
        _Carrier.Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnConsumeSlotItemChanged"));
    }

    UFUNCTION()
    private void OnConsumeSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        _SlotChanges += 1;
    }

    protected bool Get_IsConsumeServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected FString Get_ConsumeMachineName()
    {
        return Get_IsConsumeServer() ? "server" : "client";
    }

    protected int32 Get_ConsumeNewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _ConsumeEnsuresAtStart;
    }

    // Server: one item of InDefinition in slot 0, selected. The hotbar must be ready.
    protected void Feed_Server(UCk_InventoryItem_Definition InDefinition)
    {
        Seed_ServerSlotWith(0, InDefinition);
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(0)));
    }

    // This machine's own HeldItem holds an item of InDefinition.
    protected bool Get_IsFedWith(UCk_InventoryItem_Definition InDefinition)
    {
        if (Get_IsCarrierReady(_Carrier) == false)
        { return false; }

        const auto Item = _Carrier.HeldItem.Get_CurrentItem();
        return ck::IsValid(Item) && Item.Get_Definition() == InDefinition;
    }

    // Slot 0 is empty and the hands hold nothing on this machine.
    protected bool Get_IsEaten()
    {
        return Get_IsCarrierReady(_Carrier) && Get_SlotItemCount(0) == 0 && ck::Is_NOT_Valid(_Carrier.HeldItem.Get_CurrentItem());
    }

    UFUNCTION()
    protected void Is_SlotZeroEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_SlotItemCount(0) == 0);
    }

    UFUNCTION()
    protected void Is_Eaten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsEaten());
    }

    // What the consume task does with the held item.
    protected void Eat()
    {
        utils_held_item_use::Request_ConsumeFor(Get_SubjectEntity(), _Carrier.HeldItem.Get_CurrentItem());
    }

    // The consume cue straight at the subject, naming InDefinition.
    protected void Claim(UCk_InventoryItem_Definition InDefinition)
    {
        const auto Request = FMars_Request_HeldItemUse_Consume(utils_held_item::Make_DefinitionSoft(InDefinition));
        utils_cue_generic::Request_ExecuteCue(Get_SubjectEntity(), GameplayTags::Cue_Mars_HeldItemUse_Consume, Request,
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    protected void Mark_SlotChanges()
    {
        _SlotChangesAtMark = _SlotChanges;
    }

    protected int32 Get_SlotChangesSinceMark() const
    {
        return _SlotChanges - _SlotChangesAtMark;
    }

    protected FMars_HeldItemUse_ConsumeTally Get_ConsumeTallyHere()
    {
        return _Carrier.Use.Get_ConsumeTally();
    }

    protected void Assert_ConsumeTally(int32 InApplied, int32 InRefused, TOptional<EMars_HeldItemUse_ConsumeRefusal> InLastRefusal)
    {
        const auto Tally = Get_ConsumeTallyHere();
        Assert_Equals_Int(Tally.Applied, InApplied, f"the {Get_ConsumeMachineName()} applied {InApplied} consume(s)");
        Assert_Equals_Int(Tally.Refused, InRefused, f"the {Get_ConsumeMachineName()} refused {InRefused} consume(s)");
        const auto SameRefusal = Tally.LastRefusal.IsSet() == InLastRefusal.IsSet()
            && (InLastRefusal.IsSet() == false || Tally.LastRefusal.GetValue() == InLastRefusal.GetValue());
        Assert_True(SameRefusal, f"the {Get_ConsumeMachineName()}'s last refusal is the expected one");
    }

    // A client's own tally is the default: only the authority judges.
    protected void Assert_ConsumeTallyDefault()
    {
        Assert_ConsumeTally(0, 0, TOptional<EMars_HeldItemUse_ConsumeRefusal>());
        Assert_False(Get_ConsumeTallyHere().LastAppliedAt.IsSet(), "the client's tally has no applied time");
    }

    protected void Assert_SelectionZero()
    {
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0), f"the {Get_ConsumeMachineName()}'s selection is still 0");
    }

    // The row's one log line on this machine.
    protected void Log_ConsumeRow(FString InRow, FString InExtra)
    {
        const auto Tally = Get_ConsumeTallyHere();
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        const auto LastAt = Tally.LastAppliedAt.IsSet() ? Tally.LastAppliedAt.GetValue() : -1.0;
        const auto Held = _Carrier.HeldItem.Get_CurrentItem();
        const auto HeldName = ck::IsValid(Held) && ck::IsValid(Held.Get_Definition()) ? Held.Get_Definition().GetName().ToString() : FString("none");
        const auto Selected = _Carrier.Hotbar.Get_SelectedIndex();
        const auto SelectedText = Selected.IsSet() ? f"{Selected.GetValue()}" : FString("none");
        const auto Line = f"[ConsumeNetTest] {InRow} {Get_ConsumeMachineName()} tally=[applied {Tally.Applied} refused {Tally.Refused} last {Refusal} at {LastAt}] slot0={Get_SlotItemCount(0)} held={HeldName} selected={SelectedText} slotChanges={Get_SlotChangesSinceMark()} ensures={Get_ConsumeNewEnsures()} {InExtra}";
        Log(Line);
    }

    // The row's log line on this machine, no ensure, done.
    protected void Finish_ConsumeRow(FString InRow, FString InExtra)
    {
        Log_ConsumeRow(InRow, InExtra);
        Assert_Equals_Int(Get_ConsumeNewEnsures(), 0, f"no ensure on the {Get_ConsumeMachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_ConsumeServerRow(FString InRow, FString InExtra)
    {
        Log_ConsumeRow(InRow, InExtra);
        Assert_Equals_Int(Get_ConsumeNewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
