// Leaving mid-coat lifts the batch out of the batter and keeps it. A whole mushroom is carried into the bowl of the real
// batter station and dipped part way; the operator leaves: the station goes Idle, the bowl rests (the control layer's
// lift on exit), the mushroom stays in the bowl and its coat holds where the leave left it. The operator takes the station
// again, dips, and the coat completes from there. Isolated origin (196000, -76000, -30000).
class UMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch : UMars_AutoTestRig_BatterStation
{
    private const FVector k_Origin = FVector(196000.0, -76000.0, -30000.0);
    private const float32 k_PartialCoat = 0.3f;
    private const int32 k_IdleFrames = 20;

    private float32 _CoatAtLeave = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_All(InHandle, k_Origin, mars_items::Food_Mushroom());

        Add_Steps_DockedAndTaken();
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the bowl admitted the mushroom", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat is partial", n"Check_PartlyCoated", k_SlowPolls, 0);
        Add_Step("the operator leaves", n"Step_Leave");
        Add_Step_WaitUntil("the station is Idle and the bowl rests", n"Check_IdleAndResting", k_SlowPolls, 0);
        Add_Step_WaitUntil("the mushroom rose back to rest", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("record the coat the leave left", n"Step_Record");
        Add_Step_WaitFrames("nobody operates", k_IdleFrames);
        Add_Step("the batch and its coat are kept", n"Step_AssertKept");
        Add_Step("the operator takes the station again", n"Step_Take");
        Add_Step_WaitUntil("the station is Operated", n"Check_Operated", k_SlowPolls, 0);
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat completes", n"Check_Coated", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PartlyCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_PieceCount() == 1 && _Batter.Get_PieceCoat(Get_FirstId()) >= k_PartialCoat);
    }

    UFUNCTION()
    private void Check_IdleAndResting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsIdle() && _Batter.Get_Bowl() == EMars_Batter_Bowl::Resting);
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_PieceCount() == 1 && _Batter.Get_PieceImmersion(Get_FirstId()) <= 0.0f);
    }

    UFUNCTION()
    private void Step_Record(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CoatAtLeave = _Batter.Get_PieceCoat(Get_FirstId());
        Assert_True(_CoatAtLeave >= k_PartialCoat && _CoatAtLeave < 1.0f, f"the leave kept a partial coat ({_CoatAtLeave :.3})");
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Batter.Get_PieceCount(), 1, "the mushroom stays in the bowl");
        Assert_True(_Batter.Get_PieceHandle(Get_FirstId()) == _Food, "it is the mushroom");
        Assert_Equals_Float(_Batter.Get_PieceCoat(Get_FirstId()), _CoatAtLeave, 0.0, "its coat holds while nobody operates");
        FCk_Handle StationEntity = _Station;
        Assert_True(_Food.TryGet_Holder() == StationEntity, "the station still holds it");
    }
}
