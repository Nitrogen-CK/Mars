namespace utils_input_intents
{
    FCk_Handle_InputIntents Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_InputIntents());
        InHandle.Add_Fragment(FMars_Fragment_InputIntents());
        return InHandle.As_InputIntents();
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

// INDEX_NONE unless the level row is Active - the frame its current hold began on.
mixin int32 TryGet_IntentActivationFrame(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    const auto Matcher = Self.Get_Matcher();
    if (ck::Is_NOT_Valid(Matcher))
    { return -1; }

    return utils_intent_matcher::TryGet_ActivationFrame(Matcher, InIntent);
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
