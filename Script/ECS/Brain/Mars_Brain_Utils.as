namespace utils_brain
{
    // Composes the brain on InOwner: a tagged CkGoap world-state child (every fact pre-registered and set to its initial
    // value), a tagged planner child over it (goal, OnWorldStateDirty replans throttled by MinReplanIntervalSeconds) and
    // one planner action per spec action class. The planner is a child, not stamped on the owner, so its A* tunables stay
    // off the creature. The actions must include an unconditional fallback (no preconditions, effects covering the goal,
    // cost 999), or the planner's Setup ensures. A rejected spec ensures and returns an invalid handle with nothing composed.
    FCk_Handle_Brain Add(FCk_Handle& InOwner, FMars_Brain_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Brain] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Brain(); }

        auto Keys = TArray<FGameplayTag>();
        for (const auto& Fact : InSpec.Facts)
        { Keys.Add(Fact.Key); }

        auto WorldStateSpec = FCk_Goap_WorldState_Spec();
        WorldStateSpec.Set_PreRegisteredKeys(Keys);
        auto WorldState = utils_goap_world_state::Create(InOwner, InSpec.WorldStateTag, WorldStateSpec);
        for (const auto& Fact : InSpec.Facts)
        { utils_goap_world_state::Set_Value(WorldState, Fact.Key, Fact.Initial); }

        auto PlannerSpec = FCk_Goap_Planner_Spec(InSpec.PlannerTag);
        PlannerSpec.Set_Goal(InSpec.Goal);
        PlannerSpec.Set_WorldStateSource(WorldState);
        PlannerSpec.Set_ReplanPolicy(ECk_Goap_ReplanPolicy::OnWorldStateDirty);
        PlannerSpec.Set_MinReplanIntervalSeconds(InSpec.MinReplanIntervalSeconds);
        auto Planner = utils_goap_planner::Create(InOwner, InSpec.PlannerTag, PlannerSpec);
        if (ck::EnsureIfNot(ck::IsValid(WorldState) && ck::IsValid(Planner),
            f"[Brain] [{InOwner.ToString()}] CkGoap rejected the world state or the planner"))
        { return FCk_Handle_Brain(); }

        for (const auto& Action : InSpec.Actions)
        {
            const TSubclassOf<UCk_GoapAction_EntityScript> ActionClass = Action.Get();
            utils_goap_planner::AddAction(Planner, FCk_Goap_Action_Spec(ActionClass));
        }

        auto Params = FMars_Fragment_Brain_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Brain();
        State.WorldState = WorldState;
        State.Planner = Planner;

        InOwner.Add_Fragment(FMars_Feature_Brain());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(State);
        InOwner.Add_Fragment(FMars_Tag_Brain_NeedsSetup());
        return InOwner.As_Brain();
    }

    // "-" for no class (no plan yet).
    FString Get_ClassName(TSubclassOf<UCk_GoapAction_EntityScript> InClass)
    {
        if (ck::Is_NOT_Valid(InClass))
        { return "-"; }

        return InClass.Get().GetName().ToString();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Brain_Spec Get_Spec(const FCk_Handle_Brain& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Brain_Params).Spec;
}

// The first action of the planner's current plan; null until the first plan lands.
mixin TSubclassOf<UCk_GoapAction_EntityScript> Get_LeafClass(const FCk_Handle_Brain& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Brain).LeafClass.Get();
}

// The world state's current value (a SetFact shows here once its drain and CkGoap's deferred write have both run).
mixin bool Get_Fact(const FCk_Handle_Brain& Self, FGameplayTag InKey)
{
    return utils_goap_world_state::Get_Value(Self.Get_Fragment(FMars_Fragment_Brain).WorldState, InKey);
}

mixin FCk_Handle_Goap_Planner Get_Planner(const FCk_Handle_Brain& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Brain).Planner;
}

mixin FCk_Handle_Goap_WorldState Get_WorldState(const FCk_Handle_Brain& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Brain).WorldState;
}

mixin bool Get_IsEnabled(const FCk_Handle_Brain& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Brain).IsEnabled;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetEnabled(FCk_Handle_Brain& Self, const FMars_Request_Brain_SetEnabled& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Brain_Requests);
    Requests.SetEnabledRequests.Add(InRequest);
}

mixin void Request_SetFact(FCk_Handle_Brain& Self, const FMars_Request_Brain_SetFact& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Brain_Requests);
    Requests.SetFactRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLeafChanged(FCk_Handle_Brain& Self, FMars_Delegate_Brain_OnLeafChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Brain_Signals);
    Fragment.OnLeafChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLeafChanged(FCk_Handle_Brain& Self, FMars_Delegate_Brain_OnLeafChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Brain_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Brain_Signals).OnLeafChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
