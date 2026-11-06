// The Screaming Turnip's animated drawing: a single-node skeletal mesh that plays one clip per kernel state. It follows the
// kernel (UMars_ScreamingTurnip_EntityScript forwards its phase and placement signals; the tick re-reads the kernel only to
// tell an airborne root from one rolling on the ground) and writes no gameplay state; no animation notify decides anything.
// A clip is (re)started only when the wanted clip changes, never per frame. A missing mesh or clip warns once and changes
// nothing in gameplay: without the mesh the entity script keeps the static proxy visible, without a clip the mesh holds
// its reference pose. The bed (UMars_ScreamingTurnipBed_EntityScript) drives the same component with Play_Clip directly.
//
// How a clip ends is part of the play (EMars_ScreamingTurnip_ClipEnd): Loop repeats it and becomes the component's loop
// clip; HoldLastFrame stops on its last frame (the item's one-shots: the kernel's next wanted clip replaces it, so nothing
// here fights Refresh_FromKernel; the bed's Tug holds the strain until the release swaps the visuals); ReturnToLoop plays
// the loop clip again once the one-shot has played through (the bed's Cancel -> SRC_Idle), polled in Tick.
//
// The warning's first clip depends on what was on screen before it: a root coming out of its recovery (RecoveryIdle, or
// Recover when one kernel pass skipped RecoveryIdle) plays ROOT_AnticipateTired, which starts on RecoveryIdle's first pose;
// one coming out of Dormant (QuietIdle) plays ROOT_Anticipate. The component remembers the phase it last drew and, on the
// change into Anticipate, which phase that came from (presentation state, not gameplay state); the per-tick re-read keeps
// that choice until the phase changes again, so a clip never flips mid-play.
//
// A play can be stretched (FMars_ScreamingTurnip_PresentationClip.SpanSeconds: the clip's play rate is set so it spans
// those seconds; the bed's Grip and Tug span their stages whatever the stage seconds are) and can start part-way
// (StartAlpha: the bed's Cancel resumes from the strain the Tug had reached instead of popping to the full strain).
// Play_ClipChain plays clips one after another: the next starts once the one playing has played through (a Loop
// clip never does, so it ends a chain); Play_Clip drops any chain. A play of the stem already playing changes nothing,
// span and start included.
class UMars_ScreamingTurnipPresentationComponent : USkeletalMeshComponent
{
    default AnimationMode = EAnimationMode::AnimationSingleNode;
    default CollisionEnabled = ECollisionEnabled::NoCollision;
    default CastShadow = false;

    // Set by the owning item; invalid on the bed.
    private FCk_Handle_ScreamingTurnip _Turnip;
    private bool _Initialized = false;
    private bool _HasMesh = false;
    private FString _Clip;
    private EMars_ScreamingTurnip_ClipEnd _ClipEnd = EMars_ScreamingTurnip_ClipEnd::Loop;
    // Seconds; zero while no sequence plays.
    private float32 _ClipLength = 0.0f;
    // The last Loop clip played: what a ReturnToLoop one-shot goes back to.
    private FMars_ScreamingTurnip_PresentationClip _LoopClip;
    // The rest of a Play_ClipChain, in order; the front starts when the playing clip has played through.
    private TArray<FMars_ScreamingTurnip_PresentationClip> _Queued;
    private TArray<FString> _WarnedClips;
    // The kernel phase the last refresh drew, and the phase the current (or last) Anticipate was entered from.
    private EMars_ScreamingTurnip_Phase _DrawnPhase = EMars_ScreamingTurnip_Phase::Dormant;
    private EMars_ScreamingTurnip_Phase _AnticipateFrom = EMars_ScreamingTurnip_Phase::Dormant;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    { DoInitialize(); }

    UFUNCTION(BlueprintOverride)
    void Tick(float InDeltaSeconds)
    {
        // Ck invokes this after scene transforms settle: keep the native component on the held node even when a stationary
        // carrier's child-offset update did not reach the ordinary dirty-transform push (as the Cookbook's does).
        auto ComponentHandle = utils_unreal_component::TryGet_OwningHandle_FromComponent(this);
        if (utils_unreal_component::Get_CanEnableTransformPush(ComponentHandle))
        { utils_unreal_component::Request_EnableTransformPush(ComponentHandle); }

        Refresh_FromKernel();
        DoPlay_NextIfPlayedThrough();
        DoReturn_ToLoopIfPlayedThrough();
    }

    // Whether the skeletal mesh loaded: the owner hides its static stand-in only then.
    bool Get_HasMesh()
    {
        DoInitialize();
        return _HasMesh;
    }

    void Set_Turnip(FCk_Handle_ScreamingTurnip InTurnip)
    {
        _Turnip = InTurnip;
        Refresh_FromKernel();
    }

    // The stem of the clip started last (empty before the first, or without the skeletal mesh).
    FString Get_PlayingClip() const
    { return _Clip; }

    // How far through its sequence the playing clip is, 0..1 (1 once a one-shot holds its last frame; 0 without one).
    float32 Get_PlayedAlpha() const
    {
        if (_ClipLength <= 0.0f)
        { return 0.0f; }

        return Math::Clamp(GetPosition() / _ClipLength, 0.0f, 1.0f);
    }

    // The clip the kernel's state wants; plays it if it is not the one playing.
    void Refresh_FromKernel()
    {
        if (ck::Is_NOT_Valid(_Turnip))
        { return; }

        const auto Phase = _Turnip.Get_Phase();
        if (Phase != _DrawnPhase)
        {
            if (Phase == EMars_ScreamingTurnip_Phase::Anticipate)
            { _AnticipateFrom = _DrawnPhase; }

            _DrawnPhase = Phase;
        }

        Play_Clip(Get_WantedClip(FMars_ScreamingTurnip_PresentationQuery(_Turnip.Get_Placement(), Phase, _Turnip.Get_HasSupport(), _AnticipateFrom)));
    }

    // Starts InClip.Clip (a clip stem, ROOT_QuietIdle) unless it is the one playing; drops any chain.
    void Play_Clip(const FMars_ScreamingTurnip_PresentationClip& InClip)
    {
        _Queued.Empty();
        DoPlay(InClip);
    }

    // Starts the first of InClips and queues the rest: each next one starts when the playing clip has played through.
    void Play_ClipChain(const TArray<FMars_ScreamingTurnip_PresentationClip>& InClips)
    {
        _Queued.Empty();
        if (ck::EnsureIfNot(InClips.Num() > 0, "[ScreamingTurnip] Play_ClipChain with no clips"))
        { return; }

        DoPlay(InClips[0]);
        for (auto Index = 1; Index < InClips.Num(); ++Index)
        { _Queued.Add(InClips[Index]); }
    }

    private void DoPlay(const FMars_ScreamingTurnip_PresentationClip& InClip)
    {
        DoInitialize();
        if (_HasMesh == false || _Clip == InClip.Clip)
        { return; }

        if (InClip.SpanSeconds.IsSet() && ck::EnsureIfNot(InClip.SpanSeconds.GetValue() > 0.0f,
            f"[ScreamingTurnip] clip [{InClip.Clip}] asked to span {InClip.SpanSeconds.GetValue()} s"))
        { return; }

        _Clip = InClip.Clip;
        _ClipEnd = InClip.End;
        _ClipLength = 0.0f;
        if (InClip.End == EMars_ScreamingTurnip_ClipEnd::Loop)
        { _LoopClip = InClip; }

        auto Sequence = constants_screaming_turnip_assets::TryLoad_Clip(InClip.Clip);
        if (ck::Is_NOT_Valid(Sequence))
        {
            if (_WarnedClips.Contains(InClip.Clip) == false)
            {
                _WarnedClips.Add(InClip.Clip);
                ck::Warning(f"[ScreamingTurnip] presentation has no clip [{constants_screaming_turnip_assets::Clip(InClip.Clip).ToString()}]: holding the reference pose");
            }

            Stop();
            return;
        }

        _ClipLength = Sequence.GetPlayLength();
        PlayAnimation(Sequence, InClip.End == EMars_ScreamingTurnip_ClipEnd::Loop);
        // PlayAnimation resets the single node's rate to 1; the span and the start go on after it.
        SetPlayRate(InClip.SpanSeconds.IsSet() && _ClipLength > 0.0f ? _ClipLength / InClip.SpanSeconds.GetValue() : 1.0f);
        if (InClip.StartAlpha > 0.0f)
        { SetPosition(Math::Clamp(InClip.StartAlpha, 0.0f, 1.0f) * _ClipLength, false); }
    }

    // Whether the playing one-shot reached its end (the single node stopped there, or its position reached the clip's
    // length); a Loop clip never has, nor has a clip whose sequence is missing.
    private bool Get_HasPlayedThrough() const
    {
        if (_ClipLength <= 0.0f)
        { return false; }

        return IsPlaying() == false || GetPosition() >= _ClipLength;
    }

    // The front of the chain starts once the playing clip has played through.
    private void DoPlay_NextIfPlayedThrough()
    {
        if (_Queued.Num() == 0 || Get_HasPlayedThrough() == false)
        { return; }

        const auto Next = _Queued[0];
        _Queued.RemoveAt(0);
        DoPlay(Next);
    }

    // A ReturnToLoop one-shot that has played through hands back to the loop clip. A one-shot whose sequence is missing
    // never played, so it never returns.
    private void DoReturn_ToLoopIfPlayedThrough()
    {
        if (_ClipEnd != EMars_ScreamingTurnip_ClipEnd::ReturnToLoop || _LoopClip.Clip.IsEmpty() || Get_HasPlayedThrough() == false)
        { return; }

        Play_Clip(_LoopClip);
    }

    private FMars_ScreamingTurnip_PresentationClip Get_WantedClip(const FMars_ScreamingTurnip_PresentationQuery& InQuery) const
    {
        if (InQuery.Placement == EMars_ScreamingTurnip_Placement::Loose && InQuery.HasSupport == false)
        { return FMars_ScreamingTurnip_PresentationClip("ROOT_AirborneLeafTrail", EMars_ScreamingTurnip_ClipEnd::Loop); }

        if (utils_screaming_turnip::Get_IsEligible(InQuery.Placement) == false)
        { return FMars_ScreamingTurnip_PresentationClip("ROOT_QuietIdle", EMars_ScreamingTurnip_ClipEnd::Loop); }

        switch (InQuery.Phase)
        {
            case EMars_ScreamingTurnip_Phase::Anticipate:
            {
                const auto Tired = InQuery.AnticipateFrom == EMars_ScreamingTurnip_Phase::RecoveryIdle
                    || InQuery.AnticipateFrom == EMars_ScreamingTurnip_Phase::Recover;
                return FMars_ScreamingTurnip_PresentationClip(
                    Tired ? constants_screaming_turnip_assets::k_Clip_AnticipateTired : constants_screaming_turnip_assets::k_Clip_Anticipate,
                    EMars_ScreamingTurnip_ClipEnd::HoldLastFrame);
            }

            case EMars_ScreamingTurnip_Phase::Inhale:
            { return FMars_ScreamingTurnip_PresentationClip("ROOT_Inhale", EMars_ScreamingTurnip_ClipEnd::HoldLastFrame); }

            case EMars_ScreamingTurnip_Phase::Scream:
            { return FMars_ScreamingTurnip_PresentationClip("ROOT_Scream", EMars_ScreamingTurnip_ClipEnd::HoldLastFrame); }

            case EMars_ScreamingTurnip_Phase::Recover:
            { return FMars_ScreamingTurnip_PresentationClip("ROOT_Recover", EMars_ScreamingTurnip_ClipEnd::HoldLastFrame); }

            case EMars_ScreamingTurnip_Phase::RecoveryIdle:
            { return FMars_ScreamingTurnip_PresentationClip("ROOT_RecoveryIdle", EMars_ScreamingTurnip_ClipEnd::Loop); }

            case EMars_ScreamingTurnip_Phase::Dormant:
            { return FMars_ScreamingTurnip_PresentationClip("ROOT_QuietIdle", EMars_ScreamingTurnip_ClipEnd::Loop); }
        }
    }

    private void DoInitialize()
    {
        if (_Initialized)
        { return; }

        _Initialized = true;
        // CkUnrealComponent owns TickComponent; disable the engine's second scheduler.
        SetComponentTickEnabled(false);

        auto Mesh = constants_screaming_turnip_assets::TryLoad_SkeletalMesh();
        _HasMesh = ck::IsValid(Mesh);
        if (_HasMesh == false)
        {
            ck::Warning(f"[ScreamingTurnip] presentation has no skeletal mesh [{constants_screaming_turnip_assets::SkeletalMesh().ToString()}]: the static proxy stays");
            SetVisibility(false);
            return;
        }

        SetSkeletalMeshAsset(Mesh);
    }
}

// What a clip does when it reaches its end.
enum EMars_ScreamingTurnip_ClipEnd
{
    // Repeats; the component's loop clip from then on.
    Loop,
    // Stops on its last frame until something else plays.
    HoldLastFrame,
    // Plays once, then the component's loop clip again.
    ReturnToLoop
}

// What the presentation picks a clip from: the kernel's placement, phase and support, and the phase the current
// Anticipate was entered from (presentation memory).
struct FMars_ScreamingTurnip_PresentationQuery
{
    EMars_ScreamingTurnip_Placement Placement = EMars_ScreamingTurnip_Placement::Loose;
    EMars_ScreamingTurnip_Phase Phase = EMars_ScreamingTurnip_Phase::Dormant;
    bool HasSupport = false;
    EMars_ScreamingTurnip_Phase AnticipateFrom = EMars_ScreamingTurnip_Phase::Dormant;

    FMars_ScreamingTurnip_PresentationQuery() {}

    FMars_ScreamingTurnip_PresentationQuery(EMars_ScreamingTurnip_Placement InPlacement, EMars_ScreamingTurnip_Phase InPhase,
                                            bool InHasSupport, EMars_ScreamingTurnip_Phase InAnticipateFrom)
    {
        Placement = InPlacement;
        Phase = InPhase;
        HasSupport = InHasSupport;
        AnticipateFrom = InAnticipateFrom;
    }
}

// A clip stem, how it ends, the seconds it is stretched to span (unset: its authored length) and where it starts (0..1 of
// its length).
struct FMars_ScreamingTurnip_PresentationClip
{
    FString Clip;

    EMars_ScreamingTurnip_ClipEnd End = EMars_ScreamingTurnip_ClipEnd::Loop;

    TOptional<float32> SpanSeconds;

    float32 StartAlpha = 0.0f;

    FMars_ScreamingTurnip_PresentationClip() {}

    FMars_ScreamingTurnip_PresentationClip(const FString& InClip, EMars_ScreamingTurnip_ClipEnd InEnd)
    {
        Clip = InClip;
        End = InEnd;
    }

    FMars_ScreamingTurnip_PresentationClip(const FString& InClip, EMars_ScreamingTurnip_ClipEnd InEnd, float32 InSpanSeconds)
    {
        Clip = InClip;
        End = InEnd;
        SpanSeconds = TOptional<float32>(InSpanSeconds);
    }

    FMars_ScreamingTurnip_PresentationClip(const FString& InClip, EMars_ScreamingTurnip_ClipEnd InEnd, float32 InSpanSeconds,
                                           float32 InStartAlpha)
    {
        Clip = InClip;
        End = InEnd;
        SpanSeconds = TOptional<float32>(InSpanSeconds);
        StartAlpha = InStartAlpha;
    }
}
