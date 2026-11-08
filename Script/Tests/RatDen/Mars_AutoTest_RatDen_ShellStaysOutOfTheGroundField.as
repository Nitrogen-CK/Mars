// F4-3 (Phase 5): a den placed in a level with its DEFAULT shell (BlockAll, complex-as-simple, built here even headless)
// does not bake into the ground field. The court floor joins Jolt, the den's shell component is added (and its Automatic
// static-world bake has had its frames), THEN the field is built; afterwards: the shell still blocks (collision enabled,
// the BlockAll profile, the Ck.Jolt.NoBake tag), a Jolt static ray across both side walls of the arch hits nothing (the
// shell never entered the Jolt static world), and the provider answers a real route from every den marker (ExitPortal,
// EntryPortal, OutsideStand, ReturnAdmission, Inside) to a point 3 m in front of the den - the markers are on the field.
// Before the fix (Phase 4, court run01-02) the shell baked as open ground and the rat looped "refused a Home move ...
// provider [NoSurface]" at the portal stands.
class UMars_AutoTest_RatDen_ShellStaysOutOfTheGroundField : UMars_AutoTestRig_GroundNavBuildOutcome
{
    default _TimeoutSeconds = 45.0f;

    private const FVector k_DenOffset = FVector(-400.0, 0.0, 0.0);
    private FCk_Handle _DenEntity;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(736000.0, -200000.0, -60000.0);
        Arrange(InHandle);

        auto DenParams = UMars_RatDen_EntityScript::Params();
        DenParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + k_DenOffset);
        DenParams.Spec = FMars_RatDen_Spec(1);
        DenParams.BuildShellHeadless = true;
        _DenEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_RatDen_EntityScript, DenParams).Get_EntityUnderConstruction();
        _Owned.Add(_DenEntity);

        Add_Step_WaitUntil("the court floor joined Jolt", n"Check_FloorReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the den's default shell component exists", n"Check_ShellAdded", k_SlowPolls, 0);
        Add_Step_WaitFrames("the shell's add-time static-world bake had its frames", 3);
        Add_Step("request the field build with the den present", n"Step_Build");
        Add_Step_WaitUntil("the field build resolved", n"Check_Built", k_SlowPolls, 0);
        Add_Step("the shell blocks, is not in the Jolt static world, and every den marker is on the field", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private UStaticMeshComponent Get_ShellComponent() const
    {
        if (ck::Is_NOT_Valid(_DenEntity) || _DenEntity.Has_Fragment(FMars_Fragment_RatDen_Assembly) == false)
        { return nullptr; }

        auto Script = _DenEntity.Get_Fragment(FMars_Fragment_RatDen_Assembly).Script.Get();
        if (ck::Is_NOT_Valid(Script) || ck::Is_NOT_Valid(Script.Get_Shell()))
        { return nullptr; }

        return Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(Script.Get_Shell()));
    }

    UFUNCTION()
    private void Check_ShellAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(Get_ShellComponent()) && ck::IsValid(Get_ShellComponent().GetStaticMesh()));
    }

    UFUNCTION()
    private void Step_Build(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestBuild(1);
    }

    UFUNCTION()
    private void Check_Built(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(CountOutcome(1) == 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Outcome = FindOutcome(1);
        Assert_True(Outcome.Get_HasBakeStatus() && Outcome.Get_BakeStatus() == ECk_GroundNav_BakeStatus::Completed,
            "the field bake completed");

        auto Shell = Get_ShellComponent();
        Assert_True(ck::IsValid(Shell), "the den built its shell");
        if (ck::IsValid(Shell))
        {
            Assert_True(Shell.GetCollisionEnabled() != ECollisionEnabled::NoCollision, "the default shell still collides");
            Assert_True(Shell.GetCollisionProfileName() == collision::profile::BlockAll,
                f"the default shell profile is BlockAll (read [{Shell.GetCollisionProfileName()}])");
            Assert_True(Shell.ComponentHasTag(n"Ck.Jolt.NoBake"), "the shell carries Ck.Jolt.NoBake");
        }

        auto Den = _DenEntity.As_RatDen(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Den))
        {
            FinishFailure("the den did not compose");
            return;
        }

        // Across both side walls (the shell spans den-local y +-30..56) 20 cm up, 20 cm behind the front plane.
        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);
        const auto DenFrame = FTransform(FRotator::ZeroRotator, _Origin + k_DenOffset);
        const auto RayFrom = DenFrame.TransformPosition(FVector(-20.0, -80.0, 20.0));
        const auto RayTo = DenFrame.TransformPosition(FVector(-20.0, 80.0, 20.0));
        Assert_False(utils_jolt_query::Get_RayCast(RayFrom, RayTo, Filter).Get_HasHit(),
            "a Jolt static ray across the arch's side walls hits nothing (the shell is not in the static world)");

        auto Goal = DenFrame.TransformPosition(FVector(300.0, 0.0, 0.0));
        auto Markers = TArray<EMars_RatDen_Portal>();
        Markers.Add(EMars_RatDen_Portal::ExitPortal);
        Markers.Add(EMars_RatDen_Portal::EntryPortal);
        Markers.Add(EMars_RatDen_Portal::OutsideStand);
        Markers.Add(EMars_RatDen_Portal::ReturnAdmission);
        Markers.Add(EMars_RatDen_Portal::Inside);
        for (const auto Marker : Markers)
        {
            const auto Stand = Den.Get_PortalWorld(Marker);
            auto Query = FCk_NavSurface_PathQuery(Stand, FVector(Goal.X, Goal.Y, Stand.Z));
            Query.Set_AgentRadiusUu(utils_pantry_rat::k_AgentRadius);
            const auto Status = utils_nav_surface::Try_FindPathSync(Query).Get_Status();
            Assert_True(Status == ECk_NavSurface_QueryStatus::Success,
                f"{Marker :n} is on the field (provider [{Status :n}] to 3 m in front of the den)");
        }
    }
}
