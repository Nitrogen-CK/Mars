// The work rig's record on the interactable's owner: what its work task saw, and the outcome the test hands it.
struct FMars_AutoTest_WhileLiveWork
{
    UPROPERTY()
    int32 Entered = 0;

    UPROPERTY()
    int32 Exited = 0;

    UPROPERTY()
    FCk_Handle LastInitiator;

    // Running until the test decides how the work ends.
    UPROPERTY()
    ECk_SmTaskResult Outcome = ECk_SmTaskResult::Running;
}

// The work rig's interaction work: records on the owner's FMars_AutoTest_WhileLiveWork who its sub-SM root was stamped for,
// and runs until the test sets an outcome there.
class UMars_AutoTestHelper_WhileLiveWorkTask : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Owner;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Owner = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        FCk_Handle SubSm = Get_OwningStateMachine();

        auto& Work = _Owner.Get_Fragment(FMars_AutoTest_WhileLiveWork);
        Work.Entered += 1;
        Work.LastInitiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Owner))
        { return ECk_SmTaskResult::Failed; }

        return _Owner.Get_Fragment(FMars_AutoTest_WhileLiveWork).Outcome;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Owner))
        { _Owner.Get_Fragment(FMars_AutoTest_WhileLiveWork).Exited += 1; }

        _Owner = FCk_Handle();
    }
}

class UMars_AutoTestState_WhileLiveWork : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_AutoTestHelper_WhileLiveWorkTask;
}

// A WhileLive interactable whose work the test drives: a transform-only interactable on an owner entity of its own, with one
// Use target routed to UMars_AutoTestState_WhileLiveWork. Initiators are bare child entities (a target accepts any source).
// The target's finishes are recorded in order.
UCLASS(Abstract)
class UMars_AutoTestRig_WhileLiveWork : UCk_AutoTest_Base
{
    protected FCk_Handle _Owner;
    protected FCk_Handle_Interactable _Interactable;
    protected FCk_Handle_InteractTarget _Target;
    protected TArray<ECk_SucceededFailed> _FinishedResults;

    protected void Build_WhileLiveWork(FCk_Handle InHandle, FVector InOrigin)
    {
        auto Parent = InHandle;
        _Owner = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);
        _Owner.Add_Fragment(FMars_AutoTest_WhileLiveWork());

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        Target.InteractionStateClass = UMars_AutoTestState_WhileLiveWork;
        Target.Work = EMars_Interactable_Work::WhileLive;

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Target);
        _Interactable = utils_interactable::Create(Root, Spec);

        const auto Targets = _Interactable.Get_AllInteractTargets();
        if (Targets.Num() != 1)
        {
            FinishFailure(f"the work interactable has {Targets.Num()} interact targets, expected 1");
            return;
        }

        _Target = Targets[0];
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnRigFinished"));
    }

    protected FCk_Handle Add_Initiator(FCk_Handle InHandle)
    {
        auto Parent = InHandle;
        return utils_entity_lifetime::Request_CreateEntity(Parent);
    }

    protected FMars_AutoTest_WhileLiveWork Get_Work() const
    {
        return _Owner.Get_Fragment(FMars_AutoTest_WhileLiveWork);
    }

    protected void Set_WorkOutcome(ECk_SmTaskResult InOutcome)
    {
        _Owner.Get_Fragment(FMars_AutoTest_WhileLiveWork).Outcome = InOutcome;
    }

    protected bool Get_IsTargetIn(TSubclassOf<UCk_SmState_EntityScript> InState) const
    {
        return utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == InState;
    }

    UFUNCTION()
    protected void OnRigFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    protected void Check_TargetIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Idle));
    }

    UFUNCTION()
    protected void Check_TargetInteracting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Interacting) && Get_Work().Entered > 0);
    }
}
