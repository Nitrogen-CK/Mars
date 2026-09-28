// The input-profile stack. Lives on the gameplay PlayerController; the gameplay profile sits at
// the bottom, menus/stations push on top (Stack keeps both IMCs live, Replace suspends the one
// underneath until it is popped back).
class UMars_InputComponent : UEnhancedInputComponent
{
    private TArray<FMars_InputProfileEntry> ProfileStack;
    private APlayerController OwningController;

    UFUNCTION()
    UMars_InputProfile PushProfile(TSubclassOf<UMars_InputProfile> InProfileClass, APlayerController InController,
        APawn InPawn, EMars_InputActivationMode InMode = EMars_InputActivationMode::Stack)
    {
        OwningController = InController;

        if (ProfileStack.Num() > 0 && InMode == EMars_InputActivationMode::Replace)
        {
            auto& TopEntry = ProfileStack.Last();
            TopEntry.IsSuspended = true;
            TopEntry.Profile.Deactivate(InController);
        }

        auto NewProfile = NewObject(this, InProfileClass);
        NewProfile.Setup(this);
        NewProfile.Activate(InController, InPawn);

        ProfileStack.Add(FMars_InputProfileEntry(NewProfile, InPawn, false));
        return NewProfile;
    }

    UFUNCTION()
    void PopProfile(EMars_InputDeactivationMode InMode = EMars_InputDeactivationMode::Pop)
    {
        if (ProfileStack.IsEmpty())
        { return; }

        if (InMode == EMars_InputDeactivationMode::PopAll)
        {
            for (int32 Index = ProfileStack.Num() - 1; Index >= 0; --Index)
            {
                auto& Entry = ProfileStack[Index];
                if (Entry.IsSuspended == false)
                { Entry.Profile.Deactivate(OwningController); }
            }
            ProfileStack.Empty();
            return;
        }

        auto& TopEntry = ProfileStack.Last();
        TopEntry.Profile.Deactivate(OwningController);
        ProfileStack.RemoveAt(ProfileStack.Num() - 1);

        if (ProfileStack.Num() > 0)
        {
            auto& NewTopEntry = ProfileStack.Last();
            if (NewTopEntry.IsSuspended)
            {
                NewTopEntry.IsSuspended = false;
                NewTopEntry.Profile.Activate(OwningController, NewTopEntry.Pawn);
            }
        }
    }

    // Re-targets every profile onto a new pawn (re-possession, respawn).
    UFUNCTION()
    void RepointPawn(APawn InNewPawn)
    {
        for (int32 Index = 0; Index < ProfileStack.Num(); ++Index)
        {
            ProfileStack[Index].Pawn = InNewPawn;
            if (ck::IsValid(ProfileStack[Index].Profile))
            { ProfileStack[Index].Profile.Repoint(InNewPawn); }
        }
    }

    UFUNCTION()
    UMars_InputProfile GetActiveProfile()
    {
        if (ProfileStack.IsEmpty())
        { return nullptr; }

        return ProfileStack.Last().Profile;
    }

    UFUNCTION()
    int32 GetProfileCount()
    {
        return ProfileStack.Num();
    }
}
