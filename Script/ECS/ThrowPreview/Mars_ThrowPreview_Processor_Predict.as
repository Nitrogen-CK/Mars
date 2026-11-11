// Predicts in the camera group: the view, the hand chain and a mounted item's body are final for the frame there, so the
// path is the one a release drained at the start of the next frame would launch on.
//
// Per aiming entity, every frame: the held item's throw (HeldItemUse's launch solution) flown as the item's body flies
// (WorldItem's flight body), its bounds centre standing in for the centre of mass, swept as the bounds' smallest half
// extent (never below the Spec's MinCastRadius) against what blocks a thrown body. The carrier, its held presentation
// and a Persistent item's own mounted body never stop it. Empty hands, an item already launched, or an item with no body
// to fly as leave no path.
class UMars_Processor_ThrowPreview_Predict : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Camera";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ThrowPreview);
        Query.Require(FMars_Tag_ThrowPreview_Aiming);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_ThrowPreview& InState,
                       FMars_Fragment_ThrowPreview_Params& InParams)
    {
        auto Preview = InHandle.As_ThrowPreview();
        InState.Path = Predict(InHandle, InParams.Spec);

        // InState is not read past this line: a listener may add a fragment to the preview's entity.
        if (Preview.Has_Fragment(FMars_Fragment_ThrowPreview_Signals))
        { Preview.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnPathUpdated.Broadcast(Preview); }
    }

    private FMars_ThrowPreview_Path Predict(FCk_Handle& InCarrier, const FMars_ThrowPreview_Spec& InSpec)
    {
        auto Path = FMars_ThrowPreview_Path();

        auto Use = InCarrier.As_HeldItemUse();
        auto HeldItem = InCarrier.As_HeldItem();
        const auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Use.Get_IsCurrentItemLaunched())
        { return Path; }

        const auto MaybeSolution = Use.Get_LaunchSolution(EMars_LaunchKind::Throw);
        const auto MaybeFlightBody = Item.Get_FlightBody();
        if (MaybeSolution.IsSet() == false || MaybeFlightBody.IsSet() == false)
        { return Path; }

        const auto Solution = MaybeSolution.GetValue();
        const auto FlightBody = MaybeFlightBody.GetValue();
        const auto HalfExtents = FlightBody.BoundsFit.HalfExtents;
        const auto Radius = Math::Max(InSpec.MinCastRadius,
            float32(Math::Min(HalfExtents.X, Math::Min(HalfExtents.Y, HalfExtents.Z))));
        // The bounds centre stands in for the centre of mass.
        const auto Start = Solution.Origin.TransformPosition(FlightBody.BoundsFit.Centre);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Sphere);
        Shape.Set_Radius(Radius);

        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_Channel(constants_throw_preview::k_FlightChannel);
        Filter.Set_MinResponse(ECk_Jolt_PairInteraction::Block);
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::Any);

        TArray<FCk_Handle> Ignored;
        Ignored.Add(InCarrier);
        const auto Presentation = HeldItem.Get_PresentationEntity();
        if (ck::IsValid(Presentation))
        { Ignored.Add(Presentation); }

        if (Item.Has_PersistentWorldItem())
        {
            FCk_Handle WorldItemEntity = Item.Get_PersistentWorldItem();
            if (ck::IsValid(WorldItemEntity))
            { Ignored.Add(WorldItemEntity); }
        }

        auto Params = FCk_Jolt_BallisticCast_Params(Start, Solution.LinearVelocity);
        Params.Set_Flight(FlightBody.Flight);
        Params.Set_Shape(Shape);
        Params.Set_Filter(Filter);
        Params.Set_MaxDuration(FCk_Time(InSpec.MaxFlightSeconds));
        Params.Set_StepsPerSegment(InSpec.StepsPerSegment);
        Params.Set_IgnoredEntities(Ignored);

        const auto Result = utils_jolt_query::Get_BallisticCast(Params);
        const auto CastPath = Result.Get_Path();
        Path.CastRadius = Radius;
        if (CastPath.Num() == 0)
        { return Path; }

        for (const auto& Point : CastPath)
        { Path.Points.Add(Point.Get_Location()); }

        Path.FlightSeconds = float32(CastPath.Last().Get_Time().Get_Seconds());

        const auto Hit = Result.Get_Hit();
        if (Hit.Get_HasHit() == false)
        {
            Path.End = EMars_ThrowPreview_End::OutOfRange;
            return Path;
        }

        Path.End = EMars_ThrowPreview_End::Surface;
        Path.Landing.Location = Hit.Get_Position();
        Path.Landing.Normal = Hit.Get_Normal();
        Path.Landing.Entity = Hit.Get_Entity();
        return Path;
    }
}
