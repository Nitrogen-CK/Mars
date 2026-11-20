// The server spawns a crawler that severs its own leg part 0 as it is built (it stays put), so the client's copy is
// born into the sever. At the end of its first second the server's part 0 is Severed, one limb is near the base with a
// body per piece and every joint added, and its gait reads Ready and never Failed. Once the client's copy composes, its
// part 0 reads Severed and its gait has settled, ten frames later: no captured leg-0 rig part is valid, leg 0's entity is
// valid and not attached, legs 1-3 are attached, the gait reads Ready and never Failed, OnSevered was raised at most
// once, and exactly one limb is near with no authority and no body. Then the client's limb at rest matches the server's
// published rest pose as in the host's sever row. The line says whether the part ledger and the limb's ledger stood
// when the copy composed or arrived after.
// Surface: Ck.Crawler.Net.AS_Crawler_ACopyBornIntoASeverSeesTheLimbAsItLies
class UCk_AutoTest_Net_Crawler_ACopyBornIntoASeverSeesTheLimbAsItLies : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(834000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);
        _LimbRow = "ACopyBornIntoASeverSeesTheLimbAsItLies";

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawlerOfClass(Make_RowSpec(k_StaysPut), UMars_TESTONLY_NetCrawler_BornSevered_EntityScript);
        WaitUntil(n"Is_CrawlerFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(1.0f, n"OnServerFirstSecond");
    }

    UFUNCTION()
    private void OnServerFirstSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Severed), "the server's part 0 is Severed");
        Assert_OneAuthorityLimb();
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the server's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the server's gait never read Failed");
        Log_CrawlerRow("ACopyBornIntoASeverSeesTheLimbAsItLies", "firstSecond");
        WaitUntil(n"Is_EveryLimbAtRest", n"OnServerLimbAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLimbAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow("ACopyBornIntoASeverSeesTheLimbAsItLies", "limbAtRest");
        WaitUntil(n"Is_SeveredLimbsGone", n"OnServerLimbGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_CrawlerServerRow("ACopyBornIntoASeverSeesTheLimbAsItLies", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Leg0SeveredAndGaitSettled", n"OnClientSevered", k_SlowPolls);
    }

    // Part 0 reads Severed and the copy's gait has left its setup (Ready or Failed).
    UFUNCTION()
    private void Is_Leg0SeveredAndGaitSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Gait = Get_GaitStatus();
        auto Result = OutResult;
        Result.Set(Get_IsPartState(0, EMars_BodyPart_State::Severed)
            && (Gait == ECk_ProceduralAnimation_Status::Ready || Gait == ECk_ProceduralAnimation_Status::Failed));
    }

    UFUNCTION()
    private void OnClientSevered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientSeveredFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_TenFramesSinceClientSevered", n"OnClientTenFrames", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_TenFramesSinceClientSevered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(int32(utils_time::Get_FrameCounter()) >= _ClientSeveredFrame + 10);
    }

    UFUNCTION()
    private void OnClientTenFrames(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_ValidRigParts(0), 0, "no captured leg-0 rig part is valid on the client");
        FCk_Handle Leg = _Crawler.Get_Legs()[0];
        Assert_True(ck::IsValid(Leg), "the client's leg 0 entity is valid");
        Assert_False(Get_IsLegAttached(0), "the client's leg 0 is not attached");
        for (int32 Index = 1; Index < k_LegCount; ++Index)
        { Assert_True(Get_IsLegAttached(Index), f"the client's leg {Index} is attached"); }

        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");
        Assert_True(_LegSignals[0].Severed <= 1, f"the client's part 0 raised OnSevered at most once ({_LegSignals[0].Severed})");

        const auto Limbs = Get_LimbsNear();
        Assert_Equals_Int(Limbs.Num(), 1, "exactly one limb (TAG_MarsSeveredLimb) is near the client's base");
        for (auto Limb : Limbs)
        {
            Assert_False(utils_net::Get_HasAuthority(Limb), "the client's limb has no authority");
            Assert_Equals_Int(Get_LimbBodies(Limb), 0, "no piece of the client's limb carries a Jolt body");
        }

        const auto PartLedger = _RosterInitialAtFind == EMars_Net_InitialState::Taken ? "stood" : "arrived";
        const auto LimbLedger = _Limbs.Num() > 0 ? _Limbs[0].LedgerInitial : FString("none");
        Log_CrawlerRow("ACopyBornIntoASeverSeesTheLimbAsItLies", f"partLedger={PartLedger} limbLedger={LimbLedger} severedFrame={_ClientSeveredFrame}");
        Await_ClientLimbRest(n"OnClientLimbGone");
    }

    UFUNCTION()
    private void OnClientLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_CrawlerRow("ACopyBornIntoASeverSeesTheLimbAsItLies", "");
    }
}
