// The presentation getters ensure where this machine has no presentation (see Get_HasPresentation).

namespace utils_eyes
{
    // The eyes live on InFaceNode (+X forward). All-or-nothing on validation: a rejected spec adds nothing and returns an
    // invalid handle. The presentation fragment is added only where cosmetic events can run.
    FCk_Handle_Eyes Add(FCk_Handle_Transform& InFaceNode, FMars_Eyes_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Eyes] [{InFaceNode.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Eyes(); }

        auto Params = FMars_Fragment_Eyes_Params();
        Params.Blink = InSpec.Blink;
        Params.Look = InSpec.Look;

        auto State = FMars_Fragment_Eyes();
        State.Style = InSpec.Style;

        InFaceNode.Add_Fragment(FMars_Feature_Eyes());
        InFaceNode.Add_Fragment(Params);
        InFaceNode.Add_Fragment(State);

        if (utils_net::Get_CanExecuteCosmeticEvents(InFaceNode))
        {
            auto Presentation = FMars_Fragment_Eyes_Presentation();
            Presentation.Cells.LeftCell = InSpec.Style.LeftCell;
            Presentation.Cells.RightCell = InSpec.Style.RightCell;
            Presentation.Cells.PrevLeftCell = InSpec.Style.LeftCell;
            Presentation.Cells.PrevRightCell = InSpec.Style.RightCell;
            Presentation.Cells.Blend = 1.0f;
            if (InSpec.Blink.IsSet())
            { Presentation.Blink.SecondsToNextBlink = DoDraw_BlinkInterval(InSpec.Blink.GetValue()); }
            Presentation.Plate.Component = InSpec.Plate;
            InFaceNode.Add_Fragment(Presentation);
        }

        return InFaceNode.As_Eyes();
    }

    float32 DoDraw_BlinkInterval(const FMars_Eyes_BlinkSpec& InBlink)
    {
        return Math::RandRange(InBlink.IntervalMinSeconds, InBlink.IntervalMaxSeconds);
    }

    // The presentation getters are meaningless where cosmetics do not run; asking there is a caller bug.
    bool DoEnsure_HasPresentation(const FCk_Handle_Eyes& InEyes, const FString& InGetter)
    {
        const auto HasPresentation = InEyes.Has_Fragment(FMars_Fragment_Eyes_Presentation);
        ck::EnsureIfNot(HasPresentation,
            f"[Eyes] [{InEyes.ToString()}] {InGetter}: this machine has no eyes presentation - check Get_HasPresentation first");
        return HasPresentation;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetPlate(FCk_Handle_Eyes& Self, const FMars_Request_Eyes_SetPlate& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Eyes_Requests);
    Requests.SetPlateRequests.Add(InRequest);
}

mixin void Request_SetStyle(FCk_Handle_Eyes& Self, FMars_Request_Eyes_SetStyle InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Eyes_Requests);
    Requests.SetStyleRequests.Add(InRequest);
}

mixin void Request_PlayExpression(FCk_Handle_Eyes& Self, FMars_Request_Eyes_PlayExpression InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Eyes_Requests);
    Requests.PlayExpressionRequests.Add(InRequest);
}

mixin void Request_SetStateExpression(FCk_Handle_Eyes& Self, FMars_Request_Eyes_SetStateExpression InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Eyes_Requests);
    Requests.SetStateExpressionRequests.Add(InRequest);
}

mixin void Request_ClearExpression(FCk_Handle_Eyes& Self, FMars_Request_Eyes_ClearExpression InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Eyes_Requests);
    Requests.ClearExpressionRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Eyes_StyleDef Get_Style(const FCk_Handle_Eyes& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Eyes).Style;
}

mixin bool Get_HasEmote(const FCk_Handle_Eyes& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Eyes).Emote.IsSet();
}

mixin bool Get_HasPresentation(const FCk_Handle_Eyes& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Eyes_Presentation);
}

// The component the look is drawn on; invalid until one is set.
mixin FCk_Handle_UnrealComponent Get_Plate(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_Plate") == false)
    { return FCk_Handle_UnrealComponent(); }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Plate.Component;
}

mixin int32 Get_ResolvedLeftCell(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_ResolvedLeftCell") == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Cells.LeftCell;
}

mixin int32 Get_ResolvedRightCell(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_ResolvedRightCell") == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Cells.RightCell;
}

// The left cell the crossfade comes from (shown fully while Blend is 0).
mixin int32 Get_PreviousLeftCell(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_PreviousLeftCell") == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Cells.PrevLeftCell;
}

// The right cell the crossfade comes from (shown fully while Blend is 0).
mixin int32 Get_PreviousRightCell(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_PreviousRightCell") == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Cells.PrevRightCell;
}

// 0 right after the resolved cells changed, 1 once the crossfade from the previous cells is done.
mixin float32 Get_Blend(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_Blend") == false)
    { return 0.0f; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Cells.Blend;
}

// 0 open .. 1 closed.
mixin float32 Get_Blink(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_Blink") == false)
    { return 0.0f; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Blink.Closure;
}

// Completed blinks since Add.
mixin int32 Get_BlinkCount(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_BlinkCount") == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).Blink.Count;
}

// Each axis -1..1: X toward the face node's +Y (right), Y toward +Z (up).
mixin FVector2D Get_LookOffset(const FCk_Handle_Eyes& Self)
{
    if (utils_eyes::DoEnsure_HasPresentation(Self, "Get_LookOffset") == false)
    { return FVector2D::ZeroVector; }

    return Self.Get_Fragment(FMars_Fragment_Eyes_Presentation).LookOffset;
}
