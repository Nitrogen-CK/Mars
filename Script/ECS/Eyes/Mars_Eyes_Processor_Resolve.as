// Counts a timed emote down (every machine), then, where there is a presentation, resolves each eye on its own: the
// emote's cell if the emote sets one, else the state expression's, else the style's. Blinking and looking are allowed
// only when every active layer allows them. A change of cells starts a crossfade over the emote's BlendSeconds while an
// emote plays, else the state's while a state is set, else the return-to-style time; it fades from whichever cells
// were dominant on screen, so a change that lands mid-fade does not jump.
class UMars_Processor_Eyes_Resolve : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Eyes);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Eyes& InState)
    {
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (InState.Emote.IsSet() && InState.Emote.GetValue().RemainingSeconds.IsSet())
        {
            const auto RemainingSeconds = InState.Emote.GetValue().RemainingSeconds.GetValue() - DeltaSeconds;
            if (RemainingSeconds <= 0.0f)
            { InState.Emote.Reset(); }
            else
            {
                auto Emote = InState.Emote.GetValue();
                Emote.RemainingSeconds = RemainingSeconds;
                InState.Emote = Emote;
            }
        }

        if (InHandle.Has_Fragment(FMars_Fragment_Eyes_Presentation) == false)
        { return; }

        auto& Presentation = InHandle.Get_Fragment(FMars_Fragment_Eyes_Presentation);
        auto& Cells = Presentation.Cells;

        const auto HasEmote = InState.Emote.IsSet();
        const auto HasState = InState.StateExpression.IsSet();
        auto Emote = FMars_Eyes_ExpressionDef();
        if (HasEmote)
        { Emote = InState.Emote.GetValue().Expression; }

        auto StateLayer = FMars_Eyes_ExpressionDef();
        if (HasState)
        { StateLayer = InState.StateExpression.GetValue(); }

        auto WantedLeft = InState.Style.LeftCell;
        if (HasEmote && Emote.LeftCell.IsSet())
        { WantedLeft = Emote.LeftCell.GetValue(); }
        else if (HasState && StateLayer.LeftCell.IsSet())
        { WantedLeft = StateLayer.LeftCell.GetValue(); }

        auto WantedRight = InState.Style.RightCell;
        if (HasEmote && Emote.RightCell.IsSet())
        { WantedRight = Emote.RightCell.GetValue(); }
        else if (HasState && StateLayer.RightCell.IsSet())
        { WantedRight = StateLayer.RightCell.GetValue(); }

        Presentation.AllowBlink = (HasEmote == false || Emote.AllowBlink) && (HasState == false || StateLayer.AllowBlink);
        Presentation.AllowLook = (HasEmote == false || Emote.AllowLook) && (HasState == false || StateLayer.AllowLook);

        if (WantedLeft != Cells.LeftCell || WantedRight != Cells.RightCell)
        {
            // Fade from what is on screen now: the previous cells while they still dominate a crossfade in flight.
            const auto ShowsPrevious = Cells.Blend < 0.5f;
            Cells.PrevLeftCell = ShowsPrevious ? Cells.PrevLeftCell : Cells.LeftCell;
            Cells.PrevRightCell = ShowsPrevious ? Cells.PrevRightCell : Cells.RightCell;
            Cells.LeftCell = WantedLeft;
            Cells.RightCell = WantedRight;
            Cells.Blend = 0.0f;

            if (HasEmote)
            { Cells.BlendSeconds = Emote.BlendSeconds; }
            else if (HasState)
            { Cells.BlendSeconds = StateLayer.BlendSeconds; }
            else
            { Cells.BlendSeconds = constants_eyes::k_ReturnToStyleBlendSeconds; }
        }

        if (Cells.BlendSeconds <= 0.0f)
        { Cells.Blend = 1.0f; }
        else
        { Cells.Blend = Math::Min(1.0f, Cells.Blend + DeltaSeconds / Cells.BlendSeconds); }
    }
}
