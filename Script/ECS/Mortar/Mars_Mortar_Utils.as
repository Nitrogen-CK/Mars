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

        auto State = FMars_Fragment_Mortar();
        State.Batch.Seasoning = InSpec.StartSeasoning;

        InHandle.Add_Fragment(FMars_Feature_Mortar());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Mortar();
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

mixin void Request_Press(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Press& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.PressRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_Mortar& Self, const FMars_Request_Mortar_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mortar_Requests);
    Requests.ReleaseRequests.Add(InRequest);
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
