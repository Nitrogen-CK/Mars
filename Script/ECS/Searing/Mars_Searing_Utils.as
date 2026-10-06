namespace utils_searing
{
    const int32 k_FaceCount = 6;
    const int32 k_SearSignalSteps = 10;
    // The pan base disc's half height; the steak spawns and is judged relative to the disc top.
    const float32 k_PanBaseHalfHeight = 1.5f;
    // How long a new down face must stay down on the pan before it is the resting face (a flip): a tumbling cube passes
    // other faces down for a frame or two, and neither the liftoff nor the first contact shows the face it settles on.
    const float32 k_FaceSettleSeconds = 0.1f;

    // Composes the minigame on InHandle (the station entity; the feature does not need the Station feature). The spec's
    // Nodes are built by the caller: Nodes.Pan is the Implement on the pan node (the kernel makes it Driven while hot and
    // forwards the looks to it), and the steak counts as on the pan only while it rests on Nodes.PanBaseBody. The first
    // steak spawns on the next Tick. A rejected spec or a missing node ensures and returns an invalid handle.
    FCk_Handle_Searing Add(FCk_Handle& InHandle, FMars_Searing_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Searing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Searing(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Pan) && ck::IsValid(InSpec.Nodes.PanBaseBody),
            f"[Searing] [{InHandle.ToString()}] needs a pan implement and a pan base body"))
        { return FCk_Handle_Searing(); }

        auto Params = FMars_Fragment_Searing_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Searing();
        State.Phase = EMars_Searing_Phase::NoSteak;
        State.Steak.RespawnCountdown = 0.0f;

        InHandle.Add_Fragment(FMars_Feature_Searing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Searing();
    }

    // The face's outward normal in the steak's own frame.
    FVector Get_FaceNormal(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return FVector(1.0, 0.0, 0.0);
            case EMars_Searing_Face::NegX: return FVector(-1.0, 0.0, 0.0);
            case EMars_Searing_Face::PosY: return FVector(0.0, 1.0, 0.0);
            case EMars_Searing_Face::NegY: return FVector(0.0, -1.0, 0.0);
            case EMars_Searing_Face::PosZ: return FVector(0.0, 0.0, 1.0);
            default: return FVector(0.0, 0.0, -1.0);
        }
    }

    EMars_Searing_Face Get_OppositeFace(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return EMars_Searing_Face::NegX;
            case EMars_Searing_Face::NegX: return EMars_Searing_Face::PosX;
            case EMars_Searing_Face::PosY: return EMars_Searing_Face::NegY;
            case EMars_Searing_Face::NegY: return EMars_Searing_Face::PosY;
            case EMars_Searing_Face::PosZ: return EMars_Searing_Face::NegZ;
            default: return EMars_Searing_Face::PosZ;
        }
    }

    // The face whose world normal (InSteakRotation applied to its body normal) has the smallest dot with InPanUp.
    EMars_Searing_Face Get_DownFace(const FQuat& InSteakRotation, const FVector& InPanUp)
    {
        auto Best = EMars_Searing_Face::NegZ;
        auto BestDot = 2.0;
        for (int32 Index = 0; Index < k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto Dot = InSteakRotation.RotateVector(Get_FaceNormal(Face)).DotProduct(InPanUp);
            if (Dot < BestDot)
            {
                BestDot = Dot;
                Best = Face;
            }
        }

        return Best;
    }

    // The steak rotation that lays InFace against -Z. MakeFromXZ(X, -N) turns the body's +Z onto -N (X is any body axis
    // perpendicular to N); its inverse is the rotation that turns N onto -Z.
    FRotator Make_FaceDownRotation(EMars_Searing_Face InFace)
    {
        const auto Normal = Get_FaceNormal(InFace);
        const auto Perpendicular = Math::Abs(Normal.X) > 0.5 ? FVector(0.0, 0.0, 1.0) : FVector(1.0, 0.0, 0.0);
        const auto Basis = FTransform(FQuat(FRotator::MakeFromXZ(Perpendicular, -Normal)), FVector::ZeroVector, FVector::OneVector);
        return Basis.InverseTransformRotation(FQuat::Identity).Rotator();
    }

    FString Get_FaceName(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return "+X";
            case EMars_Searing_Face::NegX: return "-X";
            case EMars_Searing_Face::PosY: return "+Y";
            case EMars_Searing_Face::NegY: return "-Y";
            case EMars_Searing_Face::PosZ: return "+Z";
            default: return "-Z";
        }
    }

    // What the station's label reads, by phase and heat.
    FText Get_StateLabel(const FCk_Handle_Searing& InSearing)
    {
        const auto Seared = InSearing.Get_SearedFaceCount();
        const auto Phase = InSearing.Get_Phase();

        if (Phase == EMars_Searing_Phase::Done)
        {
            const auto Tally = InSearing.Get_Tally();
            return FText::FromString(f"Seared in {Tally.Seconds :.1} s ({Tally.Losses} lost)");
        }

        if (Phase == EMars_Searing_Phase::NoSteak)
        { return FText::FromString("Lost it! Fresh steak..."); }

        if (Phase == EMars_Searing_Phase::Airborne)
        { return FText::FromString("..."); }

        if (InSearing.Get_IsHot() == false)
        { return FText::FromString(f"Steak: {Seared}/6 seared"); }

        if (InSearing.Get_IsDownFaceSeared())
        { return FText::FromString(f"Tilt or toss! {Seared}/6"); }

        return FText::FromString(f"Searing... {Seared}/6");
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Searing_Spec Get_Spec(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing_Params).Spec;
}

mixin EMars_Searing_Phase Get_Phase(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Phase;
}

mixin EMars_Searing_Heat Get_Heat(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Heat;
}

mixin bool Get_IsHot(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Heat == EMars_Searing_Heat::Hot;
}

// Invalid while NoSteak.
mixin FCk_Handle Get_Steak(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Steak.Entity;
}

mixin FCk_Handle_JoltBody Get_SteakBody(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Steak.Body;
}

mixin bool Get_HasSteak(const FCk_Handle_Searing& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Searing).Steak.Entity);
}

// The Implement the pan node carries.
mixin FCk_Handle_Implement Get_Pan(const FCk_Handle_Searing& Self)
{
    return Self.Get_Spec().Nodes.Pan;
}

// FRotator(Pitch, 0, Roll), degrees, on top of the pan's rest rotation.
mixin FRotator Get_PanTilt(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Tilt();
}

mixin float32 Get_PanLift(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Lift();
}

// The pan base body's world transform as of the last transform update.
mixin FTransform Get_PanBaseWorld(const FCk_Handle_Searing& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Spec().Nodes.PanBaseBody.As_Transform());
}

mixin FVector Get_PanUp(const FCk_Handle_Searing& Self)
{
    return Self.Get_PanBaseWorld().GetRotation().GetUpVector();
}

// The steak's centre in the pan base body's frame (the base top is at Z = utils_searing::k_PanBaseHalfHeight); zero
// without a steak.
mixin FVector Get_SteakPanLocal(const FCk_Handle_Searing& Self)
{
    const auto Steak = Self.Get_Steak();
    if (ck::Is_NOT_Valid(Steak))
    { return FVector::ZeroVector; }

    const auto SteakWorld = utils_transform::Get_EntityCurrentTransform(Steak.As_Transform());
    return Self.Get_PanBaseWorld().InverseTransformPosition(SteakWorld.GetLocation());
}

// The steak face pointing most against the pan's up; NegZ without a steak.
mixin EMars_Searing_Face Get_DownFace(const FCk_Handle_Searing& Self)
{
    const auto Steak = Self.Get_Steak();
    if (ck::Is_NOT_Valid(Steak))
    { return EMars_Searing_Face::NegZ; }

    const auto SteakWorld = utils_transform::Get_EntityCurrentTransform(Steak.As_Transform());
    return utils_searing::Get_DownFace(SteakWorld.GetRotation(), Self.Get_PanUp());
}

// 0 raw .. 1 seared; 0 without a steak.
mixin float32 Get_FaceSear(const FCk_Handle_Searing& Self, EMars_Searing_Face InFace)
{
    const auto& FaceSear = Self.Get_Fragment(FMars_Fragment_Searing).Steak.FaceSear;
    const auto Index = int32(InFace);
    if (FaceSear.IsValidIndex(Index) == false)
    { return 0.0f; }

    return FaceSear[Index];
}

mixin int32 Get_SearedFaceCount(const FCk_Handle_Searing& Self)
{
    auto Count = 0;
    for (const auto Sear : Self.Get_Fragment(FMars_Fragment_Searing).Steak.FaceSear)
    {
        if (Sear >= 1.0f)
        { Count += 1; }
    }

    return Count;
}

mixin bool Get_IsOnPan(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Phase == EMars_Searing_Phase::OnPan;
}

mixin bool Get_IsDownFaceSeared(const FCk_Handle_Searing& Self)
{
    return Self.Get_FaceSear(Self.Get_DownFace()) >= 1.0f;
}

mixin EMars_Searing_Sizzle Get_Sizzle(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Sizzle;
}

mixin FMars_Searing_Tally Get_Tally(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Tally;
}

mixin int32 Get_LostSteakCount(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).LostSteaks.Num();
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Look(FCk_Handle_Searing& Self, const FMars_Request_Searing_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.LookRequests.Add(InRequest);
}

mixin void Request_SetHeat(FCk_Handle_Searing& Self, const FMars_Request_Searing_SetHeat& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.SetHeatRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Searing& Self, const FMars_Request_Searing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnHeatChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSteakSpawned(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSteakSpawned InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSteakSpawned.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSteakSpawned(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSteakSpawned InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSteakSpawned.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPanContactChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPanContactChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSearProgress.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSearProgress.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnFaceSeared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSizzleChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSizzleChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSteakLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSteakLost InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSteakLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSteakLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSteakLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSteakLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCompleted(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnCompleted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnCompleted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCompleted(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnCompleted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnCompleted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
