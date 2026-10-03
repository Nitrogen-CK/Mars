namespace utils_trigger
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Trigger Add(FCk_Handle_Transform& InTransform, FMars_Trigger_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Trigger] [{InTransform.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Trigger(); }

        auto TriggerTransform = InTransform;
        if (InParams.LocalOffset.Equals(FTransform::Identity) == false)
        { TriggerTransform = utils_scene_node::Create(InTransform, InParams.LocalOffset).As_Transform(); }

        auto ProbeSpec = FCk_Probe_Spec();
        ProbeSpec.Set_Filter(InParams.DetectionFilter)
                 .Set_MotionType(InParams.Moving ? ECk_MotionType::Kinematic : ECk_MotionType::Static)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Notify);

        if (InParams.Shape == EMars_Trigger_Shape::Sphere)
        { utils_probe::Add_Sphere(TriggerTransform, InParams.SphereRadius, ProbeSpec); }
        else
        { utils_probe::Add_Box(TriggerTransform, InParams.BoxHalfExtents, ProbeSpec); }

        TriggerTransform.Add_Fragment(FMars_Feature_Trigger());
        TriggerTransform.Add_Fragment(FMars_Fragment_Trigger());
        TriggerTransform.Add_Fragment(FMars_Tag_Trigger_NeedsSetup());
        return TriggerTransform.As_Trigger();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// Reads skip handles that died between a probe teardown and the next exit signal.
mixin TArray<FCk_Handle> Get_EntitiesInside(const FCk_Handle_Trigger& Self)
{
    auto Result = TArray<FCk_Handle>();
    for (auto Entity : Self.Get_Fragment(FMars_Fragment_Trigger).EntitiesInside)
    {
        if (ck::IsValid(Entity))
        { Result.Add(Entity); }
    }
    return Result;
}

mixin int32 Get_EntityCount(const FCk_Handle_Trigger& Self)
{
    auto Count = 0;
    for (auto Entity : Self.Get_Fragment(FMars_Fragment_Trigger).EntitiesInside)
    {
        if (ck::IsValid(Entity))
        { ++Count; }
    }
    return Count;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnEntityEntered(FCk_Handle_Trigger& Self, FMars_Delegate_Trigger_OnEntityEntered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Trigger_Signals);
    Fragment.OnEntityEntered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEntityEntered(FCk_Handle_Trigger& Self, FMars_Delegate_Trigger_OnEntityEntered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Trigger_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Trigger_Signals).OnEntityEntered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEntityExited(FCk_Handle_Trigger& Self, FMars_Delegate_Trigger_OnEntityExited InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Trigger_Signals);
    Fragment.OnEntityExited.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEntityExited(FCk_Handle_Trigger& Self, FMars_Delegate_Trigger_OnEntityExited InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Trigger_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Trigger_Signals).OnEntityExited.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
