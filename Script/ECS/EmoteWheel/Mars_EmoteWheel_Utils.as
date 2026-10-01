namespace utils_emote_wheel
{
    // Loads the Definition once and copies its entries; the wheel starts closed.
    FCk_Handle_EmoteWheel Add(FCk_Handle& InPlayer, FMars_EmoteWheel_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[EmoteWheel] {Validation.Get_Error()}"))
        { return FCk_Handle_EmoteWheel(); }

        auto Definition = System::LoadAsset_Blocking(InSpec.Definition);
        if (ck::EnsureIfNot(ck::IsValid(Definition), f"[EmoteWheel] the Definition [{InSpec.Definition.ToString()}] did not load"))
        { return FCk_Handle_EmoteWheel(); }

        if (ck::EnsureIfNot(Definition.Entries.Num() > 0, f"[EmoteWheel] the Definition [{InSpec.Definition.ToString()}] has no entries"))
        { return FCk_Handle_EmoteWheel(); }

        auto Params = FMars_Fragment_EmoteWheel_Params();
        Params.Entries = Definition.Entries;
        Params.PointerTravel = InSpec.PointerTravel;
        Params.DeadZoneRatio = InSpec.DeadZoneRatio;

        InPlayer.Add_Fragment(FMars_Feature_EmoteWheel());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(FMars_Fragment_EmoteWheel());
        return InPlayer.As_EmoteWheel();
    }

    // The sector under a pointer (X right, Y down, length 1 = the rim): sector 0 is centred on the top and indices run
    // clockwise. -1 inside the dead zone or for an empty wheel. The widget lays sectors out with the same convention
    // (Get_SectorAngleDegrees), so what is hovered is always what is drawn under the pointer.
    int32 Get_SectorAt(FVector2D InPointer, int32 InSectorCount, float32 InDeadZoneRatio)
    {
        if (InSectorCount <= 0 || InPointer.Size() <= InDeadZoneRatio)
        { return -1; }

        const auto SectorDegrees = 360.0 / InSectorCount;
        auto Degrees = Math::RadiansToDegrees(Math::Atan2(InPointer.X, -InPointer.Y));
        if (Degrees < 0.0)
        { Degrees += 360.0; }

        return Math::FloorToInt((Degrees + SectorDegrees * 0.5) / SectorDegrees) % InSectorCount;
    }

    // Clockwise from the top, the sector's centre line.
    float32 Get_SectorAngleDegrees(int32 InIndex, int32 InSectorCount)
    {
        if (InSectorCount <= 0)
        { return 0.0f; }

        return float32(InIndex) * 360.0f / float32(InSectorCount);
    }

    // The point at InRadius on the sector's centre line, in screen space (X right, Y down).
    FVector2D Get_SectorPoint(int32 InIndex, int32 InSectorCount, float32 InRadius)
    {
        const auto Radians = Math::DegreesToRadians(Get_SectorAngleDegrees(InIndex, InSectorCount));
        return FVector2D(Math::Sin(Radians) * InRadius, -Math::Cos(Radians) * InRadius);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin TArray<FMars_EmoteWheel_Entry> Get_Entries(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel_Params).Entries;
}

mixin int32 Get_EntryCount(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel_Params).Entries.Num();
}

// Unset when InIndex is out of range (including -1, nothing hovered).
mixin TOptional<FMars_EmoteWheel_Entry> TryGet_Entry(const FCk_Handle_EmoteWheel& Self, int32 InIndex)
{
    const auto& Entries = Self.Get_Fragment(FMars_Fragment_EmoteWheel_Params).Entries;
    if (Entries.IsValidIndex(InIndex) == false)
    { return TOptional<FMars_EmoteWheel_Entry>(); }

    return TOptional<FMars_EmoteWheel_Entry>(Entries[InIndex]);
}

mixin float32 Get_DeadZoneRatio(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel_Params).DeadZoneRatio;
}

mixin bool Get_IsOpen(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel).IsOpen;
}

mixin FVector2D Get_Pointer(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel).Pointer;
}

mixin int32 Get_HoveredIndex(const FCk_Handle_EmoteWheel& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EmoteWheel).HoveredIndex;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Open(FCk_Handle_EmoteWheel& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Requests);
    Requests.OpenRequests.Add(FMars_Request_EmoteWheel_Open());
}

mixin void Request_MovePointer(FCk_Handle_EmoteWheel& Self, const FMars_Request_EmoteWheel_MovePointer& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Requests);
    Requests.MovePointerRequests.Add(InRequest);
}

mixin void Request_Close(FCk_Handle_EmoteWheel& Self, const FMars_Request_EmoteWheel_Close& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Requests);
    Requests.CloseRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnOpened(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnOpened InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Signals);
    Fragment.OnOpened.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnOpened(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnOpened InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_EmoteWheel_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnOpened.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnClosed(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnClosed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Signals);
    Fragment.OnClosed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnClosed(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnClosed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_EmoteWheel_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnClosed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHoveredChanged(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnHoveredChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Signals);
    Fragment.OnHoveredChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHoveredChanged(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnHoveredChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_EmoteWheel_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnHoveredChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEmoteChosen(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnEmoteChosen InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_EmoteWheel_Signals);
    Fragment.OnEmoteChosen.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEmoteChosen(FCk_Handle_EmoteWheel& Self, FMars_Delegate_EmoteWheel_OnEmoteChosen InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_EmoteWheel_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnEmoteChosen.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
