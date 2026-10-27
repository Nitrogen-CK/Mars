// Every refuel, then the latest ignition request: a refuel and a Lit in one frame light the flame. A refuel adds its
// measures capped at full; one that relights a spent flame starts the new measure from the beginning. Admission at the
// drain: a refuel on unlimited or unrefuelable fuel ensures and is dropped (the caller checks Get_CanRefuel); a Lit from
// a flame that is gone or went out this frame is dropped quietly; a Lit by itself on a flame that needs a flame ensures
// and is dropped; Snuffed always applies.
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

        auto Added = 0;
        for (const auto& Refuel : InRequests.RefuelRequests)
        {
            if (ck::EnsureIfNot(Refuel.Measures > 0, f"[Flame] [{Self.ToString()}] got a refuel of [{Refuel.Measures}] measures"))
            { continue; }

            const auto IsRefuelable = Params.Fuel.IsSet() && Params.Fuel.GetValue().Refuel == EMars_Flame_Refuel::Refuelable;
            if (ck::EnsureIfNot(IsRefuelable, f"[Flame] [{Self.ToString()}] got a refuel but its fuel is unlimited or not refuelable - dropped"))
            { continue; }

            Added += Refuel.Measures;
        }

        const auto HasIgnition = InRequests.SetIgnitionRequests.Num() > 0;
        auto Ignition = FMars_Request_Flame_SetIgnition();
        if (HasIgnition)
        { Ignition = InRequests.SetIgnitionRequests.Last(); }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Flame_Requests);

        if (Added == 0 && HasIgnition == false)
        { return; }

        const auto Before = utils_flame::Make_Reading(Params, InState);

        if (Added > 0)
        {
            if (InState.MeasuresLeft <= 0)
            { InState.MeasureElapsed = 0.0f; }

            InState.MeasuresLeft = Math::Min(InState.MeasuresLeft + Added, Params.Fuel.GetValue().Measures);
        }

        // Refuels first: the ignite rules read the fuel they left.
        InState.Condition = utils_flame::Get_Condition(Params, InState);
        if (HasIgnition && Get_IsAdmitted(Self, Params, Ignition))
        { InState.Ignition = Ignition.Ignition; }

        utils_flame::Apply_Changes(Self, Before, utils_flame::Make_Reading(Params, InState));
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
