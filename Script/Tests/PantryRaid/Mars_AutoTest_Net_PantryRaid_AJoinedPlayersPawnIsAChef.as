// A joined player's pawn is a chef on the machine with authority: with the viewer possessed by the client's controller,
// the server's raid counts the viewer's entity as its one chef (it carries TAG_MarsSharedCombatTarget and a Hotbar, and
// no TAG_MarsCombatTarget), and the pawn nobody controls is no chef. The client's raid copy counts no chef and a scan
// of the client's world finds none: no pawn carries a prey tag there.
// Surface: Ck.PantryRaid.Net.AS_PantryRaid_AJoinedPlayersPawnIsAChef
class UCk_AutoTest_Net_PantryRaid_AJoinedPlayersPawnIsAChef : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(673000.0, 0.0, 5000.0);
    private const FString k_Row = "AJoinedPlayersPawnIsAChef";

    private int32 _HandOverFrame = -1;
    private int32 _ViewerTagFrame = -1;
    private int32 _ViewerChefFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPawn();
        Spawn_ServerViewer();
        _HandOverFrame = int32(utils_time::Get_FrameCounter());
        Spawn_ServerRaid(Make_RowSpec());
        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && Get_IsRowRaidFound() && Get_HasViewerTag());
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerWatched");
    }

    protected void Sample_Row() override
    {
        const auto Viewer = Get_ViewerEntity();
        if (ck::Is_NOT_Valid(Viewer))
        { return; }

        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_ViewerTagFrame < 0 && utils_entity_tag::Has(Viewer, n"TAG_MarsSharedCombatTarget"))
        { _ViewerTagFrame = Frame; }

        if (_ViewerChefFrame >= 0 || ck::Is_NOT_Valid(_RowRaid))
        { return; }

        for (const auto& Chef : _RowRaid.Get_Chefs())
        {
            if (Chef.Root == Viewer)
            { _ViewerChefFrame = Frame; }
        }
    }

    private FCk_Handle Get_ViewerEntity()
    {
        auto Viewer = Get_Viewer();
        if (ck::Is_NOT_Valid(Viewer))
        { return FCk_Handle(); }

        return Viewer.Get_GameplayComposedEntity();
    }

    private bool Get_HasViewerTag()
    {
        const auto Viewer = Get_ViewerEntity();
        return ck::IsValid(Viewer) && ck::IsValid(Get_ViewerRemoteController()) && utils_entity_tag::Has(Viewer, n"TAG_MarsSharedCombatTarget");
    }

    // The viewer reads possessed by a controller that is not local (the client's).
    private APlayerController Get_ViewerRemoteController()
    {
        auto Viewer = Get_Viewer();
        if (ck::Is_NOT_Valid(Viewer))
        { return nullptr; }

        auto Controller = Cast<APlayerController>(Viewer.GetController());
        if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController())
        { return nullptr; }

        return Controller;
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Viewer = Get_ViewerEntity();
        const auto Chefs = _RowRaid.Get_Chefs();
        const auto ChefsNow = utils_pantry_raid::Read_ChefsNow(_RowRaid);
        FString ChefText;
        for (const auto& Chef : Chefs)
        { ChefText += f"{Chef.Root.ToString()}@{Chef.Location.ToString()},"; }

        auto PawnIsChef = false;
        for (const auto& Chef : Chefs)
        { PawnIsChef = PawnIsChef || Chef.Root == _Player; }

        const auto Extra = f"chefs=[{ChefText}] chefsNow={ChefsNow.Num()} frames=[handOver {_HandOverFrame} viewerTag {_ViewerTagFrame} viewerChef {_ViewerChefFrame}]";

        Assert_Equals_Int(Chefs.Num(), 1, "the server's raid counts one chef");
        if (Chefs.Num() == 1)
        {
            Assert_True(Chefs[0].Root == Viewer, "the server's chef is the viewer's entity");
            Assert_True(Get_PlanarDistance(Chefs[0].Location, _Base + k_ViewerOffset) <= k_NearCm,
                "the server's chef stands within 150 of the viewer's spot");
        }

        Assert_Equals_Int(ChefsNow.Num(), 1, "Read_ChefsNow answers one chef");
        Assert_True(ChefsNow.Num() == 1 && ChefsNow[0].Root == Viewer, "Read_ChefsNow answers the viewer's entity");
        Assert_True(ck::IsValid(Viewer.As_Hotbar(ECk_SanityCheck::UnChecked)), "the viewer's entity has a Hotbar");
        Assert_False(utils_entity_tag::Has(Viewer, n"TAG_MarsCombatTarget"), "the viewer's entity carries no TAG_MarsCombatTarget");
        Assert_True(ck::IsValid(_Player.As_Hotbar(ECk_SanityCheck::UnChecked)), "the pawn's entity has a Hotbar");
        Assert_False(utils_entity_tag::Has(_Player, n"TAG_MarsSharedCombatTarget"), "the pawn's entity carries no prey tag");
        Assert_False(PawnIsChef, "the pawn nobody controls is no chef");
        Hold_PantryServerRow(k_Row, Extra);
    }

    UFUNCTION()
    private void Is_ClientReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Viewer = Get_Viewer();
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && ck::IsValid(Viewer) && Viewer.IsLocallyControlled() && Get_IsRowRaidFound());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowRaid))
        {
            Log_PantryRow(k_Row, "copies=gone");
            FinishFailure("the client's raid copy was gone before it asserted");
            return;
        }

        const auto Viewer = Get_ViewerEntity();
        Assert_Equals_Int(_RowRaid.Get_Chefs().Num(), 0, "the client's raid copy has no chef");
        Assert_True(_RowRaid.Get_Clock() == 0.0f, f"the client's raid copy clock reads 0 (reads {_RowRaid.Get_Clock()})");
        Assert_Equals_Int(utils_pantry_raid::Read_ChefsNow(Get_SubjectEntity()).Num(), 0, "Read_ChefsNow on the client answers none");
        Assert_False(ck::IsValid(Viewer) && utils_net::Get_HasAuthority(Viewer), "the client has no authority over the viewer's entity");
        Finish_PantryRow(k_Row, "");
    }
}
