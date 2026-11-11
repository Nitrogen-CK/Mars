namespace utils_station
{
    // Composes the station on InRoot (its frame is InRoot's transform, see FMars_Station_Spec): the Stand child node, the
    // Use interactable (probe-driven focus when Setup.Probe is set, else a transform-only child) with its one reserving
    // target and Setup.UsePrompt, the grip interactable on the root, and the minigame state machine when the spec names
    // one; it keeps Setup.View as the operator's view, and adds the replicated ledger unless it already arrived. The glove
    // grip table and the View node are the placing script's (UMars_Station_EntityScript). A rejected spec or a minigame
    // class that does not load ensures and returns an invalid handle with nothing composed.
    FCk_Handle_Station Add(FCk_Handle_Transform& InRoot, FMars_Station_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Station] [{InRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Station(); }

        // Unset = no minigame; set but not loadable is an authoring error.
        auto MinigameClass = InSpec.MinigameStateClass.Get();
        if (ck::EnsureIfNot(InSpec.MinigameStateClass.IsNull() || ck::IsValid(MinigameClass),
            f"[Station] [{InRoot.ToString()}] names a MinigameStateClass that does not load"))
        { return FCk_Handle_Station(); }

        // The construction inputs stay with the caller; only the Use prompt is read again (Make_UseTarget).
        auto Params = FMars_Fragment_Station_Params();
        Params.Spec = InSpec;
        Params.Spec.Setup = FMars_Station_Setup();
        Params.Spec.Setup.UsePrompt = InSpec.Setup.UsePrompt;

        auto Local = FMars_Fragment_Station_Local();
        Local.Stand = utils_scene_node::Create(InRoot, InSpec.StandLocal).As_Transform();
        Local.View = InSpec.Setup.View;

        InRoot.Add_Fragment(FMars_Feature_Station());
        InRoot.Add_Fragment(Params);

        // A client's copy can receive the replicated ledger before it composes: the arrived ledger stands then.
        if (InRoot.Has_Fragment(FMars_Fragment_Station) == false)
        { InRoot.Add_Fragment(FMars_Fragment_Station(), ECk_Replication::Replicates); }

        // The mirror starts from the arrived ledger with nobody operating: an operator already there is raised once, the
        // releases and refusals before this machine composed are not.
        auto Seen = InRoot.Get_Fragment(FMars_Fragment_Station);
        Seen.Occupancy = EMars_Station_Occupancy::Free;
        Local.Last = TOptional<FMars_Fragment_Station>(Seen);

        InRoot.Add_Fragment(Local);
        InRoot.Add_Fragment(FMars_Tag_Station_NeedsSetup());
        InRoot.Add_Fragment(FMars_Tag_Station_NeedsMirror());
        auto Station = InRoot.As_Station();

        auto UseSpec = FMars_Interactable_Spec();
        UseSpec.ProbeInfo = InSpec.Setup.Probe;
        UseSpec.Targets.Add(Station.Make_UseTarget());
        auto Interactable = utils_interactable::Create(InRoot, UseSpec);

        auto GripSpec = FMars_Interactable_Spec();
        GripSpec.Targets.Add(Station.Make_GripTarget());
        auto GripInteractable = utils_interactable::Create(InRoot, GripSpec);

        auto MinigameSm = FCk_Handle_StateMachine();
        if (ck::IsValid(MinigameClass))
        { MinigameSm = utils_state_machine::Add(InRoot, FCk_StateMachine_Spec(MinigameClass)); }

        auto& StoredLocal = Station.Get_Fragment(FMars_Fragment_Station_Local);
        StoredLocal.Interactable = Interactable;
        StoredLocal.GripInteractable = GripInteractable;
        StoredLocal.MinigameSm = MinigameSm;
        return Station;
    }

    // Who holds the station by InLedger: its Operator while Occupancy says Operated, else invalid.
    FCk_Handle Get_HeldBy(const FMars_Fragment_Station& InLedger)
    {
        if (InLedger.Occupancy == EMars_Station_Occupancy::Free)
        { return FCk_Handle(); }

        return InLedger.Operator;
    }

    // InOperator asks InStation for InVerb. A station with a replication driver is reached through Cue.Mars.Station.Act,
    // which only its authority applies; a local station has no other machine to reach and takes the Act request directly.
    // Either way the answer is the station's OnReserved / OnReleased / OnReserveRejected, mirrored on a client.
    void Request_ActFor(FCk_Handle_Station& InStation, FCk_Handle InOperator, EMars_Station_Verb InVerb)
    {
        const auto Request = FMars_Request_Station_Act(InOperator, InVerb);
        if (utils_entity_replication_driver::Has(InStation))
        {
            utils_cue_generic::Request_ExecuteCue(InStation, GameplayTags::Cue_Mars_Station_Act, Request,
                ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
            return;
        }

        InStation.Request_Act(Request);
    }

    // Whether InStation's operator streams its input to the authority: a station held, whose control reads there. A
    // station that reads on every machine takes none, so the authority's copy never acts on a remote operator's input.
    bool Get_TakesRemoteInput(const FCk_Handle_Station& InStation)
    {
        return ck::IsValid(InStation) && InStation.Get_InputStance() == EMars_Station_InputStance::Authority;
    }

    // The interaction context of a station interaction sub-SM: the stamped sub-SM root's copy (the stamp lands before the
    // sub-SM's first state enters), else the InteractTarget's copy, which names no initiator.
    FMars_Fragment_InteractionContext Get_InteractionContext(FCk_Handle InContext, FCk_Handle InOwningSm)
    {
        if (ck::IsValid(InOwningSm) && InOwningSm.Has_Fragment(FMars_Fragment_InteractionContext))
        { return InOwningSm.Get_Fragment(FMars_Fragment_InteractionContext); }

        if (ck::EnsureIfNot(ck::IsValid(InContext) && InContext.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[Station] [{InContext.ToString()}] is not an interact target: a station interaction state ran outside one"))
        { return FMars_Fragment_InteractionContext(); }

        return InContext.Get_Fragment(FMars_Fragment_InteractionContext);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Interact Targets
//--------------------------------------------------------------------------------------------------------------------------

// The Use target: WhileLive, routed to UMars_SmState_Station_Use, which only reserves the station for the initiator and
// ends the interaction with the answer. Operating takes both hands (RequiresFreeHands). Its prompt is Setup.UsePrompt.
mixin FMars_Interactable_TargetEntry Make_UseTarget(const FCk_Handle_Station& Self)
{
    const auto& Spec = Self.Get_Fragment(FMars_Fragment_Station_Params).Spec;

    auto Target = FMars_Interactable_TargetEntry();
    Target.InteractTargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
    Target.InteractPromptSpec = Spec.Setup.UsePrompt;
    Target.InteractionStateClass = UMars_SmState_Station_Use;
    Target.RequiresFreeHands = true;
    Target.Work = EMars_Interactable_Work::WhileLive;
    return Target;
}

// The grip target: ManuallyCompleted (nothing completes it; the Operating state cancels it on leave), no prompt, on its
// own channel (InteractionChannel.Mars.Operate, resolved only under the Operate intent the Operating state opens), so the
// Use key never touches it. Its live interaction is what the gloves hold.
mixin FMars_Interactable_TargetEntry Make_GripTarget(const FCk_Handle_Station& Self)
{
    auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Operate);
    TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::ManuallyCompleted);

    auto Target = FMars_Interactable_TargetEntry();
    Target.InteractTargetSpec = TargetSpec;
    Target.InteractionStateClass = UMars_SmState_Station_Grip;
    Target.ReachKind = EMars_FPHands_ReachKind::Hold;
    return Target;
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Station_Spec Get_Spec(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station_Params).Spec;
}

mixin EMars_Station_InputStance Get_InputStance(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station_Params).Spec.InputStance;
}

mixin FCk_Handle Get_Operator(const FCk_Handle_Station& Self)
{
    return utils_station::Get_HeldBy(Self.Get_Fragment(FMars_Fragment_Station));
}

mixin bool Get_IsOperated(const FCk_Handle_Station& Self)
{
    return ck::IsValid(utils_station::Get_HeldBy(Self.Get_Fragment(FMars_Fragment_Station)));
}

mixin bool Get_IsOperatedBy(const FCk_Handle_Station& Self, FCk_Handle InOperator)
{
    const auto Operator = utils_station::Get_HeldBy(Self.Get_Fragment(FMars_Fragment_Station));
    return ck::IsValid(Operator) && Operator == InOperator;
}

// The operator's view node (the placing script's, at Camera.ViewLocal); invalid when the spec leaves it unset.
mixin FCk_Handle_Transform Get_View(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station_Local).View;
}

// The stand's world pose (Z at the floor, +X facing the station); the station root's pose when the Stand node is gone.
mixin FTransform Get_StandWorld(const FCk_Handle_Station& Self)
{
    const auto Stand = Self.Get_Fragment(FMars_Fragment_Station_Local).Stand;
    if (ck::IsValid(Stand))
    { return utils_transform::Get_EntityCurrentTransform(Stand); }

    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station_Local).Interactable;
}

mixin FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_Station& Self)
{
    const auto Interactable = Self.Get_Fragment(FMars_Fragment_Station_Local).Interactable;
    if (ck::Is_NOT_Valid(Interactable))
    { return FCk_Handle_InteractTarget(); }

    return Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
}

mixin FCk_Handle_InteractTarget Get_GripTarget(const FCk_Handle_Station& Self)
{
    const auto GripInteractable = Self.Get_Fragment(FMars_Fragment_Station_Local).GripInteractable;
    if (ck::Is_NOT_Valid(GripInteractable))
    { return FCk_Handle_InteractTarget(); }

    return GripInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Operate);
}

mixin FCk_Handle_StateMachine Get_MinigameSm(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station_Local).MinigameSm;
}

mixin int32 Get_ReleaseSerial(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).ReleaseSerial;
}

// Why the latest release happened; meaningful once Get_ReleaseSerial is above 0.
mixin EMars_Station_ReleaseReason Get_LastReleaseReason(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).LastReleaseReason;
}

mixin int32 Get_RefusalSerial(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).RefusalSerial;
}

// Why the latest rejected reserve was rejected; meaningful once Get_RefusalSerial is above 0.
mixin EMars_Station_RejectReason Get_LastRefusal(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).LastRefusal;
}

// The latest rejected operator; on a client it may be unresolved.
mixin FCk_Handle Get_LastRefused(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).LastRefused;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Reserve(FCk_Handle_Station& Self, const FMars_Request_Station_Reserve& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Station_Requests);
    Requests.ReserveRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_Station& Self, const FMars_Request_Station_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Station_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

// A player's ask: callers go through utils_station::Request_ActFor, which reaches the authority.
mixin void Request_Act(FCk_Handle_Station& Self, const FMars_Request_Station_Act& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Station_Requests);
    Requests.ActRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReserved(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReserved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Station_Signals);
    Fragment.OnReserved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReserved(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReserved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Station_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Station_Signals).OnReserved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReleased(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReleased InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Station_Signals);
    Fragment.OnReleased.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleased(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReleased InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Station_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Station_Signals).OnReleased.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReserveRejected(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReserveRejected InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Station_Signals);
    Fragment.OnReserveRejected.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReserveRejected(FCk_Handle_Station& Self, FMars_Delegate_Station_OnReserveRejected InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Station_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Station_Signals).OnReserveRejected.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
