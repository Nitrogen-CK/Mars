// The server loads a meat slab (step 1 once it froze), then a mushroom (step 2). On the client the platter reads one held
// and one on its books and one kind container holding Food.Meat at step 1; two of each and a second container holding
// Food.Vegetable at step 2, whole, with capacity minus two free.
// Surface: Ck.Platter.Net.AS_Platter_TheCountsAndKindsReachTheClient
class UCk_AutoTest_Net_Platter_TheCountsAndKindsReachTheClient : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 231000.0;

    private FCk_Handle _Slab;
    private FCk_Handle _Mushroom;
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
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        _Mushroom = Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        ++_ServerStep;
        Publish_Rides(_ServerStep);
        if (_ServerStep == 1)
        {
            WaitSeconds(k_StepSeconds, n"OnServerLoadMushroom");
            return;
        }

        End_PlatterServer(f"{Describe_Counts()} kinds={_Platter.Get_PieceKinds().Num()} {Describe_Signals()}");
    }

    UFUNCTION()
    private void OnServerLoadMushroom(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Load_WhenReady(_Mushroom, 2);
    }

    protected FString Describe_Kinds()
    {
        auto Text = FString();
        for (const auto& Kind : _Platter.Get_PieceKinds())
        {
            const auto IsMeat = Kind.HasTag(GameplayTags::Food_Meat);
            const auto IsVegetable = Kind.HasTag(GameplayTags::Food_Vegetable);
            Text += f"[tags={Kind.Num()} meat={IsMeat} vegetable={IsVegetable}] ";
        }

        return Text;
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Kinds = _Platter.Get_PieceKinds();
        if (InStep == 1)
        {
            Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "step 1: the client's platter reads one held");
            Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "step 1: the client's platter reads one on its books");
            Assert_Equals_Int(Kinds.Num(), 1, "step 1: one kind container");
            Assert_True(Kinds.Num() == 1 && Kinds[0].HasTag(GameplayTags::Food_Meat), "step 1: the container holds Food.Meat");
            _StepOneText = f"step1 {Describe_Counts()} kinds={Describe_Kinds()}";
            Await_Step(2);
            return;
        }

        Assert_Equals_Int(_Platter.Get_HeldCount(), 2, "step 2: the client's platter reads two held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 2, "step 2: the client's platter reads two on its books");
        Assert_Equals_Int(Kinds.Num(), 2, "step 2: two kind containers");
        Assert_True(Kinds.Num() == 2 && Kinds[1].HasTag(GameplayTags::Food_Vegetable), "step 2: the second container holds Food.Vegetable");
        Assert_True(_Platter.Get_IsWhole(), "step 2: the client's platter reads whole");
        Assert_Equals_Int(_Platter.Get_FreeCount(), _Platter.Get_Capacity() - 2, "step 2: capacity minus two free");
        End_PlatterClient(f"{_StepOneText} step2 {Describe_Counts()} kinds={Describe_Kinds()} whole={_Platter.Get_IsWhole()} free={_Platter.Get_FreeCount()}/{_Platter.Get_Capacity()} {Describe_Signals()}");
    }
}
