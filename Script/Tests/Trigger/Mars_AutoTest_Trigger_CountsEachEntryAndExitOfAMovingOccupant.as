// A trigger tracks a kinematic Probe.Mars.Player occupant moved in and out twice: OnEntityEntered and OnEntityExited each
// fire once per crossing with the occupant's probe entity, the inside list holds it only while it is inside, and a probe
// the filter does not name (Probe.Mars.Backpack) never enters.
class UMars_AutoTest_Trigger_CountsEachEntryAndExitOfAMovingOccupant : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the trigger sees occupants through physics overlaps.
    private const int32 k_SlowPolls = 900;
    private const FVector k_Origin = FVector(52000.0, 330000.0, -41000.0);

    private FCk_Handle_Trigger _Trigger;
    private FCk_Handle_Transform _Occupant;
    private FCk_Handle_Transform _Stranger;
    private TArray<FCk_Handle> _Entered;
    private TArray<FCk_Handle> _Exited;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Trigger_Spec();
        Spec.Shape = EMars_Trigger_Shape::Sphere;
        Spec.SphereRadius = 150.0f;
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        _Trigger = utils_trigger::Add(Root, Spec);
        _Trigger.BindTo_OnEntityEntered(FMars_Delegate_Trigger_OnEntityEntered(this, n"OnEntered"));
        _Trigger.BindTo_OnEntityExited(FMars_Delegate_Trigger_OnEntityExited(this, n"OnExited"));

        _Occupant = MakeOccupant(InHandle, GameplayTags::Probe_Mars_Player, k_Origin + FVector(1000.0, 0.0, 0.0));
        _Stranger = MakeOccupant(InHandle, GameplayTags::Probe_Mars_Backpack, k_Origin + FVector(-1000.0, 0.0, 0.0));

        Add_Step("the occupant and the stranger move in", n"Step_In");
        Add_Step_WaitUntil("the occupant entered once", n"Check_EnteredOnce", k_SlowPolls, 0);
        Add_Step("inside: the occupant only", n"Step_AssertInside");
        Add_Step("the occupant moves out", n"Step_Out");
        Add_Step_WaitUntil("the occupant exited once", n"Check_ExitedOnce", k_SlowPolls, 0);
        Add_Step("the occupant moves in again", n"Step_OccupantIn");
        Add_Step_WaitUntil("it entered a second time", n"Check_EnteredTwice", k_SlowPolls, 0);
        Add_Step("the occupant moves out again", n"Step_Out");
        Add_Step_WaitUntil("it exited a second time", n"Check_ExitedTwice", k_SlowPolls, 0);
        Add_Step("two of each, all naming the occupant, nothing inside", n"Step_AssertCounts");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_In(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(k_Origin));
        utils_transform::Request_SetLocation(_Stranger, FCk_Request_Transform_SetLocation(k_Origin + FVector(0.0, 40.0, 0.0)));
    }

    UFUNCTION()
    private void Step_OccupantIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(k_Origin));
    }

    UFUNCTION()
    private void Step_Out(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(k_Origin + FVector(1000.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_EnteredOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Entered.Num() == 1);
    }

    UFUNCTION()
    private void Step_AssertInside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Trigger.Get_EntityCount(), 1, "one entity inside: the stranger's probe is filtered out");
        const auto Inside = _Trigger.Get_EntitiesInside();
        Assert_True(Inside.Num() == 1 && Inside[0] == _Entered[0], "the inside list holds the entity that entered");
    }

    UFUNCTION()
    private void Check_ExitedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Exited.Num() == 1 && _Trigger.Get_EntityCount() == 0);
    }

    UFUNCTION()
    private void Check_EnteredTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Entered.Num() == 2 && _Trigger.Get_EntityCount() == 1);
    }

    UFUNCTION()
    private void Check_ExitedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Exited.Num() == 2);
    }

    UFUNCTION()
    private void Step_AssertCounts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Entered.Num(), 2, "two entries");
        Assert_Equals_Int(_Exited.Num(), 2, "two exits");
        Assert_True(_Entered[0] == _Entered[1] && _Exited[0] == _Entered[0] && _Exited[1] == _Entered[0], "every signal names the occupant's probe");
        Assert_Equals_Int(_Trigger.Get_EntityCount(), 0, "nothing inside");
    }

    // Its own owner and context, so the trigger may overlap it.
    private FCk_Handle_Transform MakeOccupant(FCk_Handle InHandle, FGameplayTag InProbeName, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(InProbeName);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 30.0f, ProbeSpec);
        return Root;
    }

    UFUNCTION()
    private void OnEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        _Entered.Add(InEntity);
    }

    UFUNCTION()
    private void OnExited(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        _Exited.Add(InEntity);
    }
}
