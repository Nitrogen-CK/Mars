namespace utils_throw_preview
{
    // Predicts from the held item, so HeldItemUse must be composed first. All-or-nothing: a rejected spec adds nothing.
    FCk_Handle_ThrowPreview Add(FCk_Handle& InHandle, FMars_ThrowPreview_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ThrowPreview] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_ThrowPreview(); }

        if (ck::EnsureIfNot(InHandle.Is_HeldItemUse(), f"[ThrowPreview] [{InHandle.ToString()}] needs HeldItemUse before ThrowPreview"))
        { return FCk_Handle_ThrowPreview(); }

        auto Params = FMars_Fragment_ThrowPreview_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_ThrowPreview());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_ThrowPreview());
        return InHandle.As_ThrowPreview();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// An aim is requested (the last SetAim drained was Aiming).
mixin bool Get_IsAiming(const FCk_Handle_ThrowPreview& Self)
{
    return Self.Has_Fragment(FMars_Tag_ThrowPreview_Aiming);
}

// The path as last predicted; End is None while not aiming.
mixin FMars_ThrowPreview_Path Get_Path(const FCk_Handle_ThrowPreview& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ThrowPreview).Path;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The drain broadcasts OnAimChanged on change; only the last SetAim of a frame applies.
mixin void Request_SetAim(FCk_Handle_ThrowPreview& Self, const FMars_Request_ThrowPreview_SetAim& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ThrowPreview_Requests);
    Requests.SetAimRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnAimChanged(FCk_Handle_ThrowPreview& Self, FMars_Delegate_ThrowPreview_OnAimChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ThrowPreview_Signals);
    Fragment.OnAimChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAimChanged(FCk_Handle_ThrowPreview& Self, FMars_Delegate_ThrowPreview_OnAimChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ThrowPreview_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnAimChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPathUpdated(FCk_Handle_ThrowPreview& Self, FMars_Delegate_ThrowPreview_OnPathUpdated InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ThrowPreview_Signals);
    Fragment.OnPathUpdated.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPathUpdated(FCk_Handle_ThrowPreview& Self, FMars_Delegate_ThrowPreview_OnPathUpdated InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ThrowPreview_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnPathUpdated.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
