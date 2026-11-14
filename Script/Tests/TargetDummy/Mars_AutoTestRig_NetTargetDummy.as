// The target dummy net tests' shared steps, on top of the strike rig: the server spawns the sandbox target dummy at the
// row's base under the replicated spawn owner; each machine finds its copy by tag near the base, strikes it as the strike
// rig's target and counts what its own copy's Health raises. "The body's height" is the Z of the world scale of the
// zone's first hurtbox node, which hangs off the body node the dummy scales. "The client claims the dummy" is the strike
// rig's claim naming the dummy's zone and a point on the post's near face at hand height.
UCLASS(Abstract)
class UMars_AutoTestRig_NetTargetDummy : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    // The server waits this long after it finds its dummy, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    protected const FVector k_ClaimFromBase = FVector(-35.0, 0.0, 60.0);
    protected const float64 k_FlattenedHeight = 0.2;
    protected const float64 k_StandingHeight = 1.0;
    protected const float64 k_HeightTolerance = 0.01;

    protected float32 _DummyMaxHealth = 100.0f;
    protected float32 _DummyRearmSeconds = 30.0f;
    protected ECk_EnableDisable _DummyRowArms = ECk_EnableDisable::Disable;

    protected int32 _DummyDamaged = 0;
    protected int32 _DummyDepleted = 0;
    protected int32 _DummyHealed = 0;
    protected int32 _DepletedFrame = -1;
    protected int32 _HealedFrame = -1;
    // The Health's current value and the body's height when this machine's copy raised OnHealed.
    protected float32 _CurrentAtHealed = -1.0f;
    protected float64 _HeightAtHealed = -1.0;
    protected int32 _FirstClaimFrame = -1;
    protected int32 _SecondClaimFrame = -1;

    protected void Begin_TargetDummy(FVector InBase, float32 InMaxHealth, float32 InRearmSeconds)
    {
        Begin_Strike(InBase);
        _DummyMaxHealth = InMaxHealth;
        _DummyRearmSeconds = InRearmSeconds;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // A dummy row: the server arms (when told to), spawns the dummy and continues in OnServerFound once it finds its copy.
    //----------------------------------------------------------------------------------------------------------------------

    protected void Start_ServerDummyRow()
    {
        WaitUntil(n"Is_ServerReady", n"OnDummyRowServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnDummyRowServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_DummyRowArms == ECk_EnableDisable::Disable)
        {
            Spawn_ServerDummy();
            WaitUntil(n"Is_DummyFound", n"OnServerFound", k_SlowPolls);
            return;
        }

        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnDummyRowServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnDummyRowServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDummy();
        WaitUntil(n"Is_DummyFound", n"OnServerFound", k_SlowPolls);
    }

    // Server: the dummy at _TargetAt under the replicated spawn owner.
    protected void Spawn_ServerDummy()
    {
        auto Params = UMars_TargetDummy_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _TargetAt);
        Params.MaxHealth = _DummyMaxHealth;
        Params.RearmSeconds = _DummyRearmSeconds;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TargetDummy_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_DummyFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDummyFound());
    }

    // This machine's copy of the dummy near _TargetAt has composed its Health, its zone and the zone's hurtbox; the first
    // time, it becomes the struck target, its Health's signals are counted from here (and the server tracks it).
    protected bool Get_IsDummyFound()
    {
        if (ck::IsValid(_Zone))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTargetDummy"))
        {
            if (Get_IsNear(Candidate, _TargetAt) == false)
            { continue; }

            auto Health = Candidate.As_Health(ECk_SanityCheck::UnChecked);
            auto Zone = Candidate.As_HitZone(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone) || Zone.Get_Hurtboxes().Num() == 0)
            { continue; }

            Take_Dummy(Candidate, Health, Zone);
            return true;
        }

        return false;
    }

    private void Take_Dummy(FCk_Handle InEntity, FCk_Handle_Health InHealth, FCk_Handle_HitZone InZone)
    {
        _Target = InEntity;
        _Health = InHealth;
        _Zone = InZone;
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDummyDamaged"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDummyDepleted"));
        _Health.BindTo_OnHealed(FMars_Delegate_Health_OnHealed(this, n"OnDummyHealed"));
        if (Get_IsServer())
        { Track_ForCleanup(InEntity); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Reading the dummy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_DummyDepleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDummyFound() && _Health.Get_IsDepleted());
    }

    // The body's height, or -1 while this machine has no dummy with a hurtbox node.
    protected float64 Get_BodyHeight()
    {
        if (ck::Is_NOT_Valid(_Zone))
        { return -1.0; }

        const auto Hurtboxes = _Zone.Get_Hurtboxes();
        if (Hurtboxes.Num() == 0)
        { return -1.0; }

        const auto Node = Hurtboxes[0].As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return -1.0; }

        return utils_transform::Get_EntityCurrentTransform(Node).GetScale3D().Z;
    }

    protected void Assert_BodyHeight(float64 InExpected, FString InWhat)
    {
        const auto Height = Get_BodyHeight();
        Assert_True(Math::IsNearlyEqual(Height, InExpected, k_HeightTolerance), f"{InWhat}: the body's height reads {InExpected} (reads {Height})");
    }

    protected bool Get_HasHealthRequests()
    {
        return ck::IsValid(_Health) && _Health.Has_Fragment(FMars_Fragment_Health_Requests);
    }

    // Server: a hit of InAmount Sever on its copy of the dummy's zone.
    protected void Request_ServerDummyHit(float32 InAmount)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Claiming the dummy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ClientReadyToClaimDummy(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsDummyFound());
    }

    protected FVector Get_DummyClaimLocation() const
    {
        return _TargetAt + k_ClaimFromBase;
    }

    protected FMars_HeldItemUse_Strike Make_DummyClaim()
    {
        auto Claim = Make_Claim();
        Claim.Location = Get_DummyClaimLocation();
        return Claim;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line
    //----------------------------------------------------------------------------------------------------------------------

    // The row's one log line on this machine.
    protected void Log_DummyRow(FString InRow, FString InExtra)
    {
        const auto Tally = Get_Tally();
        const auto Current = ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto Depleted = ck::IsValid(_Health) && _Health.Get_IsDepleted();
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        const auto Height = Get_BodyHeight();
        const auto HasRequests = Get_HasHealthRequests();
        const auto Line = f"[TargetDummyNetTest] {InRow} {Get_MachineName()} current={Current} depleted={Depleted} damaged={_DummyDamaged} depletedCount={_DummyDepleted} healed={_DummyHealed} height={Height} tally=[applied {Tally.Applied} refused {Tally.Refused} last {Refusal}] requests={HasRequests} depletedFrame={_DepletedFrame} healedFrame={_HealedFrame} currentAtHealed={_CurrentAtHealed} heightAtHealed={_HeightAtHealed} claimFrames=[{_FirstClaimFrame} {_SecondClaimFrame}] ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }

    // The row's log line on this machine, no ensure, done.
    protected void Finish_DummyRow(FString InRow, FString InExtra)
    {
        Log_DummyRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_ServerDummyRow(FString InRow, FString InExtra)
    {
        Log_DummyRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDummyDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _DummyDamaged += 1;
    }

    UFUNCTION()
    private void OnDummyDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _DummyDepleted += 1;
        if (_DepletedFrame < 0)
        { _DepletedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnDummyHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        _DummyHealed += 1;
        if (_HealedFrame < 0)
        {
            _HealedFrame = int32(utils_time::Get_FrameCounter());
            _CurrentAtHealed = InRemaining;
            _HeightAtHealed = Get_BodyHeight();
        }
    }
}
