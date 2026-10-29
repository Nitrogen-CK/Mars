// Extends the existing real-process host/travel/return assertions with the authored Steward UI and mission gate.
// Open/back uses the production UI API, not a physical Use press. Gate pose is observed; collision traversal is not.
class UMars_GauntletAsTest_StewardMissionTravelReturn : UMars_GauntletAsTest_HostServiceTravelReturn
{
    default _ServiceId = n"DillBroth";
    default _ServiceDestination = TSoftObjectPtr<UWorld>(FSoftObjectPath("/Game/Mars/Maps/Warrens_Mars_MAP.Warrens_Mars_MAP"));

    // 0: open, 1: observe reading view, 2: observe Back, 3: presentation gate passed.
    private int32 _MenuStage = 0;
    private FVector _BeforeMenuLocation;
    private float32 _BeforeMenuFov = 90.0f;

    protected bool CheckHostedPresentation(AMars_Camp_PlayerController InPC) override
    {
        auto Gate = FindGate(InPC);
        if (ck::Is_NOT_Valid(Gate))
        { return false; }
        if (Gate.Get_IsOpen())
        { Fail("Steward preview opened the gate before a committed service"); return false; }

        auto Player = ck::ToEntity(InPC.GetControlledPawn());
        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return false; }
        auto Camera = Viewpoint.Get_Camera();
        if (ck::Is_NOT_Valid(Camera))
        { return false; }
        auto Presenter = FindPresenter(InPC.GetWorld());
        if (ck::Is_NOT_Valid(Presenter))
        { return false; }

        if (_MenuStage == 0)
        {
            // The HUD layout is async. Opening before it exists would test an unavailable input host, not Back.
            if (Viewpoint.Get_IsViewHeld() || ck::Is_NOT_Valid(utils_u_i_layout::Get_Layout(InPC)))
            { return false; }
            const auto Before = Camera.Get_ViewInfo();
            _BeforeMenuLocation = Before.Location;
            _BeforeMenuFov = Before.FOV;
            InPC.OpenCampStation(EMars_CampStation::Contracts);
            _MenuStage = 1;
            Controller.Request_MarkHeartbeat("[MarsGauntletAs] Steward: requested Contracts through camp controller");
            return false;
        }

        if (_MenuStage == 1)
        {
            if (Camera.Has_Layer(UMars_CameraLayer_CampService) == false || Viewpoint.Get_IsViewHeld() == false)
            { return false; }
            auto Endpoint = utils_camp_station::TryGet_Camera(InPC.GetWorld(), EMars_CampStation::Contracts);
            if (ck::Is_NOT_Valid(Endpoint))
            { Fail("Contracts has no camera endpoint"); return false; }
            const auto View = Camera.Get_ViewInfo();
            if (View.Location.Equals(Endpoint.GetActorLocation(), 0.5) == false ||
                Math::Abs(View.FOV - mars::Mars_StewardService_Config.View.FieldOfView) > 0.1f)
            { return false; }
            if (Camera.Get_Profile().Get_HasOrientationControl())
            { Fail("Steward reading view did not capture orientation"); return false; }
            Presenter.UI_Back();
            _MenuStage = 2;
            Controller.Request_MarkHeartbeat("[MarsGauntletAs] Steward: reading view reached endpoint; Back requested");
            return false;
        }

        if (_MenuStage == 2)
        {
            const auto View = Camera.Get_ViewInfo();
            if (Camera.Has_Layer(UMars_CameraLayer_CampService) || Viewpoint.Get_IsViewHeld() ||
                Camera.Get_Profile().Get_HasOrientationControl() == false ||
                View.Location.Equals(_BeforeMenuLocation, 20.0) == false || Math::Abs(View.FOV - _BeforeMenuFov) > 0.1f)
            { return false; }
            _MenuStage = 3;
            Controller.Request_MarkHeartbeat("[MarsGauntletAs] Steward: Back restored chef camera; uncommitted gate remains closed");
        }
        return _MenuStage == 3;
    }

    protected bool CheckCommittedPresentation(AMars_Camp_PlayerController InPC) override
    {
        return IsGateAt(InPC, true);
    }

    protected bool CheckReturnedPresentation(AMars_Camp_PlayerController InPC) override
    {
        // The existing host flow restores its selected service after a mission, so the new gate must rise again.
        return IsGateAt(InPC, true);
    }

    protected bool CheckResetPresentation(AMars_Camp_PlayerController InPC) override
    {
        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(State))
        { return false; }
        if (State.Get_PartyState().ServiceId.IsNone() == false)
        { Fail("standalone reset retained a selected party service"); return false; }
        return IsGateAt(InPC, false);
    }

    private bool IsGateAt(AMars_Camp_PlayerController InPC, bool InOpen)
    {
        auto Gate = FindGate(InPC);
        if (ck::Is_NOT_Valid(Gate) || Gate.Get_IsOpen() != InOpen)
        { return false; }
        auto Mover = Gate.Get_MovingNode().As_Mover();
        return ck::IsValid(Mover) && Mover.Get_IsResting() && Mover.Get_Alpha() == (InOpen ? 1.0f : 0.0f);
    }

    private FCk_Handle_Gate FindGate(AMars_Camp_PlayerController InPC)
    {
        // The context handle limits lookup to this process's current game world; never retain across travel.
        auto Context = ck::ToEntity(InPC);
        if (ck::Is_NOT_Valid(Context))
        { return FCk_Handle_Gate(); }
        const auto Gates = utils_entity_tag::ForEach_Entity(Context, n"TAG_MarsCampMissionGate");
        if (Gates.Num() > 1)
        { Fail("expected one authored Camp mission gate"); return FCk_Handle_Gate(); }
        if (Gates.IsEmpty())
        { return FCk_Handle_Gate(); }
        auto Entity = Gates[0];
        return Entity.As_Gate(ECk_SanityCheck::UnChecked);
    }

    private AMars_CampUiPresenter FindPresenter(UWorld InWorld) const
    {
        TArray<AMars_CampUiPresenter> Presenters;
        GetAllActorsOfClass(Presenters);
        for (auto Presenter : Presenters)
        {
            if (ck::IsValid(Presenter) && Presenter.GetWorld() == InWorld)
            { return Presenter; }
        }
        return nullptr;
    }
}
