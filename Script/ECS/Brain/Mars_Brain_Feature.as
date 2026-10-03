//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BrainHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Brain";
    RequiredFragments.Add(FMars_Feature_Brain);
    Description = "A creature's decision layer: a CkGoap world state and planner, facts written only by request, and the current leaf action";
}

struct FMars_Feature_Brain {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// One bool world-state key the brain owns, and the value it starts at.
struct FMars_Brain_Fact
{
    UPROPERTY()
    FGameplayTag Key;

    UPROPERTY()
    bool Initial = false;

    FMars_Brain_Fact() {}

    FMars_Brain_Fact(FGameplayTag InKey, bool InInitial)
    {
        Key = InKey;
        Initial = InInitial;
    }
}

struct FMars_Brain_Spec
{
    // The planner child's tag (utils_goap_planner::Create).
    UPROPERTY()
    FGameplayTag PlannerTag;

    // The world-state child's tag (utils_goap_world_state::Create).
    UPROPERTY()
    FGameplayTag WorldStateTag;

    // Every key the brain writes, pre-registered on the world state and set to its initial value at Add.
    UPROPERTY()
    TArray<FMars_Brain_Fact> Facts;

    // The planner's goal. A standing goal nothing ever writes true keeps the chosen action as the current behaviour.
    UPROPERTY()
    TArray<FCk_GoapWS_Condition_Authored> Goal;

    // Fact changes inside this window coalesce into one replan.
    UPROPERTY()
    float32 MinReplanIntervalSeconds = 0.25f;

    // One planner action per class (append with AddAction). Must include an unconditional fallback: no preconditions,
    // effects covering the goal, cost 999, or the planner's Setup ensures. Soft references: the spec is retained in a
    // fragment, and a strong class reference there fails the fragment schema check.
    UPROPERTY()
    TArray<TSoftClassPtr<UCk_GoapAction_EntityScript>> Actions;

    FMars_Brain_Spec() {}

    FMars_Brain_Spec(FGameplayTag InPlannerTag, FGameplayTag InWorldStateTag, TArray<FMars_Brain_Fact> InFacts,
                     TArray<FCk_GoapWS_Condition_Authored> InGoal, float32 InMinReplanIntervalSeconds)
    {
        PlannerTag = InPlannerTag;
        WorldStateTag = InWorldStateTag;
        Facts = InFacts;
        Goal = InGoal;
        MinReplanIntervalSeconds = InMinReplanIntervalSeconds;
    }
}

mixin FMars_Validation Validate(const FMars_Brain_Spec& Self)
{
    if (Self.PlannerTag.IsValid() == false || Self.WorldStateTag.IsValid() == false)
    { return FMars_Validation(f"Brain has an invalid PlannerTag [{Self.PlannerTag.ToString()}] or WorldStateTag [{Self.WorldStateTag.ToString()}]"); }

    if (Self.Facts.Num() == 0)
    { return FMars_Validation("Brain has no facts"); }

    for (const auto& Fact : Self.Facts)
    {
        if (Fact.Key.IsValid() == false)
        { return FMars_Validation("Brain has a fact with an invalid key"); }
    }

    if (Self.Goal.Num() == 0)
    { return FMars_Validation("Brain has an empty goal"); }

    if (Self.MinReplanIntervalSeconds < 0.0f)
    { return FMars_Validation(f"Brain has a negative MinReplanIntervalSeconds [{Self.MinReplanIntervalSeconds}]"); }

    if (Self.Actions.Num() == 0)
    { return FMars_Validation("Brain has no actions"); }

    for (const auto& Action : Self.Actions)
    {
        if (Action.IsNull())
        { return FMars_Validation("Brain has an unset action class"); }
    }

    return FMars_Validation();
}

mixin void AddAction(FMars_Brain_Spec& Self, TSubclassOf<UCk_GoapAction_EntityScript> InAction)
{
    TSoftClassPtr<UCk_GoapAction_EntityScript> Action;
    Action = InAction;
    Self.Actions.Add(Action);
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec is retained whole: its action classes are soft references (a strong class reference would trip Schema.IsSafe).
struct FMars_Fragment_Brain_Params
{
    UPROPERTY()
    FMars_Brain_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the brain's two processors (and composed by Add).
struct FMars_Fragment_Brain
{
    UPROPERTY()
    FCk_Handle_Goap_WorldState WorldState;

    UPROPERTY()
    FCk_Handle_Goap_Planner Planner;

    // The first action class of the planner's current plan; unset until the first plan lands. Soft: a TSubclassOf in a
    // fragment trips Schema.IsSafe.
    UPROPERTY()
    TSoftClassPtr<UCk_GoapAction_EntityScript> LeafClass;

    UPROPERTY()
    bool IsEnabled = true;
}

struct FMars_Tag_Brain_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Once per change of the plan's first action (the leaf); the state already holds InNew when it fires.
delegate void FMars_Delegate_Brain_OnLeafChanged(FCk_Handle_Brain InBrain, TSubclassOf<UCk_GoapAction_EntityScript> InOld, TSubclassOf<UCk_GoapAction_EntityScript> InNew);
event void FMars_Delegate_Brain_OnLeafChanged_MC(FCk_Handle_Brain InBrain, TSubclassOf<UCk_GoapAction_EntityScript> InOld, TSubclassOf<UCk_GoapAction_EntityScript> InNew);

struct FMars_Fragment_Brain_Signals
{
    FMars_Delegate_Brain_OnLeafChanged_MC OnLeafChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Toggles the planner: a disabled brain keeps its leaf and stops replanning until enabled again.
struct FMars_Request_Brain_SetEnabled
{
    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    FMars_Request_Brain_SetEnabled() {}

    FMars_Request_Brain_SetEnabled(ECk_EnableDisable InEnableDisable)
    {
        EnableDisable = InEnableDisable;
    }
}

// Writes one world-state key (the only writer of the brain's world state). The write itself is deferred by CkGoap.
struct FMars_Request_Brain_SetFact
{
    UPROPERTY()
    FGameplayTag Key;

    UPROPERTY()
    bool Value = false;

    FMars_Request_Brain_SetFact() {}

    FMars_Request_Brain_SetFact(FGameplayTag InKey, bool InValue)
    {
        Key = InKey;
        Value = InValue;
    }
}

// Applied SetEnabled -> SetFact, each kind in arrival order (so a disable and a fact in one drain do not replan, and of
// several writes to one key the last one stands).
struct FMars_Fragment_Brain_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Brain_SetEnabled> SetEnabledRequests;

    UPROPERTY()
    TArray<FMars_Request_Brain_SetFact> SetFactRequests;
}
