namespace utils_input_intents
{
    FCk_Handle_InputIntents Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_InputIntents());
        InHandle.Add_Fragment(FMars_Fragment_InputIntents());
        return InHandle.As_InputIntents();
    }

    // The one look path (the gameplay profile's OnLook, the acceptance driver): InIntention is degrees of view rotation
    // (X yaw right+, Y pitch DOWN+). It goes to InPlayer's InputIntents, so a gripped control can read it, and,
    // independently, to its view camera; each only when present.
    void Request_Look(FCk_Handle InPlayer, FVector InIntention)
    {
        auto Intents = InPlayer.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Intents))
        { Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(InIntention)); }

        auto Viewpoint = InPlayer.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return; }

        auto Camera = Viewpoint.Get_Camera();
        if (ck::IsValid(Camera))
        { Camera.Request_SetOrientationIntention(InIntention); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_IntentMatcher Get_Matcher(const FCk_Handle_InputIntents& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InputIntents).Matcher;
}

mixin FVector Get_MoveDirection(const FCk_Handle_InputIntents& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InputIntents).MoveDirection;
}

// The last drained look delta (camera intention units: X yaw right+, Y pitch DOWN+). Stays put on still frames, so a
// reader applies it once per Get_LookDeltaSequence value.
mixin FVector Get_LookDelta(const FCk_Handle_InputIntents& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InputIntents).LookDelta;
}

// Advances once per drain that carried a look delta.
mixin int32 Get_LookDeltaSequence(const FCk_Handle_InputIntents& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InputIntents).LookDeltaSequence;
}

mixin ECk_Intent_Phase Get_IntentPhase(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    const auto Matcher = Self.Get_Matcher();
    if (ck::Is_NOT_Valid(Matcher))
    { return ECk_Intent_Phase::Idle; }

    return utils_intent_matcher::Get_IntentPhase(Matcher, InIntent);
}

mixin bool Get_IsIntentActive(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    return Self.Get_IntentPhase(InIntent) == ECk_Intent_Phase::Active;
}

// The frame the level row's current hold began on; unset while the row is not Active or no matcher has arrived yet.
mixin TOptional<int32> TryGet_IntentActivationFrame(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    const auto Matcher = Self.Get_Matcher();
    if (ck::Is_NOT_Valid(Matcher))
    { return TOptional<int32>(); }

    const auto Frame = utils_intent_matcher::TryGet_ActivationFrame(Matcher, InIntent);
    if (Frame == ck::INDEX_NONE())
    { return TOptional<int32>(); }

    return TOptional<int32>(Frame);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The drain broadcasts OnMatcherChanged when the matcher actually changes - including the swap to INVALID, so consumers
// unbind from the dying matcher.
mixin void Request_SetMatcher(FCk_Handle_InputIntents& Self, const FMars_Request_InputIntents_SetMatcher& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Requests);
    Requests.SetMatcherRequests.Add(InRequest);
}

mixin void Request_SetMoveDirection(FCk_Handle_InputIntents& Self, const FMars_Request_InputIntents_SetMoveDirection& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Requests);
    Requests.SetMoveDirectionRequests.Add(InRequest);
}

// Every request of one drain is summed into one delta.
mixin void Request_AddLookDelta(FCk_Handle_InputIntents& Self, const FMars_Request_InputIntents_AddLookDelta& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Requests);
    Requests.AddLookDeltaRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnMatcherChanged(FCk_Handle_InputIntents& Self, FMars_Delegate_InputIntents_OnMatcherChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Signals);
    Fragment.OnMatcherChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnMatcherChanged(FCk_Handle_InputIntents& Self, FMars_Delegate_InputIntents_OnMatcherChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_InputIntents_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_InputIntents_Signals).OnMatcherChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
