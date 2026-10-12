// Production ActionPlayer -> accepted receipt -> game sphere proxy -> real Jolt world query.
// The same target moves between settled pose revisions; the wall variant blocks that same target path.
UCLASS(Abstract)
class UMars_AutoTest_CrawlerMelee_LongLimbLiveBase : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 25.0f;
    default _AutoStageOriginField = false;

    protected bool _WithWall = false;
    protected bool _WithDamage = false;
    protected bool _CancelAfterFirst = false;
    protected bool _DestroyScopeAfterFirst = false;
    protected bool _DestroyPartAfterFirst = false;
    protected bool _DestroyTargetAfterFirst = false;
    protected bool _SwapHurtboxAfterFirst = false;
    private FCk_Handle_Transform _Root;
    private FCk_Handle_Transform _Part;
    private FCk_Handle_ProceduralArticulation _Subject;
    private FCk_Handle_ProceduralActionPlayer _Player;
    private FCk_Handle _Scope;
    private FCk_Handle_ProceduralAction _Action;
    private FMars_AutoTest_CrawlerMelee_Target _SphereTarget;
    private FMars_AutoTest_CrawlerMelee_Target _ForeignTarget;
    private FCk_Handle _Wall;
    private FVector _RootLocation;
    private int32 _ProbeBeginCount = 0;

    protected void BeginFixture(FCk_Handle InHandle)
    {
        _RootLocation = _WithWall ? FVector(161000.0, 82000.0, 2000.0) :
            FVector(160000.0, 82000.0, 2000.0);
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Root = utils_transform::Add(RootEntity, FTransform(_RootLocation),
            ECk_Replication::DoesNotReplicate);
        auto PartEntity = utils_entity_lifetime::Request_CreateEntity(RootEntity);
        _Part = utils_transform::Add(PartEntity, FTransform::Identity,
            ECk_Replication::DoesNotReplicate);

        auto Lengths = TArray<float32>();
        Lengths.Add(100.0f);
        auto Layouts = TArray<FCk_ProceduralLimb_Layout>();
        Layouts.Add(FCk_ProceduralLimb_Layout(n"Arm", FTransform::Identity,
            Lengths, FTransform(FVector(100.0, 0.0, 0.0)), FVector::UpVector));
        auto Parts = TArray<FCk_Handle_Transform>();
        Parts.Add(_Part);
        auto Bindings = TArray<FCk_ProceduralLimb_Binding>();
        Bindings.Add(FCk_ProceduralLimb_Binding(n"Arm", Parts));
        _Subject = utils_procedural_articulation::Add(_Root,
            FCk_ProceduralArticulation_Spec(FCk_ProceduralArticulation_Layout(Layouts), Bindings));
        _SphereTarget = SpawnCombatTarget(InHandle, _RootLocation + FVector(150.0, 0.0, 0.0),
            FVector(5.0, 5.0, 5.0));
        if (_WithDamage)
        {
            _ForeignTarget = SpawnCombatTarget(InHandle, _RootLocation + FVector(300.0, 0.0, 0.0),
                FVector(5.0, 5.0, 5.0));
        }
        if (_WithWall)
        { _Wall = SpawnWall(InHandle, _RootLocation + FVector(50.0, 0.0, 0.0), FVector(1.0, 10.0, 10.0)); }
        if (ck::Is_NOT_Valid(_Subject) || ck::Is_NOT_Valid(_SphereTarget.Root) ||
            (_WithWall && ck::Is_NOT_Valid(_Wall)))
        { FinishFailure("Dedicated articulation, target or Jolt wall did not compose"); return; }

        Add_Step_WaitUntil("dedicated limb settles", n"LongLimb_Check_Settled", 900);
        Add_Step("admit scoped long-limb action and receipt consumer", n"LongLimb_Step_Admit");
        Add_Step_WaitUntil("limb action claims its channel", n"LongLimb_Check_Ready", 900);
        Add_Step("submit first bounded limb position", n"LongLimb_Step_First");
        Add_Step_WaitUntil("first actual pose is observed and seeds history", n"LongLimb_Check_First", 900);
        if (_CancelAfterFirst || _DestroyScopeAfterFirst || _DestroyPartAfterFirst ||
            _DestroyTargetAfterFirst || _SwapHurtboxAfterFirst)
        {
            Add_Step("terminate the active limb interval", n"LongLimb_Step_Terminate");
            if (_DestroyTargetAfterFirst)
            { Add_Step_WaitUntil("target root is destroyed", n"LongLimb_Check_TargetDestroyed", 900); }
            Add_Step_WaitUntil("closed terminal stream is acknowledged", n"LongLimb_Check_Released", 900);
            Add_Step("no geometry or damage follows terminal closure", n"LongLimb_Step_VerifyTerminated");
            Run_Steps(InHandle);
            return;
        }
        Add_Step("move explicit sphere target before the next action sample", n"LongLimb_Step_MoveTarget");
        Add_Step_WaitUntil("target transform moves", n"LongLimb_Check_TargetMoved", 900);
        Add_Step("submit second bounded limb position", n"LongLimb_Step_Second");
        Add_Step_WaitUntil("second accepted interval is consumed", n"LongLimb_Check_Second", 900);
        if (_WithDamage)
        {
            Add_Step_WaitUntil("the real damage request reaches target Health", n"LongLimb_Check_DamageApplied", 900);
            Add_Step_WaitSeconds("drain any probe notification side effects", 0.1f);
        }
        Add_Step("verify world ordering, dedup and actual part; end action", n"LongLimb_Step_VerifyAndEnd");
        Add_Step_WaitUntil("terminal stream is consumed and released", n"LongLimb_Check_Released", 900);
        Add_Step("verify terminal cleanup", n"LongLimb_Step_VerifyReleased");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void LongLimb_Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Subject.Get_SettledRevision() > 0 && _Subject.Get_Limbs().Num() == 1);
    }

    UFUNCTION()
    private void LongLimb_Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Player = utils_procedural_action_player::Add(_Subject, FCk_ProceduralActionPlayer_Spec());
        FCk_Handle Owner = _Root;
        _Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto Ids = TArray<FName>();
        Ids.Add(n"Arm");
        auto Control = FCk_ProceduralAction_ControlSpec(Ids);
        Control.Set_InputTimeout(FCk_Time(12.0));
        _Action = utils_procedural_action::Create_Manual(_Scope, _Player, Control);
        auto Spec = FMars_Crawler_LongLimbSpec();
        Spec.LimbId = n"Arm";
        Spec.SegmentLengths.Add(100.0f);
        Spec.SegmentRadii.Add(1.0f);
        Spec.TargetRadiusCm = 1.0f;
        if (_WithDamage)
        {
            const auto ForeignAttached = utils_crawler_long_limb_demo::Attach(Owner, _Subject,
                _Player, _Action, _Scope, _SphereTarget.Root, _ForeignTarget.Hurtbox, Spec);
            Assert_True(ForeignAttached == false &&
                Owner.Has_Fragment(FMars_Fragment_Crawler_LongLimbDemo) == false,
                "A target transform and another damage zone's hurtbox reject atomically");
        }
        const auto Attached = utils_crawler_long_limb_demo::Attach(Owner, _Subject,
            _Player, _Action, _Scope, _SphereTarget.Root, _SphereTarget.Hurtbox, Spec);
        Assert_True(Attached && ck::IsValid(_Action),
            "The optional resolver owns a valid bounded stream without changing the crawler jab");
        if (_WithDamage && Attached)
        {
            auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
            Demo.Dealer = utils_damage_dealer::Add(Owner, FMars_DamageDealer_Spec());
            Assert_True(ck::IsValid(Demo.Dealer), "The long-limb demo has a real game damage dealer");
            // Damage-zone hurtboxes are intentionally Silent. A separate notifying observer
            // makes the no-query-notification assertion observable without changing that policy.
            auto ObserverNode = utils_scene_node::Create(_SphereTarget.Root, FTransform::Identity);
            auto ObserverSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_HitZone);
            ObserverSpec.Set_ResponsePolicy(ECk_ProbeResponse_Policy::Notify)
                        .Set_MotionType(ECk_MotionType::Kinematic);
            const auto Observer = utils_probe::Add_Box(ObserverNode.As_Transform(),
                FVector(5.0, 5.0, 5.0), ObserverSpec);
            utils_probe::BindTo_OnBeginOverlap(Observer,
                FCk_Delegate_Probe_OnBeginOverlap(this, n"LongLimb_OnProbeBeginOverlap"));
        }
    }

    UFUNCTION()
    private void LongLimb_Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Action) && _Action.Get_State() == ECk_ProceduralAction_State::Ready);
    }

    private void Submit(float64 InAngle, int64 InToken)
    {
        auto Target = FCk_ProceduralAction_LimbTarget(n"Arm",
            FTransform(FQuat(FVector::UpVector, InAngle),
                FVector(Math::Cos(InAngle) - 1.0, Math::Sin(InAngle), 0.0)));
        Target.Set_Space(ECk_ProceduralAction_TrackSpace::LimbRestNormalized);
        auto Targets = TArray<FCk_ProceduralAction_LimbTarget>();
        Targets.Add(Target);
        auto Batch = FCk_ProceduralAction_PoseBatch();
        Batch.Set_Limbs(Targets);
        auto Request = FCk_Request_ProceduralAction_SubmitPoseBatch(Batch);
        Request.Set_CorrelationToken(InToken);
        utils_procedural_action::Request_SubmitPoseBatch(_Action, Request);
    }

    UFUNCTION()
    private void LongLimb_Step_First(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Submit(0.005, 1);
    }

    UFUNCTION()
    private void LongLimb_Check_First(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo).Receipt.LastSampleSequence >= 1);
    }

    UFUNCTION()
    private void LongLimb_Step_MoveTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Root = _SphereTarget.Root;
        utils_transform::Request_SetTransform(Root,
            FTransform(_RootLocation + FVector(50.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void LongLimb_Step_Terminate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_SwapHurtboxAfterFirst)
        { _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo).TargetHurtbox = _ForeignTarget.Hurtbox; }
        else if (_DestroyScopeAfterFirst)
        { utils_entity_lifetime::Request_DestroyEntity(_Scope); }
        else if (_DestroyPartAfterFirst)
        { utils_entity_lifetime::Request_DestroyEntity(_Part); }
        else if (_DestroyTargetAfterFirst)
        { utils_entity_lifetime::Request_DestroyEntity(_SphereTarget.Entity); }
        else
        { _Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel()); }
    }

    UFUNCTION()
    private void LongLimb_Check_TargetDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult,
        FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_SphereTarget.Root));
    }

    UFUNCTION()
    private void LongLimb_Step_VerifyTerminated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        Assert_True(Demo.TerminalSeen && Demo.StreamReleased && Demo.WindowClosed,
            "Terminal closure was consumed before the scoped stream was released");
        Assert_True(Demo.Receipt.LastSampleSequence == 1 && Demo.DamageCandidateCount == 0 &&
            Demo.DamageRequestCount == 0 && Demo.WorldQueryCount == 0,
            "Cancellation or severing cannot authorize geometry after the seed receipt");
        if (_DestroyTargetAfterFirst)
        {
            Assert_True(ck::Is_NOT_Valid(_SphereTarget.Root) && Demo.Receipt.Closed &&
                (Demo.Failure == "Subject or target disappeared" ||
                Demo.Failure == "Target sphere and hurtbox no longer identify the same live damage zone"),
                "Target-root loss closes the offensive receipt before target history can advance");
            Assert_True(Demo.ConsumePending == false && Demo.ReceiptCursor == Demo.PendingConsumeCursor,
                "Target-root loss still drains and acknowledges the terminal stream");
        }
        else if (_SwapHurtboxAfterFirst)
        {
            Assert_True(Demo.Failure == "Target sphere and hurtbox no longer identify the same live damage zone",
                "Replacing the target binding closes the consumer with an explicit reason");
            Assert_Equals_Float(_SphereTarget.Health.Get_Current(), 100.0f, 0.01f,
                "The original target receives no damage after a binding mismatch");
            Assert_Equals_Float(_ForeignTarget.Health.Get_Current(), 100.0f, 0.01f,
                "An unrelated hurtbox cannot receive damage from the original target's history");
        }
        else
        { Assert_True(Demo.Failure.IsEmpty(), f"The terminal stream closed without consumer failure ({Demo.Failure})"); }
    }

    UFUNCTION()
    private void LongLimb_Check_TargetMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set((utils_transform::Get_EntityCurrentLocation(_SphereTarget.Root) -
            (_RootLocation + FVector(50.0, 0.0, 0.0))).Size() < 0.05);
    }

    UFUNCTION()
    private void LongLimb_Step_Second(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Submit(0.01, 2);
    }

    UFUNCTION()
    private void LongLimb_Check_Second(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        Result.Set(Demo.Receipt.LastSampleSequence >= 2 || Demo.Receipt.Closed);
    }

    UFUNCTION()
    private void LongLimb_Check_DamageApplied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_SphereTarget.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void LongLimb_OnProbeBeginOverlap(FCk_Handle_Probe InProbe, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        ++_ProbeBeginCount;
    }

    UFUNCTION()
    private void LongLimb_Step_VerifyAndEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        Assert_True(Demo.Failure.IsEmpty() && Demo.Receipt.LastSampleSequence >= 2,
            f"Two settled samples survived receipt reconstruction ({Demo.Failure})");
        Assert_True(Demo.WorldQueryCount > 0 && Demo.GeometryOverlapCount > 1,
            "Multiple material spheres overlap the explicit moving target while real Jolt queries run");
        Assert_True(Demo.DamageCandidateCount == (_WithWall ? 0 : 1),
            "A real wall wins the accepted target path; clear multi-sphere contact yields one candidate");
        Assert_True(Demo.DamageRequestCount == (_WithDamage ? 1 : 0),
            "Multiple geometry overlaps yield at most one configured damage request");
        if (_WithDamage)
        {
            Assert_Equals_Float(_SphereTarget.Health.Get_Current(), 85.0f, 0.01f,
                "The real target lost exactly one 15 HP damage event");
            Assert_Equals_Int(_ProbeBeginCount, 0,
                "Long-limb world queries do not notify the nearby target probe");
        }
        const auto Last = _Action.Get_LastReceipt();
        const auto PartWorld = utils_transform::Get_EntityCurrentTransform(_Part);
        Assert_True(Last.Get_HasAcceptedPose() && Last.Get_CurrentPose().Get_Limbs().Num() == 1 &&
            (Last.Get_CurrentPose().Get_Limbs()[0].Get_Segments()[0].GetLocation() -
                PartWorld.GetLocation()).Size() < 0.05,
            "The reconstruction starts from the part's actual settled accepted geometry");
        _Action.Request_End(FCk_Request_ProceduralAction_End());
    }

    UFUNCTION()
    private void LongLimb_Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo).StreamReleased);
    }

    UFUNCTION()
    private void LongLimb_Step_VerifyReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        Assert_True(Demo.TerminalSeen && Demo.StreamReleased && Demo.Failure.IsEmpty(),
            "Terminal was consumed in order before the scoped stream was released");
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveClear : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveWall : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _WithWall = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveDamage : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _WithDamage = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveCancel : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _CancelAfterFirst = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbTargetBinding : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _WithDamage = true;
        _SwapHurtboxAfterFirst = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveScopeLoss : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _DestroyScopeAfterFirst = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveSever : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _DestroyPartAfterFirst = true;
        BeginFixture(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLiveTargetLoss : UMars_AutoTest_CrawlerMelee_LongLimbLiveBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _DestroyTargetAfterFirst = true;
        BeginFixture(InHandle);
    }
}
