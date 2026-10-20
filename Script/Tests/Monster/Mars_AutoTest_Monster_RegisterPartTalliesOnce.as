// The parts roster lists a part once however often it is registered: parts A and B register through utils_body_part::Add.
// In one later frame, A is registered twice more by request while part C composes (its Add queues its own
// registration into the same drain). C's arrival proves that drain ran; the roster then reads A, B, C, each once, in
// registration order.
class UMars_AutoTest_Monster_RegisterPartTalliesOnce : UCk_AutoTest_Base
{
    private FCk_Handle _Self;
    private FCk_Handle_Monster _Monster;
    private FCk_Handle_BodyPart _PartA;
    private FCk_Handle_BodyPart _PartB;
    private FCk_Handle_BodyPart _PartC;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        auto Root = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Monster = utils_monster::Add(Root, FMars_Monster_Spec(GameplayTags::Monster_Mars_Crawler, FMars_Health_Spec(100.0f),
            utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), 8.0f, ECk_Team_ID::Two));

        _PartA = Add_Part();
        _PartB = Add_Part();

        Add_Step_WaitUntil("A and B are registered", n"Check_TwoRegistered", 0, 0);
        Add_Step("register A twice more while C composes", n"Step_RegisterAgainAndAddC");
        Add_Step_WaitUntil("C is registered", n"Check_CRegistered", 0, 0);
        Add_Step("each part is on the roster once", n"Step_AssertTallies");
        Run_Steps(InHandle);
    }

    private FCk_Handle_BodyPart Add_Part()
    {
        auto Spec = FMars_BodyPart_Spec(GameplayTags::BodyPart_Mars_Crawler_Leg, EMars_BodyPart_Function::Movement, FMars_Health_Spec(30.0f),
            FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb),
            FMars_BodyPart_Severance(EMars_BodyPart_DepletionPolicy::Break, 0.0f, 0.5f, FMars_BodyPart_Debris()));
        Spec.Monster = _Monster;

        auto PartEntity = utils_entity_lifetime::Request_CreateEntity(_Self);
        return utils_body_part::Add(PartEntity, Spec);
    }

    private int32 Get_Tally(FCk_Handle_BodyPart InPart)
    {
        auto Tally = 0;
        for (const auto& Part : _Monster.Get_Parts())
        {
            if (Part == InPart)
            { ++Tally; }
        }

        return Tally;
    }

    UFUNCTION()
    private void Check_TwoRegistered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Monster.Get_Parts().Num() == 2);
    }

    UFUNCTION()
    private void Step_RegisterAgainAndAddC(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_PartA, "part A composed");
        Assert_Valid(_PartB, "part B composed");

        _Monster.Request_RegisterPart(FMars_Request_Monster_RegisterPart(_PartA));
        _Monster.Request_RegisterPart(FMars_Request_Monster_RegisterPart(_PartA));
        _PartC = Add_Part();
    }

    UFUNCTION()
    private void Check_CRegistered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Tally(_PartC) > 0);
    }

    UFUNCTION()
    private void Step_AssertTallies(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Parts = _Monster.Get_Parts();
        Assert_Equals_Int(Parts.Num(), 3, "the roster holds three parts");
        Assert_Equals_Int(Get_Tally(_PartA), 1, "A is listed once after three registrations");
        Assert_Equals_Int(Get_Tally(_PartB), 1, "B is listed once");
        Assert_Equals_Int(Get_Tally(_PartC), 1, "C is listed once");
        if (Parts.Num() == 3)
        { Assert_True(Parts[0] == _PartA && Parts[1] == _PartB && Parts[2] == _PartC, "the roster keeps registration order"); }

        Assert_Equals_Int(_Monster.Get_AttachedPartCount(), 3, "all three parts are attached");
    }
}
