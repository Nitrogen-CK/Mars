// The Root Maw rig: a Maw spawned through its real entity script, without visuals, its root Clearance above a runtime
// static Jolt floor (3000 x 3000 uu, top face at _Origin.Z), facing +X. Each test sets _Origin to an isolated spot: the
// Mars autotest map has no floor of its own there.
UCLASS(Abstract)
class UMars_AutoTestRig_RootMaw : UCk_AutoTest_Base
{
    protected const int32 k_SlowPolls = 600;

    protected FVector _Origin;
    protected FCk_Handle_RootMaw _Maw;
    protected FCk_Handle_Transform _TargetRoot;

    // A static Jolt box at InTransform, BlockAll.
    protected FCk_Handle SpawnStaticBox(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Box = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Box, InTransform, ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
        return Box;
    }

    protected void SpawnFloorAndMaw(FCk_Handle InHandle, FMars_RootMaw_Spec InSpec)
    {
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), FVector(1500.0, 1500.0, 10.0));

        auto SpawnParams = UMars_RootMaw_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, utils_root_maw::Clearance));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_RootMaw_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnMawConstructed"));
    }

    // A target InOffset from the origin (its root 90 up) on team One (Hostile to the Maw on Two): Health 100, a flesh body
    // zone with one 70 x 70 x 180 box hurtbox round its root, and TAG_MarsCombatTarget added last. Returns its Health; its
    // root is _TargetRoot.
    protected FCk_Handle_Health SpawnTarget(FCk_Handle InHandle, FVector InOffset)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _TargetRoot = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, Get_TargetLocation(InOffset)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Entity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        auto Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        utils_hit_zone::AddHurtbox_Box(Zone, _TargetRoot, FMars_HitZone_Hurtbox(FVector(35.0, 35.0, 90.0), FTransform::Identity));
        utils_entity_tag::Add(Entity, n"TAG_MarsCombatTarget");
        return Health;
    }

    protected FVector Get_TargetLocation(FVector InOffset) const
    {
        return _Origin + InOffset + FVector(0.0, 0.0, 90.0);
    }

    protected void MoveTarget(FVector InOffset)
    {
        utils_transform::Request_SetLocation(_TargetRoot, FCk_Request_Transform_SetLocation(Get_TargetLocation(InOffset)));
    }

    // False until the Maw is constructed and its surface motion is Ready on the ground; a failed surface motion fails the
    // test.
    protected bool Get_IsReady()
    {
        if (ck::Is_NOT_Valid(_Maw))
        { return false; }

        if (utils_surface_motion::Get_Status(_Maw.Get_Motion()) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the surface motion failed: {utils_surface_motion::Get_Failure(_Maw.Get_Motion()) :n}");
            return false;
        }

        return _Maw.Get_IsGrounded();
    }

    UFUNCTION()
    protected void OnMawConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Maw = InEntityScriptHandle.As_RootMaw();
    }

    UFUNCTION()
    protected void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsReady());
    }

    UFUNCTION()
    protected void Check_Emerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Maw.Get_IsEmerged());
    }
}
