// Drains Retarget, the last one in a drain winning: the spec takes its targets and tuners and the tracker starts over as Add
// leaves it (Apart on every new target, no contact yet, hops and apart time zeroed). The body's contact bindings stay as the
// Setup processor made them: the body is this entity's own, and the contact handler looks the other entity up in the spec
// current at the contact. A tracker that was Resting reports its Apart edge.
class UMars_Processor_Resting_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Resting_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Resting);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Resting_Requests& InRequests,
                       FMars_Fragment_Resting& InState)
    {
        auto Self = InHandle.As_Resting();
        TArray<FMars_Request_Resting_Retarget> RetargetRequests = InRequests.RetargetRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Resting_Requests);

        if (RetargetRequests.Num() == 0)
        { return; }

        const auto Request = RetargetRequests.Last();
        const auto Spec = FMars_Resting_Spec(Request.Targets, Request.GraceSeconds, Request.HopMinSeconds);
        const auto Validation = Spec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Resting] [{Self.ToString()}] rejected the retarget: {Validation.Get_Error()}"))
        { return; }

        const auto WasResting = InState.State == EMars_Resting_State::Resting;
        Self.Get_Fragment(FMars_Fragment_Resting_Params).Spec = Spec;
        InState = utils_resting::Make_State(InHandle.As_JoltBody(), Spec.Targets.Num());

        ck::Trace(f"[Resting] [{Self.ToString()}] retargeted onto {Spec.Targets.Num()} target(s), apart");

        if (WasResting && Self.Has_Fragment(FMars_Fragment_Resting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnRestingChanged.Broadcast(Self, EMars_Resting_State::Apart); }
    }
}
