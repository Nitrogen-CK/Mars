// An expedition whose route is solved from a seed: the anchor plan picks the entrance, the closures and the quarry
// court once per run, and every placed anchor resolves against that result (Script/ECS/AnchorResolver). The solve is
// pure and idempotent, so whichever asks first - the first ChoosePlayerStart or the resolver subsystem at world begin
// play - triggers it, and both see the same result.
class AMars_Anchored_GameMode : AMars_Expedition_GameMode
{
    private TOptional<FMars_AnchorRun_Result> _Result;

    // Each anchored map's game mode returns its plan (Mars_Warrens_GameMode.as).
    UMars_AnchorPlan_Def Get_Plan() const
    { return nullptr; }

    FMars_AnchorRun_Result Ensure_Solved()
    {
        if (_Result.IsSet())
        { return _Result.GetValue(); }

        auto Plan = Get_Plan();
        if (ck::EnsureIfNot(ck::IsValid(Plan), f"[AnchoredGameMode] [{GetName()}] has no anchor plan"))
        { return FMars_AnchorRun_Result(); }

        const auto Validation = Plan.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[AnchoredGameMode] the {Plan.MapName.ToString()} plan is invalid: {Validation.Get_Error()}"))
        { return FMars_AnchorRun_Result(); }

        // The fresh seed is the slice's one unseeded draw: it creates the seed every other draw derives from.
        const auto Explicit = utils_anchor_resolver::Get_SeedFromOptions(OptionsString);
        auto Input = FMars_AnchorRun_Input();
        Input.Seed = Explicit.IsSet() ? Explicit.GetValue() : Math::RandRange(1, 2147483646);

        auto History = Subsystem::GetGameInstanceSubsystem(UMars_AnchorRunHistory_Subsystem);
        if (Explicit.IsSet() == false && ck::IsValid(History))
        { Input.History = History.Get_History(Plan.MapName).Records; }

        const auto Result = utils_anchor_resolver::Solve(Plan, Input);
        _Result = TOptional<FMars_AnchorRun_Result>(Result);

        if (ck::IsValid(History))
        { History.Record(Plan.MapName, Result.To_Record(), Plan.HistoryDepth); }

        auto Closed = "";
        for (const auto& Id : Result.Closed)
        { Closed = Closed == "" ? Id.ToString() : f"{Closed}, {Id.ToString()}"; }

        const auto ExplicitText = Explicit.IsSet() ? " (explicit, history ignored)" : "";
        const auto FallbackText = Result.UsedFallback ? " fallback" : "";
        LogDisplay(f"Anchor run: map {Plan.MapName.ToString()} seed {Result.Seed}{ExplicitText} entrance {Result.Entrance.ToString()} quarry {Result.Quarry.ToString()} closed [{Closed}] divergence {Result.Divergence :.2}{FallbackText}");
        return Result;
    }

    // The solved entrance, never a random tag.
    FName Choose_Entrance(const TArray<APlayerStart>& InStarts) override
    { return Ensure_Solved().PlayerStartTag; }
}
