namespace utils_station
{
    // Engage motion rates. The glide matches the player's walk speed, so being carried to the stand reads as finishing
    // your own walk; the turn rate caps involuntary body rotation; the floor keeps a zero-travel engage from being an
    // instant snap.
    const float32 k_EngageGlideSpeed = 600.0f;
    const float32 k_EngageMaxTurnRate = 220.0f;
    const float32 k_EngageMinSeconds = 0.15f;
    // How long the operator's view takes to blend to (and back from) the station's View node.
    const float32 k_ViewBlendSeconds = 0.3f;

    // Composes the station on InRoot (its frame is InRoot's transform, see FMars_Station_Spec): the Stand child node, the
    // View child node when Camera.ViewLocal is set, the Use interactable (probe-driven focus when Setup.Probe is set, else
    // a transform-only child) with its one reserving target and Setup.UsePrompt, the grip table on the root (each spec grip
    // on the node Setup.GripNodes registers under its tag), the grip interactable on the root, and the minigame state
    // machine when the spec names one. A rejected spec, a grip naming a node tag nothing registers, or a minigame class
    // that does not load ensures and returns an invalid handle with nothing composed.
    FCk_Handle_Station Add(FCk_Handle_Transform& InRoot, FMars_Station_Spec InSpec)
    {

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Station] [{InRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Station(); }

        FString GripError;
        auto GripEntries = TArray<FMars_FPHands_GripEntry>();
        for (int32 Index = 0; Index < InSpec.Grips.Num() && GripError.IsEmpty(); ++Index)
        {
            const auto& Grip = InSpec.Grips[Index];
            const auto Node = Find_GripNode(InSpec.Setup, Grip.Node);
            if (ck::Is_NOT_Valid(Node))
            {
                GripError = f"grip [{Index}] names the node [{Grip.Node.ToString()}] that no grip node registers";
                continue;
            }

            GripEntries.Add(FMars_FPHands_GripEntry(Grip.Hand, Node, Grip.Socket == NAME_None ? TOptional<FName>() : TOptional<FName>(Grip.Socket), Grip.Pose, Grip.ReachOverrideCm, Grip.Frame, Grip.Roll));
        }

        if (ck::EnsureIfNot(GripError.IsEmpty(), f"[Station] [{InRoot.ToString()}] rejected the grips: {GripError}"))
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

        auto State = FMars_Fragment_Station();
        State.Stand = utils_scene_node::Create(InRoot, InSpec.StandLocal).As_Transform();
        if (InSpec.Camera.ViewLocal.IsSet())
        { State.View = utils_scene_node::Create(InRoot, InSpec.Camera.ViewLocal.GetValue()).As_Transform(); }

        InRoot.Add_Fragment(FMars_Feature_Station());
        InRoot.Add_Fragment(Params);
        InRoot.Add_Fragment(State);
        InRoot.Add_Fragment(FMars_Tag_Station_NeedsSetup());
        auto Station = InRoot.As_Station();

        if (GripEntries.Num() > 0)
        { utils_fphands::Add_Grips(InRoot.H(), GripEntries); }

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

        auto& StoredState = Station.Get_Fragment(FMars_Fragment_Station);
        StoredState.Interactable = Interactable;
        StoredState.GripInteractable = GripInteractable;
        StoredState.MinigameSm = MinigameSm;
        return Station;
    }

    // The node InSetup registers under InTag; invalid when none does.
    FCk_Handle_Transform Find_GripNode(const FMars_Station_Setup& InSetup, FGameplayTag InTag)
    {
        for (const auto& Entry : InSetup.GripNodes)
        {
            if (Entry.Tag == InTag)
            { return Entry.Node; }
        }

        return FCk_Handle_Transform();
    }

    // Seconds the operator glides to the stand: as long as walking InDistance (uu) or turning InTurnDegrees would take,
    // clamped to [k_EngageMinSeconds, InMaxSeconds]; 0 when InMaxSeconds is 0 (snap).
    float32 Get_EngageSeconds(float32 InDistance, float32 InTurnDegrees, float32 InMaxSeconds)
    {
        if (InMaxSeconds <= 0.0f)
        { return 0.0f; }

        const auto GlideSeconds = InDistance / k_EngageGlideSpeed;
        const auto TurnSeconds = Math::Abs(InTurnDegrees) / k_EngageMaxTurnRate;
        return Math::Clamp(Math::Max(GlideSeconds, TurnSeconds), Math::Min(k_EngageMinSeconds, InMaxSeconds), InMaxSeconds);
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

mixin FCk_Handle Get_Operator(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).Operator;
}

mixin bool Get_IsOperated(const FCk_Handle_Station& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Station).Operator);
}

mixin bool Get_IsOperatedBy(const FCk_Handle_Station& Self, FCk_Handle InOperator)
{
    const auto Operator = Self.Get_Fragment(FMars_Fragment_Station).Operator;
    return ck::IsValid(Operator) && Operator == InOperator;
}

// The operator's view node; invalid when the spec leaves Camera.ViewLocal unset.
mixin FCk_Handle_Transform Get_View(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).View;
}

// The stand's world pose (Z at the floor, +X facing the station); the station root's pose when the Stand node is gone.
mixin FTransform Get_StandWorld(const FCk_Handle_Station& Self)
{
    const auto Stand = Self.Get_Fragment(FMars_Fragment_Station).Stand;
    if (ck::IsValid(Stand))
    { return utils_transform::Get_EntityCurrentTransform(Stand); }

    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).Interactable;
}

mixin FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_Station& Self)
{
    const auto Interactable = Self.Get_Fragment(FMars_Fragment_Station).Interactable;
    if (ck::Is_NOT_Valid(Interactable))
    { return FCk_Handle_InteractTarget(); }

    return Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
}

mixin FCk_Handle_InteractTarget Get_GripTarget(const FCk_Handle_Station& Self)
{
    const auto GripInteractable = Self.Get_Fragment(FMars_Fragment_Station).GripInteractable;
    if (ck::Is_NOT_Valid(GripInteractable))
    { return FCk_Handle_InteractTarget(); }

    return GripInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Operate);
}

mixin FCk_Handle_StateMachine Get_MinigameSm(const FCk_Handle_Station& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Station).MinigameSm;
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
