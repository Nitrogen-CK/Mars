// Once per limb: the authority drops the mirror state (its publisher writes the ledger). A copy binds the ledger's
// rep-notify and poses its pieces from the ledger as it stands. Its first application is the pose the copy was born
// into and is set, as it stands; each later write starts every piece easing from where it is to its new pose over
// k_PublishSeconds (UMars_Processor_SeveredLimb_Ease, which the Easing tag added here runs on a copy only).
class UMars_Processor_SeveredLimb_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_SeveredLimb_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Fragment_SeveredLimb_Local);
        Query.Require(FMars_Tag_SeveredLimb_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_SeveredLimb_NeedsMirror);

        if (utils_net::Get_HasAuthority(InHandle))
        {
            InHandle.Get_Fragment(FMars_Fragment_SeveredLimb_Local).Last = TOptional<FMars_Fragment_SeveredLimb_Net>();
            return;
        }

        InHandle.Add_Fragment(FMars_Tag_SeveredLimb_Easing());
        InHandle.BindTo_OnRepNotify(FMars_Fragment_SeveredLimb_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(InHandle, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a limb already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Has_Fragment(FMars_Fragment_SeveredLimb_Local) == false)
        { return; }

        auto Limb = InHandle;
        if (Limb.Get_Fragment(FMars_Fragment_SeveredLimb_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Limb.Get_Fragment(FMars_Fragment_SeveredLimb_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Limb, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Limb, EMars_Net_Reconcile::AsItArrives);
    }

    private void Reconcile(FCk_Handle& InLimb, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InLimb.Get_Fragment(FMars_Fragment_SeveredLimb_Net);
        auto& Local = InLimb.Get_Fragment(FMars_Fragment_SeveredLimb_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[SeveredLimb] [{InLimb.ToString()}] has no mirror state off authority"))
        { return; }

        Local.Last = TOptional<FMars_Fragment_SeveredLimb_Net>(Ledger);

        auto Limb = InLimb.As_SeveredLimb();
        const auto Root = Limb.Get_RootTransform();
        const auto Current = Limb.Get_PiecePoses();
        auto& State = InLimb.Get_Fragment(FMars_Fragment_SeveredLimb);
        if (ck::EnsureIfNot(Ledger.Pieces.Num() == State.Pieces.Num(),
            f"[SeveredLimb] [{InLimb.ToString()}] received [{Ledger.Pieces.Num()}] piece poses for [{State.Pieces.Num()}] pieces"))
        { return; }

        State.Eases.SetNum(State.Pieces.Num());
        for (int32 Index = 0; Index < State.Pieces.Num(); ++Index)
        {
            auto& Ease = State.Eases[Index];
            Ease.To = Ledger.Pieces[Index];
            if (InHow == EMars_Net_Reconcile::AsItStands)
            {
                Ease.From = Ease.To;
                Ease.Elapsed = constants_severed_limb::k_PublishSeconds;
                auto Piece = State.Pieces[Index].Piece;
                if (ck::IsValid(Piece))
                { utils_transform::Request_SetTransform(Piece, FCk_Request_Transform_SetTransform(utils_severed_limb::Get_WorldTransform(Ease.To, Root))); }

                continue;
            }

            Ease.From = Current[Index];
            Ease.Elapsed = 0.0f;
        }
    }
}

// A copy only (the Easing tag, never removed): moves every easing piece toward its newest written pose.
class UMars_Processor_SeveredLimb_Ease : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_SeveredLimb);
        Query.Require(FMars_Tag_SeveredLimb_Easing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_SeveredLimb& InState)
    {
        const auto Root = InHandle.As_SeveredLimb().Get_RootTransform();
        const auto Duration = constants_severed_limb::k_PublishSeconds;
        for (int32 Index = 0; Index < InState.Eases.Num() && Index < InState.Pieces.Num(); ++Index)
        {
            auto& Ease = InState.Eases[Index];
            if (Ease.Elapsed >= Duration)
            { continue; }

            Ease.Elapsed = Math::Min(Ease.Elapsed + float32(InDeltaT.Get_Seconds()), Duration);
            const auto Alpha = Ease.Elapsed / Duration;
            auto Pose = FMars_SeveredLimb_Pose();
            Pose.Location = Math::Lerp(Ease.From.Location, Ease.To.Location, float64(Alpha));
            Pose.Rotation = FQuat::Slerp(Ease.From.Rotation, Ease.To.Rotation, Alpha);

            auto Piece = InState.Pieces[Index].Piece;
            if (ck::IsValid(Piece))
            { utils_transform::Request_SetTransform(Piece, FCk_Request_Transform_SetTransform(utils_severed_limb::Get_WorldTransform(Pose, Root))); }
        }
    }
}
