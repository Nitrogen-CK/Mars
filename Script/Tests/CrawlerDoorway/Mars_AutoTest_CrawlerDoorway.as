// Explicit test input struct follows ARCHITECTURE.md's supported spawn-params alternative. This also lets a fresh
// headless editor compile the fixture before the interactive editor has generated the new class's Params() accessor.
USTRUCT()
struct FMars_CrawlerDoorway_TestSpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;
    UPROPERTY()
    bool WithVisuals = false;
    UPROPERTY()
    bool Loop = false;
    UPROPERTY()
    FMars_Crawler_DoorwayPortal Portal;
    UPROPERTY()
    bool BlockExit = false;
}

UCLASS(Abstract)
class UMars_AutoTestRig_CrawlerDoorway : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 45.0f;
    default _AutoStageOriginField = false;

    protected FVector _Origin = FVector(0.0, 0.0, -2000.0);
    protected FMars_Crawler_DoorwayPortal _Portal;
    protected bool _BlockExit = false;
    protected bool _ExpectRejected = false;
    private FCk_Handle _Prototype;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = FMars_CrawlerDoorway_TestSpawnParams();
        Params.SpawnTransform = FTransform(_Origin + FVector(utils_crawler::DoorwayStartX, 0.0, utils_crawler::DoorwayStandingHeight));
        Params.WithVisuals = false;
        Params.Loop = false;
        Params.Portal = _Portal;
        Params.BlockExit = _BlockExit;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_CrawlerDoorway_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnConstructed"));
        Add_Step_WaitUntil("full accepted-pose clearance audit completes, or unsupported portal is rejected", n"Check_Terminal", 20000, 0);
        Add_Step("inspect the real eight-limb subject and its completion", n"Step_Verify");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnConstructed(FCk_Handle_EntityScript InScript)
    { _Prototype = InScript; }

    UFUNCTION()
    private void Check_Terminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Prototype))
        { Result.Set(false); return; }
        if (utils_entity_tag::Has(_Prototype, n"TAG_MarsDoorwayFailed"))
        { FinishFailure("Doorway geometry or playback audit failed; see the first [Doorway] diagnostic"); return; }
        Result.Set(utils_entity_tag::Has(_Prototype, _ExpectRejected ? n"TAG_MarsDoorwayRejected" : n"TAG_MarsDoorwayCompleted"));
    }

    UFUNCTION()
    private void Step_Verify(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Subject = _Prototype.As_ProceduralArticulation();
        Assert_True(ck::IsValid(Subject), "The actual public articulation composed");
        Assert_Equals_Int(Subject.Get_Limbs().Num(), 8, "Exactly eight limbs, not an existing six-leg spider with extra visuals");
        Assert_True(utils_entity_tag::Has(_Prototype, n"TAG_MarsDoorwayFailed") == false,
            "All consumed accepted poses and swept body/segment/foot boxes passed the real Jolt scene checks");
        if (_ExpectRejected == false)
        {
            Assert_True(utils_entity_tag::Has(_Prototype, n"TAG_MarsDoorwayTimedCrossing"),
                "Actual leading entry to trailing-box clearance took 3-5 seconds, with no body hold above 0.1 seconds");
        }
        if (_ExpectRejected)
        {
            Assert_True(utils_entity_tag::Has(_Prototype, n"TAG_MarsDoorwayCompleted") == false,
                "Unsupported/blocked passage was rejected before crossing");
            const auto Player = _Prototype.As_ProceduralActionPlayer();
            Assert_Equals_Int(Player.Get_RetainedReceiptIdentities().Num(), 0, "Rejection did not create a motion action");
        }
    }
}

class UMars_AutoTest_CrawlerDoorway_EightLegCrossing : UMars_AutoTestRig_CrawlerDoorway
{
}

class UMars_AutoTest_CrawlerDoorway_RejectsNarrow : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(169000.0, 80000.0, 600.0);
    default _Portal.Width = 180.0;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsLow : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(173000.0, 80000.0, 600.0);
    default _Portal.Height = 200.0;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsDeep : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(177000.0, 80000.0, 600.0);
    default _Portal.Depth = 80.0;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsBlockedExit : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(181000.0, 80000.0, 600.0);
    default _BlockExit = true;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsWide : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(185000.0, 80000.0, 600.0);
    default _Portal.Width = 300.0;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsTall : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(189000.0, 80000.0, 600.0);
    default _Portal.Height = 260.0;
    default _ExpectRejected = true;
}

class UMars_AutoTest_CrawlerDoorway_RejectsShallow : UMars_AutoTestRig_CrawlerDoorway
{
    default _Origin = FVector(193000.0, 80000.0, 600.0);
    default _Portal.Depth = 20.0;
    default _ExpectRejected = true;
}
