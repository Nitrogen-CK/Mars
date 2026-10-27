// A MechanismSource on a flame's own entity follows the flame: deasserted while it is dark, asserted once it is lit,
// deasserted again once it is snuffed. Isolated origin: (12000, 0, -60000).
class UMars_AutoTest_Flame_ALitFlameAssertsItsOwnSource : UCk_AutoTest_Base
{
    private FCk_Handle_Flame _Flame;
    private FCk_Handle_MechanismSource _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, FVector(12000.0, 0.0, -60000.0)), ECk_Replication::DoesNotReplicate);

        _Flame = utils_flame::Add(Entity, FMars_Flame_Spec());

        auto SourceSpec = FMars_MechanismSource_Spec();
        SourceSpec.OutputChannel = Get_TestChannel();
        _Source = utils_mechanism_source::Add(Entity, SourceSpec);

        Add_Step_WaitFrames("let the flame's source pass run", 2);
        Add_Step("a dark flame's source is deasserted", n"Step_AssertDeasserted");
        Add_Step("light the flame", n"Step_Light");
        Add_Step_WaitUntil("its source asserts", n"Check_Asserted", 0, 0);
        Add_Step("snuff the flame", n"Step_Snuff");
        Add_Step_WaitUntil("its source deasserts", n"Check_Deasserted", 0, 0);
        Run_Steps(InHandle);
    }

    // By name: a tag added to the ini while the editor runs is registered only at its next start.
    private FGameplayTag Get_TestChannel() const
    {
        return FGameplayTag::RequestGameplayTag(n"Mechanism.Channel.Flame.Test");
    }

    UFUNCTION()
    private void Step_AssertDeasserted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Source), "the source composed on the flame's entity");
        Assert_False(_Flame.Get_IsLit(), "the flame starts dark");
        Assert_False(_Source.Get_IsAsserted(), "its source is deasserted");
    }

    UFUNCTION()
    private void Step_Light(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    private void Check_Asserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit() && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_Snuff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
    }

    UFUNCTION()
    private void Check_Deasserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit() == false && _Source.Get_IsAsserted() == false);
    }
}
