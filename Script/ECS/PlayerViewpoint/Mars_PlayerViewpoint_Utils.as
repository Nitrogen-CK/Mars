namespace utils_player_viewpoint
{
    // All-or-nothing: a rejected spec adds nothing and returns an invalid handle.
    FCk_Handle_PlayerViewpoint Add(FCk_Handle& InHandle, FMars_PlayerViewpoint_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PlayerViewpoint] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_PlayerViewpoint(); }

        auto State = FMars_Fragment_PlayerViewpoint();
        State.Camera = InSpec.Camera;
        State.Viewpoint = InSpec.Camera.Get_ViewAnchor();
        utils_handle::Set_DebugName(State.Viewpoint, n"PlayerViewpoint");

        auto TraceSettings = FCk_Probe_RayCastPersistent_Settings(
            State.Viewpoint,
            FVector(InSpec.InteractionTraceDistance, 0.0, 0.0),
            GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Probe_Mars_Interact));
        TraceSettings.Set_TracePolicy(ECk_ProbeTrace_Policy::Multi);
        State.InteractionTrace = utils_probe_trace::Create_LineTrace_Persistent(TraceSettings);
        utils_handle::Set_DebugName(State.InteractionTrace, n"PlayerViewpoint.InteractionTrace");

        InHandle.Add_Fragment(FMars_Feature_PlayerViewpoint());
        InHandle.Add_Fragment(State);
        return InHandle.As_PlayerViewpoint();
    }

    // The director's resting profile for the first-person view: eye-anchored (pivot 0, boom 0), no collision, free yaw,
    // clamped pitch, LookSpeed degrees per intention unit.
    FCk_CameraProfile Make_CameraProfile(const FMars_PlayerViewpoint_Spec& InSpec)
    {
        FCk_CameraProfile Profile;

        auto Rig = Profile.Get_Rig();
        Rig.Set_BoomArmPivotOffset(FVector::ZeroVector);
        Rig.Set_BoomArmLength(0.0f);
        Rig.Set_FramingOffset(FVector::ZeroVector);
        Profile.Set_Rig(Rig);

        auto Sensor = Profile.Get_Sensor();
        Sensor.Set_FOV(InSpec.FieldOfView);
        Profile.Set_Sensor(Sensor);

        auto OrientationControl = Profile.Get_OrientationControl();
        auto Yaw = OrientationControl.Get_Yaw();
        Yaw.Set_Speed(InSpec.LookSpeed);
        Yaw.Set_Limits(FCk_FloatRange(-180.0f, 180.0f));
        OrientationControl.Set_Yaw(Yaw);
        auto Pitch = OrientationControl.Get_Pitch();
        Pitch.Set_Speed(InSpec.LookSpeed);
        Pitch.Set_Limits(InSpec.PitchLimits);
        OrientationControl.Set_Pitch(Pitch);
        Profile.Set_OrientationControl(OrientationControl);

        Profile.Set_HasOrientationControl(true);
        Profile.Set_HasAutoReorient(false);
        Profile.Set_HasCollision(false);
        return Profile;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Camera Get_Camera(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint).Camera;
}

mixin FCk_Handle_Transform Get_Viewpoint(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint).Viewpoint;
}

mixin FCk_Handle_ProbeTrace Get_InteractionTrace(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint).InteractionTrace;
}
