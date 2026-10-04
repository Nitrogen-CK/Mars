// Builds the plate's values from the presentation and the style, and pushes only the groups that moved since the last
// push (every group on the first push to a plate). Nothing is pushed while there is no plate (a CkUnrealComponent plate
// or a plate primitive); a plate that went away hands the next one every group again.
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
        // The plate primitive is held weakly: once its actor destroys it the pointer reads null and nothing is pushed.
        auto& Plate = InPresentation.Plate;
        if (ck::Is_NOT_Valid(Plate.Primitive.Get()) && ck::Is_NOT_Valid(Plate.Component))
        {
            Plate.LastPushed.Reset();
            return;
        }

        const auto& Style = InHandle.Get_Fragment(FMars_Fragment_Eyes).Style;
        const auto& Cells = InPresentation.Cells;

        auto Values = FMars_Eyes_MaterialValues();
        Values.Cells = FVector4(float(Cells.LeftCell), float(Cells.RightCell), float(Cells.PrevLeftCell), float(Cells.PrevRightCell));
        Values.Anim = FVector4(Cells.Blend, InPresentation.Blink.Closure, InPresentation.Blink.Closure, Style.EmissiveStrength);
        Values.Look = InPresentation.LookOffset;
        Values.Color = Style.Color;

        const auto PushAll = Plate.LastPushed.IsSet() == false;
        auto Last = FMars_Eyes_MaterialValues();
        if (PushAll == false)
        { Last = Plate.LastPushed.GetValue(); }

        const auto PushCells = PushAll || DoGet_HasMoved(Values.Cells, Last.Cells);
        const auto PushAnim = PushAll || DoGet_HasMoved(Values.Anim, Last.Anim);
        const auto PushLook = PushAll || Values.Look.Equals(Last.Look, constants_eyes::k_PushTolerance) == false;
        const auto PushColor = PushAll || Values.Color.Equals(Last.Color, constants_eyes::k_PushTolerance) == false;

        if ((PushCells || PushAnim || PushLook || PushColor) == false)
        { return; }

        // Only the pushed groups advance, so a slow drift below the tolerance still gets pushed once it adds up.
        if (PushCells)
        {
            utils_eyes::Push_Group(Plate, Values, EMars_Eyes_PlateGroup::Cells);
            Last.Cells = Values.Cells;
        }

        if (PushAnim)
        {
            utils_eyes::Push_Group(Plate, Values, EMars_Eyes_PlateGroup::Anim);
            Last.Anim = Values.Anim;
        }

        if (PushLook)
        {
            utils_eyes::Push_Group(Plate, Values, EMars_Eyes_PlateGroup::Look);
            Last.Look = Values.Look;
        }

        if (PushColor)
        {
            utils_eyes::Push_Group(Plate, Values, EMars_Eyes_PlateGroup::Color);
            Last.Color = Values.Color;
        }

        Plate.LastPushed = Last;
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
