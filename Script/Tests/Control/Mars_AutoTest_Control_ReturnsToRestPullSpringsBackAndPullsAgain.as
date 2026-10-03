// A pull chain (ManuallyCompleted, ReturnsToRest): a pull past EngageAlpha ends the interaction and the handle springs
// back to rest; IsActive never moves the handle; and a second pull while the control is active still runs toward the end
// pose, from rest, and engages again.
class UMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_Mover _Mover;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Interaction _Interaction;
    private FCk_Handle _Player;
    private int32 _NewInteractions = 0;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildChain(InHandle);

        Add_Step("start the first interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the first interaction exists", n"Check_FirstInteraction", 0, 5.0f);
        Add_Step("grip the chain", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the chain is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the manipulation ends", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the first interaction finishes", n"Check_FirstFinished", 0, 5.0f);
        Add_Step_WaitUntil("the handle springs back to rest", n"Check_AtRest", 0, 5.0f);
        Add_Step("the first pull engaged and left the target at rest", n"Step_AssertFirstPull");
        Add_Step("make the control active, as a momentary pull would", n"Step_SetActive");
        Add_Step_WaitUntil("the control is active", n"Check_IsActive", 0, 5.0f);
        Add_Step_WaitSeconds("give a mover request time to land, if one were made", 0.2f);
        Add_Step("being active does not move the handle, and the next pull still runs toward the end", n"Step_AssertActiveDoesNotMove");
        Add_Step("start the second interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the second interaction exists", n"Check_SecondInteraction", 0, 5.0f);
        Add_Step("grip the chain again", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the chain is gripped again", n"Check_IsManipulating", 0, 5.0f);
        Add_Step("the second grip starts from rest", n"Step_AssertGripFromRest");
        Add_Step_WaitUntil("pull until the manipulation ends again", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the second interaction finishes", n"Check_SecondFinished", 0, 5.0f);
        Add_Step_WaitUntil("the handle springs back to rest again", n"Check_AtRest", 0, 5.0f);
        Add_Step("the second pull engaged too", n"Step_AssertSecondPull");
        Run_Steps(InHandle);
    }

    private void BuildChain(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto ChainNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, -40.0);
        MoverSpec.Duration = 0.2f;
        _Mover = utils_mover::Add(ChainNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Behavior = EMars_Control_Behavior::Momentary;
        ControlSpec.ActiveSeconds = 30.0f;
        ControlSpec.Manipulation.PullAxis = FVector(0.0, 0.0, -1.0);
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        ControlSpec.Manipulation.ReturnsToRest = true;
        _Control = utils_control::Add(RootEntity, ControlSpec, _Mover);

        // No ProbeInfo: a transform-only child; the test drives the interaction without focus.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull chain")));
        auto Interactable = utils_interactable::Create(Root, Spec);
        _Target = Interactable.Get_AllInteractTargets()[0];
        _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        _Interaction = InInteraction;
        _NewInteractions += 1;
    }

    UFUNCTION()
    private void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void Step_StartInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    UFUNCTION()
    private void Check_FirstInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_NewInteractions >= 1);
    }

    UFUNCTION()
    private void Check_SecondInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_NewInteractions >= 2);
    }

    UFUNCTION()
    private void Step_BeginManipulation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(_Interaction, _Player));
    }

    UFUNCTION()
    private void Check_IsManipulating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating());
    }

    UFUNCTION()
    private void Check_PullUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Check_FirstFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() >= 1);
    }

    UFUNCTION()
    private void Check_SecondFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() >= 2);
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void Step_AssertFirstPull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "one finish for the first pull");
        if (_FinishedResults.Num() == 1)
        {
            Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Succeeded,
                f"the first pull ends the interaction Succeeded (got {_FinishedResults[0] :n})");
        }

        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "springing back never moves the Mover's target");
    }

    UFUNCTION()
    private void Step_SetActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Active));
    }

    UFUNCTION()
    private void Check_IsActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsActive());
    }

    UFUNCTION()
    private void Step_AssertActiveDoesNotMove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Mover.Get_Alpha();
        Assert_True(Alpha < 0.01f, f"an active returns-to-rest control leaves the handle at rest (alpha {Alpha})");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "an active returns-to-rest control does not move the Mover's target");
        Assert_True(_Control.Get_ReturnsToRest(), "the control reports ReturnsToRest");
        Assert_True(_Control.Get_PullDirection() == EMars_Control_PullDirection::TowardEnd, "the next pull runs toward the end pose even while active");
    }

    UFUNCTION()
    private void Step_AssertGripFromRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Control.Get_ManipulationAlpha();
        Assert_True(Alpha < 0.01f, f"the grip is seeded from the rested handle (alpha {Alpha})");
    }

    UFUNCTION()
    private void Step_AssertSecondPull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 2, "one finish per pull");
        if (_FinishedResults.Num() == 2)
        {
            Assert_True(_FinishedResults[1] == ECk_SucceededFailed::Succeeded,
                f"the second pull ends its interaction Succeeded (got {_FinishedResults[1] :n})");
        }

        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the target is still at rest");
    }
}
