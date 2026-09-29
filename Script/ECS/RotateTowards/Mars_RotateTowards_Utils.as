namespace utils_rotate_towards
{
    FCk_Handle_RotateTowards Add(FCk_Handle_Transform& InHandle, FMars_RotateTowards_Spec InParams)
    {
        auto Params = FMars_Fragment_RotateTowards_Params();
        Params.ControllerSettings = InParams.ControllerSettings;
        Params.TurnRateSettings = InParams.TurnRateSettings;
        Params.AxisLockingSettings = InParams.AxisLockingSettings;

        auto State = FMars_Fragment_RotateTowards();
        State.GoalTargetPoint = InParams.GoalTargetPoint;
        State.RangeClampSettings = InParams.RangeClampSettings;

        InHandle.Add_Fragment(FMars_Feature_RotateTowards());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_RotateTowards();
    }

    bool Has(const FCk_Handle& InHandle)
    {
        return InHandle.Has_Fragment(FMars_Feature_RotateTowards);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Transform Get_CurrentTarget(const FCk_Handle_RotateTowards& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RotateTowards).GoalTargetPoint;
}

mixin bool Get_HasReachedTarget(const FCk_Handle_RotateTowards& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RotateTowards).HasReachedTarget;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_UpdateTarget(FCk_Handle_RotateTowards& Self, FCk_Handle_Transform InNewTarget)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.UpdateTarget = FMars_Request_RotateTowards_UpdateTarget(InNewTarget);
}

mixin void Request_ClearTarget(FCk_Handle_RotateTowards& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.ClearTarget = true;
}

mixin void Request_SetRestReferencePoint(FCk_Handle_RotateTowards& Self, FCk_Handle_Transform InRestReferencePoint)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.SetRestReferencePoint = FMars_Request_RotateTowards_SetRestReferencePoint(InRestReferencePoint);
}

mixin void Request_SetYawRange(FCk_Handle_RotateTowards& Self, FCk_FloatRange InYawRange)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.SetYawRange = FMars_Request_RotateTowards_SetYawRange(InYawRange);
}

mixin void Request_SetPitchRange(FCk_Handle_RotateTowards& Self, FCk_FloatRange InPitchRange)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.SetPitchRange = FMars_Request_RotateTowards_SetPitchRange(InPitchRange);
}

mixin void Request_SetRollRange(FCk_Handle_RotateTowards& Self, FCk_FloatRange InRollRange)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Requests);
    Requests.SetRollRange = FMars_Request_RotateTowards_SetRollRange(InRollRange);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnTargetChanged(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Signals);
    Fragment.OnTargetChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetChanged(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RotateTowards_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTargetReached(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetReached InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Signals);
    Fragment.OnTargetReached.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetReached(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetReached InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RotateTowards_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetReached.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTargetCleared(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetCleared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RotateTowards_Signals);
    Fragment.OnTargetCleared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetCleared(FCk_Handle_RotateTowards& Self, FMars_Delegate_RotateTowards_OnTargetCleared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RotateTowards_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetCleared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
