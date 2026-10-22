// Exercise the real candidate's Control -> MechanismSource -> latched sink -> moving leaf chain.
// Releasing the far-side control leaves the passage raised for a later carrier; no simultaneous hold.
class UMars_AutoTest_AnchorCandidate_WarrensScoutLatchSupportsSequentialAccess : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 20.0f;

    private FCk_Handle _Candidate;
    private FGameplayTag _Channel;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.C");
        auto Context = FMars_Anchor_Context();
        Context.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Context.Channel = _Channel;
        Context.LeverSide = EMars_Anchor_LeverSide::Ahead;
        Context.CrawlOffsetCm = TOptional<FVector2D>(FVector2D(0.0, 260.0));
        _Candidate = Spawn_Candidate(InHandle, UMars_Anchor_OneSidedLeverGate_EntityScript, Context);

        Add_Step_WaitUntil("the candidate composes one gate and one far-side control", n"Check_Composed");
        Add_Step("the closed candidate has only a far-side control; engage it", n"Step_Engage");
        Add_Step_WaitUntil("the real control and source assert and the leaf finishes rising", n"Check_Raised");
        Add_Step("the scout releases the control before the carrier arrives", n"Step_Release");
        Add_Step_WaitUntil("the far-side control and source deassert", n"Check_Released");
        Add_Step_WaitSeconds("allow an erroneous unlatched close to finish", 1.0f);
        Add_Step("the later carrier still has a raised passage", n"Step_AssertSequential");
        Run_Steps(InHandle);
    }

    private TArray<FCk_Handle> Get_Levers() const
    { return Get_OwnedTagged(_Candidate, n"TAG_MarsLever"); }

    private TArray<FCk_Handle> Get_Gates() const
    { return Get_OwnedTagged(_Candidate, n"TAG_MarsGate"); }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Gates = Get_Gates();
        const auto Levers = Get_Levers();
        auto Res = OutResult;
        Res.Set(Gates.Num() == 1 && Levers.Num() == 1 && Gates[0].Has_Fragment(FMars_Feature_Gate)
            && Levers[0].Has_Fragment(FMars_Feature_Control) && Levers[0].Has_Fragment(FMars_Feature_MechanismSource));
    }

    UFUNCTION()
    private void Step_Engage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Lever = Get_Levers()[0];
        const auto Location = utils_transform::Get_EntityCurrentLocation(Lever.As_Transform());
        Assert_True(Location.X > _Base.X, "the sole control stands on the authored far (+X) side");
        Assert_True(Lever.As_MechanismSource().Get_OutputChannel() == _Channel, "the far-side control owns the candidate channel");
        Assert_False(Get_Gates()[0].As_Gate().Get_IsOpen(), "the passage starts closed");
        auto Control = Lever.As_Control();
        Control.Request_Engage(FMars_Request_Control_Engage());
    }

    UFUNCTION()
    private void Check_Raised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lever = Get_Levers()[0];
        const auto Gate = Get_Gates()[0].As_Gate();
        const auto Moving = Gate.Get_MovingNode();
        const auto Mover = Moving.As_Mover();
        auto Res = OutResult;
        Res.Set(Lever.As_Control().Get_IsActive() && Lever.As_MechanismSource().Get_IsAsserted()
            && Gate.Get_IsOpen() && Mover.Get_IsResting() && Mover.Get_Alpha() == 1.0f
            && utils_scene_node::Get_Offset(Moving).GetLocation().Z >= 220.0);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Control = Get_Levers()[0].As_Control();
        Control.Request_Engage(FMars_Request_Control_Engage());
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lever = Get_Levers()[0];
        auto Res = OutResult;
        Res.Set(Lever.As_Control().Get_IsActive() == false && Lever.As_MechanismSource().Get_IsAsserted() == false);
    }

    UFUNCTION()
    private void Step_AssertSequential(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Gate = Get_Gates()[0].As_Gate();
        const auto Moving = Gate.Get_MovingNode();
        Assert_True(Gate.Get_IsOpen(), "the later carrier needs no held lever or second actor");
        Assert_True(Moving.As_Mover().Get_IsResting(), "the leaf remains at rest");
        Assert_Equals_Float(utils_scene_node::Get_Offset(Moving).GetLocation().Z, 220.0, 0.01, "the leaf remains above the opening after the scout leaves");
    }
}
