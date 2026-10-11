namespace utils_body_probe
{
    // Creates the probe node under InParent (the character's transform), the same shape as the spec's character capsule.
    // A rejected spec ensures and returns an invalid handle with nothing created.
    FCk_Handle_BodyProbe Create(FCk_Handle_Transform& InParent, FMars_BodyProbe_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[BodyProbe] [{InParent.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_BodyProbe(); }

        auto Character = InSpec.Character.Get();
        const auto Capsule = Character.CapsuleComponent;
        // A probe capsule's half height is its cylinder's (Jolt), without the hemispheres UE's capsule half height includes.
        auto ProbeNode = utils_prefab::Create_ProbeNode_Capsule(
            InParent, Capsule.GetScaledCapsuleHalfHeight_WithoutHemisphere(), Capsule.GetScaledCapsuleRadius(), InSpec.Probe);

        auto Params = FMars_Fragment_BodyProbe_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_BodyProbe();
        State.HalfHeight = Capsule.GetScaledCapsuleHalfHeight_WithoutHemisphere();
        State.Radius = Capsule.GetScaledCapsuleRadius();

        ProbeNode.Add_Fragment(FMars_Feature_BodyProbe());
        ProbeNode.Add_Fragment(Params);
        ProbeNode.Add_Fragment(State);
        return ProbeNode.As_BodyProbe();
    }
}
