// What an interactable's owner tells a reach about itself: what it spans (in the owner's frame) and how many hands take it.
// Composition data, written by the owner's composer (a world item's Add, a dock's sync when a platter docks or leaves),
// read by the gloves (utils_fphands::Resolve_ReachTarget), so the gloves never reach into the owner's own feature to size
// a grip. No requests: it is a fact the owner declares, not state a processor advances.
struct FMars_Fragment_ReachHint
{
    UPROPERTY()
    FMars_WorldItem_BoundsFit BoundsFit;

    UPROPERTY()
    EMars_ItemPresentation_Handedness Handedness = EMars_ItemPresentation_Handedness::TwoHanded;

    // Two-handed: half the distance between the palms. Unset sizes it from BoundsFit.
    UPROPERTY()
    TOptional<float32> HalfWidth;

    FMars_Fragment_ReachHint() {}

    FMars_Fragment_ReachHint(FMars_WorldItem_BoundsFit InBoundsFit, EMars_ItemPresentation_Handedness InHandedness, TOptional<float32> InHalfWidth)
    {
        BoundsFit = InBoundsFit;
        Handedness = InHandedness;
        HalfWidth = InHalfWidth;
    }
}

mixin FMars_Validation Validate(const FMars_Fragment_ReachHint& Self)
{
    const auto Extents = Self.BoundsFit.HalfExtents;
    if (Extents.ContainsNaN() || Extents.X < 0.0 || Extents.Y < 0.0 || Extents.Z < 0.0)
    { return FMars_Validation(f"BoundsFit.HalfExtents [{Extents}] is not finite and non-negative"); }

    if (Self.HalfWidth.IsSet() && (Math::IsFinite(Self.HalfWidth.GetValue()) == false || Self.HalfWidth.GetValue() <= 0.0f))
    { return FMars_Validation(f"HalfWidth [{Self.HalfWidth.GetValue()}] is not a positive distance"); }

    return FMars_Validation();
}

namespace utils_reach_hint
{
    // An owner's hint at composition. A rejected hint adds nothing.
    void Add(FCk_Handle& InOwner, const FMars_Fragment_ReachHint& InHint)
    {
        const auto Validation = InHint.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ReachHint] [{InOwner.ToString()}] rejected the hint: {Validation.Get_Error()}"))
        { return; }

        if (ck::EnsureIfNot(InOwner.Has_Fragment(FMars_Fragment_ReachHint) == false, f"[ReachHint] [{InOwner.ToString()}] already carries a reach hint"))
        { return; }

        InOwner.Add_Fragment(InHint);
    }

    // Replaces (or adds) the hint of an owner whose shape changes after composition (a dock gaining a platter).
    void Set(FCk_Handle& InOwner, const FMars_Fragment_ReachHint& InHint)
    {
        const auto Validation = InHint.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ReachHint] [{InOwner.ToString()}] rejected the hint: {Validation.Get_Error()}"))
        { return; }

        auto& Hint = InOwner.AddOrGet_Fragment(FMars_Fragment_ReachHint);
        Hint = InHint;
    }

    // An owner with nothing to hint any more (a dock whose platter left). No hint: nothing to remove.
    void Remove(FCk_Handle& InOwner)
    {
        if (InOwner.Has_Fragment(FMars_Fragment_ReachHint))
        { InOwner.Request_TryRemove(FMars_Fragment_ReachHint); }
    }
}

mixin bool Has_ReachHint(const FCk_Handle& Self)
{
    return ck::IsValid(Self) && Self.Has_Fragment(FMars_Fragment_ReachHint);
}

// Has_ReachHint first.
mixin FMars_Fragment_ReachHint Get_ReachHint(const FCk_Handle& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ReachHint);
}
