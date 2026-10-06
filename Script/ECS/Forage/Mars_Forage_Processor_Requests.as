// The Forage arbiter. Replenish is applied before Release, so a regrow and a hit landing in one frame read as
// "replenished, then released". A release spawns the yield as a World-mode world item at the release point, owned by the
// transient entity (a Destroyed source dies the same frame); the last charge exhausts the source by its policy.
// It knows nothing of what triggers a release: the owning entity script composes the strike/knock/pluck adapters and
// decides what exhaustion means for its own parts.
//
// The state is re-fetched per request: a signal handler may compose features on another entity mid-broadcast, which can
// move the fragment storage under a reference held across the broadcast.
class UMars_Processor_Forage_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Forage_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Forage);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Forage_Requests& InRequests,
                       FMars_Fragment_Forage& InState)
    {
        auto Forage = InHandle.As_Forage();

        TArray<FMars_Request_Forage_Replenish> ReplenishRequests = InRequests.ReplenishRequests;
        TArray<FMars_Request_Forage_Release> ReleaseRequests = InRequests.ReleaseRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Forage.Request_TryRemove(FMars_Fragment_Forage_Requests);

        for (const auto& Request : ReplenishRequests)
        { HandleReplenish(Forage); }

        for (const auto& Request : ReleaseRequests)
        { HandleRelease(Forage, Request); }
    }

    private void HandleReplenish(FCk_Handle_Forage& InForage)
    {
        const auto& Params = InForage.Get_Fragment(FMars_Fragment_Forage_Params);
        auto& State = InForage.Get_Fragment(FMars_Fragment_Forage);
        State.ChargesLeft = Params.Yield.Charges;
        State.IsExhausted = false;

        if (ck::IsValid(State.RegrowTimer))
        { utils_entity_lifetime::Request_DestroyEntity(State.RegrowTimer); }

        State.RegrowTimer = FCk_Handle_Timer();

        ck::Trace(f"[Forage] [{InForage.ToString()}] replenished to [{Params.Yield.Charges}] charges");

        if (InForage.Has_Fragment(FMars_Fragment_Forage_Signals))
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReplenished.Broadcast(InForage); }
    }

    private void HandleRelease(FCk_Handle_Forage& InForage, const FMars_Request_Forage_Release& InRequest)
    {
        if (InForage.Get_Fragment(FMars_Fragment_Forage).IsExhausted)
        {
            ck::Trace(f"[Forage] [{InForage.ToString()}] ignored a {InRequest.Reason :n} release: exhausted");
            return;
        }

        const auto Definition = InForage.Get_Definition();
        if (ck::EnsureIfNot(ck::IsValid(Definition), f"[Forage] [{InForage.ToString()}] has no resolvable yield definition"))
        { return; }

        const auto Params = InForage.Get_Fragment(FMars_Fragment_Forage_Params);
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(InForage.Get_ReleasePoint());
        const auto Pose = FTransform(ReleaseWorld.Rotator(), ReleaseWorld.GetLocation());
        const auto Linear = Pose.TransformVectorNoScale(Params.Launch.LinearVelocity);

        auto Owner = ck::TransientEntity();
        auto Spawned = utils_world_item::Request_SpawnWorld(Owner,
            FMars_WorldItem_WorldSpec(Params.Yield.Definition, Pose, Linear, Params.Launch.AngularVelocityDeg));

        auto& State = InForage.Get_Fragment(FMars_Fragment_Forage);
        ++State.ReleasedCount;
        --State.ChargesLeft;
        const auto Exhausted = State.ChargesLeft <= 0;

        ck::Trace(f"[Forage] [{InForage.ToString()}] released [{Spawned.ToString()}] on a {InRequest.Reason :n}, [{State.ChargesLeft}] charges left");

        if (InForage.Has_Fragment(FMars_Fragment_Forage_Signals))
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReleased.Broadcast(InForage, Spawned, InRequest.Reason); }

        if (Exhausted)
        { Exhaust(InForage); }
    }

    private void Exhaust(FCk_Handle_Forage& InForage)
    {
        InForage.Get_Fragment(FMars_Fragment_Forage).IsExhausted = true;

        if (InForage.Has_Fragment(FMars_Fragment_Forage_Signals))
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnExhausted.Broadcast(InForage); }

        const auto Exhaustion = InForage.Get_Fragment(FMars_Fragment_Forage_Params).Exhaustion;
        switch (Exhaustion.Policy)
        {
            case EMars_Forage_Exhaustion::Persists:
            { break; }

            case EMars_Forage_Exhaustion::Regrows:
            {
                auto TimerSpec = FCk_Timer_Spec(FCk_Time(Exhaustion.RegrowSeconds));
                TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                         .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

                auto Timer = utils_timer::Add(InForage, TimerSpec);
                Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnRegrowDone"));
                InForage.Get_Fragment(FMars_Fragment_Forage).RegrowTimer = Timer;
                break;
            }

            case EMars_Forage_Exhaustion::Destroyed:
            {
                DestroySource(InForage);
                break;
            }
        }
    }

    // A Transient world item host loses its item and its emptied holder tears it down; any other host, and a Transient
    // world item whose holder is not seeded yet (nothing to remove, so no emptied holder would follow), is destroyed.
    private void DestroySource(FCk_Handle_Forage& InForage)
    {
        auto WorldItem = InForage.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto IsTransientWorldItem = ck::IsValid(WorldItem) && WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Transient;
        auto Item = IsTransientWorldItem ? WorldItem.Get_HeldItem() : FCk_Handle_Item();
        if (ck::IsValid(Item))
        {
            auto Holder = WorldItem.Get_Holder();
            auto Remove = FCk_Request_Inventory_RemoveItem(Item);
            Remove.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
            Holder.Request_RemoveItem(Remove, FCk_Delegate_Inventory_OnOperationResult_Remove());
            return;
        }

        utils_entity_lifetime::Request_DestroyEntity(InForage);
    }

    // The timer lives on the forage entity (utils_timer::Add) or, should the timer feature parent it, directly under it.
    UFUNCTION()
    private void OnRegrowDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Forage = InTimer.Is_Forage() ? InTimer.As_Forage() : utils_entity_lifetime::Get_LifetimeOwner(InTimer).As_Forage();

        // A replenish already destroyed the timer this one belonged to.
        if (Forage.Get_Fragment(FMars_Fragment_Forage).RegrowTimer != InTimer)
        { return; }

        Forage.Request_Replenish();
    }
}
