// The den's single writer. Drains Emerge -> MarkOutside -> AdmitReturn -> ResidentDied -> SetEyes, then re-derives the eye
// proxy once and broadcasts what changed. A MarkOutside / AdmitReturn / ResidentDied naming an operation id that is not the
// slot's is stale: counted, logged at Display, never applied. AdmitReturn reads the rat's own pocket: a loaded rat is
// refused (OnReturnRefused) and logged, never ensured - a loaded thief never goes home.
class UMars_Processor_RatDen_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_RatDen_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RatDen);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_RatDen_Requests& InRequests,
                       FMars_Fragment_RatDen& InState)
    {
        auto Self = InHandle.As_RatDen();

        TArray<FMars_Request_RatDen_Emerge> EmergeRequests = InRequests.EmergeRequests;
        TArray<FMars_Request_RatDen_MarkOutside> MarkOutsideRequests = InRequests.MarkOutsideRequests;
        TArray<FMars_Request_RatDen_AdmitReturn> AdmitReturnRequests = InRequests.AdmitReturnRequests;
        TArray<FMars_Request_RatDen_ResidentDied> ResidentDiedRequests = InRequests.ResidentDiedRequests;
        TArray<FMars_Request_RatDen_SetEyes> SetEyesRequests = InRequests.SetEyesRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_RatDen_Requests);

        const auto EyesBefore = InState.EyeSlot;

        TArray<int32> GrantedSlots;
        TArray<int32> GrantedOperations;
        for (const auto& Request : EmergeRequests)
        {
            const auto Slot = HandleEmerge(Self, Request);
            if (Slot.IsSet())
            {
                GrantedSlots.Add(Slot.GetValue());
                GrantedOperations.Add(Request.OperationId);
            }
        }

        for (const auto& Request : MarkOutsideRequests)
        { HandleMarkOutside(Self, Request); }

        TArray<int32> ReturnedSlots;
        TArray<FCk_Handle> ReturnedRats;
        TArray<int32> RefusedSlots;
        TArray<FCk_Handle> RefusedRats;
        TArray<EMars_RatDen_ReturnRefusal> RefusedReasons;
        for (const auto& Request : AdmitReturnRequests)
        {
            const auto Refusal = HandleAdmitReturn(Self, Request);
            if (Refusal.IsSet())
            {
                RefusedSlots.Add(Request.Slot);
                RefusedRats.Add(Request.Rat);
                RefusedReasons.Add(Refusal.GetValue());
            }
            else
            {
                ReturnedSlots.Add(Request.Slot);
                ReturnedRats.Add(Request.Rat);
            }
        }

        for (const auto& Request : ResidentDiedRequests)
        { HandleResidentDied(Self, Request); }

        for (const auto& Request : SetEyesRequests)
        { Self.Get_Fragment(FMars_Fragment_RatDen).EyesEnabled = Request.Enabled; }

        // State fully written before any broadcast.
        auto& State = Self.Get_Fragment(FMars_Fragment_RatDen);
        State.EyeSlot = utils_rat_den::Get_EyeSlotFor(State);
        const auto EyesNow = State.EyeSlot;
        const auto EyesChanged = EyesBefore.IsSet() != EyesNow.IsSet()
            || (EyesNow.IsSet() && EyesBefore.GetValue() != EyesNow.GetValue());

        if (Self.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
        { return; }

        for (int32 Index = 0; Index < GrantedSlots.Num(); ++Index)
        { Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnEmergeReady.Broadcast(Self, GrantedSlots[Index], GrantedOperations[Index]); }

        for (int32 Index = 0; Index < ReturnedSlots.Num(); ++Index)
        { Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnResidentReturned.Broadcast(Self, ReturnedSlots[Index], ReturnedRats[Index]); }

        for (int32 Index = 0; Index < RefusedSlots.Num(); ++Index)
        { Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnReturnRefused.Broadcast(Self, RefusedSlots[Index], RefusedRats[Index], RefusedReasons[Index]); }

        if (EyesChanged)
        { Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnEyesChanged.Broadcast(Self, EyesNow.IsSet(), EyesNow.IsSet() ? EyesNow.GetValue() : 0); }
    }

    private TOptional<int32> HandleEmerge(FCk_Handle_RatDen& InDen, const FMars_Request_RatDen_Emerge& InRequest)
    {
        auto& State = InDen.Get_Fragment(FMars_Fragment_RatDen);
        if (InRequest.OperationId <= 0)
        { return TOptional<int32>(); }

        for (int32 Index = 0; Index < State.Residents.Num(); ++Index)
        {
            if (State.Residents[Index].OperationId == InRequest.OperationId)
            {
                // The same operation asked twice: one resident per operation.
                ++State.StaleRequests;
                return TOptional<int32>();
            }
        }

        for (int32 Index = 0; Index < State.Residents.Num(); ++Index)
        {
            if (utils_rat_den::Get_IsAvailable(State.Residents[Index], InRequest.Now) == false)
            { continue; }

            State.Residents[Index].State = EMars_RatDen_SlotState::Pending;
            State.Residents[Index].OperationId = InRequest.OperationId;
            State.Residents[Index].DeadUntil = 0.0f;
            return TOptional<int32>(Index);
        }

        return TOptional<int32>();
    }

    private void HandleMarkOutside(FCk_Handle_RatDen& InDen, const FMars_Request_RatDen_MarkOutside& InRequest)
    {
        auto& State = InDen.Get_Fragment(FMars_Fragment_RatDen);
        if (Get_IsStale(InDen, State, InRequest.Slot, InRequest.OperationId, "MarkOutside"))
        { return; }

        if (State.Residents[InRequest.Slot].State == EMars_RatDen_SlotState::Pending)
        { State.Residents[InRequest.Slot].State = EMars_RatDen_SlotState::Outside; }
    }

    private TOptional<EMars_RatDen_ReturnRefusal> HandleAdmitReturn(FCk_Handle_RatDen& InDen, const FMars_Request_RatDen_AdmitReturn& InRequest)
    {
        auto& State = InDen.Get_Fragment(FMars_Fragment_RatDen);
        auto Refusal = TOptional<EMars_RatDen_ReturnRefusal>();

        const auto Rat = InRequest.Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Rat) || utils_world_item::Get_IsEnding(InRequest.Rat))
        { Refusal = TOptional<EMars_RatDen_ReturnRefusal>(EMars_RatDen_ReturnRefusal::NotARat); }
        else if (Get_IsStale(InDen, State, InRequest.Slot, InRequest.OperationId, "AdmitReturn"))
        { Refusal = TOptional<EMars_RatDen_ReturnRefusal>(EMars_RatDen_ReturnRefusal::NotOutside); }
        else if (Rat.Get_IsLoaded())
        { Refusal = TOptional<EMars_RatDen_ReturnRefusal>(EMars_RatDen_ReturnRefusal::Loaded); }
        else
        {
            const auto Current = State.Residents[InRequest.Slot].State;
            if (Current != EMars_RatDen_SlotState::Outside && Current != EMars_RatDen_SlotState::Pending)
            { Refusal = TOptional<EMars_RatDen_ReturnRefusal>(EMars_RatDen_ReturnRefusal::NotOutside); }
        }

        if (Refusal.IsSet())
        {
            ++State.RefusedReturns;
            Log(f"[RatDen] [{InDen.ToString()}] refused the return of [{InRequest.Rat.ToString()}] to slot [{InRequest.Slot}]: [{Refusal.GetValue() :n}]");
            return Refusal;
        }

        State.Residents[InRequest.Slot].State = EMars_RatDen_SlotState::Dormant;
        State.Residents[InRequest.Slot].OperationId = 0;
        return Refusal;
    }

    private void HandleResidentDied(FCk_Handle_RatDen& InDen, const FMars_Request_RatDen_ResidentDied& InRequest)
    {
        auto& State = InDen.Get_Fragment(FMars_Fragment_RatDen);
        if (Get_IsStale(InDen, State, InRequest.Slot, InRequest.OperationId, "ResidentDied"))
        { return; }

        State.Residents[InRequest.Slot].State = EMars_RatDen_SlotState::DeadCooldown;
        State.Residents[InRequest.Slot].OperationId = 0;
        State.Residents[InRequest.Slot].DeadUntil = InRequest.DeadUntil;
    }

    // Out of range, or the slot belongs to another (or no) operation.
    private bool Get_IsStale(const FCk_Handle_RatDen& InDen, FMars_Fragment_RatDen& InOutState, int32 InSlot, int32 InOperationId, FString InWhat)
    {
        const auto InRange = InSlot >= 0 && InSlot < InOutState.Residents.Num();
        if (InRange && InOperationId > 0 && InOutState.Residents[InSlot].OperationId == InOperationId)
        { return false; }

        ++InOutState.StaleRequests;
        Log(f"[RatDen] [{InDen.ToString()}] ignored a stale {InWhat} for slot [{InSlot}] operation [{InOperationId}]");
        return true;
    }
}
