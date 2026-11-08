// The rat kernel's per-frame pass: its clock (a zero, negative or non-finite delta does not advance; a hitch advances at most
// k_MaxStep), the threat snapshot (the nearest chef on its floor, entering at AvoidEnterCm, clearing beyond AvoidExitCm),
// the no-target clock, the provider-only route rule (a move the navigator took as a StraightLine is stopped and failed),
// and the receipts the drain waits on: the carry mount (a Persistent food settled Carried on the rat; a transient item's
// visual constructed) -> FleeWithLoot, and the release (a Persistent food back World in its holder; a transient item in its
// adopting world item's holder) -> DeadHold. Only this processor and the drain write the rat's state.
class UMars_Processor_PantryRat_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    private const float32 k_MaxStep = 0.25f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRat);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_PantryRat& InState)
    {
        const auto Delta = float32(InDeltaT.Get_Seconds());
        if (Math::IsFinite(Delta) == false || Delta <= 0.0f || InState.Phase == EMars_PantryRat_Phase::Destroyed)
        { return; }

        auto Self = InHandle.As_PantryRat();
        InState.Clock += Math::Min(Delta, k_MaxStep);

        Refresh_Threat(Self, InState);
        Refresh_NoTarget(Self, InState);
        Enforce_ProviderRoute(Self, InState);

        if (InState.Phase == EMars_PantryRat_Phase::CarryMountPending)
        { Check_CarryReceipt(Self, InState); }
        else if (InState.Phase == EMars_PantryRat_Phase::LootReleasePending)
        { Check_ReleaseReceipt(Self, InState); }

        Advance_Fade(Self, InState);

        if (InState.StepFrom.Num() > 0)
        { utils_pantry_rat::Emit_PhaseSteps(Self); }
    }

    private void Refresh_Threat(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        const auto Raid = InRat.Get_Raid();
        auto Threat = FMars_PantryRat_Threat();
        if (ck::IsValid(Raid) && utils_pantry_rat::Get_IsDeadPhase(InOutState.Phase) == false)
        {
            const auto Guard = InRat.Get_Tuning().Guard;
            const auto Here = InRat.Get_Location();
            const auto Nearest = utils_pantry_raid::Get_NearestChef(Raid.Get_Chefs(), Here, Guard.SameFloorCm);
            if (ck::IsValid(Nearest.Root))
            {
                const auto Distance = float32(utils_pantry_raid::Get_PlanarDistance(Nearest.Location, Here));
                const auto Bar = InOutState.Threat.Active ? Guard.AvoidExitCm : Guard.AvoidEnterCm;
                Threat.Chef = Nearest.Root;
                Threat.ChefLocation = Nearest.Location;
                Threat.Distance = Distance;
                Threat.Active = Distance < Bar;
            }
        }

        InOutState.Threat = Threat;
    }

    private void Refresh_NoTarget(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        const auto Raid = InRat.Get_Raid();
        auto Query = FMars_PantryRaid_TargetQuery();
        Query.Rat = InRat;
        Query.RatLocation = InRat.Get_Location();
        Query.Seed = InRat.Get_Links().OperationId;
        const auto HasTarget = ck::IsValid(Raid) && Raid.TryGet_Target(Query).IsSet();
        if (HasTarget)
        { InOutState.NoTargetSince.Reset(); }
        else if (InOutState.NoTargetSince.IsSet() == false)
        { InOutState.NoTargetSince = TOptional<float32>(InOutState.Clock); }
    }

    // A raid / flee goal is never admitted as a straight line: once the navigator has taken the move, a StraightLine route
    // (no provider, or unbuilt ground) is stopped and the route fails.
    private void Enforce_ProviderRoute(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        if (InOutState.Route.Status != EMars_PantryRat_RouteStatus::Moving)
        { return; }

        auto Navigator = InRat.Get_Navigator();
        if (Navigator.Get_HasPendingRequests())
        { return; }

        InOutState.Route.PathMode = Navigator.Get_PathMode();
        if (InOutState.Route.PathMode == EMars_SurfaceNavigator_PathMode::Provider)
        { return; }

        Log(f"[PantryRat] [{InRat.ToString()}] stopped a straight-line move to [{InOutState.Route.Goal.ToString()}]");
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        InOutState.Route.Status = EMars_PantryRat_RouteStatus::Failed;
    }

    // The one fade clock (FadeAlpha), and the hand-offs it gates:
    //   DenEnter     after DenCrouchSeconds, 1 -> 0 over ReturnFadeSeconds; at 0 the rat is hidden, FadeAlpha is reset to 1
    //                (while hidden, so no later visible frame starts half-dissolved), the phase is DormantInDen and the den is
    //                asked to admit it (its answer retires the entity through the raid). A loaded rat never fades.
    //   DormantInDen hidden; a den that never answered: the raid is asked to retire it, once, after k_DenAnswerSeconds.
    //   DeadHold     CorpseFade once the hold (CorpseDeadline, counted from the death) is over AND the loot is out (its
    //                receipt landed, the pocket empty).
    //   CorpseFade   1 -> 0 over CorpseFadeSeconds; at 0 Destroyed and one destroy request. Loot back in the pocket blocks it.
    private void Advance_Fade(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        const auto Tuning = InRat.Get_Tuning();
        const auto Age = InOutState.Clock - InOutState.PhaseStartedAt;

        if (InOutState.Phase == EMars_PantryRat_Phase::DenEnter)
        {
            if (InRat.Get_IsLoaded())
            {
                InOutState.FadeAlpha = 1.0f;
                utils_pantry_rat::Note_LoadedVeto(InRat, InOutState, "the den-entry fade");
                return;
            }

            if (Age < Tuning.DenCrouchSeconds)
            { return; }

            InOutState.FadeAlpha = Math::Clamp(1.0f - (Age - Tuning.DenCrouchSeconds) / Tuning.ReturnFadeSeconds, 0.0f, 1.0f);
            if (InOutState.FadeAlpha > 0.0f)
            { return; }

            InOutState.Hidden = true;
            InOutState.HiddenAt = InOutState.Clock;
            InOutState.FadeAlpha = 1.0f;
            utils_pantry_rat::Set_Phase(InOutState, EMars_PantryRat_Phase::DormantInDen);

            auto Den = InRat.Get_Den();
            if (ck::IsValid(Den))
            {
                const auto Links = InRat.Get_Links();
                Den.Request_AdmitReturn(FMars_Request_RatDen_AdmitReturn(InRat, Links.ResidentSlot, Links.OperationId));
            }
            return;
        }

        if (InOutState.Phase == EMars_PantryRat_Phase::DormantInDen)
        {
            if (InOutState.Hidden == false || InOutState.HomeAsked
                || InOutState.Clock - InOutState.HiddenAt < utils_pantry_rat::k_DenAnswerSeconds)
            { return; }

            InOutState.HomeAsked = true;
            Log(f"[PantryRat] [{InRat.ToString()}] hidden without its den's answer: asking the raid to retire it");
            auto Raid = InRat.Get_Raid();
            if (ck::IsValid(Raid))
            { Raid.Request_RatHome(FMars_Request_PantryRaid_RatHome(InRat)); }
            return;
        }

        if (InOutState.Phase == EMars_PantryRat_Phase::DeadHold)
        {
            if (InOutState.Clock < InOutState.Death.CorpseDeadline || ck::IsValid(InOutState.Loot) || InRat.Get_Pocket().Get_NumItems() > 0)
            { return; }

            utils_pantry_rat::Set_Phase(InOutState, EMars_PantryRat_Phase::CorpseFade);
            return;
        }

        if (InOutState.Phase != EMars_PantryRat_Phase::CorpseFade)
        { return; }

        if (ck::IsValid(InOutState.Loot) || InRat.Get_Pocket().Get_NumItems() > 0)
        {
            InOutState.FadeAlpha = 1.0f;
            utils_pantry_rat::Block_Cleanup(InRat, InOutState, "loot is back in its pocket during the corpse fade");
            return;
        }

        InOutState.FadeAlpha = Math::Clamp(1.0f - Age / Tuning.CorpseFadeSeconds, 0.0f, 1.0f);
        if (InOutState.FadeAlpha > 0.0f || InOutState.Death.DestroyRequested)
        { return; }

        InOutState.Death.DestroyRequested = true;
        utils_pantry_rat::Set_Phase(InOutState, EMars_PantryRat_Phase::Destroyed);
        FCk_Handle RatEntity = InRat;
        utils_entity_lifetime::Request_DestroyEntity(RatEntity);
    }

    private void Check_CarryReceipt(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        auto Loot = InOutState.Loot;
        if (ck::Is_NOT_Valid(Loot))
        { return; }

        auto Ready = false;
        if (Loot.Has_PersistentWorldItem())
        {
            const auto WorldItem = Loot.Get_PersistentWorldItem();
            FCk_Handle RatEntity = InRat;
            Ready = WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && WorldItem.Get_Carrier() == RatEntity && WorldItem.Get_IsSettled();
        }
        else
        {
            // A visual is the only presentation a transient item gets; an item with no presentation has nothing to wait on.
            Ready = ck::Is_NOT_Valid(InOutState.CarryVisual) ? Loot.Has_Presentation() == false : InOutState.CarryVisual.Is_WorldItem();
        }

        if (Ready == false)
        { return; }

        InOutState.CarryReceipt = true;
        utils_pantry_rat::Set_Phase(InOutState, EMars_PantryRat_Phase::FleeWithLoot);
        utils_pantry_rat::Plan_Rhythm(InRat, InOutState);
    }

    private void Check_ReleaseReceipt(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        if (InOutState.Death.ReleaseOperationId == 0)
        {
            utils_pantry_rat::Try_IssueRelease(InRat, InOutState);
            return;
        }

        auto Loot = InOutState.Loot;
        const auto Holder = InOutState.Death.ReleaseHolder;
        if (ck::Is_NOT_Valid(Loot) || ck::Is_NOT_Valid(Holder) || Holder.Is_WorldItem() == false)
        { return; }

        const auto WorldItem = Holder.As_WorldItem();
        FCk_Handle HolderInventory = WorldItem.Get_Holder();
        const FCk_Handle Parent = Loot.Get_ParentInventory();
        if (Parent != HolderInventory)
        { return; }

        // Persistent: World again, and its pickup live (a hand can take it from the floor).
        if (Loot.Has_PersistentWorldItem())
        {
            const auto Pickup = WorldItem.Get_Pickup();
            if (WorldItem.Get_Mount() != EMars_WorldItem_Mount::World || ck::Is_NOT_Valid(Pickup)
                || Pickup.Get_EnableDisable() != ECk_EnableDisable::Enable)
            { return; }
        }

        InOutState.Death.ReleaseReceipt = true;
        InOutState.Loot = FCk_Handle_Item();
        utils_pantry_rat::Enter_DeadHold(InRat, InOutState);
    }
}
