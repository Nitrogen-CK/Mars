// A crawler roams on the server. The client's copy plants its own feet on the client's floor as its replicated root
// moves: over 260 of its root's path its gait stays Ready and never reads Failed, every foot lifts more than 4 over the
// floor and is planted again, planted feet stand within 4 of the floor, the gait always trusts a contact, the root
// never steps 150 at once and never strays 700 from the base.
// Surface: Ck.Crawler.Net.AS_Crawler_TheClientsCopyWalksOnItsOwnLegs
class UCk_AutoTest_Net_Crawler_TheClientsCopyWalksOnItsOwnLegs : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(831000.0, 0.0, 5000.0);
    private const float64 k_RecordFrom = 40.0;
    private const float64 k_FarPath = 300.0;
    private const float32 k_AfterSeconds = 2.0f;
    private const float64 k_FootLift = 4.0;
    private const float64 k_PlantedOff = 4.0;
    private const float64 k_LargestStep = 150.0;
    private const float64 k_Stray = 700.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_PathFar(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && _CrawlerPath > k_FarPath);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawler(Make_RowSpec(k_Roams));
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_FeetRecord();
        WaitUntil(n"Is_PathFar", n"OnServerFarPath", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFarPath(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_AfterSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_CrawlerServerRow("TheClientsCopyWalksOnItsOwnLegs", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientMoving", n"OnClientMoving", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(_CrawlerPath > k_RecordFrom);
    }

    UFUNCTION()
    private void OnClientMoving(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_FeetRecord();
        WaitUntil(n"Is_PathFar", n"OnClientFarPath", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFarPath(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Feet = Describe_Feet();
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");
        Assert_True(Get_HaveAllFeetStepped(k_FootLift), f"every client foot lifted over 4 and was planted again ({Feet})");
        Assert_True(_FeetWorstPlanted <= k_PlantedOff, f"the client's planted feet stood within 4 of the floor ({_FeetWorstPlanted})");
        Assert_True(_FeetLowestTrusted >= 1, f"the client's gait always trusted a contact (lowest {_FeetLowestTrusted})");
        Assert_True(_CrawlerLargestStep < k_LargestStep, f"the client's root never stepped 150 at once ({_CrawlerLargestStep})");
        Assert_True(_CrawlerFarthestX <= k_Stray && _CrawlerFarthestY <= k_Stray,
            f"the client's root never strayed 700 from the base ({_CrawlerFarthestX}, {_CrawlerFarthestY})");
        Finish_CrawlerRow("TheClientsCopyWalksOnItsOwnLegs", "");
    }
}
