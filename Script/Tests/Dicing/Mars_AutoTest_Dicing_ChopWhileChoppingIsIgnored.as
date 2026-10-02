// One press = one chop: two chop requests in the same step resolve exactly one chop. Rig as
// AlignedChopsAdvanceStateAndMoveBand; the hand is on the band, then the run settles a few frames past the strike so a
// late second resolution would be seen.
class UMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored : UCk_AutoTest_Base
{
    private FCk_Handle_Dicing _Dicing;
    private FMars_Dicing_Spec _Spec;

    private TArray<bool> _Resolved;
    private int32 _SettleFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Spec = FMars_Dicing_Spec();

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto LateralNode = utils_scene_node::Create(Root, FTransform::Identity);
        auto LateralTransform = LateralNode.As_Transform();
        auto CleaverNode = utils_scene_node::Create(LateralTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 25.0)));

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, 25.0);
        MoverSpec.EndLocation = FVector::ZeroVector;
        MoverSpec.Duration = 0.05f;
        auto Mover = utils_mover::Add(CleaverNode, MoverSpec);

        _Dicing = utils_dicing::Add(StationEntity, _Spec, FMars_Dicing_Nodes(LateralNode, Mover));

        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));

        Add_Step("nudge the hand onto the band", n"Step_AimAtBand");
        Add_Step_WaitUntil("the hand is on the band", n"Check_HandOnBand", 0, 2.0f);
        Add_Step("chop twice in one step", n"Step_ChopTwice");
        Add_Step_WaitUntil("the chop resolved and the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        Add_Step_WaitUntil("a few more frames pass", n"Check_Settled", 0, 2.0f);
        Add_Step("exactly one chop resolved", n"Step_AssertOneChop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, bool InAligned)
    {
        _Resolved.Add(InAligned);
    }

    UFUNCTION()
    private void Step_AimAtBand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Dicing), "the feature composed");
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge((_Dicing.Get_BandCenter() - _Dicing.Get_HandLateral()) / _Spec.LateralPerDegree));
    }

    UFUNCTION()
    private void Check_HandOnBand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - _Dicing.Get_BandCenter()) < 0.01f);
    }

    UFUNCTION()
    private void Step_ChopTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolved.Num() > 0 && _Dicing.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _SettleFrames += 1;
        auto Res = OutResult;
        Res.Set(_SettleFrames >= 10);
    }

    UFUNCTION()
    private void Step_AssertOneChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resolved.Num(), 1, "exactly one OnChopResolved for two same-step chop requests");
        Assert_Equals_Int(_Dicing.Get_UsefulChops(), 1, "exactly one useful chop counted");
        Assert_False(_Dicing.Get_IsChopping(), "the cleaver is back up");
    }
}
