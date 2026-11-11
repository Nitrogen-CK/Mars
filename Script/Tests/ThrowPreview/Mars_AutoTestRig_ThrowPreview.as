// The throw-preview tests' rig: a carrier (UMars_AutoTestRig_Carrier, no viewpoint, so it throws along its own +X) with
// HeldItem, HeldItemUse and a ThrowPreview, the preview's signals recorded, and the measurement of one real flight
// against a predicted path: the flying world item's first Jolt contact and, every frame from its launch to that contact,
// how far its bounds centre is from the predicted polyline. Every World-mode world item a throw spawns is recorded and
// destroyed in DoEndPlay.
UCLASS(Abstract)
class UMars_AutoTestRig_ThrowPreview : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    // A flight from the hand to the floor and the hold before it outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle_HeldItemUse _Use;
    protected FCk_Handle_ThrowPreview _Preview;
    protected FVector _Origin;

    // Every OnAimChanged, in order, and how many OnPathUpdated fired.
    protected TArray<EMars_ThrowPreview_Aim> _AimChanges;
    protected int32 _PathUpdates = 0;

    // The predicted path a flight is measured against (Keep_PredictedPath), and the hand it was predicted from.
    protected FMars_ThrowPreview_Path _Predicted;
    protected FVector _HandAtPrediction;

    // The world item whose flight is measured: found by Check_FlightLanded for a Transient item, set by the test for a
    // Persistent one.
    protected FCk_Handle_WorldItem _Flying;
    protected bool _HasContact = false;
    // The first contact's point nearest the predicted landing, and its distance from it; -1 while there is none.
    protected FVector _ContactPoint;
    protected float64 _LandingErrorCm = -1.0;
    // The largest distance of a sampled bounds centre from the predicted polyline, and how many frames were sampled.
    protected float64 _MaxFlightErrorCm = 0.0;
    protected int32 _FlightSamples = 0;

    // The inputs of the prediction against the real launch (Record_LaunchInputs, Log_Flight).
    protected FMars_HeldItemUse_LaunchSolution _ThrowSolution;
    protected bool _HasFirstDynamic = false;
    protected FVector _FirstDynamicCentre;
    protected bool _HasLaunchApplied = false;
    protected FVector _LaunchCentre;
    protected FVector _LaunchVelocity;
    protected int32 _DynamicFramesBeforeLaunch = 0;
    protected FTransform _ContactTransform;
    // The flying body's bounds centre (world) at its first contact.
    protected FVector _ContactCentre;
    protected int32 _ContactPointCount = 0;

    private TArray<FCk_Handle> _LaunchedWorldItems;
    private bool _ContactBound = false;

    // HeldItem, HeldItemUse and the ThrowPreview with the default Spec on the carrier, after Add_CarrierBody*.
    protected void Add_PreviewParts(int32 InBagSlotCount)
    {
        Add_Hotbar(_Carrier, InBagSlotCount);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Preview = utils_throw_preview::Add(_Carrier, FMars_ThrowPreview_Spec());
        _Preview.BindTo_OnAimChanged(FMars_Delegate_ThrowPreview_OnAimChanged(this, n"OnRigAimChanged"));
        _Preview.BindTo_OnPathUpdated(FMars_Delegate_ThrowPreview_OnPathUpdated(this, n"OnRigPathUpdated"));
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Preview))
        {
            _Preview.UnbindFrom_OnAimChanged(FMars_Delegate_ThrowPreview_OnAimChanged(this, n"OnRigAimChanged"));
            _Preview.UnbindFrom_OnPathUpdated(FMars_Delegate_ThrowPreview_OnPathUpdated(this, n"OnRigPathUpdated"));
        }

        for (auto Entity : _LaunchedWorldItems)
        {
            if (ck::IsValid(Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Entity); }
        }
    }

    UFUNCTION()
    private void OnRigAimChanged(FCk_Handle_ThrowPreview InPreview, EMars_ThrowPreview_Aim InAim)
    {
        _AimChanges.Add(InAim);
    }

    UFUNCTION()
    private void OnRigPathUpdated(FCk_Handle_ThrowPreview InPreview)
    {
        ++_PathUpdates;
    }

    protected FVector Get_HandLocation() const
    {
        return utils_transform::Get_EntityCurrentTransform(_HandNode).GetLocation();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Holding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Items.Num() > 0 && _HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    protected void Step_Aim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Preview.Request_SetAim(FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim::Aiming));
    }

    UFUNCTION()
    protected void Check_PathMeetsASurface(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _Preview.Get_Path().End == EMars_ThrowPreview_End::Surface);
    }

    // The path as predicted now, and the hand it was predicted from; the throw after it is measured against this.
    protected void Keep_PredictedPath()
    {
        _Predicted = _Preview.Get_Path();
        _HandAtPrediction = Get_HandLocation();

        const auto Solution = _Use.Get_LaunchSolution(EMars_LaunchKind::Throw);
        if (Solution.IsSet())
        { _ThrowSolution = Solution.GetValue(); }
    }

    UFUNCTION()
    protected void Step_Throw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    // The flying world item's body has made its first contact. Every poll before then finds and binds the world item, and
    // once its body flies (added, Dynamic, its launch taken) samples how far its bounds centre is from the predicted path.
    UFUNCTION()
    protected void Check_FlightLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Flying))
        { _Flying = Find_LaunchedWorldItem(InHandle); }

        if (ck::Is_NOT_Valid(_Flying))
        {
            Res.Set(false);
            return;
        }

        auto Body = _Flying.Get_Body();
        if (ck::Is_NOT_Valid(Body))
        {
            Res.Set(false);
            return;
        }

        if (_ContactBound == false)
        {
            utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnFlyingContactAdded"));
            _ContactBound = true;
        }

        if (_HasContact == false)
        { Record_LaunchInputs(Body); }

        if (_HasContact == false && Get_IsFlying(Body))
        {
            FCk_Handle Entity = _Flying;
            const auto Centre = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform())
                .TransformPosition(_Flying.Get_BoundsFit().Centre);
            _MaxFlightErrorCm = Math::Max(_MaxFlightErrorCm, Get_DistanceToPolyline(Centre, _Predicted.Points));
            ++_FlightSamples;
        }

        Res.Set(_HasContact);
    }

    // The three inputs a prediction is checked against: the body's first Dynamic-frame bounds centre (the start), how many
    // frames it stays Dynamic before the launch velocity is on it and how far it moves in them, and the first velocity
    // after the launch is applied.
    private void Record_LaunchInputs(const FCk_Handle_JoltBody& InBody)
    {
        if (utils_jolt_body::Get_IsBodyAdded(InBody) == false || utils_jolt_body::Get_MotionType(InBody) != ECk_MotionType::Dynamic)
        { return; }

        FCk_Handle Entity = _Flying;
        const auto Centre = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform())
            .TransformPosition(_Flying.Get_BoundsFit().Centre);
        if (_HasFirstDynamic == false)
        {
            _HasFirstDynamic = true;
            _FirstDynamicCentre = Centre;
        }

        if (_HasLaunchApplied)
        { return; }

        const auto Velocity = utils_jolt_body::Get_LinearVelocity(InBody);
        const auto Applied = _Flying.Has_Fragment(FMars_Fragment_WorldItem_PendingLaunch) == false
            && _Flying.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease) == false
            && Velocity.Size() > 0.5 * _ThrowSolution.LinearVelocity.Size();
        if (Applied == false)
        {
            ++_DynamicFramesBeforeLaunch;
            return;
        }

        _HasLaunchApplied = true;
        _LaunchCentre = Centre;
        _LaunchVelocity = Velocity;
    }

    // Added, Dynamic, and nothing left pending: a release answered and the launch velocity taken.
    private bool Get_IsFlying(const FCk_Handle_JoltBody& InBody) const
    {
        return utils_jolt_body::Get_IsBodyAdded(InBody) && utils_jolt_body::Get_MotionType(InBody) == ECk_MotionType::Dynamic
            && _Flying.Has_Fragment(FMars_Fragment_WorldItem_PendingLaunch) == false
            && _Flying.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease) == false;
    }

    UFUNCTION()
    private void OnFlyingContactAdded(FCk_Handle_JoltBody InHandle, FCk_JoltBody_Payload_OnContact InPayload)
    {
        if (_HasContact)
        { return; }

        _HasContact = true;
        FCk_Handle Entity = _Flying;
        _ContactTransform = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        _ContactCentre = _ContactTransform.TransformPosition(_Flying.Get_BoundsFit().Centre);
        const auto Points = InPayload.Get_ContactPoints();
        _ContactPointCount = Points.Num();
        for (auto Point : Points)
        {
            const auto Distance = Point.Distance(_Predicted.Landing.Location);
            if (_LandingErrorCm < 0.0 || Distance < _LandingErrorCm)
            {
                _LandingErrorCm = Distance;
                _ContactPoint = Point;
            }
        }
    }

    // The body's bounds centre at its first contact, projected onto the predicted landing surface (the plane through the
    // landing with its normal), and its distance from the landing; -1 before a contact.
    protected float64 Get_CentreLandingErrorCm() const
    {
        if (_HasContact == false)
        { return -1.0; }

        const auto Landing = _Predicted.Landing;
        const auto Normal = Landing.Normal.GetSafeNormal();
        const auto Projected = _ContactCentre - Normal * (_ContactCentre - Landing.Location).DotProduct(Normal);
        return Projected.Distance(Landing.Location);
    }

    // The flight's numbers, logged whether or not the test passes.
    protected void Log_Flight(const FString& InWhat)
    {
        Log(f"[ThrowPreview] {InWhat}: landing error {_LandingErrorCm} cm (nearest contact point), body centre at contact "
            + f"projected onto the landing surface {Get_CentreLandingErrorCm()} cm from the landing, max flight-sample error {_MaxFlightErrorCm} cm over "
            + f"{_FlightSamples} samples, horizontal throw distance {(_Predicted.Landing.Location - _HandAtPrediction).Size2D()} cm, "
            + f"predicted flight {_Predicted.FlightSeconds} s over {_Predicted.Points.Num()} points, cast radius {_Predicted.CastRadius} cm");

        const auto Start = _Predicted.Points.Num() > 0 ? _Predicted.Points[0] : FVector::ZeroVector;
        const auto VelocityDelta = _LaunchVelocity - _ThrowSolution.LinearVelocity;
        Log(f"[ThrowPreview] {InWhat} inputs: solution velocity {_ThrowSolution.LinearVelocity}, body's first velocity after the "
            + f"launch {_LaunchVelocity} (delta {VelocityDelta}, |delta| {VelocityDelta.Size()} cm/s); predicted start {Start}, body's "
            + f"first Dynamic bounds centre {_FirstDynamicCentre} (off {_FirstDynamicCentre.Distance(Start)} cm); Dynamic frames before "
            + f"the launch {_DynamicFramesBeforeLaunch}, moved {_LaunchCentre.Distance(_FirstDynamicCentre)} cm in them "
            + f"(centre at launch {_LaunchCentre}, off the start {_LaunchCentre.Distance(Start)} cm)");

        if (ck::IsValid(_Flying) && ck::IsValid(_Flying.Get_Body()))
        {
            const auto Flight = utils_jolt_body::Get_BallisticFlight(_Flying.Get_Body());
            const auto Fit = _Flying.Get_BoundsFit();
            const auto ContactCentre = _ContactTransform.TransformPosition(Fit.Centre);
            const auto LocalContact = _ContactTransform.InverseTransformPosition(_ContactPoint) - Fit.Centre;
            auto End = FVector::ZeroVector;
            if (_Predicted.Points.Num() > 0)
            { End = _Predicted.Points.Last(); }

            Log(f"[ThrowPreview] {InWhat} body: flight damping {Flight.Get_LinearDamping()} gravity {Flight.Get_GravityFactor()} "
                + f"max {Flight.Get_MaxLinearVelocity()}; bounds half extents {Fit.HalfExtents} centre {Fit.Centre}; rotation at "
                + f"contact {_ContactTransform.Rotator()}; centre at contact {ContactCentre}; {_ContactPointCount} contact points, the "
                + f"nearest {_ContactPoint} is {_ContactPoint - ContactCentre} from the centre (body frame {LocalContact}); predicted "
                + f"landing {_Predicted.Landing.Location}, predicted centre at the hit {End}");
        }
    }

    // A World-mode world item near the origin that the rig has not seen yet: the one a throw just spawned (found from the
    // frame it exists). Recorded for destruction in DoEndPlay.
    private FCk_Handle_WorldItem Find_LaunchedWorldItem(FCk_Handle InHandle)
    {
        const auto WorldItems = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem");
        for (const auto& Entity : WorldItems)
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false || _LaunchedWorldItems.Contains(Entity))
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(_Origin) < 3000.0)
            {
                _LaunchedWorldItems.Add(Entity);
                return WorldItem;
            }
        }

        return FCk_Handle_WorldItem();
    }

    // The distance from InPoint to the polyline through InPoints; a large number when there is none.
    protected float64 Get_DistanceToPolyline(FVector InPoint, const TArray<FVector>& InPoints) const
    {
        if (InPoints.Num() == 0)
        { return 1.0e9; }

        auto Best = InPoint.Distance(InPoints[0]);
        for (int32 Index = 1; Index < InPoints.Num(); ++Index)
        {
            const auto A = InPoints[Index - 1];
            const auto Segment = InPoints[Index] - A;
            const auto LengthSquared = Segment.SizeSquared();
            auto Alpha = 0.0;
            if (LengthSquared > 0.0)
            { Alpha = Math::Clamp((InPoint - A).DotProduct(Segment) / LengthSquared, 0.0, 1.0); }

            Best = Math::Min(Best, InPoint.Distance(A + Segment * Alpha));
        }

        return Best;
    }

    // The length of the polyline through InPoints.
    protected float64 Get_PolylineLength(const TArray<FVector>& InPoints) const
    {
        auto Length = 0.0;
        for (int32 Index = 1; Index < InPoints.Num(); ++Index)
        { Length += InPoints[Index].Distance(InPoints[Index - 1]); }

        return Length;
    }
}
