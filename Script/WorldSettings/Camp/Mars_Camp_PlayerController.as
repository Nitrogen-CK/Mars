// Camp front-end controller. Client-local: the menu camera tour (FocusStation) and the gameplay input profile once a chef
// is possessed. Server: the host's service commit and departure RPCs. Input mode is owned by the CkUI layout.
class AMars_Camp_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Gameplay_CheatManager;

    private AMars_CampUiPresenter _UiPresenter;

    UFUNCTION(BlueprintOverride)
    protected void EcsConstructionScript(FCk_Handle InEntity)
    {
        if (IsLocalController() == false)
        { return; }
        // Client-local targets are owned by this controller's entity and follow the placed boards.
        auto ContractsAnchor = utils_camp_station::TryGet_BoardAnchor(GetWorld(), EMars_CampStation::Contracts);
        auto DepartureAnchor = utils_camp_station::TryGet_BoardAnchor(GetWorld(), EMars_CampStation::Departure);
        if (ck::Is_NOT_Valid(ContractsAnchor) || ck::Is_NOT_Valid(DepartureAnchor))
        { return; }

        // Contracts belongs to the Steward's visible entity; a separate target cannot outline him.
        SpawnStationTarget(InEntity, DepartureAnchor, EMars_CampStation::Departure);
    }

    private void SpawnStationTarget(FCk_Handle InEntity, AMars_CampBoardAnchor InAnchor, EMars_CampStation InStation)
    {
        const auto Scale = InAnchor.GetActorScale3D();
        if (ck::EnsureIfNot(InAnchor.DrawSize.X > 0 && InAnchor.DrawSize.Y > 0
            && Math::Abs(Scale.Y) > 0.0 && Math::Abs(Scale.Z) > 0.0,
            "[Mars_Camp_PlayerController] board anchor has invalid size or scale"))
        { return; }

        const auto HalfExtents = FVector(15.0,
            InAnchor.DrawSize.X * Math::Abs(Scale.Y) * 0.5,
            InAnchor.DrawSize.Y * Math::Abs(Scale.Z) * 0.5);
        // The probe dimensions are already world-sized; keep the entity root at unit scale.
        const auto SpawnTransform = FTransform(InAnchor.GetActorRotation(), InAnchor.GetActorLocation());
        utils_entity_script::Request_SpawnEntity(InEntity, UMars_CampUiStation_EntityScript,
            UMars_CampUiStation_EntityScript::Params(SpawnTransform, InStation, HalfExtents));
    }

    UFUNCTION(BlueprintOverride)
    void EndPlay(EEndPlayReason InReason)
    {
        if (ck::IsValid(_UiPresenter))
        { _UiPresenter.DestroyActor(); }
        _UiPresenter = nullptr;
    }

    UFUNCTION()
    void OpenCampStation(EMars_CampStation InStation)
    {
        if (IsLocalController() && ck::IsValid(_UiPresenter))
        { _UiPresenter.OpenStation(InStation); }
    }

    private void EnsurePresenter()
    {
        if (ck::IsValid(_UiPresenter) || !IsLocalController())
        { return; }
        _UiPresenter = Cast<AMars_CampUiPresenter>(SpawnActor(AMars_CampUiPresenter));
        if (ck::IsValid(_UiPresenter))
        { _UiPresenter.Initialize(this); }
    }

    // Cuts the local view to a station camera. The vestibule's moving tour is UMars_MenuCameraTransition's.
    UFUNCTION()
    void FocusStation(EMars_CampStation InStation)
    {
        if (ck::EnsureIfNot(IsLocalController(), f"[Mars_Camp_PlayerController] FocusStation [{InStation}] drives the local view; call it on the local controller"))
        { return; }

        auto Camera = utils_camp_station::TryGet_Camera(GetWorld(), InStation);
        if (ck::Is_NOT_Valid(Camera))
        { return; }

        SetViewTargetWithBlend(Camera, 0.0f);
    }

    UFUNCTION(Server)
    void Server_CommitService(FName InServiceId)
    {
        auto Mode = Cast<AMars_Camp_GameMode>(Gameplay::GetGameMode());
        if (ck::IsValid(Mode))
        { Mode.TryCommitService(this, InServiceId); }
    }

    UFUNCTION(Server)
    void Server_RequestDepart()
    {
        auto Mode = Cast<AMars_Camp_GameMode>(Gameplay::GetGameMode());
        if (ck::IsValid(Mode))
        { Mode.TryDepart(this); }
    }

    protected void OnLocalPawnPossessed(APawn InPawn) override
    {
        EnsurePresenter();
        if (ck::IsValid(Cast<AMars_Camp_ViewerPawn>(InPawn)))
        {
            FocusStation(EMars_CampStation::Title);
            if (ck::IsValid(_UiPresenter))
            { _UiPresenter.OpenVestibule(); }
            return;
        }

        if (ck::IsValid(Cast<AMars_PlayerCharacter>(InPawn)))
        {
            if (ck::IsValid(_UiPresenter))
            { _UiPresenter.OnChefPossessed(); }
            TryActivateGameplayInputs(InPawn);
            SetViewTargetWithBlend(InPawn, 0.0f);
        }
    }
}
