// Stance: following its host (the authority's mortar): a remote operator's pestle reaches the authority as an event, a
// press carrying the sweep that operator's machine showed.

// The client-to-authority bridge for the pestle: fired at the station's replicated root by utils_mortar::Request_PestleFor
// on the operating machine, and applied only on the authority. An edge from anyone but the station's operator is refused
// without an ensure (an operator may leave while its edge is in flight); otherwise it becomes the Pestle request, a press
// with the sweep it saw, carrying the act's sequence so acts that arrive together apply in the order made. The operator
// is the player's entity (replicated with its pawn), so it resolves on the authority.
class UMars_Cue_Mortar_Pestle : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Mortar_PestleAct's fields.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Operator;

    UPROPERTY(ExposeOnSpawn)
    EMars_Mortar_PestleVerb Verb = EMars_Mortar_PestleVerb::Press;

    UPROPERTY(ExposeOnSpawn)
    float32 SweepSeconds = 0.0f;

    UPROPERTY(ExposeOnSpawn)
    int32 Sequence = 0;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Mortar_Pestle;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Mortar = Owner.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Mortar), f"[Mortar] a Pestle cue reached [{Owner.ToString()}], which has no Mortar"))
        { return; }

        if (utils_mortar::Get_MayWorkFor(Mortar, Operator) == false)
        { return; }

        Mortar.Request_Pestle(utils_mortar::Make_PestleRequest(FMars_Mortar_PestleAct(Operator, Verb, SweepSeconds, Sequence)));
    }
}
