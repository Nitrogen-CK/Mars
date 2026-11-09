// The planted root draws the pull the Control has this frame, not the frame before: while a walk pull's spring is moving,
// every sample of the anim instance's CrownOffset.X is -alpha x TravelCm and its ClipTime (SRC_Tug, scrubbed) is
// alpha x the clip's length, alpha being the Control's manipulation alpha read at the same moment. The test's step timer
// runs in FGroup_Gameplay_TimeDelta, before the Control's tick (FGroup_Gameplay_Script) and the presentation's tick
// (FGroup_PostTransform): both reads are the previous frame's end state, so a presentation that draws a frame-old alpha
// misses by one spring step. The walk is a step the spring takes several frames to follow, so the samples are sensitive.
class UMars_AutoTest_ScreamingTurnipBed_TheDrawnStretchIsThisFramesPull : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 42000.0, -30000.0);

    private const int32 k_SampleFrames = 30;
    // A frame-old alpha misses by a spring step; the samples must move more than this per frame for that to show.
    private const float32 k_MinAlphaStep = 0.01f;
    private const float64 k_OffsetToleranceCm = 0.01;
    private const float32 k_ClipTimeTolerance = 0.0005f;

    private UMars_ScreamingTurnipPresentationComponent _Presentation;
    private int32 _Samples = 0;
    private int32 _TugSamples = 0;
    private float64 _MaxOffsetError = 0.0;
    private float32 _MaxClipTimeError = 0.0f;
    private float32 _MaxAlphaStep = 0.0f;
    private TOptional<float32> _LastAlpha;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step_WaitUntil("the planted presentation plays through its anim blueprint", n"Check_PresentationReady", k_SlowPolls);
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the puller grips the stalks", n"Check_PullGripped", k_SlowPolls);
        Add_Step("walk back 0.8 of the travel at once", n"Step_Walk");
        Add_Step_WaitUntil("sample the drawing against the Control while the spring follows", n"Check_Sampled", k_SlowPolls);
        Add_Step("the drawing is this frame's pull", n"Step_AssertSameFrame");
        Add_Step("let go", n"Step_LetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PresentationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Presentation))
        {
            for (auto Node : utils_fphands::Get_TransformTree(_Bed))
            {
                const auto Components = utils_unreal_component::Get_ComponentsByType(Node, UMars_ScreamingTurnipPresentationComponent);
                if (Components.Num() == 1)
                { _Presentation = Cast<UMars_ScreamingTurnipPresentationComponent>(Components[0]); }
            }
        }

        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_Anim()));
    }

    UFUNCTION()
    private void Step_Walk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Walk_Puller(Get_WalkCmFor(0.8f));
    }

    UFUNCTION()
    private void Check_Sampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Anim = Get_Anim();
        const auto Alpha = _BedControl.TryGet_ManipulationAlpha();
        if (ck::IsValid(Anim) && Alpha.IsSet())
        {
            const auto Value = Alpha.GetValue();
            if (_LastAlpha.IsSet())
            { _MaxAlphaStep = Math::Max(_MaxAlphaStep, Math::Abs(Value - _LastAlpha.GetValue())); }
            _LastAlpha = TOptional<float32>(Value);

            _MaxOffsetError = Math::Max(_MaxOffsetError, Math::Abs(Anim.CrownOffset.X + Value * _BedPull.Stretch.TravelCm));
            if (_Presentation.Get_PlayingClip() == constants_screaming_turnip_assets::k_Clip_Tug && ck::IsValid(Anim.Sequence))
            {
                ++_TugSamples;
                const auto Expected = Value * float32(Anim.Sequence.GetPlayLength());
                _MaxClipTimeError = Math::Max(_MaxClipTimeError, Math::Abs(Anim.ClipTime - Expected));
            }

            ++_Samples;
        }

        auto Res = OutResult;
        Res.Set(_Samples >= k_SampleFrames);
    }

    UFUNCTION()
    private void Step_AssertSameFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MaxAlphaStep > k_MinAlphaStep,
            f"the spring moved the alpha by up to {_MaxAlphaStep :.4} a frame (the samples can see a frame-old drawing)");
        Assert_True(_MaxOffsetError <= k_OffsetToleranceCm,
            f"CrownOffset.X is -alpha x TravelCm on every sample (worst {_MaxOffsetError :.4} cm over {_Samples} samples)");
        Assert_True(_TugSamples > 0, "SRC_Tug was sampled");
        Assert_True(_MaxClipTimeError <= k_ClipTimeTolerance,
            f"the Tug's ClipTime is alpha x its length on every Tug sample (worst {_MaxClipTimeError :.5} s over {_TugSamples})");
    }

    UFUNCTION()
    private void Step_LetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cancel_Pull();
    }

    private UMars_ScreamingTurnip_AnimInstance Get_Anim() const
    {
        if (ck::Is_NOT_Valid(_Presentation))
        { return nullptr; }

        return Cast<UMars_ScreamingTurnip_AnimInstance>(_Presentation.GetAnimInstance());
    }
}
