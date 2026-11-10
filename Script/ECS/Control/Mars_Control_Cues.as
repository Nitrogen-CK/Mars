// The client-to-authority bridge for a control's engage: fired at the control's replicated root by the interaction
// task on the initiating machine, run where the multicast policy says, and applied only on the authority, which turns
// it into the request its drain writes from. Engage carries no payload: the request is the verb.
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
