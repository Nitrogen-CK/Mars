// Compose: utils_rat_den::Add on a transform root. Two residents, both Dormant, the eye proxy standing for slot 0, the den
// tagged TAG_MarsRatDen and its portals in the den frame (OutsideStand 75 cm out of the opening, ExitPortal mirrored from
// Blender). Then the kernel's slot identity: Emerge(op 7) takes slot 0 (Pending, OnEmergeReady(slot 0, op 7)) and the proxy
// moves to slot 1; the same op again is stale (no second slot); a MarkOutside naming another op is stale; Emerge(op 8) takes
// slot 1 and the plate goes black (vacant). Kernel half of R01 (one pending emergence per slot) and R27 (stale ids ignored).
class UMars_AutoTest_RatDen_ComposesDormantAndGrantsOneSlotPerOperation : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    private const FVector k_Origin = FVector(616000.0, -200000.0, -60000.0);
    private FCk_Handle_RatDen _Den;
    private TArray<int32> _ReadySlots;
    private TArray<int32> _ReadyOperations;
    private TArray<bool> _EyesShown;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _Den = utils_rat_den::Add(Owner, FMars_RatDen_Spec(2));

        Add_Step("composed: two Dormant residents, the proxy on slot 0, portals in the den frame", n"Step_AssertComposed");
        Add_Step("emerge op 7, then op 7 again and a stale MarkOutside", n"Step_EmergeSeven");
        Add_Step_WaitUntil("the den answered op 7", n"Check_OneReady");
        Add_Step("slot 0 pending for op 7 only; proxy on slot 1; emerge op 8", n"Step_AssertSevenAndEmergeEight");
        Add_Step_WaitUntil("the den answered op 8", n"Check_TwoReady");
        Add_Step("both slots pending, the plate vacant", n"Step_AssertVacant");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnEmergeReady(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId)
    {
        _ReadySlots.Add(InSlot);
        _ReadyOperations.Add(InOperationId);
    }

    UFUNCTION()
    private void OnEyesChanged(FCk_Handle_RatDen InDen, bool InShown, int32 InEyeSlot)
    {
        _EyesShown.Add(InShown);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Den, "the den composed");
        Assert_Equals_Int(_Den.Get_ResidentCount(), 2, "two residents");
        Assert_Equals_Int(_Den.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant), 2, "both Dormant");
        Assert_True(_Den.Get_EyeSlot() == TOptional<int32>(0), "the proxy stands for slot 0");
        Assert_True((_Den.Get_PortalWorld(EMars_RatDen_Portal::OutsideStand) - (k_Origin + FVector(75.0, 0.0, 0.0))).Size() < 0.01,
            "OutsideStand is 75 cm out of the opening");
        Assert_True((_Den.Get_PortalWorld(EMars_RatDen_Portal::ExitPortal) - (k_Origin + FVector(24.0, -14.0, 0.0))).Size() < 0.01,
            "ExitPortal is Blender (24, 14) mirrored to UE (24, -14)");

        auto Tagged = false;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, utils_rat_den::DenTag))
        { Tagged = Tagged || Candidate == _Den; }
        Assert_True(Tagged, "the den carries TAG_MarsRatDen");

        _Den.BindTo_OnEmergeReady(FMars_Delegate_RatDen_OnEmergeReady(this, n"OnEmergeReady"));
        _Den.BindTo_OnEyesChanged(FMars_Delegate_RatDen_OnEyesChanged(this, n"OnEyesChanged"));
    }

    UFUNCTION()
    private void Step_EmergeSeven(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Den.Request_Emerge(FMars_Request_RatDen_Emerge(7, 0.0f));
        _Den.Request_Emerge(FMars_Request_RatDen_Emerge(7, 0.0f));
        _Den.Request_MarkOutside(FMars_Request_RatDen_MarkOutside(0, 99));
    }

    UFUNCTION()
    private void Check_OneReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ReadySlots.Num() > 0 && _Den.Has_Fragment(FMars_Fragment_RatDen_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertSevenAndEmergeEight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ReadySlots.Num(), 1, "one OnEmergeReady for op 7 asked twice");
        Assert_Equals_Int(_ReadySlots[0], 0, "op 7 took slot 0");
        Assert_Equals_Int(_ReadyOperations[0], 7, "the signal names op 7");
        Assert_True(_Den.Get_SlotState(0) == EMars_RatDen_SlotState::Pending, "slot 0 Pending");
        Assert_True(_Den.Get_SlotState(1) == EMars_RatDen_SlotState::Dormant, "slot 1 still Dormant");
        Assert_Equals_Int(_Den.Get_StaleRequests(), 2, "the repeated op and the foreign MarkOutside were stale");
        Assert_True(_Den.Get_EyeSlot() == TOptional<int32>(1), "the proxy moved to the still-hidden slot 1");
        _Den.Request_Emerge(FMars_Request_RatDen_Emerge(8, 0.0f));
    }

    UFUNCTION()
    private void Check_TwoReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ReadySlots.Num() > 1);
    }

    UFUNCTION()
    private void Step_AssertVacant(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ReadySlots[1], 1, "op 8 took slot 1");
        Assert_Equals_Int(_Den.Get_SlotCountIn(EMars_RatDen_SlotState::Pending), 2, "both slots Pending");
        Assert_False(_Den.Get_EyesShown(), "no hidden resident: the plate is vacant (black)");
        Assert_True(_EyesShown.Num() > 0 && _EyesShown.Last() == false, "OnEyesChanged reported the vacancy");
    }
}
