// Editor-only review readout for the Screaming Turnip PIE pass (Phase F). Reads the kernel of every live turnip and the
// state of a bed; Watch binds a trace to each turnip's signals (OnScreamCommitted, OnPhaseChanged, OnPlacementChanged)
// so Mars.log carries one line per commit and per change. Writes no gameplay state.
#if EDITOR
class UMars_ScreamingTurnipAcceptance : UObject
{
    private TArray<FCk_Handle> _Watched;

    // One line per live turnip: entity, placement, phase, sequence, clock, warning, cooldown left, last commit, mount,
    // settled, support, speed, sleep, root location and up vector.
    UFUNCTION()
    FString Turnips(AMars_PlayerCharacter InCharacter)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return "no live character"; }

        auto Player = InCharacter.TryGet_ActorEntityHandle();
        FString Result;
        auto WorldItems = 0;
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsWorldItem"))
        {
            WorldItems += 1;
            auto Turnip = Entity.As_ScreamingTurnip(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Turnip))
            { continue; }

            Result += Describe(Turnip) + "\n";
        }

        return f"world_items={WorldItems}\n" + Result;
    }

    // The bed behind InBed: charges, released count, exhausted, the Use target enabled.
    UFUNCTION()
    FString Bed(UMars_ScreamingTurnipBed_EntityScript InBed)
    {
        if (ck::Is_NOT_Valid(InBed))
        { return "no bed"; }

        auto Interactable = InBed.Get_Interactable();
        if (ck::Is_NOT_Valid(Interactable))
        { return "bed without interactable"; }

        auto Target = Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        auto Owner = Target.TryGet_InteractableOwner();
        auto Forage = Owner.As_Forage(ECk_SanityCheck::UnChecked);
        FString Result = f"bed={Owner.ToString()} enabled={Interactable.Get_EnableDisable() :n} focused={Interactable.Get_IsFocused()}";
        Result += f" exhausted_reason={Interactable.Get_IsDisabledFor(EMars_Interactable_DisableReason::Exhausted)}";
        if (ck::IsValid(Forage))
        { Result += f" charges={Forage.Get_ChargesLeft()} released={Forage.Get_ReleasedCount()} exhausted={Forage.Get_IsExhausted()}"; }

        auto OwnerTransform = Owner.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(OwnerTransform))
        { Result += f" at={utils_transform::Get_EntityCurrentLocation(OwnerTransform)}"; }

        return Result;
    }

    // Binds the trace lines to every live turnip not yet watched; returns how many are watched.
    UFUNCTION()
    int32 Watch(AMars_PlayerCharacter InCharacter)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return -1; }

        auto Player = InCharacter.TryGet_ActorEntityHandle();
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsWorldItem"))
        {
            auto Turnip = Entity.As_ScreamingTurnip(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Turnip))
            { continue; }

            auto Known = false;
            for (auto Watched : _Watched)
            {
                if (Watched == Entity)
                { Known = true; }
            }

            if (Known)
            { continue; }

            _Watched.Add(Entity);
            Turnip.BindTo_OnScreamCommitted(FMars_Delegate_ScreamingTurnip_OnScreamCommitted(this, n"OnScreamCommitted"));
            Turnip.BindTo_OnPhaseChanged(FMars_Delegate_ScreamingTurnip_OnPhaseChanged(this, n"OnPhaseChanged"));
            Turnip.BindTo_OnPlacementChanged(FMars_Delegate_ScreamingTurnip_OnPlacementChanged(this, n"OnPlacementChanged"));
            ck::Trace(f"[TurnipReview] watch {Describe(Turnip)}");
        }

        return _Watched.Num();
    }

    private FString Describe(FCk_Handle_ScreamingTurnip InTurnip)
    {
        FCk_Handle Entity = InTurnip;
        auto WorldItem = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
        FString Result = f"turnip={Entity.ToString()} frame={utils_time::Get_FrameCounter()} placement={InTurnip.Get_Placement() :n} phase={InTurnip.Get_Phase() :n}";
        Result += f" seq={InTurnip.Get_ScreamSequence()} clock={InTurnip.Get_Clock()} warning={InTurnip.Get_WarningElapsed()}";
        const auto Next = InTurnip.Get_SecondsUntilNextWarning();
        if (Next.IsSet())
        { Result += f" next_warning={Next.GetValue()}"; }
        else
        { Result += " next_warning=unset"; }
        const auto Last = InTurnip.Get_LastScreamCommittedAt();
        if (Last.IsSet())
        { Result += f" last_commit={Last.GetValue()}"; }
        else
        { Result += " last_commit=unset"; }
        Result += f" support={InTurnip.Get_HasSupport()}";
        if (ck::IsValid(WorldItem))
        {
            Result += f" mount={WorldItem.Get_Mount() :n} settled={WorldItem.Get_IsSettled()}";
            auto Body = WorldItem.Get_Body();
            if (ck::IsValid(Body) && utils_jolt_body::Get_IsBodyAdded(Body))
            { Result += f" speed={utils_jolt_body::Get_LinearVelocity(Body).Size()} sleep={utils_jolt_body::Get_SleepState(Body) :n}"; }
        }

        auto Root = Entity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Root))
        {
            const auto Transform = utils_transform::Get_EntityCurrentTransform(Root);
            Result += f" at={Transform.GetLocation()} up={Transform.GetRotation().GetUpVector()}";
        }

        return Result;
    }

    UFUNCTION()
    private void OnScreamCommitted(FCk_Handle_ScreamingTurnip InTurnip, int32 InSequence, FVector InWorldPosition)
    {
        ck::Trace(f"[TurnipReview] OnScreamCommitted seq={InSequence} pos={InWorldPosition} {Describe(InTurnip)}");
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew)
    {
        ck::Trace(f"[TurnipReview] phase {InPrevious :n} -> {InNew :n} {Describe(InTurnip)}");
    }

    UFUNCTION()
    private void OnPlacementChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Placement InPrevious,
                                    EMars_ScreamingTurnip_Placement InNew)
    {
        ck::Trace(f"[TurnipReview] placement {InPrevious :n} -> {InNew :n} {Describe(InTurnip)}");
    }
}
#endif
