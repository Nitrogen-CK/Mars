class AMars_Gameplay_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Gameplay_CheatManager;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Super::BeginPlay();

        if (IsLocalController() == false)
        { return; }

        Widget::SetInputMode_GameOnly(this);
        bShowMouseCursor = false;
    }

    protected void OnLocalPawnPossessed(APawn InPawn) override
    { TryActivateGameplayInputs(InPawn); }

    UFUNCTION(Server)
    void Server_ReturnToCamp()
    {
        // A remote client's server-side controller is not local; clients cannot make the party travel.
        if (HasAuthority() == false || IsLocalController() == false || GetWorld().GetNetMode() != ENetMode::NM_ListenServer)
        { return; }

        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::IsValid(Flow))
        { Flow.RequestServerTravel(assets::Camp_Mars_MAP(), EMars_LanFlowTravel::ReturnToCamp); }
    }
}
