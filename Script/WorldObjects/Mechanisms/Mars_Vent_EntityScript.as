// Placeable steam vent. The origin is the base of the nozzle block; the jet fires along local +X from the nozzle mouth.
// A looping Trap cycle (Idle / Telegraph / Fire) arms the push hazard in front of the nozzle on Fire. The jet is the
// CkParticles SteamJet behavior (47), one component at the nozzle mouth aimed along the vent's +X: Telegraph plays it
// small and faint, Fire at full tuning, Idle or a stopped cycle deactivates it. An optional MechanismSink gates the cycle
// per Trap.Powered.
class UMars_Vent_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trap_Spec Trap = utils_trap::Make_VentSpec();

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // A zero PushImpulse takes the vent's push away from the nozzle. Not a `default`: the spawn-params generator emits
    // a non-default script struct as a positional constructor call, which script structs do not have.
    UPROPERTY(ExposeOnSpawn)
    FMars_Hazard_Spec Hazard;

    private FCk_Handle_Transform VentRoot;

    // Spawned at the first Telegraph or Fire whose template is ready, so a cold template never stalls the game thread;
    // null under nullrhi, where Niagara spawns nothing. The entity script is a UObject, not a fragment, so it may hold it.
    private UNiagaraComponent Steam;
    private bool _SteamActive = false;

    private const FVector NozzleMouth = FVector(30.0, 0.0, 60.0);
    private const float64 JetLength = 300.0;
    private const float64 JetWidth = 80.0;

    private const int32 k_SteamJetBehaviorId = 47;
    private const float32 k_TelegraphSize = 0.45f;
    private const float32 k_TelegraphAlpha = 0.5f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        VentRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsVent");

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.Shape = EMars_Trigger_Shape::Box;
        TriggerSpec.BoxHalfExtents = FVector(JetLength * 0.5, JetWidth * 0.5, JetWidth * 0.5);
        TriggerSpec.LocalOffset = FTransform(FRotator::ZeroRotator,
            NozzleMouth + FVector(JetLength * 0.5, 0.0, 0.0), FVector::OneVector);
        TriggerSpec.DetectionFilter = GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_Player);
        auto Trigger = utils_trigger::Add(VentRoot, TriggerSpec);

        auto HazardSpec = Hazard;
        if (HazardSpec.PushImpulse.IsNearlyZero())
        { HazardSpec.PushImpulse = FVector(900.0, 0.0, 250.0); }
        auto HazardHandle = utils_hazard::Add(InHandle, HazardSpec, Trigger);

        utils_trap::Add(InHandle, utils_trap::Resolve_Spec(Trap, utils_trap::Make_VentSpec()), HazardHandle, FCk_Handle_Mover());

        if (Sink.InputChannels.Num() > 0)
        { utils_mechanism_sink::Add(InHandle, Sink); }

        AddVisuals(VentRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A rejected trap already ensured in utils_trap::Add and composed no cycle; the vent then never fires.
        auto Cycle = InHandle.As_Cycle(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Cycle))
        { return; }

        Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnCyclePhaseChanged"));
        Cycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnCycleRunningChanged"));

        if (Cycle.Get_IsRunning())
        { Apply_SteamForPhase(Cycle.Get_CurrentPhase()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(Steam))
        { Steam.DestroyComponent(); }

        Steam = nullptr;
        _SteamActive = false;
    }

    UFUNCTION()
    private void OnCyclePhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        Apply_SteamForPhase(InPhase);
    }

    UFUNCTION()
    private void OnCycleRunningChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        if (InRunState == EMars_Cycle_RunState::Stopped)
        { Set_SteamActive(false); }
    }

    private void Apply_SteamForPhase(FGameplayTag InPhase)
    {
        const auto IsFire = InPhase == GameplayTags::Mechanism_Phase_Fire;
        const auto IsTelegraph = InPhase == GameplayTags::Mechanism_Phase_Telegraph;
        if (IsFire == false && IsTelegraph == false)
        {
            Set_SteamActive(false);
            return;
        }

        if (Ensure_Steam() == false)
        { return; }

        Set_SteamActive(true);
        if (IsTelegraph)
        { utils_particles::Request_ApplyTuningValues(Steam, k_TelegraphSize, 1.0f, k_TelegraphAlpha, 1.0f); }
        else
        { utils_particles::Request_ApplyTuningValues(Steam, 1.0f, 1.0f, 1.0f, 1.0f); }
    }

    private bool Ensure_Steam()
    {
        if (ck::IsValid(Steam))
        { return true; }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_SteamJetBehaviorId) == false)
        {
            ck::Trace("[Vent] steam template compiling; the jet joins at the next phase");
            return false;
        }

        const auto Root = utils_transform::Get_EntityCurrentTransform(VentRoot);
        Steam = utils_particles::Spawn_BehaviorAtLocation(k_SteamJetBehaviorId,
            Root.TransformPosition(NozzleMouth), Root.Rotator(), FVector::OneVector, NAME_None);

        _SteamActive = false;
        return ck::IsValid(Steam);
    }

    // Activate(true) RESETS the system, so it only runs on an off -> on edge; a Telegraph -> Fire step keeps the jet's
    // particles and only retunes it.
    private void Set_SteamActive(bool InActive)
    {
        if (ck::Is_NOT_Valid(Steam))
        { return; }

        if (InActive == _SteamActive)
        { return; }

        _SteamActive = InActive;

        if (InActive)
        { Steam.Activate(true); }
        else
        { Steam.Deactivate(); }
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        // Engine cube is 100 uu with its pivot at the centre. The nozzle block ends at the nozzle mouth.
        const auto NozzleDepth = NozzleMouth.X * 2.0;
        const auto NozzleHeight = NozzleMouth.Z + JetWidth;
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, NozzleHeight * 0.5), FVector(NozzleDepth, JetWidth * 1.4, NozzleHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"Vent_Nozzle"));
    }
}
