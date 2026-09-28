enum EMars_InputActivationMode
{
    // Keep the current profile's IMC active and add the new one on top.
    Stack,
    // Suspend the current profile's IMC and activate the new one exclusively.
    Replace
}

enum EMars_InputDeactivationMode
{
    Pop,
    PopAll
}

struct FMars_InputProfileEntry
{
    UPROPERTY()
    UMars_InputProfile Profile;

    UPROPERTY()
    APawn Pawn;

    UPROPERTY()
    bool IsSuspended = false;

    FMars_InputProfileEntry() {}

    FMars_InputProfileEntry(UMars_InputProfile InProfile, APawn InPawn, bool InSuspended)
    {
        Profile = InProfile;
        Pawn = InPawn;
        IsSuspended = InSuspended;
    }
}

// A profile owns one runtime-built IMC plus the bindings that feed its pawn's intents.
class UMars_InputProfile : UObject
{
    protected APawn ControlledPawn;
    protected APlayerController OwningController;
    protected UInputMappingContext Context;
    protected FModifyContextOptions ModifyContextOptions;

    // Called once when the profile is created: build the IMC and bind actions here.
    UFUNCTION(BlueprintEvent)
    void Setup(UEnhancedInputComponent InInputComponent)
    {
        ModifyContextOptions = FModifyContextOptions();
        // Registers the IMC with the player's mappable key profile - that registration is what mints
        // the CkInput Mapped buttons intent rows terminate on.
        ModifyContextOptions.bNotifyUserSettings = true;
    }

    UFUNCTION(BlueprintEvent)
    void Activate(APlayerController InController, APawn InPawn)
    {
        OwningController = InController;
        ControlledPawn = InPawn;

        auto EnhancedInputSubsystem = UEnhancedInputLocalPlayerSubsystem::Get(InController);
        if (ck::IsValid(EnhancedInputSubsystem) && ck::IsValid(Context))
        { EnhancedInputSubsystem.AddMappingContext(Context, 0, ModifyContextOptions); }
    }

    UFUNCTION(BlueprintEvent)
    void Repoint(APawn InNewPawn)
    {
        ControlledPawn = InNewPawn;
    }

    UFUNCTION(BlueprintEvent)
    void Deactivate(APlayerController InController)
    {
        auto EnhancedInputSubsystem = UEnhancedInputLocalPlayerSubsystem::Get(InController);
        if (ck::IsValid(EnhancedInputSubsystem) && ck::IsValid(Context))
        { EnhancedInputSubsystem.RemoveMappingContext(Context, ModifyContextOptions); }

        OwningController = nullptr;
        ControlledPawn = nullptr;
    }

    protected FCk_Handle_InputIntents TryGet_PawnIntents() const
    {
        if (ck::Is_NOT_Valid(ControlledPawn) || ControlledPawn.Get_IsActorEcsReady() == false)
        { return FCk_Handle_InputIntents(); }

        return ControlledPawn.TryGet_ActorEntityHandle().As_InputIntents(ECk_SanityCheck::UnChecked);
    }
}
