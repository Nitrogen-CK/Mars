// The MarsEyeball and MarsEyelid looks read per-instance data and custom primitive data exactly where utils_eye_swarm writes
// them (constants_eye_swarm): Phase / Variant at k_Slot_Phase / k_Slot_Variant with k_NumCustomDataFloats per instance, and
// PhaseCpd / FocusOverride / FocusOverrideWeight at k_Cpd_*; and both read the four roster heads Player0..Player3 as
// vectors from EyeSwarm_Mars_MPC, which the roster writes. Reads the definitions only; nothing is placed or rendered, so the
// masters, the collection and the meshes need not exist. Isolated Z band: -79000 (unused).
class UMars_AutoTest_EyeSwarm_LookMatchesSlotLayout : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("both looks resolve", n"Step_AssertLooksResolve");
        Add_Step("Phase and Variant sit at the per-instance slots the ISM writer fills", n"Step_AssertPerInstance");
        Add_Step("PhaseCpd, FocusOverride and FocusOverrideWeight read the custom primitive data the cluster writes", n"Step_AssertCpd");
        Add_Step("both looks read Player0..Player3 from EyeSwarm_Mars_MPC", n"Step_AssertRoster");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLooksResolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(utils_eye_swarm::Get_EyeballLook()) || ck::Is_NOT_Valid(utils_eye_swarm::Get_EyelidLook()))
        { FinishFailure("MarsEyeball or MarsEyelid does not resolve (Script/ECS/EyeSwarm/Mars_EyeSwarm_Look_Assets.as)"); }
    }

    UFUNCTION()
    private void Step_AssertPerInstance(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertPerInstance(utils_eye_swarm::Get_EyeballLook());
        AssertPerInstance(utils_eye_swarm::Get_EyelidLook());
    }

    UFUNCTION()
    private void Step_AssertCpd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < 2; ++Index)
        {
            auto Look = Index == 0 ? utils_eye_swarm::Get_EyeballLook() : utils_eye_swarm::Get_EyelidLook();
            AssertCpd(Look, n"PhaseCpd", constants_eye_swarm::k_Cpd_PhaseCpd, ECk_Usf_ParamType::Scalar);
            AssertCpd(Look, n"FocusOverride", constants_eye_swarm::k_Cpd_FocusOverride, ECk_Usf_ParamType::Vector);
            AssertCpd(Look, n"FocusOverrideWeight", constants_eye_swarm::k_Cpd_FocusOverrideWeight, ECk_Usf_ParamType::Scalar);
        }
    }

    UFUNCTION()
    private void Step_AssertRoster(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Slot = 0; Slot < constants_eye_swarm::k_NumPlayerSlots; ++Slot)
        {
            AssertRosterParam(utils_eye_swarm::Get_EyeballLook(), utils_eye_swarm::Get_PlayerParam(Slot));
            AssertRosterParam(utils_eye_swarm::Get_EyelidLook(), utils_eye_swarm::Get_PlayerParam(Slot));
        }
    }

    private void AssertPerInstance(const UCkUsf_LookDefinition InLook)
    {
        const auto LookName = InLook.GetName().ToString();
        Assert_Equals_Int(InLook.Get_PerInstanceSlotOf(n"Phase"), constants_eye_swarm::k_Slot_Phase, f"[{LookName}] Phase per-instance slot");
        Assert_Equals_Int(InLook.Get_PerInstanceSlotOf(n"Variant"), constants_eye_swarm::k_Slot_Variant, f"[{LookName}] Variant per-instance slot");
        Assert_Equals_Int(InLook.Get_NumPerInstanceFloats(), constants_eye_swarm::k_NumCustomDataFloats, f"[{LookName}] per-instance floats");
    }

    private void AssertCpd(const UCkUsf_LookDefinition InLook, FName InName, int32 InExpectedIndex, ECk_Usf_ParamType InExpectedType)
    {
        const auto What = f"[{InLook.GetName().ToString()}] [{InName.ToString()}]";
        for (const auto& Parameter : InLook._Parameters)
        {
            if (Parameter._Name != InName)
            { continue; }

            Assert_True(Parameter._Type == InExpectedType, f"{What} is a {InExpectedType :n} (got [{Parameter._Type :n}])");
            Assert_True(Parameter._CustomPrimitiveData, f"{What} reads custom primitive data");
            Assert_Equals_Int(Parameter._CustomPrimitiveDataIndex, InExpectedIndex, f"{What} custom primitive data index");
            return;
        }

        Assert_True(false, f"{What} is a parameter of the look");
    }

    private void AssertRosterParam(const UCkUsf_LookDefinition InLook, FName InCollectionParameter)
    {
        const auto What = f"[{InLook.GetName().ToString()}] [{InCollectionParameter.ToString()}]";
        for (const auto& Parameter : InLook._Parameters)
        {
            if (Parameter._FromCollection == false)
            { continue; }

            // NAME_None reads the collection parameter named like the material parameter.
            const auto ReadName = Parameter._CollectionParameterName.IsNone() ? Parameter._Name : Parameter._CollectionParameterName;
            if (ReadName != InCollectionParameter)
            { continue; }

            Assert_True(Parameter._Type == ECk_Usf_ParamType::Vector, f"{What} is a Vector (got [{Parameter._Type :n}])");
            const auto CollectionPath = Parameter._Collection.ToSoftObjectPath().ToString();
            Assert_True(CollectionPath == constants_eye_swarm::k_MpcPath || CollectionPath == constants_eye_swarm::k_MpcPackage,
                f"{What} reads [{constants_eye_swarm::k_MpcPath}] (got [{CollectionPath}])");
            return;
        }

        Assert_True(false, f"{What} is read from a collection by the look");
    }
}
