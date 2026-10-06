// The lever rig: a ManuallyCompleted Control (pull axis -X, 0.02 alpha per degree, EngageAlpha 0.85) on a root entity,
// turning a scene-node handle 70 degrees in pitch over 0.3 s through a Mover, with one transform-only interact target
// (no ProbeInfo: the reach resolves as a point grip at the owner). The test entity is the player. The handlers record
// the Control's engages and the target's interactions.
UCLASS(Abstract)
class UMars_AutoTestRig_Lever : UCk_AutoTest_Base
{
    protected FCk_Handle_Control _Control;
    protected FCk_Handle_Mover _Mover;
    protected FCk_Handle_Interactable _Interactable;
    protected FCk_Handle_InteractTarget _Target;
    protected FCk_Handle_Interaction _Interaction;
    protected FCk_Handle _Player;
    protected int32 _EngagedCount = 0;
    protected int32 _NewInteractionCount = 0;
    protected TArray<ECk_SucceededFailed> _FinishedResults;

    // An Active lever starts with its handle at the far stop.
    protected void BuildLever(FCk_Handle InHandle, EMars_Control_Activation InStart)
    {
        _Player = InHandle;
        const auto StartActive = InStart == EMars_Control_Activation::Active;

        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandleNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(70.0, 0.0, 0.0);
        MoverSpec.Duration = 0.3f;
        MoverSpec.StartPose = StartActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        _Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.StartActive = StartActive;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        _Control = utils_control::Add(RootEntity, ControlSpec, _Mover);
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull")));
        _Interactable = utils_interactable::Create(Root, Spec);
        _Target = _Interactable.Get_AllInteractTargets()[0];
        BindTargetSignals();
    }

    protected void BindTargetSignals()
    {
        _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnEngaged(FCk_Handle_Control InControl)
    {
        _EngagedCount += 1;
    }

    UFUNCTION()
    protected void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        _Interaction = InInteraction;
        _NewInteractionCount += 1;
    }

    UFUNCTION()
    protected void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_StartInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    UFUNCTION()
    protected void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Interaction));
    }

    UFUNCTION()
    protected void Step_BeginManipulation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(_Interaction, _Player));
    }

    UFUNCTION()
    protected void Check_IsManipulating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating());
    }

    UFUNCTION()
    protected void Check_PullUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    protected void Check_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() == 1);
    }

    UFUNCTION()
    protected void Check_SettledToRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mover.Get_Alpha() < 0.01f);
    }
}
