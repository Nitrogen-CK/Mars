// The presentation's first warning clip follows what was on screen: a root that settles from Dormant (QuietIdle) plays
// ROOT_Anticipate for its first warning; every later warning comes out of RecoveryIdle and plays ROOT_AnticipateTired. The
// clip is sampled on every poll of every Anticipate phase and must not change inside one (the per-tick re-read keeps the
// choice). Three screams on a short clock give one fresh and two tired warnings.
class UMars_AutoTest_ScreamingTurnip_TheWarningAfterARecoveryPlaysTheTiredAnticipate : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 27000.0, -30000.0);

    // The clips seen in each Anticipate phase, in order: one entry per distinct clip within that phase.
    private TArray<FString> _AnticipateClips;
    private TArray<int32> _AnticipateRuns;
    private int32 _Run = 0;
    private bool _WasAnticipating = false;
    private int32 _Samples = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Floor(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 30.0), Make_ShortVocal());

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step("the skeletal presentation loaded", n"Step_AssertPresentation");
        Add_Step_WaitUntil("three screams, every Anticipate sampled", n"Check_ThreeScreamsSampling", k_SlowPolls);
        Add_Step("fresh, then tired, never switched mid-phase", n"Step_AssertClips");
        Run_Steps(InHandle);
    }

    private UMars_ScreamingTurnipPresentationComponent TryGet_Presentation() const
    {
        if (_WorldItems.Num() == 0 || ck::Is_NOT_Valid(_WorldItems[0]))
        { return nullptr; }

        for (auto Node : utils_fphands::Get_TransformTree(_WorldItems[0].H()))
        {
            const auto Components = utils_unreal_component::Get_ComponentsByType(Node, UMars_ScreamingTurnipPresentationComponent);
            if (Components.Num() == 1)
            { return Cast<UMars_ScreamingTurnipPresentationComponent>(Components[0]); }
        }

        return nullptr;
    }

    UFUNCTION()
    private void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Presentation = TryGet_Presentation();
        Assert_True(ck::IsValid(Presentation), "the root carries a presentation component");
        if (ck::IsValid(Presentation))
        { Assert_True(Presentation.Get_HasMesh(), "the skeletal mesh loaded (the clip choice is observable)"); }
    }

    UFUNCTION()
    private void Check_ThreeScreamsSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Presentation = TryGet_Presentation();
        const auto Anticipating = _Turnips.Num() > 0 && _Turnips[0].Get_Phase() == EMars_ScreamingTurnip_Phase::Anticipate;
        if (Anticipating && ck::IsValid(Presentation))
        {
            if (_WasAnticipating == false)
            { ++_Run; }

            const auto Clip = Presentation.Get_PlayingClip();
            ++_Samples;
            const auto Last = _AnticipateClips.Num() - 1;
            if (Last < 0 || _AnticipateRuns[Last] != _Run || _AnticipateClips[Last] != Clip)
            {
                _AnticipateClips.Add(Clip);
                _AnticipateRuns.Add(_Run);
            }
        }

        _WasAnticipating = Anticipating;
        auto Res = OutResult;
        Res.Set(_Commits.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertClips(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FString Seen;
        for (int32 Index = 0; Index < _AnticipateClips.Num(); ++Index)
        { Seen += f" [{_AnticipateRuns[Index]}:{_AnticipateClips[Index]}]"; }

        Assert_Equals_Int(_Run, 3, f"three Anticipate phases were sampled ({_Samples} samples;{Seen})");
        Assert_Equals_Int(_AnticipateClips.Num(), 3, f"one clip per Anticipate phase, never switched inside one ({Seen})");
        if (_AnticipateClips.Num() != 3)
        { return; }

        Assert_True(_AnticipateClips[0] == constants_screaming_turnip_assets::k_Clip_Anticipate,
            f"the first warning (out of Dormant / QuietIdle) plays {constants_screaming_turnip_assets::k_Clip_Anticipate}, got {_AnticipateClips[0]}");
        Assert_True(_AnticipateClips[1] == constants_screaming_turnip_assets::k_Clip_AnticipateTired,
            f"the second warning (out of RecoveryIdle) plays {constants_screaming_turnip_assets::k_Clip_AnticipateTired}, got {_AnticipateClips[1]}");
        Assert_True(_AnticipateClips[2] == constants_screaming_turnip_assets::k_Clip_AnticipateTired,
            f"the third warning (out of RecoveryIdle) plays {constants_screaming_turnip_assets::k_Clip_AnticipateTired}, got {_AnticipateClips[2]}");
    }
}
