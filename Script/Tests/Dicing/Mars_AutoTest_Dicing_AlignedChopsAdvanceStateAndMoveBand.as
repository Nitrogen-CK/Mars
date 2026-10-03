// ChopsPerState aligned chops advance the pile one state, and the band steps through the band table after each useful
// chop. Before each chop the hand is nudged onto the band, which moved after the previous chop.
class UMars_AutoTest_Dicing_AlignedChopsAdvanceStateAndMoveBand : UCk_AutoTest_Base
{
    private FCk_Handle_Dicing _Dicing;
    private FMars_Dicing_Spec _Spec;

    private int32 _ChopsIssued = 0;
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

        _Spec.Nodes = FMars_Dicing_Nodes(LateralNode, Mover);
        _Dicing = utils_dicing::Add(StationEntity, _Spec);

        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
        _Dicing.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _Dicing.BindTo_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));

        Add_Step("the feature composed with the band on table entry 0", n"Step_AssertComposed");
        for (int32 Index = 0; Index < _Spec.ChopsPerState; ++Index)
        {
            Add_Step("nudge the hand onto the band", n"Step_AimAtBand");
            Add_Step_WaitUntil("the hand is on the band", n"Check_HandOnBand", 0, 2.0f);
            Add_Step("chop", n"Step_Chop");
            Add_Step_WaitUntil("the chop resolved and the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        }
        Add_Step("the pile advanced one state and the band followed the table", n"Step_AssertAdvanced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        _Resolved.Add(InResult == EMars_Dicing_ChopResult::Aligned);
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
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Dicing), "the feature composed");
        const auto MaterialState = _Dicing.Get_MaterialState();
        Assert_True(MaterialState == EMars_Dicing_State::WholeLeaves, f"the pile starts as whole leaves (got {MaterialState :n})");
        Assert_Equals_Float(_Dicing.Get_BandCenter(), utils_dicing::Get_BandCenterAt(_Spec, 0), 0.001, "the band starts on table entry 0");
        Assert_Equals_Float(_Dicing.Get_HandLateral(), 0.0, 0.001, "the hand starts at the board centre");
    }

    UFUNCTION()
    private void Step_AimAtBand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Degrees = (_Dicing.Get_BandCenter() - _Dicing.Get_HandLateral()) / _Spec.LateralPerDegree;
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge(Degrees));
    }

    UFUNCTION()
    private void Check_HandOnBand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - _Dicing.Get_BandCenter()) < 0.01f);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Dicing.Get_IsAligned(), f"the hand is aligned before chop {_ChopsIssued + 1}");
        _ChopsIssued += 1;
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolved.Num() == _ChopsIssued && _Dicing.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_AssertAdvanced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resolved.Num(), _Spec.ChopsPerState, "one OnChopResolved per chop");
        for (int32 Index = 0; Index < _Resolved.Num(); ++Index)
        { Assert_True(_Resolved[Index], f"chop {Index + 1} resolved aligned"); }

        Assert_Equals_Int(_States.Num(), 1, "OnStateChanged fired once");
        if (_States.Num() > 0)
        { Assert_True(_States[0] == EMars_Dicing_State::CoarseChop, f"the pile became coarse chop (got {_States[0] :n})"); }

        const auto MaterialState = _Dicing.Get_MaterialState();
        Assert_True(MaterialState == EMars_Dicing_State::CoarseChop, f"the pile reads coarse chop (got {MaterialState :n})");
        Assert_Equals_Int(_Dicing.Get_UsefulChops(), _Spec.ChopsPerState, "every chop was useful");
        Assert_Equals_Int(_Dicing.Get_ChopsInState(), 0, "the chop count restarted in the new state");

        Assert_Equals_Int(_BandMoves.Num(), _Spec.ChopsPerState, "the band moved after every useful chop");
        for (int32 Index = 0; Index < _BandMoves.Num(); ++Index)
        {
            Assert_Equals_Float(_BandMoves[Index], utils_dicing::Get_BandCenterAt(_Spec, Index + 1), 0.001,
                f"band move {Index + 1} landed on table entry {Index + 1}");
        }

        Assert_Equals_Float(_Dicing.Get_BandCenter(), utils_dicing::Get_BandCenterAt(_Spec, _Spec.ChopsPerState), 0.001,
            "the band sits on the table entry after the last chop");
    }
}
