// The drum keeps the piece it is handed, never a copy: box 0 released at the open hatch is the entity OnPieceAdded names and
// the kernel's record holds, still under the world's transient entity (no new entity, no new owner), the station its holder;
// the body the kernel reads is the box's own, Dynamic, and it comes to rest inside the shell at coverage 0.
class UMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Boxes(1);

        Add_Steps_StationReady();
        Add_Steps_OpenHatch();
        Add_Step("release box 0", n"Step_Admit");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered", 0, 0);
        Add_Step("the drum holds the box itself", n"Step_AssertTheBox");
        Add_Step_WaitUntil("it rests inside the shell", n"Check_AllAtRest", k_SlowPolls, 0);
        Add_Step("on its own Dynamic body, uncoated", n"Step_AssertBody");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertTheBox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"accepted (reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        if (_Added.Num() < 1)
        { return; }

        const auto Box = _Boxes[0];
        FCk_Handle BoxEntity = Box;
        Assert_True(_Added[0] == BoxEntity, "OnPieceAdded names the released box");
        Assert_True(_AddedIds[0].Get_IsSame(Make_Id(0)), "under the release's Id");
        Assert_True(_Tumbler.Get_PieceHandle(Make_Id(0)) == Box, "the kernel's record holds the box");
        Assert_True(_Tumbler.Get_PieceEntity(Make_Id(0)) == BoxEntity, "the record's entity is the box's");
        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(BoxEntity) == ck::TransientEntity(), "the box is still under the world's transient entity");
        Assert_True(Box.TryGet_Holder() == _StationEntity, "the station holds the box");
    }

    UFUNCTION()
    private void Step_AssertBody(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Box = _Boxes[0];
        FCk_Handle BoxEntity = Box;
        Assert_True(BoxEntity.Is_JoltBody(), "the box carries a body");
        if (BoxEntity.Is_JoltBody() == false)
        { return; }

        const auto Body = BoxEntity.As_JoltBody();
        Assert_True(_Tumbler.Get_PieceBody(Make_Id(0)) == Body, "the body the kernel reads is the box's own");
        Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, "the body is Dynamic");
        Assert_True(Check_PieceInside(Make_Id(0)), "the box rests inside the shell");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), 0.0, 0.0, "loaded with the hatch open, it was never coated");
    }
}
