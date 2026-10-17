// A Shun crawler (the default LightResponse) will not lunge at a target that holds a lit lantern in its hand: with the lit
// lantern raised its light sense feels the Held pool, Get_IsWarded holds, and a start at the target is rejected Warded with
// no attack begun. Stowing the lantern (selecting an empty hotbar slot: it goes dark, the crawler feels no light) lifts the
// ward, and the next start is admitted (it is a ward, never a flee: the crawler never moves away). The target stands 55 cm
// beyond the neutral hit centre, so the admitted jab misses and cools down.
class UMars_AutoTest_CrawlerMelee_ShunsAHeldLitLantern : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-200000.0, -260000.0, 600.0);

    private FCk_Handle_Hotbar _TargetHotbar;
    private FCk_Handle_HeldItem _TargetHeldItem;
    private FCk_Handle_WorldItem _LanternItem;
    private int32 _GenerationBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target ahead that can hold a lantern, and a lantern beside it", n"Step_SpawnTargetAndLantern");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step_WaitUntil("the lantern world item is composed", n"Check_LanternReady", k_SlowPolls, 0);
        Add_Step("the target picks the lantern up and opens it", n"Step_RaiseLitLantern");
        Add_Step_WaitUntil("the target holds the lit lantern and the crawler feels its Held pool", n"Check_Warded", k_SlowPolls, 0);
        Add_Step("select the target and request an attack", n"Step_TargetAndStart");
        Add_Step_WaitFrames("let the start drain", 3);
        Add_Step("the start was rejected Warded and no attack began", n"Step_AssertWarded");
        Add_Step("the target stows the lantern", n"Step_LowerLantern");
        Add_Step_WaitUntil("the stowed lantern is dark, the crawler feels no light and the ward is lifted", n"Check_Lowered", k_SlowPolls, 0);
        Add_Step("request the attack again", n"Step_StartAgain");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTargetAndLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));

        // The hand and belt sit on the target's far side (its +X points away from the crawler), out of the jab's path.
        auto HandNode = utils_scene_node::Create(_Target.Root, FTransform(FRotator::ZeroRotator, FVector(30.0, 25.0, 30.0))).As_Transform();
        auto BeltNode = utils_scene_node::Create(_Target.Root, FTransform(FRotator::ZeroRotator, FVector(15.0, 25.0, 0.0))).As_Transform();
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(constants_lantern_item::Get_BeltPoint(), BeltNode));
        utils_attach_points::Add(_Target.Entity, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 2;
        _TargetHotbar = utils_hotbar::Add(_Target.Entity, HotbarSpec);
        _TargetHeldItem = utils_held_item::Add(_Target.Entity);

        auto SpawnParams = UMars_Lantern_EntityScript::Params();
        SpawnParams.Definition = mars_items::Lantern();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator,
            utils_transform::Get_EntityCurrentLocation(_Target.Root) + Get_Forward() * 60.0 + FVector(0.0, 0.0, 30.0));
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Lantern_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnLanternConstructed"));
    }

    UFUNCTION()
    private void OnLanternConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _LanternItem = InEntityScriptHandle.As_WorldItem();
    }

    private FCk_Handle_Lantern Get_Lantern() const
    {
        return _LanternItem.H().As_Lantern(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_LanternReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_LanternItem) && ck::IsValid(Get_Lantern()) && ck::IsValid(_LanternItem.Get_HeldItem()));
    }

    // The pickup task's stow: the lantern's holder -> the target's stow target (its empty hand takes it).
    UFUNCTION()
    private void Step_RaiseLitLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Item = _LanternItem.Get_HeldItem();
        auto Target = _TargetHotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the lantern has a stow target on the target's hotbar");
            return;
        }

        auto Holder = _LanternItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());

        auto Lantern = Get_Lantern();
        Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter::Open));
    }

    UFUNCTION()
    private void Check_Warded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lantern = Get_Lantern();
        auto Res = OutResult;
        Res.Set(Lantern.Get_IsLit() && Lantern.Get_IsHeldBy(_Target.Entity) && _Crawler.Get_IsWarded(_Target.Entity));
    }

    UFUNCTION()
    private void Step_AssertWarded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastReject = _Crawler.Get_AttackLastReject();
        Assert_True(LastReject.IsSet() && LastReject.GetValue() == EMars_Crawler_AttackReject::Warded,
            f"a start at a target raising a lit lantern is rejected Warded (last reject {Get_LastRejectText()})");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle, f"no attack began (phase {_Crawler.Get_AttackPhase() :n})");

        const auto Rejection = _Crawler.Get_StartRejection(_Target.Entity);
        Assert_True(Rejection.IsSet() && Rejection.GetValue() == EMars_Crawler_AttackReject::Warded, "Get_StartRejection names the ward");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Windup) < 0, "no Windup was entered");
        _GenerationBefore = _Crawler.Get_AttackGeneration();
    }

    // Selecting the empty slot stows the lantern on its carry point (the target's belt node), where it lights nothing.
    UFUNCTION()
    private void Step_LowerLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TargetHotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_Lowered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lantern = Get_Lantern();
        auto Res = OutResult;
        Res.Set(_LanternItem.Get_Mount() == EMars_WorldItem_Mount::Carried && Lantern.Get_IsStowed()
            && Lantern.Get_IsLit() == false && Lantern.Get_Shutter() == EMars_Lantern_Shutter::Open
            && _Crawler.Get_LightsOn().Num() == 0 && _Crawler.Get_IsWarded(_Target.Entity) == false);
    }

    UFUNCTION()
    private void Step_StartAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Crawler.Get_AttackGeneration(), _GenerationBefore, "the warded start began nothing");
        _RecordMark = _Records.Num();
        _AdmissionPolls = 0;
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }
}
