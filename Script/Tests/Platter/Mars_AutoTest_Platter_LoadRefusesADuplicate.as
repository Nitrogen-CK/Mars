// A platter refuses a piece it already holds. A platter with room for two holds a landed box P; P loaded onto it again is
// refused AlreadyHeld (OnLoadRefused names P), though the platter has room: the duplicate is refused for itself, not for
// space. P stays held once, and the platter's books are as they were.
class UMars_AutoTest_Platter_LoadRefusesADuplicate : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(151000.0, -70000.0, -30000.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;

    // The platter's books when P's second load is issued.
    private int32 _HeldBefore = 0;
    private int32 _PendingBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("load P onto the platter", n"Step_LoadP");
        Add_Step_WaitUntil("the platter answered P's load", n"Check_PAnswered", k_SlowPolls, 0);
        Add_Step("P landed and the platter has room; load P again", n"Step_LoadPAgain");
        Add_Step_WaitUntil("the platter answered P's second load", n"Check_SecondLoadAnswered", 0, 0);
        Add_Step("P is refused AlreadyHeld and the platter's books are unchanged", n"Step_AssertRefusedAlreadyHeld");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
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
    private void Step_LoadPAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(TryGet_Loaded(_P).IsSet(), "P landed on the platter");
        Assert_False(_Platter.Get_IsFull(), "the platter has room for another piece");

        _HeldBefore = _Platter.Get_HeldCount();
        _PendingBefore = _Platter.Get_PendingCount();
        Load(_Platter, _P);
    }

    // A refusal is never deferred: the drain answers the second load in the pass after it is issued.
    UFUNCTION()
    private void Check_SecondLoadAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AllRefusalCount(_Platter) > 0 || _Platter.Get_Occupancy() != _HeldBefore + _PendingBefore);
    }

    UFUNCTION()
    private void Step_AssertRefusedAlreadyHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Refusals = Get_RefusalsOf(_P);
        Assert_Equals_Int(Refusals.Num(), 1, "the platter answered P's second load with one refusal");
        if (Refusals.Num() == 1)
        { Assert_True(Refusals[0] == EMars_Platter_LoadRefusal::AlreadyHeld, f"P is refused AlreadyHeld (got {Refusals[0] :n})"); }

        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "the platter refused nothing but P's second load");
        Assert_Equals_Int(_Platter.Get_HeldCount(), _HeldBefore, "the platter holds what it held before the second load");
        Assert_True(_Platter.Get_Held().Contains(_P), "P is still held");
        Assert_Equals_Int(_Platter.Get_PendingCount(), _PendingBefore, "nothing new waits to drop");
        Assert_True(_P.TryGet_Platter() == _Platter, "P still carries the platter");
        Assert_Equals_Int(Get_LoadedCountOf(_P), 1, "P landed once");
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
