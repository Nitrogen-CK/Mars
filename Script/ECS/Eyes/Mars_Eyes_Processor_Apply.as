// Builds the plate's values from the presentation and the style, and pushes only the groups that moved since the last
// push (everything on the first push to a plate). The only writer of the plate's custom primitive data; nothing is
// pushed before Set_Plate.
class UMars_Processor_Eyes_Apply : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Eyes);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Eyes_Presentation& InPresentation)
    {
        if (ck::Is_NOT_Valid(InPresentation.Plate))
        { return; }

        const auto& Style = InHandle.Get_Fragment(FMars_Fragment_Eyes).Style;

        auto Values = FMars_Eyes_MaterialValues();
        Values.Cells = FVector4(
            float(InPresentation.LeftCell), float(InPresentation.RightCell),
            float(InPresentation.PrevLeftCell), float(InPresentation.PrevRightCell));
        Values.Anim = FVector4(InPresentation.Blend, InPresentation.Blink, InPresentation.Blink, Style.EmissiveStrength);
        Values.Look = InPresentation.LookOffset;
        Values.Color = Style.Color;

        const auto PushAll = InPresentation.HasPushed == false;
        const auto& Last = InPresentation.LastPushed;
        const auto PushCells = PushAll || DoGet_HasMoved(Values.Cells, Last.Cells);
        const auto PushAnim = PushAll || DoGet_HasMoved(Values.Anim, Last.Anim);
        const auto PushLook = PushAll || Values.Look.Equals(Last.Look, constants_eyes::k_PushTolerance) == false;
        const auto PushColor = PushAll || Values.Color.Equals(Last.Color, constants_eyes::k_PushTolerance) == false;

        if ((PushCells || PushAnim || PushLook || PushColor) == false)
        { return; }

        mars_eyes_material::Push(InPresentation.Plate, Values, PushCells, PushAnim, PushLook, PushColor);

        // Only the pushed groups advance, so a slow drift below the tolerance still gets pushed once it adds up.
        if (PushCells)
        { InPresentation.LastPushed.Cells = Values.Cells; }

        if (PushAnim)
        { InPresentation.LastPushed.Anim = Values.Anim; }

        if (PushLook)
        { InPresentation.LastPushed.Look = Values.Look; }

        if (PushColor)
        { InPresentation.LastPushed.Color = Values.Color; }

        InPresentation.HasPushed = true;
    }

    private bool DoGet_HasMoved(const FVector4& InNow, const FVector4& InLast) const
    {
        const auto Tolerance = float(constants_eyes::k_PushTolerance);
        return Math::Abs(InNow.X - InLast.X) > Tolerance
            || Math::Abs(InNow.Y - InLast.Y) > Tolerance
            || Math::Abs(InNow.Z - InLast.Z) > Tolerance
            || Math::Abs(InNow.W - InLast.W) > Tolerance;
    }
}
