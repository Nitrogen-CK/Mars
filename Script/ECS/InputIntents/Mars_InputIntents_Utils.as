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
// Operations
//--------------------------------------------------------------------------------------------------------------------------

mixin void Set_Matcher(FCk_Handle_InputIntents& Self, FCk_Handle_IntentMatcher InMatcher)
{
    Self.Get_Fragment(FMars_Fragment_InputIntents).Matcher = InMatcher;
}

mixin void Set_MoveDirection(FCk_Handle_InputIntents& Self, FVector InMoveDirection)
{
    Self.Get_Fragment(FMars_Fragment_InputIntents).MoveDirection = InMoveDirection;
}
