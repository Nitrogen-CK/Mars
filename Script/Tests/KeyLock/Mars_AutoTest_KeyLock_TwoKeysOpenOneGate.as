// A gate whose sink takes Mechanism.Channel.Keys.Red and .Blue with AllChannels opens only once both a red lock and a
// blue lock hold their keys: the red key alone leaves it closed, the blue key then opens it. The keys go in straight from
// their holders (no carrier). The driver is the world's. Isolated Z band: -94000.
class UMars_AutoTest_KeyLock_TwoKeysOpenOneGate : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _RedLock;
    private FCk_Handle_KeyLock _BlueLock;
    private FCk_Handle_Gate _Gate;
    private FCk_Handle_MechanismSink _Sink;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto RedChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Keys.Red");
        const auto BlueChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Keys.Blue");

        _RedLock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(-150.0, 0.0, -94000.0),
            GameplayTags::Key_Mars_Red, EMars_KeyLock_Release::Kept, RedChannel));
        _BlueLock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -94000.0),
            GameplayTags::Key_Mars_Blue, EMars_KeyLock_Release::Kept, BlueChannel));

        auto GateEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto GateRoot = utils_transform::Add(GateEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 300.0, -94000.0)), ECk_Replication::DoesNotReplicate);
        _Gate = utils_gate::Add(GateRoot, FMars_Gate_Spec());

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(RedChannel);
        SinkSpec.InputChannels.Add(BlueChannel);
        SinkSpec.Rule = EMars_MechanismSink_Rule::AllChannels;
        _Sink = utils_mechanism_sink::Add(GateEntity, SinkSpec);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Red()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Blue()));

        Add_Step_WaitUntil("both key holders are seeded", n"Check_HoldersSeeded");
        Add_Step_WaitUntil("the driver evaluates the gate's sink", n"Check_Evaluated");
        Add_Step("insert the red key", n"Step_InsertRed");
        Add_Step_WaitUntil("the red lock holds its key and its source is asserted", n"Check_RedUnlocked");
        Add_Step_WaitUntil("the driver re-evaluates the sink with the red channel asserted", n"Check_SinkSeesRed");
        Add_Step("one key of two leaves the gate closed", n"Step_AssertStillClosed");
        Add_Step("insert the blue key", n"Step_InsertBlue");
        Add_Step_WaitUntil("both keys in: the gate opens", n"Check_Open");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Evaluated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Sink) && _Sink.Get_HasEvaluated());
    }

    UFUNCTION()
    private void Step_InsertRed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Gate, "the gate");
        Assert_False(_Gate.Get_IsOpen(), "the gate before any key");
        _RedLock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[0]));
    }

    UFUNCTION()
    private void Check_RedUnlocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RedLock.Get_Key() == _Items[0] && Get_IsSourceAsserted(_RedLock));
    }

    UFUNCTION()
    private void Check_SinkSeesRed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto SeesRed = false;
        for (const auto& Input : _Sink.Get_Fragment(FMars_Fragment_MechanismSink).Inputs)
        {
            if (Input.Channel == _RedLock.As_MechanismSource().Get_OutputChannel())
            { SeesRed = Input.AssertedCount == 1; }
        }

        auto Res = OutResult;
        Res.Set(SeesRed);
    }

    UFUNCTION()
    private void Step_AssertStillClosed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Sink.Get_IsPowered(), "the sink with only the red channel asserted");
        Assert_False(_Gate.Get_IsOpen(), "the gate with only the red key in");
    }

    UFUNCTION()
    private void Step_InsertBlue(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BlueLock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[1]));
    }

    UFUNCTION()
    private void Check_Open(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_BlueLock.Get_Key() == _Items[1] && _Sink.Get_IsPowered() && _Gate.Get_IsOpen());
    }
}
