namespace utils_gaze
{
    // InEyeNode's +X is forward. All-or-nothing: a rejected spec adds nothing and returns an invalid handle.
    // The sense trigger sits on a child scene node of InEyeNode (kinematic), so it follows the eye.
    FCk_Handle_Gaze Add(FCk_Handle_Transform& InEyeNode, FMars_Gaze_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Gaze] [{InEyeNode.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Gaze(); }

        auto SenseNode = utils_scene_node::Create(InEyeNode, FTransform::Identity);
        utils_handle::Set_DebugName(FCk_Handle(SenseNode), n"Gaze.Sense");

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.Shape = EMars_Trigger_Shape::Sphere;
        TriggerSpec.SphereRadius = InSpec.RangeCm;
        TriggerSpec.DetectionFilter = InSpec.DetectionFilter;
        TriggerSpec.Moving = true;

        auto SenseTransform = SenseNode.As_Transform();

        auto Params = FMars_Fragment_Gaze_Params();
        Params.Tuning.AimPoint = InSpec.AimPoint;
        Params.Tuning.RangeCm = InSpec.RangeCm;
        Params.Tuning.MinRangeCm = InSpec.MinRangeCm;
        Params.Tuning.ConeHalfAngleDeg = InSpec.ConeHalfAngleDeg;
        Params.Tuning.SwitchCloserRatio = InSpec.SwitchCloserRatio;

        auto State = FMars_Fragment_Gaze();
        State.Sense = utils_trigger::Add(SenseTransform, TriggerSpec);

        InEyeNode.Add_Fragment(FMars_Feature_Gaze());
        InEyeNode.Add_Fragment(Params);
        InEyeNode.Add_Fragment(State);
        return InEyeNode.As_Gaze();
    }

    bool Has(const FCk_Handle& InHandle)
    {
        return InHandle.Has_Fragment(FMars_Feature_Gaze);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_HasTarget(const FCk_Handle_Gaze& Self)
{
    return ck::IsValid(Self.Get_Target());
}

// Invalid when there is nothing to look at.
mixin FCk_Handle_Transform Get_Target(const FCk_Handle_Gaze& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gaze).Target;
}

// Degrees relative to the eye node's +X: X = yaw (positive right), Y = pitch (positive up). Zero when there is no target.
mixin FVector2D Get_AimYawPitchDeg(const FCk_Handle_Gaze& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gaze).AimYawPitchDeg;
}

// Sensed owners publishing no AimPoint that have been reported (ensured) and are still sensed.
mixin int32 Get_ReportedOwnerCount(const FCk_Handle_Gaze& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gaze).ReportedOwnersWithoutAim.Num();
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnTargetChanged(FCk_Handle_Gaze& Self, FMars_Delegate_Gaze_OnTargetChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Gaze_Signals);
    Fragment.OnTargetChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetChanged(FCk_Handle_Gaze& Self, FMars_Delegate_Gaze_OnTargetChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Gaze_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Gaze_Signals).OnTargetChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
