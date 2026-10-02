// A chop with the hand just outside the band resolves not aligned: no useful chop, the pile and the band stay put. Rig as
// AlignedChopsAdvanceStateAndMoveBand; the hand is nudged to BandCenter + BandHalfWidth + 5.
class UMars_AutoTest_Dicing_OffTargetChopDoesNotAdvance : UCk_AutoTest_Base
{
    private FCk_Handle_Dicing _Dicing;
    private FMars_Dicing_Spec _Spec;

    private float32 _BandBefore = 0.0f;
    private float32 _HandTarget = 0.0f;
    private TArray<bool> _Resolved;
    private TArray<EMars_Dicing_State> _States;
    private TArray<float32> _BandMoves;

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
        _Dicing.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _Dicing.BindTo_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));

        Add_Step("nudge the hand just past the band edge", n"Step_AimOffBand");
        Add_Step_WaitUntil("the hand is off the band", n"Check_HandAtTarget", 0, 2.0f);
        Add_Step("chop", n"Step_Chop");
        Add_Step_WaitUntil("the chop resolved and the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        Add_Step("the chop was not aligned and nothing advanced", n"Step_AssertNothingAdvanced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, bool InAligned)
    {
        _Resolved.Add(InAligned);
    }

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState)
    {
        _States.Add(InState);
    }

    UFUNCTION()
    private void OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter)
    {
        _BandMoves.Add(InCenter);
    }

    UFUNCTION()
    private void Step_AimOffBand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Dicing), "the feature composed");
        _BandBefore = _Dicing.Get_BandCenter();
        _HandTarget = _BandBefore + _Spec.BandHalfWidth + 5.0f;
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge((_HandTarget - _Dicing.Get_HandLateral()) / _Spec.LateralPerDegree));
    }

    UFUNCTION()
    private void Check_HandAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - _HandTarget) < 0.01f);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Dicing.Get_IsAligned(), "the hand is outside the band before the chop");
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolved.Num() > 0 && _Dicing.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_AssertNothingAdvanced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resolved.Num(), 1, "OnChopResolved fired once");
        if (_Resolved.Num() > 0)
        { Assert_False(_Resolved[0], "the chop resolved not aligned"); }

        Assert_Equals_Int(_States.Num(), 0, "OnStateChanged did not fire");
        Assert_True(_Dicing.Get_MaterialState() == EMars_Dicing_State::WholeLeaves, "the pile is still whole leaves");
        Assert_Equals_Int(_Dicing.Get_UsefulChops(), 0, "no useful chop");
        Assert_Equals_Int(_Dicing.Get_ChopsInState(), 0, "no chop counted toward the next state");
        Assert_Equals_Int(_BandMoves.Num(), 0, "OnBandMoved did not fire");
        Assert_Equals_Float(_Dicing.Get_BandCenter(), _BandBefore, 0.001, "the band stayed put");
    }
}
