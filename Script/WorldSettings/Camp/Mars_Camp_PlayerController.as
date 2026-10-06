// Camp front-end controller. Client-local: the menu camera tour (FocusStation) and the gameplay input profile once a chef
// is possessed. Server: the host's service commit and departure RPCs. Input mode is owned by the CkUI layout.
class AMars_Camp_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Gameplay_CheatManager;

    private TArray<AMars_CampStationCamera> _StationCameras;
    private AMars_CampUiPresenter _UiPresenter;

    UFUNCTION(BlueprintOverride)
    protected void EcsConstructionScript(FCk_Handle InEntity)
    {
        if (IsLocalController() == false)
        { return; }
        // Client-local targets are owned by this controller's entity and follow the placed boards.
        TArray<AMars_CampBoardAnchor> Anchors;
        GetAllActorsOfClass(Anchors);
        AMars_CampBoardAnchor ContractsAnchor;
        AMars_CampBoardAnchor DepartureAnchor;
        int32 ContractsCount = 0;
        int32 DepartureCount = 0;
        for (auto Anchor : Anchors)
        {
            if (ck::Is_NOT_Valid(Anchor) || Anchor.GetWorld() != GetWorld())
            { continue; }
            if (Anchor.Station == EMars_CampStation::Contracts)
            {
                ContractsAnchor = Anchor;
                ++ContractsCount;
            }
            else if (Anchor.Station == EMars_CampStation::Departure)
            {
                DepartureAnchor = Anchor;
                ++DepartureCount;
            }
        }

        if (ck::EnsureIfNot(ContractsCount == 1 && DepartureCount == 1,
            f"[Mars_Camp_PlayerController] expected one Contracts and one Departure board anchor, found [{ContractsCount}] and [{DepartureCount}]"))
        { return; }

        SpawnStationTarget(InEntity, ContractsAnchor, EMars_CampStation::Contracts);
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

    // Blends the local view to a station camera, starting now. Cameras are level content, gathered once.
    UFUNCTION()
    void FocusStation(EMars_CampStation InStation, float32 InBlendSeconds = 0.6f)
    {
        if (ck::EnsureIfNot(IsLocalController(), f"[Mars_Camp_PlayerController] FocusStation [{InStation}] drives the local view; call it on the local controller"))
        { return; }

        auto Camera = GetStationCamera(InStation);
        if (ck::EnsureIfNot(ck::IsValid(Camera), f"[Mars_Camp_PlayerController] no AMars_CampStationCamera for station [{InStation}] in this map"))
        { return; }

        const float32 BlendExponent = 2.0f;
        // Freeze the current cached POV so Back can reverse an unfinished blend without snapping.
        const bool LockOutgoing = true;
        SetViewTargetWithBlend(Camera, InBlendSeconds, EViewTargetBlendFunction::VTBlend_EaseInOut, BlendExponent, LockOutgoing);
    }

    AMars_CampStationCamera GetStationCamera(EMars_CampStation InStation)
    {
        _StationCameras.Empty();
        GetAllActorsOfClass(_StationCameras);
        AMars_CampStationCamera Result;
        int Matches = 0;
        for (auto Camera : _StationCameras)
        {
            if (ck::IsValid(Camera) && Camera.bStationEnabled && Camera.GetWorld() == GetWorld() && Camera.Station == InStation)
            { Result = Camera; ++Matches; }
        }
        if (ck::EnsureIfNot(Matches == 1, f"[Camp] Expected exactly one camera for [{InStation}], found [{Matches}]"))
        { return nullptr; }
        return Result;
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
            FocusStation(EMars_CampStation::Title, 0.0f);
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
