// Drains SetPlate, SetStyle, ClearExpression, SetStateExpression, then PlayExpression (each kind in queue order), so a
// clear and a new expression issued in the same frame leave the new one showing. Every style and expression is
// validated with its def's Validate(); a rejected one ensures and changes nothing. SetPlate is the only request that
// writes the presentation; the cells follow the logic fragment on the resolve pass.
class UMars_Processor_Eyes_Requests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Eyes_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Eyes);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Eyes_Requests& InRequests,
                       FMars_Fragment_Eyes& InState)
    {
        auto Self = InHandle.As_Eyes();

        TArray<FMars_Request_Eyes_SetPlate> SetPlateRequests = InRequests.SetPlateRequests;
        TArray<FMars_Request_Eyes_SetStyle> SetStyleRequests = InRequests.SetStyleRequests;
        TArray<FMars_Request_Eyes_ClearExpression> ClearExpressionRequests = InRequests.ClearExpressionRequests;
        TArray<FMars_Request_Eyes_SetStateExpression> SetStateExpressionRequests = InRequests.SetStateExpressionRequests;
        TArray<FMars_Request_Eyes_PlayExpression> PlayExpressionRequests = InRequests.PlayExpressionRequests;

        // InRequests is invalid past this line; removing before acting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Eyes_Requests);

        for (const auto& Request : SetPlateRequests)
        { HandleSetPlate(Self, Request); }

        for (const auto& Request : SetStyleRequests)
        { HandleSetStyle(Self, InState, Request); }

        for (const auto& Request : ClearExpressionRequests)
        { HandleClearExpression(InState, Request); }

        for (const auto& Request : SetStateExpressionRequests)
        { HandleSetStateExpression(Self, InState, Request); }

        for (const auto& Request : PlayExpressionRequests)
        { HandlePlayExpression(Self, InState, Request); }
    }

    // Where cosmetics do not run there is no plate to draw on.
    private void HandleSetPlate(FCk_Handle_Eyes& InEyes, const FMars_Request_Eyes_SetPlate& InRequest)
    {
        if (InEyes.Has_Fragment(FMars_Fragment_Eyes_Presentation) == false)
        { return; }

        auto& Presentation = InEyes.Get_Fragment(FMars_Fragment_Eyes_Presentation);
        Presentation.Plate.Component = InRequest.Plate;
        Presentation.Plate.LastPushed.Reset();
    }

    private void HandleSetStyle(FCk_Handle_Eyes& InEyes,
                                FMars_Fragment_Eyes& InState,
                                const FMars_Request_Eyes_SetStyle& InRequest)
    {
        const auto Validation = InRequest.Style.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Eyes] [{InEyes.ToString()}] rejected SetStyle: {Validation.Get_Error()}"))
        { return; }

        InState.Style = InRequest.Style;
    }

    private void HandleClearExpression(FMars_Fragment_Eyes& InState,
                                       const FMars_Request_Eyes_ClearExpression& InRequest)
    {
        if (InRequest.Layer == EMars_Eyes_Layer::Emote)
        {
            InState.Emote.Reset();
            return;
        }

        InState.StateExpression.Reset();
    }

    private void HandleSetStateExpression(FCk_Handle_Eyes& InEyes,
                                          FMars_Fragment_Eyes& InState,
                                          const FMars_Request_Eyes_SetStateExpression& InRequest)
    {
        const auto Validation = InRequest.Expression.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Eyes] [{InEyes.ToString()}] rejected SetStateExpression: {Validation.Get_Error()}"))
        { return; }

        InState.StateExpression = InRequest.Expression;
    }

    private void HandlePlayExpression(FCk_Handle_Eyes& InEyes,
                                      FMars_Fragment_Eyes& InState,
                                      const FMars_Request_Eyes_PlayExpression& InRequest)
    {
        const auto Validation = InRequest.Expression.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Eyes] [{InEyes.ToString()}] rejected PlayExpression: {Validation.Get_Error()}"))
        { return; }

        auto Emote = FMars_Eyes_PlayingEmote();
        Emote.Expression = InRequest.Expression;
        Emote.RemainingSeconds = InRequest.Expression.DurationSeconds;
        InState.Emote = Emote;
    }
}
