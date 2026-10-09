// A piece loaded in the step that builds it, still importing, is accepted and held pending (it counts against the capacity)
// and lands once Ready. A Ready piece loaded from where it stands starts there and eases into its slot: one frame after it
// landed it is still nearer its start, and once the arrival has run it rests at the slot with no Arrival left.
class UMars_AutoTest_Platter_PendingPieceLandsOnceReadyAndArrivalLerpsIn : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -14000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_FoodPiece _Q;
    private FVector _QStart;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 60.0, 0.0), k_Origin), Make_PlatterSpec(2, 0.3f));

        Add_Step("build P and load it at once", n"Step_BuildAndLoadP");
        Add_Step("the load was accepted, pending", n"Step_AssertPending");
        Add_Step_WaitUntil("P landed", n"Check_PLanded");
        Add_Step("P landed Ready; build Q", n"Step_AssertPLandedAndBuildQ");
        Add_Step_WaitUntil("Q is Ready", n"Check_QReady");
        Add_Step("load Q from where it stands", n"Step_LoadQ");
        Add_Step_WaitUntil("Q landed", n"Check_QLanded");
        Add_Step_WaitFrames("one frame of arrival", 1);
        Add_Step("Q is still nearer its start than its slot", n"Step_AssertArriving");
        Add_Step_WaitSeconds("the arrival runs out", 0.5f);
        Add_Step("Q rests at its slot with no Arrival left", n"Step_AssertArrived");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BuildAndLoadP(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        Assert_True(_P.Get_Status() == EMars_FoodPiece_Status::Pending, "P is still importing when it is loaded");
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Step_AssertPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "the load of an importing piece is not refused");
        if (TryGet_Loaded(_P).IsSet())
        {
            ck::Trace("[Platter test] P was Ready by the platter's first drain: it landed without waiting");
            return;
        }

        Assert_Equals_Int(_Platter.Get_PendingCount(), 1, "P is pending");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the pending P counts against the capacity");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the pending P has not landed");
        Assert_True(_P.TryGet_Platter() == _Platter, "the pending P carries the platter");
    }

    UFUNCTION()
    private void Check_PLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertPLandedAndBuildQ(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_True(_P.Get_Status() == EMars_FoodPiece_Status::Ready, "P landed Ready");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the platter holds P");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing is pending");

        _Q = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 0.0, 0.0)), 0.5);
    }

    UFUNCTION()
    private void Check_QReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Q));
    }

    UFUNCTION()
    private void Step_LoadQ(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto QWorld = Get_World(_Q);
        _QStart = QWorld.GetLocation();
        Load_From(_Platter, _Q, QWorld);
    }

    UFUNCTION()
    private void Check_QLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_Q).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertArriving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Now = Get_World(_Q).GetLocation();
        const auto Slot = Get_SlotWorld(_Platter, _Q, 1).GetLocation();
        Assert_True(Now.Distance(_QStart) < Now.Distance(Slot),
            f"one frame after landing Q is nearer its start than its slot ({Now.Distance(_QStart) :.2} vs {Now.Distance(Slot) :.2} cm)");
        Assert_True(_Q.Has_Fragment(FMars_Fragment_Platter_Arrival), "Q is arriving");
    }

    UFUNCTION()
    private void Step_AssertArrived(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Now = Get_World(_Q).GetLocation();
        const auto Slot = Get_SlotWorld(_Platter, _Q, 1).GetLocation();
        Assert_True(Now.Equals(Slot, 0.1), f"Q rests at slot 1 ({Now} vs {Slot})");
        Assert_False(_Q.Has_Fragment(FMars_Fragment_Platter_Arrival), "Q's arrival is over");
        Assert_True(Get_Parent(_Q) == Get_Root(_Platter), "Q is a scene node of the platter root");
    }
}
