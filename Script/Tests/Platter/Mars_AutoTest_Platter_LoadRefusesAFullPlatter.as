// A full platter refuses the next load at the drain. A platter of one holds a landed box P; a second box Q loaded onto it is
// refused Full (OnLoadRefused names Q), Q carries no platter, and the platter's books are as they were: P held, nothing
// pending.
class UMars_AutoTest_Platter_LoadRefusesAFullPlatter : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(150000.0, -70000.0, -30000.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_FoodPiece _Q;

    // The platter's books when Q's load is issued.
    private int32 _HeldBefore = 0;
    private int32 _PendingBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(1));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        _Q = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 50.0, 0.0)), 0.5);

        Add_Step_WaitUntil("the boxes are Ready", n"Check_Ready", 0, 0);
        Add_Step("load P onto the platter of one", n"Step_LoadP");
        Add_Step_WaitUntil("the platter answered P's load", n"Check_PAnswered", k_SlowPolls, 0);
        Add_Step("P landed and the platter is full; load Q", n"Step_LoadQ");
        Add_Step_WaitUntil("the platter answered Q's load", n"Check_QAnswered", 0, 0);
        Add_Step("Q is refused Full and the platter's books are unchanged", n"Step_AssertRefusedFull");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P) && Get_HasReadied(_Q));
    }

    UFUNCTION()
    private void Step_LoadP(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _P);
    }

    // P froze into the pile, or the platter refused it (the next step fails on that).
    UFUNCTION()
    private void Check_PAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_LoadQ(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(TryGet_Loaded(_P).IsSet(), "P landed on the platter");
        Assert_True(_Platter.Get_IsFull(), "the platter of one is full with P");

        _HeldBefore = _Platter.Get_HeldCount();
        _PendingBefore = _Platter.Get_PendingCount();
        Load(_Platter, _Q);
    }

    // A refusal is never deferred: the drain answers it, or accepts Q onto the books.
    UFUNCTION()
    private void Check_QAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_RefusalsOf(_Q).Num() > 0 || ck::IsValid(_Q.TryGet_Platter()));
    }

    UFUNCTION()
    private void Step_AssertRefusedFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Refusals = Get_RefusalsOf(_Q);
        Assert_Equals_Int(Refusals.Num(), 1, "the platter answered Q's load with one refusal");
        if (Refusals.Num() == 1)
        { Assert_True(Refusals[0] == EMars_Platter_LoadRefusal::Full, f"Q is refused Full (got {Refusals[0] :n})"); }

        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "the platter refused nothing but Q");
        Assert_True(ck::Is_NOT_Valid(_Q.TryGet_Platter()), "the refused Q carries no platter");
        Assert_Equals_Int(_Platter.Get_HeldCount(), _HeldBefore, "the platter holds what it held before Q's load");
        Assert_True(_Platter.Get_Held().Contains(_P), "P is still held");
        Assert_Equals_Int(_Platter.Get_PendingCount(), _PendingBefore, "nothing new waits to drop");
        Assert_True(_P.TryGet_Platter() == _Platter, "P still carries the platter");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 1, "only P ever landed");
    }

    // InPiece's refusals by the platter, in order.
    private TArray<EMars_Platter_LoadRefusal> Get_RefusalsOf(FCk_Handle_FoodPiece InPiece) const
    {
        TArray<EMars_Platter_LoadRefusal> Refusals;
        for (const auto& Event : _Refused)
        {
            if (Event.Platter == _Platter && Event.Piece == InPiece)
            { Refusals.Add(Event.Refusal); }
        }

        return Refusals;
    }
}
