// A dock's policy judges every piece a platter holds, not only the frozen pile: a piece queued or still settling is on the
// platter. A box (no kind) is loaded onto an empty platter; in the first frame it is the platter's (queued: held 0, pending
// 1, not yet dropped), an Output dock (which takes only an empty platter) refuses the platter MustBeEmpty and a Food.Meat
// input dock refuses it KindRejected. Both refuse it the same way while it settles after its drop, and once it froze. Isolated origin (187000, -70000, -30000).
class UMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(187000.0, -70000.0, -30000.0);
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Box;
    private FMars_PlatterDock_Spec _OutputSpec;
    private FMars_PlatterDock_Spec _MeatSpec;
    // Each dock's refusal in the first frame the box was pending, not held.
    private TOptional<EMars_PlatterDock_Refusal> _OutputWhilePending;
    private TOptional<EMars_PlatterDock_Refusal> _MeatWhilePending;
    private bool _WasSettlingWhilePending = false;
    // Each dock's refusal in the first frame the box was settling.
    private TOptional<EMars_PlatterDock_Refusal> _OutputWhileSettling;
    private TOptional<EMars_PlatterDock_Refusal> _MeatWhileSettling;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _Box = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        _OutputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Output, FMars_PlatterDock_Policy(), FTransform::Identity);
        _MeatSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input,
            FMars_PlatterDock_Policy(FGameplayTagQuery::MakeQuery_MatchTag(GameplayTags::Food_Meat), false), FTransform::Identity);

        Add_Step_WaitUntil("the box is Ready", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("both docks take the empty platter", n"Step_AssertEmptyPasses");
        Add_Step("load the box", n"Step_Load");
        Add_Step_WaitUntil("the box is the platter's, pending, not frozen", n"Check_Pending", 0, 0);
        Add_Step("both docks refuse the platter while the box is queued", n"Step_AssertPendingRefused");
        Add_Step_WaitUntil("the box dropped and is settling", n"Check_Settling", k_SlowPolls, 0);
        Add_Step("both docks refuse the platter while the box settles", n"Step_AssertSettlingRefused");
        Add_Step_WaitUntil("the box froze", n"Check_Held", k_SlowPolls, 0);
        Add_Step("both docks still refuse it", n"Step_AssertHeldRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Box));
    }

    UFUNCTION()
    private void Step_AssertEmptyPasses(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_platter_dock::Get_Refusal(_OutputSpec, _Platter).IsSet(), "the Output dock takes the empty platter");
        Assert_False(utils_platter_dock::Get_Refusal(_MeatSpec, _Platter).IsSet(), "the meat dock takes the empty platter");
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _Box);
    }

    // Polled every frame: the refusals are read in the first frame the box is the platter's and not frozen.
    UFUNCTION()
    private void Check_Pending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Box.TryGet_Platter() != _Platter || _Platter.Get_HeldCount() != 0 || _Platter.Get_PendingCount() != 1)
        {
            Res.Set(false);
            return;
        }

        _OutputWhilePending = utils_platter_dock::Get_Refusal(_OutputSpec, _Platter);
        _MeatWhilePending = utils_platter_dock::Get_Refusal(_MeatSpec, _Platter);
        _WasSettlingWhilePending = Get_IsSettling(_Platter, _Box);
        Res.Set(true);
    }

    // Polled every frame: the refusals are read in the first frame the box settles.
    UFUNCTION()
    private void Check_Settling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsSettling(_Platter, _Box) == false)
        {
            Res.Set(_Platter.Get_HeldCount() > 0);
            return;
        }

        _OutputWhileSettling = utils_platter_dock::Get_Refusal(_OutputSpec, _Platter);
        _MeatWhileSettling = utils_platter_dock::Get_Refusal(_MeatSpec, _Platter);
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertSettlingRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_OutputWhileSettling == EMars_PlatterDock_Refusal::MustBeEmpty,
            f"the Output dock refuses a platter with a settling piece MustBeEmpty (got [{Describe(_OutputWhileSettling)}])");
        Assert_True(_MeatWhileSettling == EMars_PlatterDock_Refusal::KindRejected,
            f"the meat dock refuses a settling piece of no kind KindRejected (got [{Describe(_MeatWhileSettling)}])");
    }

    UFUNCTION()
    private void Step_AssertPendingRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_WasSettlingWhilePending, "the box was still queued, not yet dropped");
        Assert_True(_OutputWhilePending == EMars_PlatterDock_Refusal::MustBeEmpty,
            f"the Output dock refuses a platter with a pending piece MustBeEmpty (got [{Describe(_OutputWhilePending)}])");
        Assert_True(_MeatWhilePending == EMars_PlatterDock_Refusal::KindRejected,
            f"the meat dock refuses a pending piece of no kind KindRejected (got [{Describe(_MeatWhilePending)}])");
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_AssertHeldRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Output = utils_platter_dock::Get_Refusal(_OutputSpec, _Platter);
        const auto Meat = utils_platter_dock::Get_Refusal(_MeatSpec, _Platter);
        Assert_True(Output == EMars_PlatterDock_Refusal::MustBeEmpty, f"the Output dock still refuses it MustBeEmpty (got [{Describe(Output)}])");
        Assert_True(Meat == EMars_PlatterDock_Refusal::KindRejected, f"the meat dock still refuses it KindRejected (got [{Describe(Meat)}])");
    }

    private FString Describe(TOptional<EMars_PlatterDock_Refusal> InRefusal) const
    {
        if (InRefusal.IsSet() == false)
        { return "none"; }

        return f"{InRefusal.GetValue() :n}";
    }
}
