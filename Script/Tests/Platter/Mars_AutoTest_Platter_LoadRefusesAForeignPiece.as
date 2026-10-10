// A platter refuses a piece another platter holds. Platter A holds a landed box P; P loaded onto platter B (with room) is
// refused HeldElsewhere by B (OnLoadRefused names P). P still carries A, A still holds it, and B's books are as they
// were: empty.
class UMars_AutoTest_Platter_LoadRefusesAForeignPiece : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(152000.0, -70000.0, -30000.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _PlatterA;
    private FCk_Handle_Platter _PlatterB;
    private FCk_Handle_FoodPiece _P;

    // A's books when P's load onto B is issued.
    private int32 _HeldBeforeA = 0;
    private int32 _PendingBeforeA = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _PlatterA = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _PlatterB = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 200.0, 0.0)), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("load P onto A", n"Step_LoadPOntoA");
        Add_Step_WaitUntil("A answered P's load", n"Check_AAnswered", k_SlowPolls, 0);
        Add_Step("P landed on A and B is empty; load P onto B", n"Step_LoadPOntoB");
        Add_Step_WaitUntil("B answered P's load", n"Check_BAnswered", 0, 0);
        Add_Step("B refuses P HeldElsewhere and neither platter's books changed", n"Step_AssertRefusedHeldElsewhere");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_LoadPOntoA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_PlatterA, _P);
    }

    // P froze into A's pile, or A refused it (the next step fails on that).
    UFUNCTION()
    private void Check_AAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_PlatterA) > 0);
    }

    UFUNCTION()
    private void Step_LoadPOntoB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(TryGet_Loaded(_P).IsSet() && TryGet_Loaded(_P).GetValue().Platter == _PlatterA, "P landed on A");
        Assert_Equals_Int(_PlatterB.Get_Occupancy(), 0, "B is empty");

        _HeldBeforeA = _PlatterA.Get_HeldCount();
        _PendingBeforeA = _PlatterA.Get_PendingCount();
        Load(_PlatterB, _P);
    }

    // A refusal is never deferred: B's drain answers it, or accepts P onto B's books.
    UFUNCTION()
    private void Check_BAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AllRefusalCount(_PlatterB) > 0 || _PlatterB.Get_Occupancy() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefusedHeldElsewhere(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Platter_LoadRefusal> Refusals;
        for (const auto& Event : _Refused)
        {
            if (Event.Platter == _PlatterB && Event.Piece == _P)
            { Refusals.Add(Event.Refusal); }
        }

        Assert_Equals_Int(Refusals.Num(), 1, "B answered P's load with one refusal");
        if (Refusals.Num() == 1)
        { Assert_True(Refusals[0] == EMars_Platter_LoadRefusal::HeldElsewhere, f"B refuses P HeldElsewhere (got {Refusals[0] :n})"); }

        Assert_Equals_Int(Get_AllRefusalCount(_PlatterB), 1, "B refused nothing but P");
        Assert_Equals_Int(Get_AllRefusalCount(_PlatterA), 0, "A refused nothing");
        Assert_Equals_Int(_PlatterB.Get_Occupancy(), 0, "B's books are still empty");
        Assert_Equals_Int(Get_LoadedCount(_PlatterB), 0, "nothing landed on B");
        Assert_True(_P.TryGet_Platter() == _PlatterA, "P still carries A");
        Assert_Equals_Int(_PlatterA.Get_HeldCount(), _HeldBeforeA, "A holds what it held before");
        Assert_True(_PlatterA.Get_Held().Contains(_P), "A still holds P");
        Assert_Equals_Int(_PlatterA.Get_PendingCount(), _PendingBeforeA, "nothing new waits to drop on A");
    }
}
