// The client-to-authority bridge for a station: fired at the station's replicated root by utils_station::Request_ActFor
// on the asking machine, and applied only on the authority, which turns it into the Act request its arbiter resolves. The
// operator is the player's entity (replicated with its pawn), so it resolves on the authority.
class UMars_Cue_Station_Act : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_Station_Act's fields: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Operator;

    UPROPERTY(ExposeOnSpawn)
    EMars_Station_Verb Verb = EMars_Station_Verb::Reserve;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Station_Act;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Station = Owner.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Station), f"[Station] an Act cue reached [{Owner.ToString()}], which is no station"))
        { return; }

        Station.Request_Act(FMars_Request_Station_Act(Operator, Verb));
    }
}
