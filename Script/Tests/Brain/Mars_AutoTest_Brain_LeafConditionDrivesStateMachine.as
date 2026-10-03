// The shared BrainLeaf condition drives a state machine through an Idle hub with no request: a brain (the crawler's
// catalog) and a test-local machine on one entity that overrides its context to itself first. The machine settles in
// BrainRoam; IsHurt true -> it leaves Roam for Idle and Idle dispatches to BrainFlinch; IsHurt false -> back to BrainRoam
// through Idle. Each leaf state's exit condition is the RequirePresent = false variant, not _NegateResult.

class UMars_AutoTestCondition_LeafIsRoam : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Roam;
}

class UMars_AutoTestCondition_LeafIsNotRoam : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Roam;
    default RequirePresent = false;
}

class UMars_AutoTestCondition_LeafIsFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
}

class UMars_AutoTestCondition_LeafIsNotFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
    default RequirePresent = false;
}

class UMars_AutoTestState_BrainIdle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRoam = AddTransition(InHandle, UMars_AutoTestState_BrainRoam);
        AddCondition(ToRoam, UMars_AutoTestCondition_LeafIsRoam);

        auto ToFlinch = AddTransition(InHandle, UMars_AutoTestState_BrainFlinch);
        AddCondition(ToFlinch, UMars_AutoTestCondition_LeafIsFlinch);
    }
}

class UMars_AutoTestState_BrainRoam : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_AutoTestState_BrainIdle);
        AddCondition(ToIdle, UMars_AutoTestCondition_LeafIsNotRoam);
    }
}

class UMars_AutoTestState_BrainFlinch : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_AutoTestState_BrainIdle);
        AddCondition(ToIdle, UMars_AutoTestCondition_LeafIsNotFlinch);
    }
}

class UMars_AutoTest_Brain_LeafConditionDrivesStateMachine : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FCk_Handle_Brain _Brain;
    private FCk_Handle_StateMachine _Machine;
    private TArray<FString> _States;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        // First: the conditions resolve ck::Ctx to this entity only if the override precedes every child.
        Entity.Request_OverrideToSelf();
        _Brain = utils_brain::Add(Entity, Make_Spec());
        _Machine = utils_state_machine::Add(Entity, FCk_StateMachine_Spec(UMars_AutoTestState_BrainIdle));
        utils_state_machine::BindTo_OnStateChanged(_Machine, FCk_Delegate_Sm_OnStateChanged(this, n"OnStateChanged"));

        Add_Step("the brain and the machine composed on one entity", n"Step_AssertComposed");
        Add_Step_WaitUntil("the machine settles in BrainRoam", n"Check_InRoam", 0, 3.0f);
        Add_Step("IsHurt true", n"Step_Hurt");
        Add_Step_WaitUntil("the machine reaches BrainFlinch", n"Check_InFlinch", 0, 3.0f);
        Add_Step("Roam -> Flinch passed through the Idle hub", n"Step_AssertThroughIdle");
        Add_Step("IsHurt false", n"Step_Heal");
        Add_Step_WaitUntil("the machine returns to BrainRoam", n"Check_InRoam", 0, 3.0f);
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
    //----------------------------------------------------------------------------------------------------------------------

    private FGameplayTag IsHurt() const
    {
        return GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.IsHurt");
    }

    private FMars_Brain_Spec Make_Spec() const
    {
        const auto Settled = GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.Settled");

        auto Facts = TArray<FMars_Brain_Fact>();
        Facts.Add(FMars_Brain_Fact(IsHurt(), false));
        Facts.Add(FMars_Brain_Fact(GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.CanWalk"), true));
        Facts.Add(FMars_Brain_Fact(Settled, false));

        auto Goal = TArray<FCk_GoapWS_Condition_Authored>();
        Goal.Add(FCk_GoapWS_Condition_Authored(Settled, true));

        auto Spec = FMars_Brain_Spec(GameplayTags::ResolveGameplayTag(n"Mars.Goap.Crawler"), GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler"),
            Facts, Goal, 0.0f);
        Spec.AddAction(UMars_GoapAction_Crawler_Roam);
        Spec.AddAction(UMars_GoapAction_Crawler_Flinch);
        Spec.AddAction(UMars_GoapAction_Crawler_Cower);
        Spec.AddAction(UMars_GoapAction_Crawler_Idle);
        return Spec;
    }

    private FString StateName(TSubclassOf<UCk_SmState_EntityScript> InState) const
    {
        return ck::IsValid(InState) ? InState.Get().GetName().ToString() : "-";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_StateMachine InStateMachine, FCk_Sm_Payload_OnStateChanged InPayload)
    {
        _States.Add(StateName(InPayload.Get_NewStateClass()));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Brain), "the brain composed");
        Assert_True(ck::IsValid(_Machine), "the machine composed");
        Assert_True(FCk_Handle(_Brain) == FCk_Handle(_Machine), "brain and machine share the entity");
    }

    UFUNCTION()
    private void Step_Hurt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _States.Empty();
        _Brain.Request_SetFact(FMars_Request_Brain_SetFact(IsHurt(), true));
    }

    UFUNCTION()
    private void Step_Heal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Brain.Request_SetFact(FMars_Request_Brain_SetFact(IsHurt(), false));
    }

    UFUNCTION()
    private void Step_AssertThroughIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Trail = FString();
        for (const auto& State : _States)
        { Trail += f"{State} > "; }
        Assert_True(_States.Num() >= 2, f"the machine changed state at least twice ({Trail})");
        if (_States.Num() >= 2)
        {
            Assert_True(_States[0] == StateName(UMars_AutoTestState_BrainIdle), f"Roam left for the Idle hub first ({Trail})");
            Assert_True(_States.Last() == StateName(UMars_AutoTestState_BrainFlinch), f"Idle dispatched to Flinch ({Trail})");
        }
    }

    UFUNCTION()
    private void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_Machine, UMars_AutoTestState_BrainRoam));
    }

    UFUNCTION()
    private void Check_InFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_Machine, UMars_AutoTestState_BrainFlinch));
    }
}
