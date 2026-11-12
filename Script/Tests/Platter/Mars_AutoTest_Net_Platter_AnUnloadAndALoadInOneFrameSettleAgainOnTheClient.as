// The server loads a meat slab (step 1 once it froze), then in one frame unloads and loads it again; once it froze a second
// time (a second OnLoaded) it reports step 2, having raised OnUnloaded once, OnLoadAccepted twice and OnLoaded twice. On
// the client the food rides at step 1's offset at step 1 and at step 2's at step 2, and in no sampled frame between is it
// a child of its platter's root while its ledger says it does not ride.
// Surface: Ck.Platter.Net.AS_Platter_AnUnloadAndALoadInOneFrameSettleAgainOnTheClient
class UCk_AutoTest_Net_Platter_AnUnloadAndALoadInOneFrameSettleAgainOnTheClient : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 235000.0;

    private FCk_Handle _Food;
    private int32 _ServerStep = 0;
    // Client: sampled frames, from step 1, in which the ledger said the food does not ride, and of those the ones in which
    // it was a child of its platter's root.
    private int32 _LooseFrames = 0;
    private int32 _BrokenFrames = 0;
    private FString _StepOneText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            Await_Step(1);
        }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Load_WhenReady(_Food, 1);
    }

    protected void On_ServerFrozen() override
    {
        ++_ServerStep;
        Publish_Rides(_ServerStep);
        if (_ServerStep == 1)
        {
            WaitSeconds(k_StepSeconds, n"OnServerReload");
            return;
        }

        Assert_Equals_Int(_Unloaded, 1, "the server raised OnUnloaded once");
        Assert_Equals_Int(_Accepted, 2, "the server raised OnLoadAccepted twice");
        Assert_Equals_Int(_Loaded, 2, "the server raised OnLoaded twice");
        End_PlatterServer(f"{Describe_Counts()} {Describe_Signals()}");
    }

    UFUNCTION()
    private void OnServerReload(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Piece = _Food.As_FoodPiece();
        _Platter.Request_Unload(FMars_Request_Platter_Unload(Piece));
        _Platter.Request_Load(FMars_Request_Platter_Load(Piece));
        Await_Frozen(1, 2);
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (Get_PlatterReport().Step < 1 || ck::Is_NOT_Valid(_Platter))
        { return; }

        const auto Piece = Find_PieceById(Get_PlatterReport().Slot0.Id);
        if (Get_IsLive(Piece) == false || Piece.TryGet_ReplicatedRide().IsSet())
        { return; }

        ++_LooseFrames;
        if (Get_IsOnPlatterRoot(Piece))
        { ++_BrokenFrames; }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        Assert_True(Fault.IsEmpty(), f"step {InStep}: the client's food rides at the step's offset ({Fault})");
        const auto Text = f"step{InStep} rides=[{Fault}] offset={Slot.RideLocation} errorCm={_RideErrorCm}";
        if (InStep == 1)
        {
            _StepOneText = Text;
            Await_Step(2);
            return;
        }

        Assert_Equals_Int(_BrokenFrames, 0, f"no sampled frame shows the food on its platter's root while its ledger says it does not ride ({_LooseFrames} loose frames)");
        End_PlatterClient(f"{_StepOneText} {Text} looseFrames={_LooseFrames} brokenFrames={_BrokenFrames} {Describe_Counts()} {Describe_Signals()}");
    }
}
