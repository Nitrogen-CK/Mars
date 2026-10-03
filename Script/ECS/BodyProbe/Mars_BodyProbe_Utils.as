namespace utils_body_probe
{
    // Creates the probe node under InParent (the character's transform), sized to the spec's character capsule. A rejected
    // spec ensures and returns an invalid handle with nothing created.
    FCk_Handle_BodyProbe Create(FCk_Handle_Transform& InParent, FMars_BodyProbe_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[BodyProbe] [{InParent.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_BodyProbe(); }

        auto Character = InSpec.Character.Get();
        const auto Capsule = Character.CapsuleComponent;
        auto ProbeNode = utils_prefab::Create_ProbeNode_Capsule(
            InParent, Capsule.GetScaledCapsuleHalfHeight(), Capsule.GetScaledCapsuleRadius(), InSpec.Probe);

        auto Params = FMars_Fragment_BodyProbe_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_BodyProbe();
        State.HalfHeight = Capsule.GetScaledCapsuleHalfHeight();
        State.Radius = Capsule.GetScaledCapsuleRadius();

        ProbeNode.Add_Fragment(FMars_Feature_BodyProbe());
        ProbeNode.Add_Fragment(Params);
        ProbeNode.Add_Fragment(State);
        return ProbeNode.As_BodyProbe();
    }
}
