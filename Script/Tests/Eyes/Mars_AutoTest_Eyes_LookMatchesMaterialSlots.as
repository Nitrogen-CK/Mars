// The MarsEyePlate look reads custom primitive data exactly where utils_eyes::Push_PlateGroup writes it: LeftCell / Blend /
// LookX / EyeColor sit at k_Slot_Cells / k_Slot_Anim / k_Slot_Look / k_Slot_Color and the 4 + 4 + 2 scalars of each group are
// consecutive from their slot. The parameters are in the shader's order after In (the generator passes them
// positionally). The master is generated under the Mars root as an unlit opaque surface. Reads the definition only;
// nothing is placed. Isolated Z band: -69000.
class UMars_AutoTest_Eyes_LookMatchesMaterialSlots : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the parameters are in Mars_Look_EyePlate's order", n"Step_AssertOrder");
        Add_Step("each group's parameters read consecutive slots from the material's group slot", n"Step_AssertSlots");
        Add_Step("the master is an unlit opaque surface generated under the Mars root", n"Step_AssertMaster");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertOrder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<FName> Expected;
        Expected.Add(n"Atlas");
        Expected.Add(n"LeftCell");
        Expected.Add(n"RightCell");
        Expected.Add(n"PrevLeftCell");
        Expected.Add(n"PrevRightCell");
        Expected.Add(n"Blend");
        Expected.Add(n"BlinkLeft");
        Expected.Add(n"BlinkRight");
        Expected.Add(n"Strength");
        Expected.Add(n"LookX");
        Expected.Add(n"LookY");
        Expected.Add(n"EyeColor");
        Expected.Add(n"AtlasCols");
        Expected.Add(n"AtlasRows");
        Expected.Add(n"EyeScale");
        Expected.Add(n"LookMaxUV");
        Expected.Add(n"MinBlinkScale");
        Expected.Add(n"GlowStrength");
        Expected.Add(n"CellPad");

        auto LookDefinition = utils_eyes::Look_EyePlate();
        const auto NumParameters = LookDefinition._Parameters.Num();
        Assert_Equals_Int(NumParameters, Expected.Num(), "MarsEyePlate parameter count");

        const auto NumToCompare = NumParameters < Expected.Num() ? NumParameters : Expected.Num();
        for (int32 Index = 0; Index < NumToCompare; ++Index)
        {
            const auto ActualName = LookDefinition._Parameters[Index]._Name;
            Assert_True(ActualName == Expected[Index],
                f"parameter {Index} is [{Expected[Index].ToString()}] (got [{ActualName.ToString()}])");
        }
    }

    UFUNCTION()
    private void Step_AssertSlots(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertSlot(n"LeftCell", constants_eyes::k_Slot_Cells, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"RightCell", constants_eyes::k_Slot_Cells + 1, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"PrevLeftCell", constants_eyes::k_Slot_Cells + 2, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"PrevRightCell", constants_eyes::k_Slot_Cells + 3, ECk_Usf_ParamType::Scalar);

        AssertSlot(n"Blend", constants_eyes::k_Slot_Anim, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"BlinkLeft", constants_eyes::k_Slot_Anim + 1, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"BlinkRight", constants_eyes::k_Slot_Anim + 2, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"Strength", constants_eyes::k_Slot_Anim + 3, ECk_Usf_ParamType::Scalar);

        AssertSlot(n"LookX", constants_eyes::k_Slot_Look, ECk_Usf_ParamType::Scalar);
        AssertSlot(n"LookY", constants_eyes::k_Slot_Look + 1, ECk_Usf_ParamType::Scalar);

        AssertSlot(n"EyeColor", constants_eyes::k_Slot_Color, ECk_Usf_ParamType::Vector);
    }

    UFUNCTION()
    private void Step_AssertMaster(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_String(utils_eyes::Look_EyePlate()._GeneratedPackageRoot, "/Game/Mars/Materials/GeneratedLooks", "_GeneratedPackageRoot");

        const auto Domain = utils_eyes::Look_EyePlate()._Domain;
        Assert_True(Domain == ECk_Usf_Domain::SurfaceUnlit, f"_Domain is SurfaceUnlit (got [{Domain :n}])");

        const auto BlendMode = utils_eyes::Look_EyePlate()._BlendMode;
        Assert_True(BlendMode == ECk_Usf_BlendMode::Opaque, f"_BlendMode is Opaque (got [{BlendMode :n}])");
    }

    private void AssertSlot(FName InName, int32 InExpectedIndex, ECk_Usf_ParamType InExpectedType)
    {
        const auto ParamName = InName.ToString();
        for (const auto& Parameter : utils_eyes::Look_EyePlate()._Parameters)
        {
            if (Parameter._Name != InName)
            { continue; }

            Assert_True(Parameter._Type == InExpectedType, f"[{ParamName}] is a {InExpectedType :n} (got [{Parameter._Type :n}])");
            Assert_True(Parameter._CustomPrimitiveData, f"[{ParamName}] reads custom primitive data");
            Assert_Equals_Int(Parameter._CustomPrimitiveDataIndex, InExpectedIndex, f"[{ParamName}] custom primitive data index");
            return;
        }

        Assert_True(false, f"[{ParamName}] is a parameter of MarsEyePlate");
    }
}
