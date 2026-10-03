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

enum EMars_InputProfile_State
{
    Active,
    // Deactivated by a Replace push above it; reactivated when that profile pops.
    Suspended
}

struct FMars_InputProfileEntry
{
    UPROPERTY()
    UMars_InputProfile Profile;

    UPROPERTY()
    APawn Pawn;

    UPROPERTY()
    EMars_InputProfile_State State = EMars_InputProfile_State::Active;

    FMars_InputProfileEntry() {}

    FMars_InputProfileEntry(UMars_InputProfile InProfile, APawn InPawn, EMars_InputProfile_State InState)
    {
        Profile = InProfile;
        Pawn = InPawn;
        State = InState;
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

        if (ck::EnsureIfNot(ck::IsValid(Context), f"[InputProfile] [{GetName()}] has no mapping context - Setup must build one"))
        { return; }

        auto EnhancedInputSubsystem = UEnhancedInputLocalPlayerSubsystem::Get(InController);
        if (ck::EnsureIfNot(ck::IsValid(EnhancedInputSubsystem),
            f"[InputProfile] [{GetName()}] activated on a controller without a local player"))
        { return; }

        EnhancedInputSubsystem.AddMappingContext(Context, 0, ModifyContextOptions);
    }

    UFUNCTION(BlueprintEvent)
    void Repoint(APawn InNewPawn)
    {
        ControlledPawn = InNewPawn;
    }

    // The local player can already be gone when the stack is popped during teardown.
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
