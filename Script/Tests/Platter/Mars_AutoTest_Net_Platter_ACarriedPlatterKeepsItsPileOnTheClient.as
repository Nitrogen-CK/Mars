// The server loads a meat slab (step 1 once it froze), then carries the platter into the subject's hands (step 2 once it is
// Held). On the client the platter is Held by the subject on the client's own hand node, 60 cm from the server's, and for
// 1.5 s of frames the food's world pose is the reported offset under its own platter root and it rides throughout.
// Surface: Ck.Platter.Net.AS_Platter_ACarriedPlatterKeepsItsPileOnTheClient
class UCk_AutoTest_Net_Platter_ACarriedPlatterKeepsItsPileOnTheClient : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 232000.0;
    private const float32 k_SampleSeconds = 1.5f;

    private FCk_Handle _SampleOwner;
    private FCk_Handle _Food;
    private bool _IsSampling = false;
    private int32 _Samples = 0;
    private int32 _RideFaults = 0;
    private FString _FirstFault;
    private float64 _WorstCm = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _SampleOwner = InHandle;
        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(2); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Load_WhenReady(_Food, 1);
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
        End_PlatterServer(f"{Describe_Counts()} held={Get_HeldFault().IsEmpty()} onRoot={Get_IsOnPlatterRoot(_Food.As_FoodPiece())} {Describe_Signals()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto HeldFault = Get_HeldFault();
        Assert_True(HeldFault.IsEmpty(), f"the client's platter is Held by the subject on its own hand node ({HeldFault})");
        _IsSampling = true;
        Begin_Sampling(_SampleOwner);
        WaitSeconds(k_SampleSeconds, n"OnClientSampled");
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (_IsSampling == false)
        { return; }

        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        ++_Samples;
        const auto Fault = Get_RideFault(Piece, Slot);
        if (Fault.IsEmpty() == false)
        {
            if (_RideFaults == 0)
            { _FirstFault = Fault; }

            ++_RideFaults;
        }

        if (Get_IsLive(Piece))
        { _WorstCm = Math::Max(_WorstCm, Get_CarriedError(Piece, Slot)); }
    }

    UFUNCTION()
    private void OnClientSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _IsSampling = false;
        Assert_True(_Samples > 0, "the client sampled frames");
        Assert_Equals_Int(_RideFaults, 0, f"the food rides throughout (first fault: {_FirstFault})");
        Assert_True(_WorstCm <= k_CarriedToleranceCm, f"the food stays at the reported offset under its own platter root (worst {_WorstCm} cm)");
        End_PlatterClient(f"held=[{Get_HeldFault()}] samples={_Samples} rideFaults={_RideFaults} worstCm={_WorstCm} {Describe_Counts()} {Describe_Signals()}");
    }
}
