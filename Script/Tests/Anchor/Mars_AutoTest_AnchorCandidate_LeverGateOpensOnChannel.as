// The lever-gate candidate on a channel no other test uses (Test.B): a closed barred gate, two levers on its channel,
// and either lever latches it open through the world's mechanism driver.
class UMars_AutoTest_AnchorCandidate_LeverGateOpensOnChannel : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 20.0f;

    private FCk_Handle _Candidate;
    private FGameplayTag _Channel;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.B");
        auto Context = FMars_Anchor_Context();
        Context.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Context.Channel = _Channel;
        _Candidate = Spawn_Candidate(InHandle, UMars_Anchor_LeverGate_EntityScript, Context);

        Add_Step_WaitUntil("the candidate composes one gate and two levers on its channel", n"Check_Composed");
        Add_Step("the gate starts closed; pull one lever", n"Step_Pull");
        Add_Step_WaitUntil("the gate opens", n"Check_Open");
        Run_Steps(InHandle);
    }

    private TArray<FCk_Handle_MechanismSource> Get_MySources() const
    {
        auto Sources = TArray<FCk_Handle_MechanismSource>();
        for (auto Entity : Get_OwnedTagged(_Candidate, n"TAG_MarsMechanismSource"))
        {
            const auto Source = Entity.As_MechanismSource();
            if (Source.Get_OutputChannel() == _Channel)
            { Sources.Add(Source); }
        }
        return Sources;
    }

    private TArray<FCk_Handle> Get_MyGates() const
    { return Get_OwnedTagged(_Candidate, n"TAG_MarsGate"); }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Gates = Get_MyGates();
        auto Res = OutResult;
        Res.Set(_Channel.IsValid() && Gates.Num() == 1 && Gates[0].Has_Fragment(FMars_Feature_Gate) && Get_MySources().Num() == 2);
    }

    UFUNCTION()
    private void Step_Pull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Gate = Get_MyGates()[0].As_Gate();
        Assert_False(Gate.Get_IsOpen(), "the portcullis starts closed");
        Assert_True(Get_MyGates()[0].Has_Fragment(FMars_Feature_MechanismSink), "the gate listens on a sink");

        auto Source = Get_MySources()[0];
        Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_Open(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_MyGates()[0].As_Gate().Get_IsOpen());
    }
}
