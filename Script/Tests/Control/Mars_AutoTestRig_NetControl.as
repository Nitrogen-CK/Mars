// The control net tests' shared steps. The server spawns a ManuallyCompleted lever or pull chain under the replicated
// spawn owner; each machine finds its own copy by tag, with the copy's Mover and Use interact target. On the client the
// subject is the gripper: it starts the interaction on its copy's target and drives the grip through kernel requests,
// as the single-machine lever rig does. Each machine counts the OnEngaged, OnActiveChanged and OnGripRefused its own copy
// raises. A stand-in is a second replicated entity the server spawns to hold a grip through direct grip requests.

// A replicated root whose Control sits on a scene node beneath it: the node has no replication driver of its own.
class UMars_TESTONLY_NetNodeControl_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the root and its transform replicate, the node and its
    // Control are built on every machine.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY()
    FVector Location = FVector(124000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, FTransform(FRotator::ZeroRotator, Location), ECk_Replication::Replicates);
        auto Node = utils_scene_node::Create(Root, FTransform::Identity);
        utils_entity_tag::Add(Node.H(), n"TAG_MarsTestNetNodeControl");

        auto Spec = FMars_Control_Spec();
        Spec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        utils_control::Add(Node.H(), Spec);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// The same, placed apart from it for a second test.
class UMars_TESTONLY_NetNodeControlApart_EntityScript : UMars_TESTONLY_NetNodeControl_EntityScript
{
    default Location = FVector(136000.0, 0.0, 5000.0);
}

// A replicated entity that holds a grip for the server, tagged so each machine finds its copy.
class UMars_TESTONLY_NetGripper_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity and its transform replicate.
    default _Replication = ECk_Replication::Replicates;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetGripper");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetControl : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    protected const float32 k_ServerHoldSeconds = 2.0f;
    // Long enough for a replicated ledger and the moves its reconcile queues to land.
    protected const float32 k_SettleSeconds = 1.0f;
    // Degrees of pull per poll; negative pulls toward the start pose.
    protected float32 _PullDegrees = 4.0f;

    protected FCk_Handle_Control _Control;
    protected FCk_Handle_Mover _Mover;
    protected FCk_Handle_InteractTarget _Target;
    protected FCk_Handle_Interaction _Interaction;
    protected int32 _EnsuresAtStart = 0;

    protected int32 _EngagedCount = 0;
    protected TArray<EMars_Control_Activation> _Activations;
    protected TArray<ECk_SucceededFailed> _FinishedResults;
    protected TArray<FCk_Handle> _GripRefusals;
    // The highest handle alpha this machine saw while its ledger still counted no engagement.
    protected float32 _MaxAlphaBeforeEngage = 0.0f;
    protected FCk_Handle _StandIn;
    protected FCk_Handle _Subject;

    // Both machines, first thing.
    protected void Begin_NetControlTest()
    {
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _Subject = Get_SubjectEntity();
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    // Server: a ManuallyCompleted toggle lever at InLocation, under the spawn owner.
    protected void Spawn_ServerLever(FVector InLocation, EMars_Control_Activation InStart)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_Lever_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Params.Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        Params.Control.StartActive = InStart == EMars_Control_Activation::Active;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Lever_EntityScript, Params);
    }

    // Server: a pull chain (Momentary, returns to rest) at InLocation, under the spawn owner.
    protected void Spawn_ServerPullChain(FVector InLocation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_PullChain_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        utils_entity_script::Request_SpawnEntity(Owner, UMars_PullChain_EntityScript, Params);
    }

    // Server: a lever whose stiff spring and low threshold cross in the first frame of a full pull.
    protected void Spawn_ServerQuickLever(FVector InLocation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_Lever_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Params.Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        Params.Control.Manipulation.EngageAlpha = 0.2f;
        Params.Control.Manipulation.Stiffness = 20000.0f;
        Params.Control.Manipulation.Damping = 280.0f;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Lever_EntityScript, Params);
    }

    // Server: a stand-in gripper, under the spawn owner.
    protected void Spawn_ServerStandIn()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetGripper_EntityScript, FInstancedStruct());
    }

    // This machine's stand-in has composed (the server tracks it).
    protected bool Get_IsStandInFound()
    {
        if (ck::IsValid(_StandIn))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetGripper"))
        {
            _StandIn = Candidate;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // Server: InGripper claims or releases _Control directly, as a holder with no grip of its own does.
    protected void Request_ServerGrip(FCk_Handle InGripper, EMars_Control_GripVerb InVerb)
    {
        _Control.Request_Grip(FMars_Request_Control_Grip(InGripper, InVerb));
    }

    // The grip report the kernel sends, sent for InGripper from this machine as if its own grip had ended so.
    protected void Fire_GripCue(FCk_Handle InGripper, EMars_Control_GripVerb InVerb)
    {
        utils_control::Request_GripFor(_Control, InGripper, InVerb);
    }

    // Who InHandle is, for the log lines.
    protected FString Get_WhoText(FCk_Handle InHandle) const
    {
        if (ck::Is_NOT_Valid(InHandle))
        { return "none"; }

        if (InHandle == _Subject)
        { return "subject"; }

        if (ck::IsValid(_StandIn) && InHandle == _StandIn)
        { return "standIn"; }

        return InHandle.ToString();
    }

    // InControl's grip ledger as this machine reads it.
    protected FString Get_GripText(FCk_Handle_Control InControl) const
    {
        const auto& Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        return f"grip {Ledger.Grip :n}, gripper {Get_WhoText(InControl.Get_Gripper())}, gripSerial {Ledger.GripSerial}, release {Ledger.LastRelease :n}, refusals {Ledger.RefusalSerial}, lastRefused {Get_WhoText(Ledger.LastRefused)}";
    }

    protected bool Get_HasPendingEngage() const
    {
        return _Control.Get_Fragment(FMars_Fragment_Control_Local).PendingEngage.IsSet();
    }

    // This machine's copy tagged InTag has composed with its Use target; the first time, its signals are counted from
    // here (and the server tracks it).
    protected bool Get_IsControlFound(FName InTag)
    {
        if (ck::IsValid(_Control))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            auto Control = Candidate.As_Control(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Control))
            { continue; }

            auto Target = DoFind_UseTarget(Candidate);
            if (ck::Is_NOT_Valid(Target))
            { continue; }

            _Control = Control;
            _Mover = Control.Get_Mover();
            _Target = Target;
            _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnControlEngaged"));
            _Control.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnControlActiveChanged"));
            _Control.BindTo_OnGripRefused(FMars_Delegate_Control_OnGripRefused(this, n"OnControlGripRefused"));
            _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnTargetNewInteraction"));
            _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnTargetInteractionFinished"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // The interactable is a node two levels down at most (the lever's probe node under its root).
    private FCk_Handle_InteractTarget DoFind_UseTarget(FCk_Handle InRoot)
    {
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InRoot))
        {
            auto Interactable = Dependent.As_Interactable(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Interactable))
            { return Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use); }

            for (auto Grandchild : utils_entity_lifetime::Get_LifetimeDependents(Dependent))
            {
                auto Inner = Grandchild.As_Interactable(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Inner))
                { return Inner.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use); }
            }
        }

        return FCk_Handle_InteractTarget();
    }

    protected int32 Get_Engagements() const
    {
        return _Control.Get_Fragment(FMars_Fragment_Control).Engagements;
    }

    // The Control's alpha while gripped, else the Mover's.
    protected float32 Get_HandleAlpha() const
    {
        const auto Alpha = _Control.TryGet_ManipulationAlpha();
        if (Alpha.IsSet())
        { return Alpha.GetValue(); }

        return ck::IsValid(_Mover) ? _Mover.Get_Alpha() : 0.0f;
    }

    protected FString Get_ActivationsText() const
    {
        auto Text = FString();
        for (auto Activation : _Activations)
        { Text += f"{Activation :n} "; }

        return Text;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client steps
    //----------------------------------------------------------------------------------------------------------------------

    // The subject starts the interaction on its own copy's target, as the source and the instigator.
    protected void Start_ClientInteraction()
    {
        auto Subject = Get_SubjectEntity();
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(Subject, Subject));
    }

    protected void Begin_ClientGrip()
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(_Interaction));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Predicates
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    protected void Is_LeverFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsLever"));
    }

    UFUNCTION()
    protected void Is_PullChainFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsPullChain"));
    }

    UFUNCTION()
    protected void Is_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Interaction));
    }

    UFUNCTION()
    protected void Is_Manipulating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_IsManipulating());
    }

    // Nudges every poll until the grip ends, recording the highest alpha seen before any engagement replicated.
    UFUNCTION()
    protected void Is_PulledUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_Engagements() == 0)
        {
            const auto Alpha = _PullDegrees < 0.0f ? 1.0f - Get_HandleAlpha() : Get_HandleAlpha();
            _MaxAlphaBeforeEngage = Math::Max(_MaxAlphaBeforeEngage, Alpha);
        }

        auto Result = OutResult;
        if (_Control.Get_IsManipulating() == false)
        {
            Result.Set(true);
            return;
        }

        _Control.Request_Nudge(FMars_Request_Control_Nudge(_PullDegrees));
        Result.Set(false);
    }

    UFUNCTION()
    protected void Is_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_FinishedResults.Num() > 0);
    }

    UFUNCTION()
    protected void Is_EngagedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Engagements() >= 1);
    }

    UFUNCTION()
    protected void Is_HandleAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_IsManipulating() == false && ck::IsValid(_Mover) && _Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    protected void Is_HandleAtEnd(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_IsManipulating() == false && ck::IsValid(_Mover) && _Mover.Get_Alpha() > 0.99f);
    }

    UFUNCTION()
    protected void Is_StandInFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStandInFound());
    }

    // This machine's ledger shows the stand-in holding _Control.
    UFUNCTION()
    protected void Is_GrippedByStandIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && Get_IsStandInFound() && _Control.Get_Gripper() == _StandIn);
    }

    // This machine's ledger shows the subject holding _Control.
    UFUNCTION()
    protected void Is_GrippedBySubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_Gripper() == Get_SubjectEntity());
    }

    // This machine's ledger shows a granted grip released.
    UFUNCTION()
    protected void Is_GripReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    protected void Is_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_RefusalSerial() >= 1);
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnControlEngaged(FCk_Handle_Control InControl)
    {
        _EngagedCount += 1;
    }

    UFUNCTION()
    private void OnControlActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        _Activations.Add(InActivation);
    }

    UFUNCTION()
    private void OnControlGripRefused(FCk_Handle_Control InControl, FCk_Handle InRefused)
    {
        _GripRefusals.Add(InRefused);
    }

    UFUNCTION()
    private void OnTargetNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        _Interaction = InInteraction;
    }

    UFUNCTION()
    private void OnTargetInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }
}
