// Load refuses, without deferring, a piece the platter already holds (AlreadyHeld), one past its capacity (Full), one another
// platter holds (HeldElsewhere) and one with a cut in flight (Cutting); a refused piece carries no platter. The cut and the
// load of the cutting piece are requested together: when the piece drains its cut first the load is refused Cutting; when
// the platter drains first the piece is accepted, and its cut then replaces it with halves no platter holds.
class UMars_AutoTest_Platter_LoadRefusesFullDuplicateForeignAndCutting : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -10000.0, -30000.0);

    private FCk_Handle_Platter _PlatterA;
    private FCk_Handle_Platter _PlatterB;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_FoodPiece _Q;
    private FCk_Handle_FoodPiece _R;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _PlatterA = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(1, 0.0f));
        _PlatterB = Build_Platter(InHandle, FTransform(FRotator(0.0, 45.0, 0.0), k_Origin + FVector(0.0, 200.0, 0.0)), Make_PlatterSpec(1, 0.0f));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        _Q = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 50.0, 0.0)), 0.5);
        _R = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 100.0, 0.0)), 0.5);

        Add_Step_WaitUntil("the boxes are Ready", n"Check_Ready");
        Add_Step("load P onto A", n"Step_LoadP");
        Add_Step_WaitUntil("P landed on A", n"Check_PLanded");
        Add_Step("load P onto A again, Q onto A, P onto B", n"Step_LoadRefused");
        Add_Step_WaitUntil("the three loads were answered", n"Check_ThreeRefused");
        Add_Step("cut R and load it onto B together", n"Step_CutAndLoadR");
        Add_Step_WaitUntil("R's cut and its load are both answered", n"Check_RAnswered");
        Add_Step_WaitFrames("a late landing or refusal would show here", 3);
        Add_Step("the refusals, the ledgers and the memberships", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P) && Get_HasReadied(_Q) && Get_HasReadied(_R));
    }

    UFUNCTION()
    private void Step_LoadP(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_PlatterA, _P);
    }

    UFUNCTION()
    private void Check_PLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_PlatterA) > 0);
    }

    UFUNCTION()
    private void Step_LoadRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_PlatterA, _P);
        Load(_PlatterA, _Q);
        Load(_PlatterB, _P);
    }

    UFUNCTION()
    private void Check_ThreeRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AllRefusalCount(_PlatterA) + Get_AllRefusalCount(_PlatterB) >= 3);
    }

    UFUNCTION()
    private void Step_CutAndLoadR(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cut(_R, Get_BoundsCenter(_R), FVector::ForwardVector);
        Load(_PlatterB, _R);
    }

    // Settles once R's cut resolved and the platter answered its load: a refusal, a landing, or a pending load dropped when
    // the cut destroyed R.
    UFUNCTION()
    private void Check_RAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto IsCutResolved = _Cuts.Num() > 0;
        const auto IsLoadAnswered = Get_AllRefusalCount(_PlatterB) > 1 || TryGet_Loaded(_R).IsSet() || _PlatterB.Get_PendingCount() == 0;
        Res.Set(IsCutResolved && IsLoadAnswered);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(TryGet_Loaded(_P).IsSet(), "P landed on A");
        Assert_Equals_Int(Get_RefusalCount(_PlatterA, EMars_Platter_LoadRefusal::AlreadyHeld), 1, "P loaded onto A again is refused AlreadyHeld");
        Assert_Equals_Int(Get_RefusalCount(_PlatterA, EMars_Platter_LoadRefusal::Full), 1, "Q loaded onto a full A is refused Full");
        Assert_Equals_Int(Get_AllRefusalCount(_PlatterA), 2, "A refused exactly two loads");
        Assert_Equals_Int(Get_RefusalCount(_PlatterB, EMars_Platter_LoadRefusal::HeldElsewhere), 1, "P loaded onto B is refused HeldElsewhere");

        Assert_True(_P.TryGet_Platter() == _PlatterA, "P carries A");
        Assert_True(ck::Is_NOT_Valid(_Q.TryGet_Platter()), "the refused Q carries no platter");
        Assert_Equals_Int(_PlatterA.Get_HeldCount(), 1, "A holds only P");

        Assert_Equals_Int(_Cuts.Num(), 1, "R's cut resolved once");
        const auto IsCut = _Cuts.Num() == 1 && _Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut;
        Assert_True(IsCut, "R was cut");

        if (Get_RefusalCount(_PlatterB, EMars_Platter_LoadRefusal::Cutting) == 1)
        {
            ck::Trace("[Platter test] R's cut drained before its load: refused Cutting");
            Assert_Equals_Int(Get_AllRefusalCount(_PlatterB), 2, "B refused exactly P and R");
            Assert_False(TryGet_Loaded(_R).IsSet(), "the refused R never landed");
        }
        else
        {
            ck::Trace(f"[Platter test] R's load drained before its cut: accepted, landed: {TryGet_Loaded(_R).IsSet()}");
            Assert_Equals_Int(Get_AllRefusalCount(_PlatterB), 1, "B refused only P");
        }

        Assert_Equals_Int(_PlatterB.Get_PendingCount(), 0, "B waits on nothing");
        for (const auto& Piece : _PlatterB.Get_Slots())
        { Assert_True(ck::Is_NOT_Valid(Piece) || Get_IsEnding(Piece), "B holds nothing live: R was replaced by its halves"); }
        if (IsCut)
        {
            Assert_True(ck::Is_NOT_Valid(_Cuts[0].Positive.TryGet_Platter()) && ck::Is_NOT_Valid(_Cuts[0].Negative.TryGet_Platter()),
                "R's halves are born on no platter");
        }
    }
}
