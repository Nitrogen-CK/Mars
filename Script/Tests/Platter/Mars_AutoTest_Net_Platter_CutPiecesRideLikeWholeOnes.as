// The server cuts a meat slab lying beside a platter once through its centre and loads both halves; once both froze it
// reports step 1, then carries the platter into the subject's hands (step 2 once it is Held). On the client at step 1 two
// standing pieces ride at the report, the platter reads two held and two on its books and not whole; at step 2 the
// platter is Held by the subject and both halves keep their reported offsets under its own platter root.
// Surface: Ck.Platter.Net.AS_Platter_CutPiecesRideLikeWholeOnes
class UCk_AutoTest_Net_Platter_CutPiecesRideLikeWholeOnes : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 239000.0;

    private int32 _ServerStep = 0;
    private FString _StepOneText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Rock = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        WaitUntil(n"Is_ServerSlabReady", n"OnServerSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Rock));
    }

    UFUNCTION()
    private void OnServerSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the slab was cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            End_PlatterServer("not cut");
            return;
        }

        _Platter.Request_Load(FMars_Request_Platter_Load(Result.Positive));
        _Platter.Request_Load(FMars_Request_Platter_Load(Result.Negative));
        Await_Frozen(2, 2);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitSeconds(k_StepSeconds, n"OnServerCarry");
    }

    UFUNCTION()
    private void OnServerCarry(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Carry_Platter();
    }

    protected void On_ServerPlatterHeld() override
    {
        Publish_Rides(2);
        End_PlatterServer(f"{Describe_Counts()} whole={_Platter.Get_IsWhole()} held={Get_HeldFault().IsEmpty()} {Describe_Signals()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_PlatterReport();
        if (InStep == 1)
        {
            Assert_Equals_Int(Report.Count, 2, "step 1 reports two frozen pieces");
            auto Text = FString();
            for (int32 Index = 0; Index < Report.Count; ++Index)
            {
                const auto Slot = Get_Slot(Report, Index);
                const auto Piece = Find_PieceById(Slot.Id);
                const auto Fault = Get_RideFault(Piece, Slot);
                FCk_Handle Entity = Piece;
                Assert_True(Get_Stands(Entity), f"step 1: piece {Index} stands on the client");
                Assert_True(Fault.IsEmpty(), f"step 1: piece {Index} rides at the report ({Fault})");
                Text += f"piece{Index}=[{Fault}] errorCm={_RideErrorCm} ";
            }

            Assert_Equals_Int(_Platter.Get_HeldCount(), 2, "step 1: the client's platter reads two held");
            Assert_Equals_Int(_Platter.Get_Occupancy(), 2, "step 1: the client's platter reads two on its books");
            Assert_True(_Platter.Get_IsWhole() == false, "step 1: the client's platter reads not whole");
            _StepOneText = f"step1 {Text}{Describe_Counts()} whole={_Platter.Get_IsWhole()}";
            Await_Step(2);
            return;
        }

        const auto HeldFault = Get_HeldFault();
        Assert_True(HeldFault.IsEmpty(), f"step 2: the client's platter is Held by the subject on its own hand node ({HeldFault})");
        auto WorstCm = 0.0;
        for (int32 Index = 0; Index < Report.Count; ++Index)
        {
            const auto Slot = Get_Slot(Report, Index);
            const auto Piece = Find_PieceById(Slot.Id);
            Assert_True(Get_IsLive(Piece), f"step 2: the client finds piece {Index}");
            if (Get_IsLive(Piece))
            { WorstCm = Math::Max(WorstCm, Get_CarriedError(Piece, Slot)); }
        }

        Assert_True(WorstCm <= k_CarriedToleranceCm, f"step 2: both pieces keep their reported offsets under the client's platter root (worst {WorstCm} cm)");
        End_PlatterClient(f"{_StepOneText} step2 held=[{HeldFault}] worstCm={WorstCm} {Describe_Counts()} {Describe_Signals()}");
    }
}
