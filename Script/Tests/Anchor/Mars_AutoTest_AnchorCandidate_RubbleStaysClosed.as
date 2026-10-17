// The rubble candidate is a closed solid gate with nothing that could ever open it. The settle before the check is a
// positive-then-negative pair: the gate must exist first, then stay closed through a window of wall-clock.
class UMars_AutoTest_AnchorCandidate_RubbleStaysClosed : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 15.0f;

    private FCk_Handle _Candidate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Context = FMars_Anchor_Context();
        Context.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        _Candidate = Spawn_Candidate(InHandle, UMars_Anchor_Rubble_EntityScript, Context);

        Add_Step_WaitUntil("the rubble composes its gate", n"Check_Composed");
        Add_Step_WaitSeconds("give anything that could open it a chance", 0.5f);
        Add_Step("the gate is closed and has no sink", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Gates = Get_OwnedTagged(_Candidate, n"TAG_MarsGate");
        auto Res = OutResult;
        Res.Set(Gates.Num() == 1 && Gates[0].Has_Fragment(FMars_Feature_Gate));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Gates = Get_OwnedTagged(_Candidate, n"TAG_MarsGate");
        Assert_Equals_Int(Gates.Num(), 1, "exactly one gate");
        Assert_False(Gates[0].As_Gate().Get_IsOpen(), "the rubble gate is closed");
        Assert_False(Gates[0].Has_Fragment(FMars_Feature_MechanismSink), "nothing can open it: no sink");
    }
}
