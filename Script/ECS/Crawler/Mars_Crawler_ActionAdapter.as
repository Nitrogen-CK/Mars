// The crawler owns damage, cooldown and cancellation policy; the attack tick plays one loadout clip per attack as an action
// of the crawler with explicit receipt delivery (the resolver needs every accepted interval), its slots bound to the
// limbs the plan claimed. The tick cancels the action; the player releases it once the resolver has acknowledged its
// terminal record, and a claim the return left unplanted is handed back to the gait. A copy's show plays the same
// entry's clip with the same bindings with the player's own delivery: nothing reads its receipts.
namespace utils_crawler
{
    // InEntry's clip with each of its slots bound to the limb the slot claims; Delivery is left at its default. The one
    // play spec for both machines: the authority's attack sets Explicit on it, a copy's show plays it as it is.
    FCk_ProceduralAction_PlaySpec Make_AttackPlaySpec(const FMars_Attack_ResolvedEntry& InEntry)
    {
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        for (const auto& Slot : InEntry.Slots)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(Slot.Slot, Slot.Binding.LimbId)); }

        auto PlaySpec = FCk_ProceduralAction_PlaySpec(InEntry.Definition.Clip);
        PlaySpec.Set_SlotBindings(Bindings);
        return PlaySpec;
    }

    // The action is gone before its terminal record was read: something other than its own release destroyed it.
    bool Get_IsAttackActionLost(const FCk_Handle_Crawler& InSelf)
    {
        const auto& Stream = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Stream;
        FCk_Handle Action = Stream.Action;
        return Stream.Identity.Get_Value() != 0 && InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Stream.TerminalSeen == false &&
            (ck::Is_NOT_Valid(Action) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    // Asks the gait to take back every limb an earlier action's return left unplanted (the return ran out of time or of
    // landing probes). Sent when an action with claims is gone and again before the next attack's action is created: a
    // leg left out of the gait is never the last word.
    bool Recover_UnplantedLimbs(FCk_Handle_Crawler& InSelf)
    {
        auto Subject = InSelf.Get_Articulation();
        if (utils_procedural_articulation::Get_UnplantedLimbIds(Subject).Num() == 0)
        { return false; }

        utils_procedural_articulation::Request_RecoverUnplantedLimbs(Subject, FCk_Request_ProceduralArticulation_RecoverUnplantedLimbs());
        return true;
    }
}
