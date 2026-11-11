// Every act, then every refuel, then the latest ignition request: a refuel and a Lit in one frame light the flame. Every
// kind changes the ledger, so a machine without authority drops them all (the result replicates from the authority).
// An act is checked again here from its initiator's side and becomes a request; one whose check fails is dropped with a
// trace (two machines can race for one flame, and the verbs are instant: the prompt stays as it was).
//   Light: Get_ActionFor(Initiator) is Light; this flame takes a Lit from the initiator's held flame.
//   TakeLight: Get_ActionFor(Initiator) is TakeLight; the initiator's held flame takes a Lit from this one.
//   Toggle: this flame is the initiator's held flame; a lit one snuffs, an unlit one that can light itself lights.
//   Refuel: the initiator holds tallow and this flame is its hotbar's refuel target with room; this flame takes the
//           tallow's measures and the tallow is destroyed out of its inventory.
// A refuel adds its measures capped at full; one that relights a spent flame starts the new measure from the beginning.
// Admission at the drain: a refuel on unlimited or unrefuelable fuel ensures and is dropped (the caller checks
// Get_CanRefuel); a Lit from a flame that is gone or went out this frame is dropped quietly; a Lit by itself on a flame
// that needs a flame ensures and is dropped; Snuffed always applies.
class UMars_Processor_Flame_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Flame_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Flame_Requests& InRequests,
                       FMars_Fragment_Flame& InState)
    {
        auto Self = InHandle.As_Flame();
        const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);

        TArray<FMars_Request_Flame_Act> ActRequests = InRequests.ActRequests;
        TArray<FMars_Request_Flame_Refuel> RefuelRequests = InRequests.RefuelRequests;
        TArray<FMars_Request_Flame_SetIgnition> SetIgnitionRequests = InRequests.SetIgnitionRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Flame_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Local = InHandle.Get_Fragment(FMars_Fragment_Flame_Local);
        for (const auto& Act : ActRequests)
        { HandleActRequest(Self, Act, RefuelRequests, SetIgnitionRequests); }

        auto Added = 0;
        for (const auto& Refuel : RefuelRequests)
        {
            if (ck::EnsureIfNot(Refuel.Measures > 0, f"[Flame] [{Self.ToString()}] got a refuel of [{Refuel.Measures}] measures"))
            { continue; }

            const auto IsRefuelable = Params.Fuel.IsSet() && Params.Fuel.GetValue().Refuel == EMars_Flame_Refuel::Refuelable;
            if (ck::EnsureIfNot(IsRefuelable, f"[Flame] [{Self.ToString()}] got a refuel but its fuel is unlimited or not refuelable - dropped"))
            { continue; }

            Added += Refuel.Measures;
        }

        const auto HasIgnition = SetIgnitionRequests.Num() > 0;
        auto Ignition = FMars_Request_Flame_SetIgnition();
        if (HasIgnition)
        { Ignition = SetIgnitionRequests.Last(); }

        if (Added == 0 && HasIgnition == false)
        { return; }

        const auto Before = utils_flame::Make_Reading(Params, InState);

        if (Added > 0)
        {
            if (InState.MeasuresLeft <= 0)
            { Local.MeasureElapsed = 0.0f; }

            InState.MeasuresLeft = Math::Min(InState.MeasuresLeft + Added, Params.Fuel.GetValue().Measures);
        }

        // Refuels first: the ignite rules read the fuel they left.
        InState.Condition = utils_flame::Get_Condition(Params, InState, Local);
        if (HasIgnition && Get_IsAdmitted(Self, Params, Ignition))
        { InState.Ignition = Ignition.Ignition; }

        utils_flame::Mark_LedgerDirty(InHandle, Params);
        utils_flame::Apply_Changes(Self, Before, utils_flame::Make_Reading(Params, InState));
    }

    // The act's verb, checked from its initiator's side, as the request it stands for: on this flame's own lists, or (a
    // TakeLight) on the initiator's held flame.
    private void HandleActRequest(FCk_Handle_Flame& InFlame, const FMars_Request_Flame_Act& InAct,
                                  TArray<FMars_Request_Flame_Refuel>& OutRefuels,
                                  TArray<FMars_Request_Flame_SetIgnition>& OutIgnitions)
    {
        if (ck::Is_NOT_Valid(InAct.Initiator))
        {
            ck::Trace(f"[Flame] [{InFlame.ToString()}] dropped a [{InAct.Verb :n}] act whose initiator is gone");
            return;
        }

        auto Held = utils_flame::TryGet_HeldFlame(InAct.Initiator);
        switch (InAct.Verb)
        {
            case EMars_Flame_Verb::Light:
            {
                if (InFlame.Get_ActionFor(InAct.Initiator) != EMars_Flame_Action::Light)
                { DoTrace_Dropped(InFlame, InAct); return; }

                OutIgnitions.Add(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, Held));
                return;
            }
            case EMars_Flame_Verb::TakeLight:
            {
                if (InFlame.Get_ActionFor(InAct.Initiator) != EMars_Flame_Action::TakeLight)
                { DoTrace_Dropped(InFlame, InAct); return; }

                Held.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, InFlame));
                return;
            }
            case EMars_Flame_Verb::Toggle:
            {
                if (Held != InFlame)
                { DoTrace_Dropped(InFlame, InAct); return; }

                if (InFlame.Get_Ignition() == EMars_Flame_Ignition::Lit)
                {
                    OutIgnitions.Add(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
                    return;
                }

                if (InFlame.Get_CanSelfLight() == false)
                { DoTrace_Dropped(InFlame, InAct); return; }

                OutIgnitions.Add(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
                return;
            }
            case EMars_Flame_Verb::Refuel:
            {
                HandleRefuelAct(InFlame, InAct, OutRefuels);
                return;
            }
        }
    }

    private void HandleRefuelAct(FCk_Handle_Flame& InFlame, const FMars_Request_Flame_Act& InAct,
                                 TArray<FMars_Request_Flame_Refuel>& OutRefuels)
    {
        // One refuel per pass: a second act in the same pass would read the tallow the first is still removing from
        // its inventory, and spend it twice. It is dropped with its tallow untouched.
        if (OutRefuels.Num() > 0)
        { DoTrace_Dropped(InFlame, InAct); return; }

        FCk_Handle Initiator = InAct.Initiator;
        const auto HeldItem = Initiator.As_HeldItem(ECk_SanityCheck::UnChecked);
        const auto Hotbar = Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Tallow = ck::IsValid(HeldItem) ? HeldItem.Get_CurrentItem() : FCk_Handle_Item();
        const auto HoldsTallow = ck::IsValid(Tallow) && Tallow.Has_Tallow();
        const auto IsTarget = ck::IsValid(Hotbar) && utils_flame::TryGet_RefuelTarget(Hotbar) == InFlame;
        if (HoldsTallow == false || IsTarget == false || InFlame.Get_CanRefuel() == false)
        { DoTrace_Dropped(InFlame, InAct); return; }

        auto Inventory = Tallow.Get_ParentInventory();
        if (ck::Is_NOT_Valid(Inventory))
        { DoTrace_Dropped(InFlame, InAct); return; }

        OutRefuels.Add(FMars_Request_Flame_Refuel(Tallow.Get_Tallow().Measures));

        auto Request = FCk_Request_Inventory_RemoveItem(Tallow);
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    private void DoTrace_Dropped(const FCk_Handle_Flame& InFlame, const FMars_Request_Flame_Act& InAct) const
    {
        ck::Trace(f"[Flame] [{InFlame.ToString()}] dropped a [{InAct.Verb :n}] act from [{InAct.Initiator.ToString()}]: its check no longer holds");
    }

    private bool Get_IsAdmitted(const FCk_Handle_Flame& InFlame, const FMars_Fragment_Flame_Params& InParams,
                                const FMars_Request_Flame_SetIgnition& InRequest) const
    {
        if (InRequest.Ignition == EMars_Flame_Ignition::Snuffed)
        { return true; }

        if (InRequest.Origin == EMars_Flame_IgnitionOrigin::FromAFlame)
        {
            if (InFlame.Get_Ignition() == EMars_Flame_Ignition::Lit)
            { return false; }

            if (ck::Is_NOT_Valid(InRequest.Source) || InFlame.Get_CanBeLitBy(InRequest.Source) == false)
            {
                ck::Trace(f"[Flame] [{InFlame.ToString()}] dropped a light from a flame that is gone or can no longer pass fire");
                return false;
            }

            return true;
        }

        return ck::EnsureIfNot(InParams.Lighting == EMars_Flame_Lighting::SelfLighting,
            f"[Flame] [{InFlame.ToString()}] needs a flame to light it but got a Lit request by itself - dropped") == false;
    }
}
