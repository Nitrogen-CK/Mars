// A cast to work out: from Origin, along the unit horizontal Forward, at PitchDeg above level, to land DistanceCm out on
// the water plane at SurfaceZ under GravityCmPerS2.
struct FMars_Fishing_CastQuery
{
    FVector Origin;
    FVector Forward;
    float32 PitchDeg = 35.0f;
    float32 DistanceCm = 500.0f;
    float32 GravityCmPerS2 = 980.0f;
    float64 SurfaceZ = 0.0;
}

namespace utils_fishing
{
    // Composes the fishing spot on InHandle (the station entity; the feature does not need the Station feature). Every
    // clock is the kernel's; what draws the rod, line, bait and fish follows its state and signals. A rejected spec ensures
    // and returns an invalid handle.
    FCk_Handle_Fishing Add(FCk_Handle& InHandle, FMars_Fishing_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Fishing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Fishing(); }

        auto Params = FMars_Fragment_Fishing_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Fishing();
        State.Rng = Make_Seed(InSpec.Seed);
        State.Presence = InSpec.Presence.StartOpen ? EMars_Fishing_Presence::Open : EMars_Fishing_Presence::Arriving;
        State.Clock.PresenceLeft = InSpec.Presence.StartOpen ? 0.0f : InSpec.Presence.ArriveSeconds;

        InHandle.Add_Fragment(FMars_Feature_Fishing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        if (InSpec.Presence.StartOpen == false)
        { InHandle.Add_Fragment(FMars_Tag_Fishing_Transitioning()); }

        return InHandle.As_Fishing();
    }

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // A non-zero xorshift state from a seed.
    uint32 Make_Seed(int32 InSeed)
    {
        uint32 X = uint32(InSeed) * uint32(2654435761);
        X = X ^ (X >> 16);
        X = X * uint32(0x7feb352d);
        X = X ^ (X >> 15);
        return X == 0 ? uint32(0x9e3779b9) : X;
    }

    // The next draw in [0, 1), advancing the state (xorshift32).
    float32 Next_Unit(uint32& InOutRng)
    {
        uint32 X = InOutRng;
        X = X ^ (X << 13);
        X = X ^ (X >> 17);
        X = X ^ (X << 5);
        InOutRng = X;
        return float32(float64(X >> 8) / 16777216.0);
    }

    float32 Next_Range(uint32& InOutRng, float32 InMin, float32 InMax)
    {
        return Math::Lerp(InMin, InMax, Next_Unit(InOutRng));
    }

    // A weighted draw from the table (the table is non-empty: Validate).
    FMars_Fishing_FishEntry Draw_Fish(const TArray<FMars_Fishing_FishEntry>& InTable, uint32& InOutRng)
    {
        float32 Total = 0.0f;
        for (const auto& Entry : InTable)
        { Total += Entry.Weight; }

        auto Pick = Next_Unit(InOutRng) * Total;
        for (const auto& Entry : InTable)
        {
            Pick -= Entry.Weight;
            if (Pick < 0.0f)
            { return Entry; }
        }

        return InTable[InTable.Num() - 1];
    }

    // The launch velocity that lands the bait DistanceCm out on the plane: v^2 = g d^2 / (2 cos^2(p) (h + d tan(p))) with
    // h the drop from the origin to the water. An origin under the water (h + d tan p <= 0) launches level at a minimum.
    FVector Make_LaunchVelocity(const FMars_Fishing_CastQuery& InQuery)
    {
        const auto Pitch = Math::DegreesToRadians(InQuery.PitchDeg);
        const auto CosP = Math::Cos(Pitch);
        const auto SinP = Math::Sin(Pitch);
        const auto Drop = InQuery.Origin.Z - InQuery.SurfaceZ;
        const auto Reach = Drop + InQuery.DistanceCm * (SinP / CosP);
        const auto Denominator = 2.0 * CosP * CosP * Math::Max(Reach, 1.0);
        const auto Speed = Math::Sqrt(InQuery.GravityCmPerS2 * InQuery.DistanceCm * InQuery.DistanceCm / Denominator);
        return InQuery.Forward * (Speed * CosP) + FVector::UpVector * (Speed * SinP);
    }

    // The aim's unit horizontal direction in the world: the frame's X turned by the aim's yaw.
    FVector Make_AimForward(const FTransform& InFrame, float32 InYawDeg)
    {
        const auto Local = FRotator(0.0, InYawDeg, 0.0).RotateVector(FVector::ForwardVector);
        auto Forward = InFrame.GetRotation().RotateVector(Local);
        Forward.Z = 0.0;
        return Forward.GetSafeNormal(0.0001, FVector::ForwardVector);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Fishing_Spec Get_Spec(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing_Params).Spec;
}

mixin EMars_Fishing_Phase Get_Phase(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Phase;
}

mixin EMars_Fishing_Presence Get_Presence(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Presence;
}

// 0..1 of the spot's being here: fading in while Arriving, 1 while Open, fading out while Leaving, 0 once Gone.
mixin float32 Get_PresenceAlpha(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    const auto Presence = Self.Get_Spec().Presence;
    switch (State.Presence)
    {
        case EMars_Fishing_Presence::Arriving: return 1.0f - Math::Clamp(State.Clock.PresenceLeft / Presence.ArriveSeconds, 0.0f, 1.0f);
        case EMars_Fishing_Presence::Leaving: return Math::Clamp(State.Clock.PresenceLeft / Presence.LeaveSeconds, 0.0f, 1.0f);
        case EMars_Fishing_Presence::Gone: return 0.0f;
        default: return 1.0f;
    }
}

mixin EMars_Fishing_Reel Get_Reel(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Reel;
}

mixin FMars_Fishing_Aim Get_Aim(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Aim;
}

mixin FMars_Fishing_Bait Get_Bait(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Bait;
}

mixin FMars_Fishing_Line Get_Line(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line;
}

mixin float32 Get_Tension(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line.Tension;
}

mixin float32 Get_LineLengthCm(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line.LengthCm;
}

mixin bool Get_IsRunning(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Run.Running;
}

mixin FMars_Fishing_Catch Get_Catch(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Catch;
}

mixin int32 Get_Tally(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Tally;
}

// Seconds into the current phase.
mixin float32 Get_PhaseSeconds(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Clock.PhaseSeconds;
}

// An operator is working the spot: its clocks run.
mixin bool Get_IsEngaged(const FCk_Handle_Fishing& Self)
{
    return Self.Has_Fragment(FMars_Tag_Fishing_Engaged);
}

// A line is out: the bait is in the air or on the water, or a fish is on.
mixin bool Get_HasLineOut(const FCk_Handle_Fishing& Self)
{
    const auto Phase = Self.Get_Phase();
    return Phase != EMars_Fishing_Phase::Idle && Phase != EMars_Fishing_Phase::Landed && Phase != EMars_Fishing_Phase::Snapped;
}

mixin FVector Get_AnchorWorld(const FCk_Handle_Fishing& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Spec().Setup.Anchor);
}

mixin FVector Get_CatchWorld(const FCk_Handle_Fishing& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Spec().Setup.Catch);
}

// The bait as drawn: its kernel position with the float's bob and a bite's dip, once it is on the water.
mixin FVector Get_BaitWorld(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    if (State.Phase == EMars_Fishing_Phase::Casting || State.Phase == EMars_Fishing_Phase::Idle)
    { return State.Bait.Position; }

    const auto Bob = Self.Get_Spec().Water.BobAmpCm * Math::Sin(State.Bait.BobPhase);
    return State.Bait.Position + FVector(0.0, 0.0, Bob - State.Bait.DipCm);
}

// 0..1 of the landed fish's fling from the water to the catch point (1 once Landed and arrived, 0 before Landed).
mixin float32 Get_FlingAlpha(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    if (State.Phase != EMars_Fishing_Phase::Landed)
    { return 0.0f; }

    const auto Fling = Self.Get_Spec().Fish.LandFlingSeconds;
    return 1.0f - Math::Clamp(State.Catch.FlingLeft / Fling, 0.0f, 1.0f);
}

// The landed fish as drawn: an arc from where it left the water to the catch point, LandArcHeightCm high at its middle.
mixin FVector Get_FishWorld(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    const auto Alpha = Self.Get_FlingAlpha();
    const auto Eased = 0.5f - 0.5f * Math::Cos(PI * Alpha);
    const auto Height = Self.Get_Spec().Fish.LandArcHeightCm * Math::Sin(PI * Eased);
    const auto Catch = Self.Get_CatchWorld();
    return State.Catch.LandedAt + (Catch - State.Catch.LandedAt) * float64(Eased) + FVector(0.0, 0.0, Height);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Engage(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Engage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.EngageRequests.Add(InRequest);
}

mixin void Request_Disengage(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Disengage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.DisengageRequests.Add(InRequest);
}

mixin void Request_Leave(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Leave& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.LeaveRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_ForceBite(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ForceBite& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ForceBiteRequests.Add(InRequest);
}

mixin void Request_ForceLand(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ForceLand& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ForceLandRequests.Add(InRequest);
}

mixin void Request_Aim(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Aim& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.AimRequests.Add(InRequest);
}

mixin void Request_Cast(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Cast& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.CastRequests.Add(InRequest);
}

mixin void Request_Hook(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Hook& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.HookRequests.Add(InRequest);
}

mixin void Request_ReelHold(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ReelHold& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ReelHoldRequests.Add(InRequest);
}

mixin void Request_ReelRelease(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ReelRelease& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ReelReleaseRequests.Add(InRequest);
}

mixin void Request_Collect(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Collect& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.CollectRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPresenceChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPresenceChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnPresenceChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPresenceChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPresenceChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPresenceChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCast(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCast InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnCast.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCast(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCast InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCast.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBaitLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBaitLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBaitLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBaitLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBaitLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBaitLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBite(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBite InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBite.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBite(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBite InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBite.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBiteEnded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBiteEnded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBiteEnded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBiteEnded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBiteEnded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBiteEnded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRun(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnRun InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnRun.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRun(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnRun InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnRun.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSnapped(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnSnapped InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnSnapped.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSnapped(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnSnapped InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnSnapped.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCollected(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCollected InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnCollected.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCollected(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCollected InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCollected.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
