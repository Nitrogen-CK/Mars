// Counts a timed emote down (every machine), then, where there is a presentation, resolves each eye on its own: the
// emote's cell if an emote is playing and overrides that eye, else the state expression's if one is set and overrides
// it, else the style's. Blinking and looking are allowed only when every active layer (emote, state) allows them. A
// change of cells starts a crossfade over the emote's BlendSeconds while an emote plays, else the state's while a state
// is set, else the return-to-style time; it fades from whichever cells were dominant on screen, so a change that lands
// mid-fade does not jump.
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

        if (InState.HasEmote && InState.EmoteExpression.DurationSeconds > 0.0f)
        {
            InState.EmoteRemainingSeconds -= DeltaSeconds;
            if (InState.EmoteRemainingSeconds <= 0.0f)
            {
                InState.HasEmote = false;
                InState.EmoteExpression = FMars_Eyes_ExpressionDef();
                InState.EmoteRemainingSeconds = 0.0f;
            }
        }

        if (InHandle.Has_Fragment(FMars_Fragment_Eyes_Presentation) == false)
        { return; }

        auto& Presentation = InHandle.Get_Fragment(FMars_Fragment_Eyes_Presentation);

        const auto& Emote = InState.EmoteExpression;
        const auto& StateLayer = InState.StateExpression;

        auto WantedLeft = InState.Style.LeftCell;
        if (InState.HasEmote && Emote.OverrideLeft)
        { WantedLeft = Emote.LeftCell; }
        else if (InState.HasState && StateLayer.OverrideLeft)
        { WantedLeft = StateLayer.LeftCell; }

        auto WantedRight = InState.Style.RightCell;
        if (InState.HasEmote && Emote.OverrideRight)
        { WantedRight = Emote.RightCell; }
        else if (InState.HasState && StateLayer.OverrideRight)
        { WantedRight = StateLayer.RightCell; }

        Presentation.AllowBlink = (InState.HasEmote == false || Emote.AllowBlink)
            && (InState.HasState == false || StateLayer.AllowBlink);
        Presentation.AllowLook = (InState.HasEmote == false || Emote.AllowLook)
            && (InState.HasState == false || StateLayer.AllowLook);

        if (WantedLeft != Presentation.LeftCell || WantedRight != Presentation.RightCell)
        {
            // Fade from what is on screen now: the previous cells while they still dominate a crossfade in flight.
            const auto ShowsPrevious = Presentation.Blend < 0.5f;
            Presentation.PrevLeftCell = ShowsPrevious ? Presentation.PrevLeftCell : Presentation.LeftCell;
            Presentation.PrevRightCell = ShowsPrevious ? Presentation.PrevRightCell : Presentation.RightCell;
            Presentation.LeftCell = WantedLeft;
            Presentation.RightCell = WantedRight;
            Presentation.Blend = 0.0f;

            if (InState.HasEmote)
            { Presentation.BlendSeconds = Emote.BlendSeconds; }
            else if (InState.HasState)
            { Presentation.BlendSeconds = StateLayer.BlendSeconds; }
            else
            { Presentation.BlendSeconds = constants_eyes::k_ReturnToStyleBlendSeconds; }
        }

        if (Presentation.BlendSeconds <= 0.0f)
        { Presentation.Blend = 1.0f; }
        else
        { Presentation.Blend = Math::Min(1.0f, Presentation.Blend + DeltaSeconds / Presentation.BlendSeconds); }
    }
}
