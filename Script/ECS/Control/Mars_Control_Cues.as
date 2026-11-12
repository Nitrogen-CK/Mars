// Stance A for both: a client's verb reaches the authority as a reliable, server-only cue at the control's replicated
// root, and only the authority turns it into the request its drain writes from.

// The client-to-authority bridge for a control's engage: fired by the interaction task on the initiating machine, except
// for an arbitrated ManuallyCompleted control, whose engage rides its grip's Cross. Engage carries no payload: the request
// is the verb.
class UMars_Cue_Control_Engage : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Control_Engage;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Control = Owner.As_Control();
        Control.Request_Engage(FMars_Request_Control_Engage());
    }
}

// The client-to-authority bridge for a grip claim or its end: fired by utils_control::Request_GripFor on the machine
// whose grip began or ended. The gripper is the player's entity (replicated with its pawn), so it resolves on the
// authority.
class UMars_Cue_Control_Grip : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_Control_Grip's fields: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Gripper;

    UPROPERTY(ExposeOnSpawn)
    EMars_Control_GripVerb Verb = EMars_Control_GripVerb::Begin;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Control_Grip;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Control = Owner.As_Control(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Control), f"[Control] a Grip cue reached [{Owner.ToString()}], which has no Control"))
        { return; }

        Control.Request_Grip(FMars_Request_Control_Grip(Gripper, Verb));
    }
}
