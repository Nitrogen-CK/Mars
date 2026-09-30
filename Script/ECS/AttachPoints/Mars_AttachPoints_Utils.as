namespace utils_attach_points
{
    // All-or-nothing (FMars_AttachPoints_Spec::Validate): a rejected spec adds nothing.
    FCk_Handle_AttachPoints Add(FCk_Handle& InOwner, FMars_AttachPoints_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[AttachPoints] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_AttachPoints(); }

        auto Params = FMars_Fragment_AttachPoints_Params();
        Params.Points = InSpec.Points;

        InOwner.Add_Fragment(FMars_Feature_AttachPoints());
        InOwner.Add_Fragment(Params);
        return InOwner.As_AttachPoints();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Has_AttachPoint(const FCk_Handle_AttachPoints& Self, FGameplayTag InTag)
{
    return ck::IsValid(Self.Get_AttachPoint(InTag));
}

// Invalid when the carrier publishes no point under InTag.
mixin FCk_Handle_Transform Get_AttachPoint(const FCk_Handle_AttachPoints& Self, FGameplayTag InTag)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_AttachPoints_Params);
    for (const auto& Entry : Params.Points)
    {
        if (Entry.Tag == InTag)
        { return Entry.Node; }
    }

    return FCk_Handle_Transform();
}
