// The remote-input net tests' shared steps. The subject composes InputIntents (and the Operator feature) on both
// machines, as the pawn does. On the client its InputIntents is fed by a private key stack (UMars_AutoTestHelper_UseKey,
// Interact_Primary on one key), sampled with utils_input_intents::Make_RemoteSample and carried to the server by a
// test-only reliable cue; the lanes' subject is no pawn, so the pawn's own transport is not under test. Loss is simulated
// at the sender by not sending some samples. On the server the sample is applied to the subject's InputIntents, which has
// no matcher, through Request_ApplyRemoteSample.

// Carries one sample from the asking machine to the authority's copy of the owner's InputIntents.
class UMars_TESTONLY_Cue_InputIntents_Sample : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_InputIntents_ApplyRemoteSample's field: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FMars_InputIntents_RemoteSample Sample;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Test_InputIntentsSample;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Intents = Owner.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Intents), f"[InputIntentsNet] a sample cue reached [{Owner.ToString()}], which has no InputIntents"))
        { return; }

        Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }
}

// How many presses a station's test reader counted on this machine's copy.
struct FMars_TESTONLY_Fragment_NetReaderPresses
{
    int32 Presses = 0;
}

// A test station's control state machine: Idle until operated, then the reader.
class UMars_TESTONLY_SmState_NetReader_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_TESTONLY_SmState_NetReader_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);
    }
}

class UMars_TESTONLY_SmState_NetReader_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_TESTONLY_SmState_NetReader_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_TESTONLY_SmTask_NetReader);
    }
}

// Counts the operator's Interact_Primary presses into the station's FMars_TESTONLY_Fragment_NetReaderPresses.
class UMars_TESTONLY_SmTask_NetReader : UMars_SmTask_StationOperatorInput
{
    private FMars_IntentEdge _Primary;

    protected void Bind(FCk_Handle InStation) override
    {
        const auto Station = InStation.As_Station();
        Log(f"[InputIntentsNet] a reader enters on [{InStation.ToString()}]: stance {Station.Get_InputStance() :n}, authority {utils_net::Get_HasAuthority(InStation)}");
    }

    protected void Seed() override
    {
        _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
    }

    protected void Poll() override
    {
        if (utils_input_intents::Get_HasPress(_Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary)))
        { _Station.AddOrGet_Fragment(FMars_TESTONLY_Fragment_NetReaderPresses).Presses += 1; }
    }
}

// The reader station: the base station, tagged on its root so each machine finds its copy.
class UMars_TESTONLY_NetReaderStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetReaderStation");
    }
}

// Where a client's press cycle is: idle samples first, then press / release pairs, then idle samples to flush the last one.
enum EMars_TESTONLY_PressPhase
{
    Seeding,
    Pressing,
    Releasing,
    Flushing
}

enum EMars_TESTONLY_SendPolicy
{
    // Every sample made is sent (unless dropped).
    EveryFrame,
    // As the operating client sends: on a change, or after constants_input_intents::k_KeepAliveFrames unchanged frames.
    OnChangeOrKeepAlive
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetInputIntents : UMars_AutoTestRig_NetStation
{
    default _TimeoutSeconds = 25.0f;

    protected const FGameplayTag k_Intent = GameplayTags::Mars_Intent_Interact_Primary;
    // Idle samples before a cycle's first press, so the server seeds on a sample with nothing held.
    protected const int32 k_SeedFrames = 10;
    // Frames a press or a release is kept past the client's own reading of it.
    protected const int32 k_PhaseFrames = 2;
    // Idle samples after a cycle's last release, so a dropped last sample is made up.
    protected const int32 k_FlushFrames = 12;
    // Frames the server keeps reading after it has what it expects, to see nothing more arrives.
    protected const int32 k_ServerSettleFrames = 60;

    protected FCk_Handle_InputIntents _Intents;
    protected UMars_AutoTestHelper_UseKey _Keys;
    private EMars_TESTONLY_KeysSetup _KeysSetup = EMars_TESTONLY_KeysSetup::Recording;

    protected FMars_InputIntents_Sampler _Sampler;
    protected FMars_InputIntents_RemoteSample _LastSent;
    protected EMars_TESTONLY_SendPolicy _SendPolicy = EMars_TESTONLY_SendPolicy::EveryFrame;
    // 0 sends every sample; N drops every Nth sample made.
    protected int32 _DropEvery = 0;
    protected int32 _SamplesMade = 0;
    protected int32 _SamplesSent = 0;
    private int32 _FramesSinceSent = 0;

    protected EMars_TESTONLY_PressPhase _PressPhase = EMars_TESTONLY_PressPhase::Seeding;
    protected int32 _PressTarget = 0;
    protected int32 _PressesDone = 0;
    private int32 _PhaseFrames = 0;

    protected FMars_IntentEdge _ServerEdge;
    protected int32 _ServerPresses = 0;
    protected int32 _ServerSettleFrames = 0;

    // Both machines, first thing: the station rig's start, and the subject's InputIntents (reused when an earlier test of
    // this session composed it). The server clears any remote state left behind and seeds its edge.
    protected void Begin_NetInputIntentsTest()
    {
        Begin_NetStationTest();

        auto Subject = Get_SubjectEntity();
        _Intents = Subject.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { _Intents = utils_input_intents::Add(Subject); }

        if (utils_net::Get_HasAuthority(Subject))
        {
            _Intents.Request_ClearRemote(FMars_Request_InputIntents_ClearRemote());
            _ServerEdge.Seed(_Intents, k_Intent);
        }
    }

    // Client: the key stack under InOwner, its matcher handed to the subject's InputIntents.
    protected void Build_ClientKeys(FCk_Handle InOwner)
    {
        auto Rows = TArray<FMars_AutoTestHelper_KeyRow>();
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F9, k_Intent, n"IP"));

        _Keys = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _Keys.Build_Rows(InOwner, Rows);
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Keys.Get_Matcher()));
    }

    // Client: one press cycle of InPresses presses starts on the next poll.
    protected void Start_PressCycle(int32 InPresses)
    {
        _PressPhase = EMars_TESTONLY_PressPhase::Seeding;
        _PressTarget = InPresses;
        _PressesDone = 0;
        _PhaseFrames = 0;
    }

    // Client, once a frame: advances the cycle by this frame's reading; true once it has flushed.
    protected bool Tick_PressCycle()
    {
        _PhaseFrames += 1;
        const auto IsHeld = _Intents.Get_IsIntentActive(k_Intent);

        if (_PressPhase == EMars_TESTONLY_PressPhase::Seeding)
        {
            if (_PhaseFrames >= k_SeedFrames)
            { Enter_PressPhase(EMars_TESTONLY_PressPhase::Pressing); }

            return false;
        }

        if (_PressPhase == EMars_TESTONLY_PressPhase::Pressing)
        {
            if (_PhaseFrames >= k_PhaseFrames && IsHeld)
            { Enter_PressPhase(EMars_TESTONLY_PressPhase::Releasing); }

            return false;
        }

        if (_PressPhase == EMars_TESTONLY_PressPhase::Releasing)
        {
            if (_PhaseFrames < k_PhaseFrames || IsHeld)
            { return false; }

            _PressesDone += 1;
            Enter_PressPhase(_PressesDone >= _PressTarget ? EMars_TESTONLY_PressPhase::Flushing : EMars_TESTONLY_PressPhase::Pressing);
            return false;
        }

        return _PhaseFrames >= k_FlushFrames;
    }

    private void Enter_PressPhase(EMars_TESTONLY_PressPhase InPhase)
    {
        _PressPhase = InPhase;
        _PhaseFrames = 0;

        if (InPhase == EMars_TESTONLY_PressPhase::Pressing)
        { _Keys.Press_Row(k_Intent); }
        else if (InPhase == EMars_TESTONLY_PressPhase::Releasing)
        { _Keys.Release_Row(k_Intent); }
    }

    // Client, once a frame: this frame's sample, sent by the policy unless it is one the loss drops.
    protected void Sample_AndSend()
    {
        const auto FirstSample = _Sampler.Rows.IsEmpty();
        const auto Sample = utils_input_intents::Make_RemoteSample(_Intents, _Sampler);
        _SamplesMade += 1;
        _FramesSinceSent += 1;

        if (_SendPolicy == EMars_TESTONLY_SendPolicy::OnChangeOrKeepAlive && FirstSample == false
            && _FramesSinceSent < constants_input_intents::k_KeepAliveFrames && utils_input_intents::Get_AreSameSamples(Sample, _LastSent))
        { return; }

        _LastSent = Sample;
        _FramesSinceSent = 0;
        if (_DropEvery > 0 && _SamplesMade % _DropEvery == 0)
        { return; }

        _SamplesSent += 1;
        utils_cue_generic::Request_ExecuteCue(Get_SubjectEntity(), GameplayTags::Cue_Mars_Test_InputIntentsSample,
            FMars_Request_InputIntents_ApplyRemoteSample(Sample), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    // Client: the press serial its sampler counted for k_Intent.
    protected int32 Get_ClientPressSerial() const
    {
        for (const auto& Row : _Sampler.Rows)
        {
            if (Row.Intent == k_Intent)
            { return Row.PressSerial; }
        }

        return 0;
    }

    // Server, once a frame: the edge over the subject's InputIntents, counting presses.
    protected void Tick_ServerEdge()
    {
        if (utils_input_intents::Get_HasPress(_ServerEdge.Advance(_Intents, k_Intent)))
        { _ServerPresses += 1; }
    }

    // The reader station of InStance on this machine; invalid until its copy has composed.
    protected FCk_Handle_Station Find_ReaderStation(EMars_Station_InputStance InStance)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetReaderStation"))
        {
            auto Station = Candidate.As_Station(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Station) || Station.Get_InputStance() != InStance)
            { continue; }

            return Station;
        }

        return FCk_Handle_Station();
    }

    // Server: a reader station of InStance at InLocation, under the spawn owner.
    protected void Spawn_ServerReaderStation(FVector InLocation, EMars_Station_InputStance InStance)
    {
        auto Spec = FMars_Station_Spec();
        Spec.MinigameStateClass = UMars_TESTONLY_SmState_NetReader_Idle;
        Spec.InputStance = InStance;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, InLocation), Spec);
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetReaderStation_EntityScript, Params);
    }

    protected int32 Get_ReaderPresses(FCk_Handle_Station InStation) const
    {
        if (ck::Is_NOT_Valid(InStation) || InStation.Has_Fragment(FMars_TESTONLY_Fragment_NetReaderPresses) == false)
        { return 0; }

        return InStation.Get_Fragment(FMars_TESTONLY_Fragment_NetReaderPresses).Presses;
    }

    UFUNCTION()
    protected void Is_ClientKeysReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (_KeysSetup == EMars_TESTONLY_KeysSetup::Recording)
        {
            if (_Keys.Get_IsRecording())
            {
                const auto Swapped = _Keys.Request_SwapUseSet();
                if (Swapped.IsValid() == false)
                { FinishFailure(Swapped.Get_Error()); }

                _KeysSetup = EMars_TESTONLY_KeysSetup::Swapping;
            }

            Result.Set(false);
            return;
        }

        Result.Set(_Keys.Get_IsUseSetActive() && _Intents.Get_Matcher() == _Keys.Get_Matcher());
    }
}

enum EMars_TESTONLY_KeysSetup
{
    // Waiting for the key to be minted and the sampler to record.
    Recording,
    // The level row is baked and swapped in; waiting for it to be live.
    Swapping
}
