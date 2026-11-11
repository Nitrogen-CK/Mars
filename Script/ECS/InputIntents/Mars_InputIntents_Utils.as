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

    // InEdge carries a press (alone, or after a release between two polls).
    bool Get_HasPress(EMars_IntentEdge InEdge)
    {
        return InEdge == EMars_IntentEdge::Pressed || InEdge == EMars_IntentEdge::ReleasedAndPressed;
    }

    // InEdge carries a release (alone, or before a press between two polls).
    bool Get_HasRelease(EMars_IntentEdge InEdge)
    {
        return InEdge == EMars_IntentEdge::Released || InEdge == EMars_IntentEdge::ReleasedAndPressed;
    }

    // The sending machine's sample of InIntents this frame: the look total and, per operator intent, its press serial and
    // hold. Call once a frame (each look delta is counted once, on the frame it drained). The first call seeds: a hold and
    // a look from before it never count.
    FMars_InputIntents_RemoteSample Make_RemoteSample(const FCk_Handle_InputIntents& InIntents, FMars_InputIntents_Sampler& InOutSampler)
    {
        if (InOutSampler.Rows.IsEmpty())
        {
            InOutSampler.Look.Seed(InIntents);
            for (const auto& Intent : constants_input_intents::Get_OperatorIntents())
            {
                auto Row = FMars_InputIntents_SamplerRow();
                Row.Intent = Intent;
                Row.Edge.Seed(InIntents, Intent);
                InOutSampler.Rows.Add(Row);
            }
        }
        else if (InOutSampler.Look.Advance(InIntents))
        { InOutSampler.LookTotal += InIntents.Get_LookDelta(); }

        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.LookTotal = InOutSampler.LookTotal;
        for (auto& Row : InOutSampler.Rows)
        {
            if (utils_input_intents::Get_HasPress(Row.Edge.Advance(InIntents, Row.Intent)))
            { Row.PressSerial += 1; }

            const auto Hold = Row.Edge.Seen.IsSet() ? EMars_InputIntents_Hold::Held : EMars_InputIntents_Hold::Released;
            Sample.Intents.Add(FMars_InputIntents_RemoteIntent(Row.Intent, Row.PressSerial, Hold));
        }

        return Sample;
    }

    bool Get_AreSameSamples(const FMars_InputIntents_RemoteSample& InA, const FMars_InputIntents_RemoteSample& InB)
    {
        if (InA.LookTotal != InB.LookTotal || InA.Intents.Num() != InB.Intents.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.Intents.Num(); ++Index)
        {
            const auto& A = InA.Intents[Index];
            const auto& B = InB.Intents[Index];
            if (A.Intent != B.Intent || A.PressSerial != B.PressSerial || A.Hold != B.Hold)
            { return false; }
        }

        return true;
    }

    // The frame the InIndex-th press of a run stamped on InStamp first reads on: the first on its stamp, the second two
    // frames later (a reader that polled before the stamp's drain still reads the first on the frame between), each later
    // one a frame after the one before.
    int32 Get_RemotePressFrame(int32 InStamp, int32 InIndex)
    {
        return InIndex == 0 ? InStamp : InStamp + InIndex + 1;
    }

    // Every press of InRow's run has been readable for a whole frame by InFrame, or the row has no run: its next press
    // starts a new run instead of lengthening this one.
    bool Get_IsRemoteRunRead(const FMars_InputIntents_RemoteRow& InRow, int32 InFrame)
    {
        if (InRow.ActivationFrame.IsSet() == false)
        { return true; }

        return InFrame > Get_RemotePressFrame(InRow.ActivationFrame.GetValue(), InRow.Presses - 1) + 1;
    }

    // The remote operator's activation of InIntent as the authority last applied it: the press of the row's run that reads
    // this frame, each press under a frame of its own so a reader polling once a frame counts every one. The run's last
    // press reads while held, and while released through constants_input_intents::k_ReleasedPressFrames after the frame it
    // first read on (a press that arrived already released); unset without remote state.
    TOptional<int32> TryGet_RemoteActivationFrame(const FCk_Handle_InputIntents& InIntents, FGameplayTag InIntent)
    {
        if (InIntents.Has_Fragment(FMars_Fragment_InputIntents_Remote) == false)
        { return TOptional<int32>(); }

        for (const auto& Row : InIntents.Get_Fragment(FMars_Fragment_InputIntents_Remote).Rows)
        {
            if (Row.Intent != InIntent || Row.ActivationFrame.IsSet() == false)
            { continue; }

            const auto Frame = int32(utils_time::Get_FrameCounter());
            const auto Stamp = Row.ActivationFrame.GetValue();
            const auto Index = Math::Clamp(Frame - Stamp - 1, 0, Row.Presses - 1);
            const auto IsLastPress = Index == Row.Presses - 1;
            if (IsLastPress && Row.Hold == EMars_InputIntents_Hold::Released
                && Frame > Get_RemotePressFrame(Stamp, Index) + constants_input_intents::k_ReleasedPressFrames)
            { return TOptional<int32>(); }

            return TOptional<int32>(Stamp + Index);
        }

        return TOptional<int32>();
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

// From the matcher while it is valid; otherwise from the remote operator's samples (Active while its activation stands,
// Idle otherwise); Idle with neither.
mixin ECk_Intent_Phase Get_IntentPhase(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    const auto Matcher = Self.Get_Matcher();
    if (ck::IsValid(Matcher))
    { return utils_intent_matcher::Get_IntentPhase(Matcher, InIntent); }

    if (utils_input_intents::TryGet_RemoteActivationFrame(Self, InIntent).IsSet())
    { return ECk_Intent_Phase::Active; }

    return ECk_Intent_Phase::Idle;
}

mixin bool Get_IsIntentActive(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    return Self.Get_IntentPhase(InIntent) == ECk_Intent_Phase::Active;
}

// The frame the level row's current hold began on; unset while the row is not Active or no input has arrived yet. From
// the matcher while it is valid; otherwise the frame the authority applied the remote operator's press on.
mixin TOptional<int32> TryGet_IntentActivationFrame(const FCk_Handle_InputIntents& Self, FGameplayTag InIntent)
{
    const auto Matcher = Self.Get_Matcher();
    if (ck::Is_NOT_Valid(Matcher))
    { return utils_input_intents::TryGet_RemoteActivationFrame(Self, InIntent); }

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

// On the authority's copy of a remote operator: the samples of one drain apply in arrival order.
mixin void Request_ApplyRemoteSample(FCk_Handle_InputIntents& Self, const FMars_Request_InputIntents_ApplyRemoteSample& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Requests);
    Requests.ApplyRemoteSampleRequests.Add(InRequest);
}

// Drains before the samples of the same drain, which then seed.
mixin void Request_ClearRemote(FCk_Handle_InputIntents& Self, const FMars_Request_InputIntents_ClearRemote& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InputIntents_Requests);
    Requests.ClearRemoteRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Polled readers
//--------------------------------------------------------------------------------------------------------------------------

// The edge from the frame last seen to InFrame, which becomes the frame seen.
mixin EMars_IntentEdge Advance_To(FMars_IntentEdge& Self, TOptional<int32> InFrame)
{
    if (InFrame == Self.Seen)
    { return EMars_IntentEdge::None; }

    const auto WasHeld = Self.Seen.IsSet();
    Self.Seen = InFrame;
    if (InFrame.IsSet() == false)
    { return EMars_IntentEdge::Released; }

    return WasHeld ? EMars_IntentEdge::ReleasedAndPressed : EMars_IntentEdge::Pressed;
}

mixin EMars_IntentEdge Advance(FMars_IntentEdge& Self, const FCk_Handle_InputIntents& InIntents, FGameplayTag InIntent)
{
    return Self.Advance_To(InIntents.TryGet_IntentActivationFrame(InIntent));
}

// A hold already going counts as seen, so only a fresh press is an edge.
mixin void Seed(FMars_IntentEdge& Self, const FCk_Handle_InputIntents& InIntents, FGameplayTag InIntent)
{
    Self.Seen = InIntents.TryGet_IntentActivationFrame(InIntent);
}

// True once per drained look delta (InIntents.Get_LookDelta() is that delta).
mixin bool Advance(FMars_LookCursor& Self, const FCk_Handle_InputIntents& InIntents)
{
    const auto Sequence = InIntents.Get_LookDeltaSequence();
    if (Sequence == Self.Seen)
    { return false; }

    Self.Seen = Sequence;
    return true;
}

// A delta drained before the seed never counts.
mixin void Seed(FMars_LookCursor& Self, const FCk_Handle_InputIntents& InIntents)
{
    Self.Seen = InIntents.Get_LookDeltaSequence();
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
