// Depleting a leg part severs the leg: after the crawler walks for 1 s (and has moved), 30 Sever damage on leg 1's Health
// depletes it, the part reads Severed, OnSevered fires once with the 3 released parts (2 segments + foot), the leg reads
// Detached and stays in the body's record, the gait runs on 3 enabled legs (OnLegSetChanged 3 of 4) and stays Ready, the
// leg's hurtboxes are destroyed, and the leg stays the body's. Within ten frames of OnSevered every released part is
// gone; exactly one severed limb appears near the crawler with a Jolt body on every piece and every joint added, and
// its pieces fall to the floor (it ragdolls, jointed). The limb is gone after its 1 s lifetime; the crawler lives on with
// 3 attached legs and keeps the severed one, valid and detached.
class UMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 25.0f;
    default _Origin = FVector(130000.0, 84000.0, 600.0);

    private FCk_Handle_BodyPart _Part;
    private FCk_Handle_ProceduralLeg _Leg;
    private TArray<FCk_Handle> _Hurtboxes;
    private float64 _WalkStart = 0.0;
    private FVector _WalkStartLocation;

    private int32 _SeveredCount = 0;
    private int32 _SeveredFrame = -1;
    private FMars_DamageEvent _SeveredCause;
    private TArray<FCk_Handle_Transform> _Released;
    private TArray<int32> _LegSetEnabled;
    private TArray<int32> _LegSetTotal;
    private FCk_Handle_SeveredLimb _Limb;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("bind leg 1's OnSevered and the gait's OnLegSetChanged", n"Step_Bind");
        Add_Step_WaitUntil("the crawler walks +X for 1 s", n"Check_Walked", k_SlowPolls, 0);
        Add_Step("record leg 1's hurtboxes; deplete its Health with 30 Sever", n"Step_Deplete");
        Add_Step_WaitUntil("leg 1 is severed, detached and its hurtboxes are gone", n"Check_Severed", 0, 0);
        Add_Step("the sever contract holds", n"Step_AssertSevered");
        Add_Step_WaitUntil("every released part is gone within ten frames of OnSevered", n"Check_ReleasedGone", 0, 0);
        Add_Step_WaitUntil("one severed limb is near, a body on every piece and every joint added", n"Check_OneLimb", k_SlowPolls, 0);
        Add_Step_WaitUntil("the limb's pieces fell to the floor", n"Check_LimbFell", k_SlowPolls, 0);
        Add_Step_WaitUntil("the limb is gone after its lifetime", n"Check_NoLimbNear", k_SlowPolls, 0);
        Add_Step("the crawler lives on with 3 legs and keeps the severed one", n"Step_AssertAfterLimb");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(400.0, 400.0, 200.0));
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        ++_SeveredCount;
        _SeveredFrame = int32(utils_time::Get_FrameCounter());
        _SeveredCause = InCause;
        _Released = InReleased;
    }

    UFUNCTION()
    private void OnLegSetChanged(FCk_Handle_ProceduralGait InGait, int32 InEnabledCount, int32 InTotalCount)
    {
        _LegSetEnabled.Add(InEnabledCount);
        _LegSetTotal.Add(InTotalCount);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_Bind(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Part = _Crawler.Get_LegParts()[1];
        _Leg = _Crawler.Get_Legs()[1];
        _Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnSevered"));
        utils_procedural_gait::BindTo_OnLegSetChanged(_Crawler.Get_Gait(), FCk_Delegate_ProceduralGait_OnLegSetChanged(this, n"OnLegSetChanged"));
        _WalkStart = System::GetGameTimeInSeconds();
        _WalkStartLocation = BodyLocation();
    }

    UFUNCTION()
    private void Check_Walked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        utils_surface_motion::Request_Steering(_Crawler.Get_Motion(), FCk_Request_SurfaceMotion_Steering(FVector(1.0, 0.0, 0.0), 120.0f));

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _WalkStart >= 1.0);
    }

    UFUNCTION()
    private void Step_Deplete(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Walked = (BodyLocation() - _WalkStartLocation).Size2D();
        Assert_True(Walked > 30.0, f"the crawler walked before the sever (moved {Walked} uu in the 1 s walk)");

        _Hurtboxes = _Part.Get_Zone().Get_Hurtboxes();
        Assert_Equals_Int(_Hurtboxes.Num(), 3, "leg 1 has 3 hurtboxes before the sever");
        Assert_Equals_Int(_Crawler.Get_LegRig(1).Segments.Num(), 2, "leg 1 has 2 segments");

        auto Health = _Part.Get_Health();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_Severed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto HurtboxesGone = true;
        for (auto Hurtbox : _Hurtboxes)
        { HurtboxesGone = HurtboxesGone && ck::Is_NOT_Valid(Hurtbox); }

        auto Res = OutResult;
        Res.Set(_Part.Get_State() == EMars_BodyPart_State::Severed && _SeveredCount > 0 &&
            utils_procedural_leg::Get_Status(_Leg) == ECk_ProceduralLeg_Status::Detached && HurtboxesGone);
    }

    UFUNCTION()
    private void Step_AssertSevered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Root = _Crawler;
        const auto Gait = _Crawler.Get_Gait();

        Assert_Equals_Int(_SeveredCount, 1, "OnSevered fired once");
        Assert_Equals_Float(_SeveredCause.Amount, 30.0f, 0.001f, "OnSevered carries the lethal hit");
        Assert_Equals_Int(_Released.Num(), 3, "the sever released 2 segments and the foot");
        Assert_False(_Part.Get_Zone().Get_IsEnabled(), "the severed part's zone is disabled");
        Assert_Equals_Int(_Part.Get_Zone().Get_Hurtboxes().Num(), 0, "the severed part's zone has no hurtboxes");

        Assert_False(utils_procedural_leg::Get_IsAttached(_Leg), "leg 1 is no longer attached");
        Assert_Equals_Int(utils_procedural_leg::Get_Legs(Root, ECk_ProceduralLeg_Filter::OnlyAttached).Num(), 3, "3 legs stay attached");
        Assert_Equals_Int(utils_procedural_leg::Get_Legs(Root, ECk_ProceduralLeg_Filter::NoFilter).Num(), 4, "the record keeps the detached leg");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(Gait), 3, "the gait runs on 3 enabled legs");
        const auto GaitStatus = utils_procedural_gait::Get_Status(Gait);
        Assert_True(GaitStatus == ECk_ProceduralAnimation_Status::Ready, f"the gait stays Ready (got {GaitStatus :n})");

        Assert_Equals_Int(_LegSetEnabled.Num(), 1, "OnLegSetChanged fired once");
        if (_LegSetEnabled.Num() > 0)
        {
            Assert_Equals_Int(_LegSetEnabled[0], 3, "OnLegSetChanged reports 3 enabled");
            Assert_Equals_Int(_LegSetTotal[0], 4, "OnLegSetChanged reports 4 total");
        }

        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(_Leg) == Root, "the severed leg stays the body's");

        const auto Monster = _Crawler.Get_Monster();
        Assert_Equals_Int(Monster.Get_Parts().Num(), 4, "the roster keeps the severed part");
        Assert_Equals_Int(Monster.Get_AttachedPartCount(), 3, "3 parts are attached");
        Assert_False(Monster.Get_IsDead(), "losing a leg does not kill the crawler");
    }

    UFUNCTION()
    private void Check_ReleasedGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Gone = true;
        for (auto Released : _Released)
        {
            FCk_Handle Entity = Released;
            Gone = Gone && (ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
        }

        const auto Frames = int32(utils_time::Get_FrameCounter()) - _SeveredFrame;
        if (Gone == false && Frames > 10)
        {
            FinishFailure(f"a released part is still valid {Frames} frames after OnSevered");
            return;
        }

        auto Res = OutResult;
        Res.Set(Gone);
    }

    UFUNCTION()
    private void Check_OneLimb(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Limbs = Get_LimbsNear(InHandle);
        if (Limbs.Num() > 1)
        {
            FinishFailure(f"{Limbs.Num()} limbs near the crawler for one severed leg");
            return;
        }

        auto Res = OutResult;
        Res.Set(Limbs.Num() == 1 && Get_IsLimbSimulated(Limbs[0]));
        if (Limbs.Num() == 1)
        { _Limb = Limbs[0]; }
    }

    UFUNCTION()
    private void Check_LimbFell(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Limb))
        {
            FinishFailure("the limb died before its pieces were seen on the floor");
            return;
        }

        auto AllDown = true;
        for (auto Piece : _Limb.Get_Pieces())
        { AllDown = AllDown && utils_transform::Get_EntityCurrentLocation(Piece).Z <= _Origin.Z + 60.0; }

        auto Res = OutResult;
        Res.Set(AllDown);
    }

    UFUNCTION()
    private void Step_AssertAfterLimb(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Crawler), "the crawler outlives its severed limb");
        Assert_True(ck::IsValid(_Leg), "the severed leg stays valid while the crawler lives");
        Assert_False(utils_procedural_leg::Get_IsAttached(_Leg), "the severed leg stays detached");
        Assert_True(_Part.Get_State() == EMars_BodyPart_State::Severed, "the severed part reads Severed");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()), 3, "the gait still runs on 3 legs");
        const auto GaitStatus = utils_procedural_gait::Get_Status(_Crawler.Get_Gait());
        Assert_True(GaitStatus == ECk_ProceduralAnimation_Status::Ready, f"the gait is still Ready (got {GaitStatus :n})");
        Assert_Equals_Int(_Crawler.Get_Monster().Get_AttachedPartCount(), 3, "3 parts are attached");
    }
}
