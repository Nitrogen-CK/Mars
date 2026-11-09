// The Screaming Turnip's animated drawing: a skeletal mesh played through its anim blueprint (UMars_ScreamingTurnip_AnimInstance,
// constants_screaming_turnip_assets::AnimClass), one clip per kernel state. It follows the kernel
// (UMars_ScreamingTurnip_EntityScript forwards its phase and placement signals; the tick re-reads the kernel only to tell an
// airborne root from one rolling on the ground) and writes no gameplay state; no animation notify decides anything. A clip
// is (re)started only when the wanted clip changes, never per frame. A missing mesh, clip or anim blueprint warns once and
// changes nothing in gameplay: without the mesh the entity script keeps the static proxy visible, without a clip or the
// anim blueprint the mesh holds its bind pose (there is no second playback path). The bed
// (UMars_ScreamingTurnipBed_EntityScript) drives the same component with Play_Clip and Set_PullDrawing.
//
// This component is the single clip clock: _Time advances by the tick's seconds times the play rate, a Loop clip wraps,
// a one-shot clamps at its end; every tick it writes the clip (Sequence), its time (ClipTime) and the stretch's crown
// offset (CrownOffset) into the anim instance, whose graph evaluates the clip at that explicit time and adds the offset to
// the crown bone. Get_PlayedAlpha and the played-through checks read _Time, never the engine.
//
// How a clip ends is part of the play (EMars_ScreamingTurnip_ClipEnd): Loop repeats it and becomes the component's loop
// clip; HoldLastFrame stops on its last frame (the item's one-shots: the kernel's next wanted clip replaces it, so nothing
// here fights Refresh_FromKernel; the bed's scrubbed Tug holds its strain until the release swaps the visuals); ReturnToLoop
// plays the loop clip again once the one-shot has played through (the bed's Cancel -> SRC_Idle), polled in Tick.
//
// The warning's first clip depends on what was on screen before it: a root coming out of its recovery (RecoveryIdle, or
// Recover when one kernel pass skipped RecoveryIdle) plays ROOT_AnticipateTired, which starts on RecoveryIdle's first pose;
// one coming out of Dormant (QuietIdle) plays ROOT_Anticipate. The component remembers the phase it last drew and, on the
// change into Anticipate, which phase that came from (presentation state, not gameplay state); the per-tick re-read keeps
// that choice until the phase changes again, so a clip never flips mid-play.
//
// A play can be stretched (FMars_ScreamingTurnip_PresentationClip.SpanSeconds: the play rate is the clip's length over
// those seconds) and can start part-way (StartAlpha seeds the clock). A play of the stem already playing changes nothing,
// span and start included. Scrub_Clip holds a clip at a caller's alpha (rate 0; the bed's SRC_Tug follows the pull's
// alpha), so Get_PlayedAlpha reads the scrub alpha and the clip has not played through short of alpha 1.
//
// A pulled root (Set_PullDrawing: the bed's walk Control and its Pull.Stretch) is drawn from this tick's Control alpha, in
// this component's own tick: the Control ticks in FGroup_Gameplay_Script and this component in FGroup_PostTransform
// (FProcessor_UnrealComponent_Tick, which calls TickComponent: this tick, then TickPose and RefreshBoneTransforms), so
// the pose evaluated this frame is this frame's pull. While the pull shows SRC_Grip or SRC_Tug, SRC_Tug is scrubbed to
// the alpha once it moved or the Grip has played through. The stretch alpha follows the clip on screen: SRC_Tug's played
// alpha (the scrub; it holds after the threshold ends the grip, until the release hides the root), SRC_Cancel's mirror
// (1 - its played alpha), else 0. It maps to the crown offset (-Alpha * TravelCm, 0, Alpha * LiftCm) in the mesh's own
// space, the lean toward its -X (the Use side, as the clips are authored). The bounds widen with the travel (BoundsScale),
// so the leaves draw while the bulb is off-screen.
class UMars_ScreamingTurnipPresentationComponent : USkeletalMeshComponent
{
    default AnimationMode = EAnimationMode::AnimationBlueprint;
    default CollisionEnabled = ECollisionEnabled::NoCollision;
    default CastShadow = false;

    // Set by the owning item; invalid on the bed.
    private FCk_Handle_ScreamingTurnip _Turnip;
    private bool _Initialized = false;
    private bool _HasMesh = false;
    // The mesh's imported bounds' half-diagonal, cm: what the stretch's reach widens.
    private float64 _MeshExtentCm = 0.0;
    // Null without the anim blueprint (warned once): the mesh holds its bind pose.
    private UMars_ScreamingTurnip_AnimInstance _Anim;
    private bool _HasAnimClass = false;
    private FString _Clip;
    private EMars_ScreamingTurnip_ClipEnd _ClipEnd = EMars_ScreamingTurnip_ClipEnd::Loop;
    // The playing clip's sequence; null while none plays or its asset is missing.
    private UAnimSequenceBase _Sequence;
    // Seconds; zero while no sequence plays.
    private float32 _ClipLength = 0.0f;
    // The clock: seconds into the playing clip, and how many clip seconds pass per tick second (0 while scrubbed).
    private float32 _Time = 0.0f;
    private float32 _Rate = 1.0f;
    // The last Loop clip played: what a ReturnToLoop one-shot goes back to.
    private FMars_ScreamingTurnip_PresentationClip _LoopClip;
    private TArray<FString> _WarnedClips;
    // The pull this root draws; no Control and no travel on an item.
    private FMars_ScreamingTurnip_PullDrawing _Pull;
    // The travel and lift the bounds were last widened for; unset before the first.
    private TOptional<FVector> _BoundsReach;
    // The kernel phase the last refresh drew, and the phase the current (or last) Anticipate was entered from.
    private EMars_ScreamingTurnip_Phase _DrawnPhase = EMars_ScreamingTurnip_Phase::Dormant;
    private EMars_ScreamingTurnip_Phase _AnticipateFrom = EMars_ScreamingTurnip_Phase::Dormant;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    { DoInitialize(); }

    // Runs inside TickComponent before the pose ticks and evaluates (USkinnedMeshComponent::TickComponent: the component's
    // own tick, then TickPose and RefreshBoneTransforms), so the fields written here are this frame's.
    UFUNCTION(BlueprintOverride)
    void Tick(float InDeltaSeconds)
    {
        // Ck invokes this after scene transforms settle: keep the native component on the held node even when a stationary
        // carrier's child-offset update did not reach the ordinary dirty-transform push (as the Cookbook's does).
        auto ComponentHandle = utils_unreal_component::TryGet_OwningHandle_FromComponent(this);
        if (utils_unreal_component::Get_CanEnableTransformPush(ComponentHandle))
        { utils_unreal_component::Request_EnableTransformPush(ComponentHandle); }

        DoAdvance_Clock(float32(InDeltaSeconds));
        Refresh_FromKernel();
        DoReturn_ToLoopIfPlayedThrough();
        DoFollow_Pull();
        DoWrite_AnimInstance();
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

        return Math::Clamp(_Time / _ClipLength, 0.0f, 1.0f);
    }

    // The pull drawn from this component's next tick on (the bed's, once); the bounds widen when its reach changes. An
    // empty drawing (no Control, no travel) draws no stretch.
    void Set_PullDrawing(const FMars_ScreamingTurnip_PullDrawing& InPull)
    {
        _Pull = InPull;
        DoRefresh_Bounds();
    }

    // Starts InClip.Clip (HoldLastFrame, its span and start ignored) unless it is the one playing, and holds it at InAlpha
    // (0..1) of its length: the clock stops (rate 0) and every call moves it. A later Play_Clip of another stem plays at its
    // own rate.
    void Scrub_Clip(const FMars_ScreamingTurnip_PresentationClip& InClip, float32 InAlpha)
    {
        DoPlay(FMars_ScreamingTurnip_PresentationClip(InClip.Clip, EMars_ScreamingTurnip_ClipEnd::HoldLastFrame));
        if (_HasMesh == false || _Clip != InClip.Clip || _ClipLength <= 0.0f)
        { return; }

        _Rate = 0.0f;
        _Time = Math::Clamp(InAlpha, 0.0f, 1.0f) * _ClipLength;
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

    // Starts InClip.Clip (a clip stem, ROOT_QuietIdle) unless it is the one playing.
    void Play_Clip(const FMars_ScreamingTurnip_PresentationClip& InClip)
    {
        DoPlay(InClip);
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
        _Sequence = nullptr;
        _ClipLength = 0.0f;
        _Time = 0.0f;
        _Rate = 1.0f;
        if (InClip.End == EMars_ScreamingTurnip_ClipEnd::Loop)
        { _LoopClip = InClip; }

        auto Sequence = constants_screaming_turnip_assets::TryLoad_Clip(InClip.Clip);
        if (ck::Is_NOT_Valid(Sequence))
        {
            if (_WarnedClips.Contains(InClip.Clip) == false)
            {
                _WarnedClips.Add(InClip.Clip);
                ck::Warning(f"[ScreamingTurnip] presentation has no clip [{constants_screaming_turnip_assets::Clip(InClip.Clip).ToString()}]: holding the bind pose");
            }

            return;
        }

        _Sequence = Sequence;
        _ClipLength = Sequence.GetPlayLength();
        if (InClip.SpanSeconds.IsSet() && _ClipLength > 0.0f)
        { _Rate = _ClipLength / InClip.SpanSeconds.GetValue(); }

        _Time = Math::Clamp(InClip.StartAlpha, 0.0f, 1.0f) * _ClipLength;
    }

    // A Loop clip wraps; a one-shot clamps at its end.
    private void DoAdvance_Clock(float32 InDeltaSeconds)
    {
        if (_ClipLength <= 0.0f || _Rate == 0.0f)
        { return; }

        _Time += InDeltaSeconds * _Rate;
        if (_ClipEnd == EMars_ScreamingTurnip_ClipEnd::Loop)
        {
            _Time = float32(Math::Fmod(_Time, _ClipLength));
            return;
        }

        _Time = Math::Clamp(_Time, 0.0f, _ClipLength);
    }

    // Whether the playing one-shot reached its end; a Loop clip never has, nor has a clip whose sequence is missing.
    private bool Get_HasPlayedThrough() const
    {
        if (_ClipLength <= 0.0f || _ClipEnd == EMars_ScreamingTurnip_ClipEnd::Loop)
        { return false; }

        return _Time >= _ClipLength;
    }

    // A ReturnToLoop one-shot that has played through hands back to the loop clip. A one-shot whose sequence is missing
    // never played, so it never returns.
    private void DoReturn_ToLoopIfPlayedThrough()
    {
        if (_ClipEnd != EMars_ScreamingTurnip_ClipEnd::ReturnToLoop || _LoopClip.Clip.IsEmpty() || Get_HasPlayedThrough() == false)
        { return; }

        Play_Clip(_LoopClip);
    }

    // A gripped pull scrubs SRC_Tug to the Control's alpha of this frame (the Control ticked before this component did).
    private void DoFollow_Pull()
    {
        if (ck::Is_NOT_Valid(_Pull.Control))
        { return; }

        const auto Alpha = _Pull.Control.TryGet_ManipulationAlpha();
        if (Alpha.IsSet() == false)
        { return; }

        const auto InTug = _Clip == constants_screaming_turnip_assets::k_Clip_Tug;
        const auto InGrip = _Clip == constants_screaming_turnip_assets::k_Clip_Grip;
        const auto GripOver = InGrip && (Alpha.GetValue() > 0.0f || Get_PlayedAlpha() >= 1.0f);
        if (InTug == false && GripOver == false)
        { return; }

        Scrub_Clip(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Tug,
            EMars_ScreamingTurnip_ClipEnd::HoldLastFrame), Alpha.GetValue());
    }

    // The stretch the clip on screen draws: SRC_Tug's scrub, SRC_Cancel's mirror of it, else none.
    private float32 Get_StretchAlpha() const
    {
        if (_Clip == constants_screaming_turnip_assets::k_Clip_Tug)
        { return Get_PlayedAlpha(); }

        if (_Clip == constants_screaming_turnip_assets::k_Clip_Cancel)
        { return 1.0f - Get_PlayedAlpha(); }

        return 0.0f;
    }

    // The clip, its time and the crown offset into the anim instance (fetched again until the anim blueprint gave one).
    private void DoWrite_AnimInstance()
    {
        if (_HasAnimClass == false)
        { return; }

        if (ck::Is_NOT_Valid(_Anim))
        { _Anim = Cast<UMars_ScreamingTurnip_AnimInstance>(GetAnimInstance()); }

        if (ck::Is_NOT_Valid(_Anim))
        { return; }

        const auto Alpha = Get_StretchAlpha();
        _Anim.Set_Pose(_Sequence, _Time, FVector(-Alpha * _Pull.TravelCm, 0.0, Alpha * _Pull.LiftCm));
    }

    // BoundsScale grows the mesh's bounds about their centre: the extent plus the stretch's full reach, over the extent.
    private void DoRefresh_Bounds()
    {
        if (_HasMesh == false || _MeshExtentCm <= 0.0)
        { return; }

        const auto Reach = FVector(_Pull.TravelCm, 0.0, _Pull.LiftCm);
        if (_BoundsReach.IsSet() && _BoundsReach.GetValue().Equals(Reach))
        { return; }

        _BoundsReach = TOptional<FVector>(Reach);
        const auto ReachCm = Reach.Size();
        SetBoundsScale(float32(Math::Max(1.0, (_MeshExtentCm + ReachCm) / _MeshExtentCm)));
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

    // The mesh, then the anim blueprint (warned once if it is not saved yet: the mesh holds its bind pose).
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
        _MeshExtentCm = Mesh.GetImportedBounds().BoxExtent.Size();

        auto AnimClass = constants_screaming_turnip_assets::TryLoad_AnimClass();
        _HasAnimClass = ck::IsValid(AnimClass);
        if (_HasAnimClass == false)
        {
            ck::Warning(f"[ScreamingTurnip] presentation has no anim blueprint [{constants_screaming_turnip_assets::AnimClass().ToSoftObjectPath().ToString()}]: the mesh holds its bind pose");
            return;
        }

        // Sets AnimationMode to AnimationBlueprint and initialises the instance (USkeletalMeshComponent::SetAnimInstanceClass).
        SetAnimInstanceClass(AnimClass);
        _Anim = Cast<UMars_ScreamingTurnip_AnimInstance>(GetAnimInstance());
    }
}

// The pull a planted root draws: the bed's walk Control (its alpha scrubs SRC_Tug) and the bed's Pull.Stretch (the crown
// offset at alpha 1: TravelCm toward the mesh's -X, LiftCm up). The default draws nothing.
struct FMars_ScreamingTurnip_PullDrawing
{
    FCk_Handle_Control Control;

    float32 TravelCm = 0.0f;

    float32 LiftCm = 0.0f;

    FMars_ScreamingTurnip_PullDrawing() {}

    FMars_ScreamingTurnip_PullDrawing(FCk_Handle_Control InControl, float32 InTravelCm, float32 InLiftCm)
    {
        Control = InControl;
        TravelCm = InTravelCm;
        LiftCm = InLiftCm;
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
