// Destroys the actual composition during its terminal guard motion, with its repeating verification timer live.
// The old deck's Jolt support must disappear as well as every captured descendant handle.
class UMars_AutoTest_SlidingBridge_DestroyingWhileGuardsMoveLeavesNoOwnedWork : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 12.0f;

    private FCk_Handle _Bridge;
    private FCk_Handle_Control _Windlass;
    private FCk_Handle_Gate _Guard;
    private FCk_Handle_Timer _Verification;
    private TArray<FCk_Handle> _Owned;
    private FTransform _BridgeWorld;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = UMars_SlidingBridge_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator(0.0, -35.0, 0.0), FVector(-55000.0, 356000.0, -41000.0));
        Params.Bridge.GuardMoveDuration = 2.0f;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_SlidingBridge_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBridgeConstructed"));
        Add_Step_WaitUntil("assembly ready", n"Check_Ready", 900, 0);
        Add_Step("grip actual windlass", n"Step_Grip");
        Add_Step_WaitUntil("grip accepted", n"Check_Gripped");
        Add_Step("request full haul", n"Step_Haul");
        Add_Step_WaitUntil("actual guard in flight with verification timer", n"Check_InFlight");
        Add_Step("capture descendants and destroy owner", n"Step_Destroy");
        Add_Step_WaitUntil("all descendants and actual Jolt deck gone", n"Check_Gone");
        Add_Step_WaitSeconds("outlast verification polling after teardown", 0.3f);
        Add_Step("no orphan work or support", n"Step_AssertGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBridgeConstructed(FCk_Handle_EntityScript InBridge)
    { _Bridge = InBridge; }

    private FCk_Handle Find_OwnedTagged(FCk_Handle InContext, FName InTag) const
    {
        for (auto Entity : utils_entity_tag::ForEach_Entity(InContext, InTag))
        {
            if (ck::IsValid(Entity) && utils_entity_lifetime::Get_LifetimeOwner(Entity) == _Bridge)
            { return Entity; }
        }
        return FCk_Handle();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Bridge))
        { Result.Set(false); return; }
        _Windlass = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeWindlass").As_Control(ECk_SanityCheck::UnChecked);
        _Guard = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeNearGuard").As_Gate(ECk_SanityCheck::UnChecked);
        Result.Set(ck::IsValid(_Windlass) && ck::IsValid(_Guard)
            && _Windlass.Has_Fragment(FMars_Tag_Control_NeedsSetup) == false
            && _Guard.Has_Fragment(FMars_Tag_Gate_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_Grip(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Windlass.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(FCk_Handle_Interaction())); }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(_Windlass.Get_IsManipulating()); }

    UFUNCTION()
    private void Step_Haul(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Windlass.Request_Nudge(FMars_Request_Control_Nudge(1080.0f)); }

    UFUNCTION()
    private void Check_InFlight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _Verification = Find_OwnedTagged(InHandle, n"TAG_MarsSlidingBridgeVerification").As_Timer(ECk_SanityCheck::UnChecked);
        const auto Mover = _Guard.Get_MovingNode().As_Mover();
        Result.Set(ck::IsValid(_Verification) && _Guard.Get_IsOpen() && Mover.Get_Alpha() > 0.0f
            && Mover.Get_Alpha() < 1.0f && Mover.Get_IsResting() == false);
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BridgeWorld = utils_transform::Get_EntityCurrentTransform(_Bridge.As_Transform());
        _Owned.Add(_Bridge);
        // Capture recursively: tween and timer lifetime owners may be nested beneath a scene node.
        for (int32 Index = 0; Index < _Owned.Num(); ++Index)
        {
            for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(_Owned[Index]))
            { _Owned.AddUnique(Dependent); }
        }
        Assert_True(_Owned.Num() > 10, "actual visual, control, gate and timer assembly was captured");
        Assert_True(Get_HasOldDeckSupport(), "the real deck was seated before owner destruction");
        Assert_True(ck::IsValid(_Verification), "verification was active during destruction");
        utils_entity_lifetime::Request_DestroyEntity(_Bridge);
    }

    private bool Get_HasOldDeckSupport() const
    {
        const auto Top = _BridgeWorld.TransformPosition(FVector(0.0, 525.0, 0.0));
        const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(Top + FVector(0.0, 0.0, 10.0), Top - FVector(0.0, 0.0, 40.0));
        return Hit.Get_HasHit() && Math::Abs(Hit.Get_Position().Z - Top.Z) <= 2.0;
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        for (const auto Entity : _Owned)
        {
            if (ck::IsValid(Entity))
            { Result.Set(false); return; }
        }
        Result.Set(Get_HasOldDeckSupport() == false);
    }

    UFUNCTION()
    private void Step_AssertGone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto Entity : _Owned)
        { Assert_False(ck::IsValid(Entity), "no captured descendant survives"); }
        Assert_False(ck::IsValid(_Verification), "no verification timer survives");
        Assert_False(ck::IsValid(_Windlass), "no windlass survives");
        Assert_False(ck::IsValid(_Guard), "no guard survives");
        Assert_False(Get_HasOldDeckSupport(), "no stale Jolt support survives the bridge");
    }
}
