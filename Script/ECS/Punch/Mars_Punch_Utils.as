namespace utils_punch
{
    // The fists of InOwner. Blows go through InOwner's DamageDealer and leave from its PlayerViewpoint (its own transform
    // without one); an owner with no dealer jabs and hits nothing. A spec that fails Validate() adds nothing.
    FCk_Handle_Punch Add(FCk_Handle& InOwner, FMars_Punch_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Punch] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Punch(); }

        auto Params = FMars_Fragment_Punch_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Punch();
        State.NextHand = InSpec.LeadHand;

        InOwner.Add_Fragment(FMars_Feature_Punch());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(State);
        return InOwner.As_Punch();
    }

    EMars_Hand Get_OtherHand(EMars_Hand InHand)
    {
        return InHand == EMars_Hand::Left ? EMars_Hand::Right : EMars_Hand::Left;
    }

    // From a throw until the fist is home again.
    float32 Get_JabSeconds(const FMars_Punch_Rhythm& InRhythm)
    {
        return InRhythm.ImpactSeconds + InRhythm.RecoverySeconds;
    }

    // The stroke of a fist thrown InElapsed seconds ago.
    EMars_Punch_Stroke Get_StrokeAt(const FMars_Punch_Rhythm& InRhythm, float32 InElapsed)
    {
        if (InElapsed < InRhythm.ImpactSeconds)
        { return EMars_Punch_Stroke::Out; }

        if (InElapsed < Get_JabSeconds(InRhythm))
        { return EMars_Punch_Stroke::Back; }

        return EMars_Punch_Stroke::None;
    }

    // How far InFist is through its current stroke, 0..1, linear in time. 0 at home.
    float32 Get_StrokeAlpha(const FMars_Punch_Rhythm& InRhythm, const FMars_Punch_Fist& InFist)
    {
        if (InFist.Stroke == EMars_Punch_Stroke::Out)
        { return Math::Clamp(InFist.Elapsed / Math::Max(InRhythm.ImpactSeconds, KINDA_SMALL_NUMBER), 0.0f, 1.0f); }

        if (InFist.Stroke == EMars_Punch_Stroke::Back)
        { return Math::Clamp((InFist.Elapsed - InRhythm.ImpactSeconds) / Math::Max(InRhythm.RecoverySeconds, KINDA_SMALL_NUMBER), 0.0f, 1.0f); }

        return 0.0f;
    }

    // How far InFist is from home, 0..1, linear in time: out to 1 at the blow, back to 0 over the recovery.
    float32 Get_Extension(const FMars_Punch_Rhythm& InRhythm, const FMars_Punch_Fist& InFist)
    {
        const auto Alpha = Get_StrokeAlpha(InRhythm, InFist);
        if (InFist.Stroke == EMars_Punch_Stroke::Out)
        { return Alpha; }

        if (InFist.Stroke == EMars_Punch_Stroke::Back)
        { return 1.0f - Alpha; }

        return 0.0f;
    }

    // A throw can start now: the interval since the last jab has passed and the next hand's fist is home.
    bool Get_CanThrow(const FMars_Punch_Rhythm& InRhythm, const FMars_Fragment_Punch& InState)
    {
        if (InState.SinceThrow.IsSet() && InState.SinceThrow.GetValue() < InRhythm.IntervalSeconds)
        { return false; }

        const auto Stroke = InState.NextHand == EMars_Hand::Left ? InState.Left.Stroke : InState.Right.Stroke;
        return Stroke == EMars_Punch_Stroke::None;
    }

    // Both fists are home.
    bool Get_AreFistsHome(const FMars_Fragment_Punch& InState)
    {
        return InState.Left.Stroke == EMars_Punch_Stroke::None && InState.Right.Stroke == EMars_Punch_Stroke::None;
    }

    // Throws InHand's fist from the start of its jab; the next throw uses the other hand. Called by the feature's
    // processors only.
    void Start_Jab(FMars_Fragment_Punch& InOutState, EMars_Hand InHand, bool InDealsBlow)
    {
        auto Fist = FMars_Punch_Fist();
        Fist.Stroke = EMars_Punch_Stroke::Out;
        Fist.DealsBlow = InDealsBlow;

        if (InHand == EMars_Hand::Left)
        { InOutState.Left = Fist; }
        else
        { InOutState.Right = Fist; }

        InOutState.NextHand = Get_OtherHand(InHand);
        InOutState.SinceThrow = TOptional<float32>(0.0f);
        InOutState.JabsThrown += 1;
    }

    // Where InThrower's blows leave from: its view, or its own transform without a PlayerViewpoint (a test rig).
    FTransform Get_BlowOrigin(const FCk_Handle& InThrower)
    {
        auto Thrower = InThrower;
        auto Viewpoint = Thrower.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        { return utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint()); }

        return utils_transform::Get_EntityCurrentTransform(Thrower.As_Transform());
    }
}

// Finite, non-negative damage and impulse, a positive reach and radius, a positive recovery, and a combo window no shorter
// than the interval (the combo would end between two jabs of one string). A NaN fails every comparison below.
mixin FMars_Validation Validate(const FMars_Punch_Spec& Self)
{
    const auto& Blow = Self.Blow;
    if ((Blow.Damage >= 0.0f) == false || Math::IsFinite(Blow.Damage) == false)
    { return FMars_Validation(f"Blow.Damage [{Blow.Damage}] must be finite and not negative"); }

    if ((Blow.Reach > 0.0f) == false || Math::IsFinite(Blow.Reach) == false)
    { return FMars_Validation(f"Blow.Reach [{Blow.Reach}] must be finite and positive"); }

    if ((Blow.Radius > 0.0f) == false || Math::IsFinite(Blow.Radius) == false)
    { return FMars_Validation(f"Blow.Radius [{Blow.Radius}] must be finite and positive"); }

    if ((Blow.ImpulseSpeed >= 0.0f) == false || Math::IsFinite(Blow.ImpulseSpeed) == false)
    { return FMars_Validation(f"Blow.ImpulseSpeed [{Blow.ImpulseSpeed}] must be finite and not negative"); }

    const auto& Rhythm = Self.Rhythm;
    if ((Rhythm.ImpactSeconds >= 0.0f) == false || Math::IsFinite(Rhythm.ImpactSeconds) == false)
    { return FMars_Validation(f"Rhythm.ImpactSeconds [{Rhythm.ImpactSeconds}] must be finite and not negative"); }

    if ((Rhythm.RecoverySeconds > 0.0f) == false || Math::IsFinite(Rhythm.RecoverySeconds) == false)
    { return FMars_Validation(f"Rhythm.RecoverySeconds [{Rhythm.RecoverySeconds}] must be finite and positive"); }

    if ((Rhythm.IntervalSeconds >= 0.0f) == false || Math::IsFinite(Rhythm.IntervalSeconds) == false)
    { return FMars_Validation(f"Rhythm.IntervalSeconds [{Rhythm.IntervalSeconds}] must be finite and not negative"); }

    if ((Rhythm.ComboSeconds >= Rhythm.IntervalSeconds) == false || Math::IsFinite(Rhythm.ComboSeconds) == false)
    { return FMars_Validation(f"Rhythm.ComboSeconds [{Rhythm.ComboSeconds}] must be finite and no shorter than IntervalSeconds [{Rhythm.IntervalSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Punch_Spec Get_Spec(const FCk_Handle_Punch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Punch_Params).Spec;
}

mixin FMars_Punch_Fist Get_Fist(const FCk_Handle_Punch& Self, EMars_Hand InHand)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Punch);
    return InHand == EMars_Hand::Left ? State.Left : State.Right;
}

mixin EMars_Punch_Stroke Get_Stroke(const FCk_Handle_Punch& Self, EMars_Hand InHand)
{
    return Self.Get_Fist(InHand).Stroke;
}

// How far InHand's fist is through its current stroke, 0..1, linear in time (utils_punch::Get_StrokeAlpha).
mixin float32 Get_StrokeAlpha(const FCk_Handle_Punch& Self, EMars_Hand InHand)
{
    return utils_punch::Get_StrokeAlpha(Self.Get_Fragment(FMars_Fragment_Punch_Params).Spec.Rhythm, Self.Get_Fist(InHand));
}

// How far InHand's fist is from home, 0..1, linear in time (utils_punch::Get_Extension).
mixin float32 Get_Extension(const FCk_Handle_Punch& Self, EMars_Hand InHand)
{
    return utils_punch::Get_Extension(Self.Get_Fragment(FMars_Fragment_Punch_Params).Spec.Rhythm, Self.Get_Fist(InHand));
}

// A fist is out of its home.
mixin bool Get_IsPunching(const FCk_Handle_Punch& Self)
{
    return utils_punch::Get_AreFistsHome(Self.Get_Fragment(FMars_Fragment_Punch)) == false;
}

// The hand the next throw uses.
mixin EMars_Hand Get_NextHand(const FCk_Handle_Punch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Punch).NextHand;
}

mixin bool Get_HasWaitingThrow(const FCk_Handle_Punch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Punch).HasWaitingThrow;
}

// Jabs started since Add, mirrored ones included.
mixin int32 Get_JabsThrown(const FCk_Handle_Punch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Punch).JabsThrown;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Throw(FCk_Handle_Punch& Self, const FMars_Request_Punch_Throw& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Punch_Requests);
    Requests.ThrowRequests.Add(InRequest);
}

mixin void Request_Mirror(FCk_Handle_Punch& Self, const FMars_Request_Punch_Mirror& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Punch_Requests);
    Requests.MirrorRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnThrown(FCk_Handle_Punch& Self, FMars_Delegate_Punch_OnThrown InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Punch_Signals);
    Fragment.OnThrown.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnThrown(FCk_Handle_Punch& Self, FMars_Delegate_Punch_OnThrown InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Punch_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Punch_Signals).OnThrown.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBlow(FCk_Handle_Punch& Self, FMars_Delegate_Punch_OnBlow InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Punch_Signals);
    Fragment.OnBlow.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBlow(FCk_Handle_Punch& Self, FMars_Delegate_Punch_OnBlow InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Punch_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Punch_Signals).OnBlow.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
