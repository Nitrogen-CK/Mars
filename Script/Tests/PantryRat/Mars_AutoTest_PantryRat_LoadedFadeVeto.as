// R23 (loaded fade veto). A loaded thief is asked, in one step, to go ReturnEmpty, to enter its den and to start its corpse
// fade (Advance requests naming its current phase), and its den is asked to admit it home. Every one is refused: three more
// rejected Advances, one refused return (Loaded, logged, never ensured), the rat still in its flee phases with the same
// item, FadeAlpha still 1, its den slot still Outside. Phase 4: the raid is also asked to retire it (RatHome, the request a
// den's admission sends): refused and counted (RefusedRetirements), the rat's own veto counted (LoadedVetoes) and logged
// once; the thief entity lives on, never hidden.
class UMars_AutoTest_PantryRat_LoadedFadeVeto : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Thief;
    private int32 _RejectedBefore = 0;
    private TArray<EMars_RatDen_ReturnRefusal> _Refusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(696000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("ask the loaded thief to return, enter and fade", n"Step_AskHome");
        Add_Step_WaitUntil("the den answered", n"Check_DenAnswered", k_SlowPolls, 0);
        Add_Step("every request was refused", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnReturnRefused(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat, EMars_RatDen_ReturnRefusal InReason)
    {
        _Refusals.Add(InReason);
    }

    UFUNCTION()
    private void Step_AskHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Thief = Get_FirstRat();
        _RejectedBefore = _Thief.Get_RejectedAdvances();
        const auto Now = _Thief.Get_Phase();
        _Thief.Request_Advance(FMars_Request_PantryRat_Advance(Now, EMars_PantryRat_Phase::ReturnEmpty));
        _Thief.Request_Advance(FMars_Request_PantryRat_Advance(Now, EMars_PantryRat_Phase::DenEnter));
        _Thief.Request_Advance(FMars_Request_PantryRat_Advance(Now, EMars_PantryRat_Phase::CorpseFade));

        _Den.BindTo_OnReturnRefused(FMars_Delegate_RatDen_OnReturnRefused(this, n"OnReturnRefused"));
        const auto Links = _Thief.Get_Links();
        _Den.Request_AdmitReturn(FMars_Request_RatDen_AdmitReturn(_Thief, Links.ResidentSlot, Links.OperationId));
        _Raid.Request_RatHome(FMars_Request_PantryRaid_RatHome(_Thief));
    }

    UFUNCTION()
    private void Check_DenAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Refusals.Num() > 0 && _Thief.Has_Fragment(FMars_Fragment_PantryRat_Requests) == false);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thief.Get_RejectedAdvances() - _RejectedBefore >= 3, "the return, the den entry and the fade were rejected");
        Assert_True(_Refusals[0] == EMars_RatDen_ReturnRefusal::Loaded, "the den refused a loaded rat");
        Assert_True(utils_pantry_rat::Get_IsLoadedPhase(_Thief.Get_Phase()), "still fleeing");
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "still the same cheese");
        Assert_True(_Thief.Get_FadeAlpha() == 1.0f, "no fade");
        Assert_True(_Den.Get_SlotState(0) == EMars_RatDen_SlotState::Outside, "the den slot is still Outside");
        Assert_True(_Raid.Get_RefusedRetirements() >= 1, "the raid refused to retire the loaded thief");
        Assert_True(_Thief.Get_LoadedVetoes() >= 3, "the rat counted its three home / fade vetoes");
        Assert_False(_Thief.Get_IsHidden(), "never hidden");
        FCk_Handle ThiefEntity = _Thief;
        Assert_True(ck::IsValid(ThiefEntity) && utils_world_item::Get_IsEnding(ThiefEntity) == false, "the thief entity lives on");
        Assert_True(_Raid.Get_HasRat(ThiefEntity), "still on the raid's roster");
    }
}
