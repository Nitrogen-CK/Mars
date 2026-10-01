// A spawned eyes dummy publishes its head as AttachPoint.Mars.Head; the face node under the head carries Gaze and Eyes
// with a presentation and a plate, and the apply pass writes the catalog's first style into the plate's custom
// primitive data: its glow strength (slot 7), its cells (slots 0 and 1) and its colour (slots 10..12). Fails at the
// plate until the editor step has generated the MarsEyePlate master: without it the dummy builds no plate. Isolated Z
// band: -71000.
class UMars_AutoTest_EyesDummy_ComposesAndWrites : UCk_AutoTest_Base
{
    private const int32 StrengthSlot = mars_eyes_material::Slot_Anim + 3;

    private FCk_Handle _Dummy;
    private FCk_Handle _Face;
    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_UnrealComponent _Plate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_EyesDummy_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -71000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_EyesDummy_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnDummyConstructed"));

        Add_Step_WaitUntil("the dummy is constructed", n"Check_Constructed");
        Add_Step("the face node under the head carries Gaze and Eyes with a presentation", n"Step_AssertFaceComposed");
        Add_Step("the eyes have a plate", n"Step_AssertPlate");
        Add_Step_WaitUntil("the plate's strength slot is above 0", n"Check_StrengthWritten");
        Add_Step("the plate holds the first style's cells and colour", n"Step_AssertFirstStyleWritten");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDummyConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Dummy = FCk_Handle(InEntityScriptHandle);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Dummy));
    }

    UFUNCTION()
    private void Step_AssertFaceComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto AttachPoints = _Dummy.As_AttachPoints(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(AttachPoints))
        {
            FinishFailure("the dummy publishes no attach points");
            return;
        }

        auto Head = AttachPoints.Get_AttachPoint(GameplayTags::AttachPoint_Mars_Head);
        if (ck::Is_NOT_Valid(Head))
        {
            FinishFailure("the dummy publishes no [AttachPoint.Mars.Head] attach point");
            return;
        }

        // The face is a scene node of the head, so its lifetime is owned by the head.
        for (auto Dependent : FCk_Handle(Head).Get_LifetimeDependents())
        {
            if (utils_eyes::Has(Dependent))
            { _Face = Dependent; }
        }

        if (ck::Is_NOT_Valid(_Face))
        {
            FinishFailure("no node under the dummy's head carries Eyes");
            return;
        }

        Assert_True(utils_gaze::Has(_Face), "the face node carries Gaze");

        _Eyes = _Face.As_Eyes();
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Step_AssertPlate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Plate = _Eyes.Get_Fragment(FMars_Fragment_Eyes_Presentation).Plate;
        if (ck::Is_NOT_Valid(_Plate))
        { FinishFailure("the dummy built no plate - the MarsEyePlate master is not generated; run Ck_Usf_GenerateLooks MarsEyePlate in the editor"); }
    }

    UFUNCTION()
    private void Check_StrengthWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_unreal_component::Get_CustomPrimitiveDataFloat(_Plate, StrengthSlot) > 0.0f);
    }

    UFUNCTION()
    private void Step_AssertFirstStyleWritten(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Style = mars_eyes::Catalog().Styles[0].Def;
        AssertSlot(mars_eyes_material::Slot_Cells, float32(Style.LeftCell), "slot 0 holds the first style's left cell");
        AssertSlot(mars_eyes_material::Slot_Cells + 1, float32(Style.RightCell), "slot 1 holds the first style's right cell");
        AssertSlot(mars_eyes_material::Slot_Color, Style.Color.R, "slot 10 holds the first style's red");
        AssertSlot(mars_eyes_material::Slot_Color + 1, Style.Color.G, "slot 11 holds the first style's green");
        AssertSlot(mars_eyes_material::Slot_Color + 2, Style.Color.B, "slot 12 holds the first style's blue");
    }

    private void AssertSlot(int32 InIndex, float32 InExpected, const FString& InWhat)
    {
        const auto Actual = utils_unreal_component::Get_CustomPrimitiveDataFloat(_Plate, InIndex);
        Assert_True(Math::Abs(Actual - InExpected) < 0.001f, f"{InWhat} [{InExpected}] (got [{Actual}])");
    }
}
