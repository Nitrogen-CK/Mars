namespace utils_mortar
{
    // Composes the mortar on InHandle (the station entity; the feature does not need the Station feature) with a fresh batch
    // of the spec's StartSeasoning. Every clock is the kernel's; what draws the pestle, the pile and the meter follows its
    // state and signals. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_Mortar Add(FCk_Handle& InHandle, FMars_Mortar_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Mortar] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Mortar(); }

        auto Params = FMars_Fragment_Mortar_Params();
        Params.Spec = InSpec;

        // A copy without authority can receive the replicated ledger before it composes: the arrived ledger stands then,
        // and a mortar first read mid-batch shows that batch and raises nothing.
        if (InHandle.Has_Fragment(FMars_Fragment_Mortar_Net) == false)
        {
            auto Fresh = FMars_Fragment_Mortar_Net();
            Fresh.Batch.Seasoning = InSpec.StartSeasoning;
            InHandle.Add_Fragment(Fresh, ECk_Replication::Replicates);
        }

        const auto Ledger = InHandle.Get_Fragment(FMars_Fragment_Mortar_Net);
        auto State = FMars_Fragment_Mortar();
        State.Batch.Seasoning = InSpec.StartSeasoning;
        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            const auto Shown = Get_Shown(InHandle, Ledger, InSpec);
            State.Batch = Shown.Batch;
            State.Tally = Shown.Tally;
            State.Pestle.Motion = Shown.Pestle.Motion;
            State.SweepSeconds = Shown.SweepSeconds;
        }

        auto Local = FMars_Fragment_Mortar_Local();
        Local.Last = TOptional<FMars_Fragment_Mortar_Net>(Ledger);

        InHandle.Add_Fragment(FMars_Feature_Mortar());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Mortar_NeedsMirror());
        if (utils_net::Get_HasAuthority(InHandle) == false && Ledger.Engagement == EMars_Mortar_Engagement::Engaged)
        { InHandle.Add_Fragment(FMars_Tag_Mortar_Engaged()); }

        return InHandle.As_Mortar();
    }

    // What a copy without authority shows from InLedger now: the ledger's batch, tally and motion, the grind's progress
    // carried on from the anchor while the pestle circles (capped at 1), and the sweep carried on from the anchor while
    // engaged in the Crush phase. The seconds since the anchor are on the server's clock and never negative. Only the
    // state's Batch, Tally, Pestle.Motion and SweepSeconds are meaningful.
    FMars_Fragment_Mortar Get_Shown(const FCk_Handle& InHandle, const FMars_Fragment_Mortar_Net& InLedger, const FMars_Mortar_Spec& InSpec)
    {
        const auto Elapsed = float32(Math::Max(utils_mars_net::Get_ServerWorldSeconds(InHandle) - InLedger.AnchorServerSeconds, 0.0));

        auto Shown = FMars_Fragment_Mortar();
        Shown.Batch = InLedger.Batch;
        Shown.Tally = InLedger.Tally;
        Shown.Pestle.Motion = InLedger.Motion;
        if (InLedger.Motion == EMars_Mortar_Pestle::Grinding)
        { Shown.Batch.GrindProgress = Get_AdvancedGrind(InLedger.Batch.GrindProgress, InSpec, Elapsed); }

        const auto IsRunning = InLedger.Engagement == EMars_Mortar_Engagement::Engaged && InLedger.Batch.Phase == EMars_Mortar_Phase::Crush;
        Shown.SweepSeconds = IsRunning ? Get_AdvancedSweep(InLedger.SweepAtAnchor, InSpec.Timing, Elapsed) : InLedger.SweepAtAnchor;
        return Shown;
    }

    // The sweep InDeltaSeconds on from InSweepSeconds, wrapped into the pass: the one advance of the timing window, with
    // authority and without.
    float32 Get_AdvancedSweep(float32 InSweepSeconds, const FMars_Mortar_TimingSpec& InTiming, float32 InDeltaSeconds)
    {
        return Get_WrappedSweep(InSweepSeconds + InDeltaSeconds, InTiming);
    }

    // The grind's progress InDeltaSeconds of grinding on from InProgress, capped at 1: the one advance of the grind, with
    // authority and without.
    float32 Get_AdvancedGrind(float32 InProgress, const FMars_Mortar_Spec& InSpec, float32 InDeltaSeconds)
    {
        return Math::Min(1.0f, InProgress + InDeltaSeconds / InSpec.GrindSeconds);
    }

    // InSeconds wrapped into [0, Timing.SweepSeconds).
    float32 Get_WrappedSweep(float32 InSeconds, const FMars_Mortar_TimingSpec& InTiming)
    {
        auto Wrapped = float32(Math::Fmod(InSeconds, InTiming.SweepSeconds));
        if (Wrapped < 0.0f)
        { Wrapped += InTiming.SweepSeconds; }

        if (Wrapped >= InTiming.SweepSeconds)
        { Wrapped = 0.0f; }

        return Wrapped;
    }

    // The sweep a press is judged at: the operator's observed sweep wrapped into the pass when it is set and finite, else
    // the kernel's own InKernelSweep.
    float32 Get_JudgedSweep(const FMars_Request_Mortar_Pestle& InRequest, const FMars_Mortar_TimingSpec& InTiming, float32 InKernelSweep)
    {
        if (InRequest.ObservedSweepSeconds.IsSet() == false || Math::IsFinite(InRequest.ObservedSweepSeconds.GetValue()) == false)
        { return InKernelSweep; }

        return Get_WrappedSweep(InRequest.ObservedSweepSeconds.GetValue(), InTiming);
    }

    // The ledger a copy without authority reads the mortar through, from the live state and what the caller announced:
    // written and marked dirty only when the engagement, the batch's seasoning, stage, phase or hits, the pestle's motion,
    // the tally or an answer differ. A write stamps the anchor (the server's clock, the sweep and the grind's progress now)
    // and adds the serials. Called only by the mortar's processors on the authority, by the drain once after its last
    // apply and its tag move and by the tick after its step, each before its broadcasts. Reads the state through the handle.
    void Publish(FCk_Handle_Mortar& InMortar, const FMars_Mortar_Answers& InAnswers)
    {
        const auto State = InMortar.Get_Fragment(FMars_Fragment_Mortar);
        const auto Ledger = InMortar.Get_Fragment(FMars_Fragment_Mortar_Net);
        const auto Engagement = InMortar.Get_IsEngaged() ? EMars_Mortar_Engagement::Engaged : EMars_Mortar_Engagement::Idle;

        const auto HasAnswer = InAnswers.StrikesStarted > 0 || InAnswers.Landed.IsSet() || InAnswers.Sweep == EMars_Mortar_Sweep::Restarted;
        const auto IsSame = HasAnswer == false && Engagement == Ledger.Engagement
            && State.Batch.Seasoning == Ledger.Batch.Seasoning && State.Batch.Stage == Ledger.Batch.Stage
            && State.Batch.Phase == Ledger.Batch.Phase && State.Batch.CrushHits == Ledger.Batch.CrushHits
            && State.Pestle.Motion == Ledger.Motion && Get_IsSameTally(State.Tally, Ledger.Tally);
        if (IsSame)
        { return; }

        auto Next = Ledger;
        Next.Engagement = Engagement;
        Next.Batch = State.Batch;
        Next.Motion = State.Pestle.Motion;
        Next.Tally = State.Tally;
        Next.AnchorServerSeconds = utils_mars_net::Get_ServerWorldSeconds(InMortar);
        Next.SweepAtAnchor = State.SweepSeconds;
        Next.StrikeSerial += InAnswers.StrikesStarted;
        if (InAnswers.Sweep == EMars_Mortar_Sweep::Restarted)
        { Next.SweepSerial += 1; }

        if (InAnswers.Landed.IsSet())
        {
            Next.LandedSerial += 1;
            Next.LastLanded = InAnswers.Landed.GetValue();
        }

        InMortar.Get_Fragment(FMars_Fragment_Mortar_Net) = Next;
        FCk_Handle Entity = InMortar;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Mortar_Net);
    }

    bool Get_IsSameTally(const FMars_Mortar_Tally& InA, const FMars_Mortar_Tally& InB)
    {
        if (InA.Counts.Num() != InB.Counts.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.Counts.Num(); ++Index)
        {
            if (InA.Counts[Index] != InB.Counts[Index])
            { return false; }
        }

        return true;
    }

    // Whether InOperator may work InMortar's pestle: the station on InMortar's entity is operated by InOperator. A Mortar
    // with no Station on its entity answers no.
    bool Get_MayWorkFor(const FCk_Handle_Mortar& InMortar, FCk_Handle InOperator)
    {
        const auto Station = InMortar.H().As_Station(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Station) && Station.Get_IsOperatedBy(InOperator);
    }

    // InAct's edge of the pestle at InMortar. A Mortar with a replication driver is reached through Cue.Mars.Mortar.Pestle,
    // which only its authority applies; a local one has no other machine to reach and takes the request directly. Either
    // way the edge is refused unless InAct's operator operates the station.
    void Request_PestleFor(FCk_Handle_Mortar& InMortar, const FMars_Mortar_PestleAct& InAct)
    {
        if (utils_entity_replication_driver::Has(InMortar))
        {
            utils_cue_generic::Request_ExecuteCue(InMortar, GameplayTags::Cue_Mars_Mortar_Pestle, InAct,
                ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
            return;
        }

        if (Get_MayWorkFor(InMortar, InAct.Operator))
        { InMortar.Request_Pestle(Make_PestleRequest(InAct)); }
    }

    // The request an act becomes: a press with the sweep it saw, or a release, either with the act's sequence.
    FMars_Request_Mortar_Pestle Make_PestleRequest(const FMars_Mortar_PestleAct& InAct)
    {
        auto Sweep = TOptional<float32>();
        if (InAct.Verb == EMars_Mortar_PestleVerb::Press)
        { Sweep = InAct.SweepSeconds; }

        return FMars_Request_Mortar_Pestle(InAct.Verb, Sweep, InAct.Sequence);
    }

    // InRequests in the order they were made: those with no sequence (this machine's own reader) as issued, then those with
    // one by ascending sequence, ties as issued. A remote operator's acts are separate messages, and those that reach the
    // authority together are not applied in the order sent. Sequences are compared within one drain only: a re-seated
    // operator's count may start again.
    TArray<FMars_Request_Mortar_Pestle> Get_InOrderMade(const TArray<FMars_Request_Mortar_Pestle>& InRequests)
    {
        TArray<FMars_Request_Mortar_Pestle> Ordered;
        for (const auto& Request : InRequests)
        {
            if (Request.Sequence.IsSet() == false)
            { Ordered.Add(Request); }
        }

        const auto Unsequenced = Ordered.Num();
        for (const auto& Request : InRequests)
        {
            if (Request.Sequence.IsSet() == false)
            { continue; }

            auto Index = Ordered.Num();
            while (Index > Unsequenced && Ordered[Index - 1].Sequence.GetValue() > Request.Sequence.GetValue())
            { --Index; }

            Ordered.Insert(Request, Index);
        }

        return Ordered;
    }

    // The timing bar InSweepSeconds into a pass: the window enters from off the bar's left end and leaves off its right.
    FMars_Mortar_Window Make_Window(const FMars_Mortar_TimingSpec& InTiming, float32 InSweepSeconds)
    {
        auto Window = FMars_Mortar_Window();
        Window.HalfWidth = InTiming.WindowHalfWidth;
        Window.Marker = InTiming.Marker;
        Window.Centre = -InTiming.WindowHalfWidth + (1.0f + 2.0f * InTiming.WindowHalfWidth) * (InSweepSeconds / InTiming.SweepSeconds);
        return Window;
    }

    // A strike pressed now is a hit.
    bool Get_IsOnMarker(const FMars_Mortar_Window& InWindow)
    {
        return Math::Abs(InWindow.Centre - InWindow.Marker) <= InWindow.HalfWidth;
    }

    // As loaded: nothing has been done to the batch yet.
    bool Get_IsFresh(const FMars_Mortar_Batch& InBatch)
    {
        return InBatch.Phase == EMars_Mortar_Phase::Crush && InBatch.CrushHits == 0;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Mortar_Spec Get_Spec(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar_Params).Spec;
}

mixin FMars_Mortar_Batch Get_Batch(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar).Batch;
}

mixin FMars_Mortar_Tally Get_Tally(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar).Tally;
}

// Whether the pestle is circling in the bowl.
mixin EMars_Mortar_Pestle Get_Pestle(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar).Pestle.Motion;
}

mixin EMars_Mortar_StrikePhase Get_StrikePhase(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar).Pestle.StrikePhase;
}

// An operator is working the mortar: its clocks run.
mixin bool Get_IsEngaged(const FCk_Handle_Mortar& Self)
{
    return Self.Has_Fragment(FMars_Tag_Mortar_Engaged);
}

// The timing window's seconds into its pass as this machine shows it.
mixin float32 Get_SweepSeconds(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar).SweepSeconds;
}

// The replicated ledger as it stands on this machine.
mixin FMars_Fragment_Mortar_Net Get_Ledger(const FCk_Handle_Mortar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mortar_Net);
}

// The timing bar as it stands now.
mixin FMars_Mortar_Window Get_Window(const FCk_Handle_Mortar& Self)
{
    return utils_mortar::Make_Window(Self.Get_Spec().Timing, Self.Get_Fragment(FMars_Fragment_Mortar).SweepSeconds);
}

// 0..1 of the whole batch: the crush is the first half, the grind the second.
mixin float32 Get_Progress(const FCk_Handle_Mortar& Self)
{
    const auto Batch = Self.Get_Batch();
    if (Batch.Phase == EMars_Mortar_Phase::Done)
    { return 1.0f; }

    if (Batch.Phase == EMars_Mortar_Phase::Grind)
    { return 0.5f + 0.5f * Batch.GrindProgress; }

    return 0.5f * float32(Batch.CrushHits) / float32(Self.Get_Spec().CrushesNeeded);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Engage(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Engage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.EngageRequests.Add(InRequest);
}

mixin void Request_Disengage(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Disengage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.DisengageRequests.Add(InRequest);
}

// Applied in the order issued.
mixin void Request_Pestle(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Pestle& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.PestleRequests.Add(InRequest);
}

mixin void Request_Collect(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Collect& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.CollectRequests.Add(InRequest);
}

mixin void Request_SwitchSeasoning(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_SwitchSeasoning& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.SwitchSeasoningRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnStrikeStarted(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnStrikeStarted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Signals);
    Fragment.OnStrikeStarted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStrikeStarted(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnStrikeStarted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Mortar_Signals).OnStrikeStarted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnStrikeLanded(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnStrikeLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Signals);
    Fragment.OnStrikeLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStrikeLanded(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnStrikeLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Mortar_Signals).OnStrikeLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBatchChanged(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnBatchChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Signals);
    Fragment.OnBatchChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBatchChanged(FCk_Handle_Mortar& Self, FMars_Delegate_Mortar_OnBatchChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Mortar_Signals).OnBatchChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
