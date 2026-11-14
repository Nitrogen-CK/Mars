// What one machine's copy of a part raised: OnConditionChanged (with the last pair), OnBroken (with the frame of the
// first) and OnSevered.
struct FMars_NetBodyPartTest_Signals
{
    UPROPERTY()
    int32 ConditionChanged = 0;

    UPROPERTY()
    EMars_BodyPart_Condition LastOld = EMars_BodyPart_Condition::Pristine;

    UPROPERTY()
    EMars_BodyPart_Condition LastNew = EMars_BodyPart_Condition::Pristine;

    UPROPERTY()
    int32 Broken = 0;

    UPROPERTY()
    int32 BrokenFrame = -1;

    UPROPERTY()
    int32 Severed = 0;
}

// The body part net tests' shared steps, on top of the strike rig: the server spawns a test monster with two Break parts
// under the replicated spawn owner and tracks it for cleanup; each machine finds its copy by tag near where it was
// spawned, takes its parts in roster order and counts what each of its own parts raises. "Hits part N" is a Sever zone
// hit on the server's copy of that part's zone; "the client claims part N" is the strike rig's claim naming part N's zone
// address and a point on part N's hurtbox.
UCLASS(Abstract)
class UMars_AutoTestRig_NetBodyPart : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    protected const int32 k_PartCount = 2;
    // The server waits this long after it finds its monster, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    // The test monster's part spacing along +Y from its root, and its part hurtbox half extent.
    protected const float64 k_PartSpacingCm = 80.0;
    protected const float64 k_PartHurtboxHalfExtent = 20.0;

    protected FVector _MonsterAt = FVector::ZeroVector;
    protected FCk_Handle _MonsterRoot;
    protected FCk_Handle_Monster _Monster;
    protected TArray<FCk_Handle_BodyPart> _Parts;
    protected TArray<FMars_NetBodyPartTest_Signals> _PartSignals;

    // A row without the striker: the monster at InBase.
    protected void Begin_BodyPart(FVector InBase)
    {
        _Base = InBase;
        _TargetAt = InBase;
        _MonsterAt = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
    }

    // A row with the striker: the monster placed so that part InPart sits at InBase, in front of the hand.
    protected void Begin_BodyPartStrike(FVector InBase, int32 InPart)
    {
        Begin_Strike(InBase);
        _MonsterAt = InBase - FVector(0.0, k_PartSpacingCm * (InPart + 1), 0.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The monster
    //----------------------------------------------------------------------------------------------------------------------

    // Server: a monster with two parts at _MonsterAt whose hits spill InPartSpill into its body.
    protected void Spawn_ServerMonster(float32 InPartSpill)
    {
        auto Params = FMars_NetCombat_Monster_SpawnParams(FTransform(FRotator::ZeroRotator, _MonsterAt), k_PartCount);
        Params.PartSpill = InPartSpill;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Monster_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_MonsterFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound());
    }

    // This machine's copy of the monster near _MonsterAt lists both its parts; the first time, their signals are counted
    // from here (and the server tracks it).
    protected bool Get_IsMonsterFound()
    {
        if (_Parts.Num() == k_PartCount)
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetMonster"))
        {
            if (Get_IsNear(Candidate, _MonsterAt) == false)
            { continue; }

            auto Monster = Candidate.As_Monster(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Monster))
            { continue; }

            const auto Parts = Get_RosterParts(Candidate);
            if (Parts.Num() != k_PartCount)
            { continue; }

            Take_Monster(Candidate, Monster, Parts);
            return true;
        }

        return false;
    }

    // This machine's parts of the monster on InRoot, in roster order.
    protected TArray<FCk_Handle_BodyPart> Get_RosterParts(FCk_Handle InRoot)
    {
        if (InRoot.Has_Fragment(FMars_Fragment_BodyPart_Roster) == false)
        { return TArray<FCk_Handle_BodyPart>(); }

        return InRoot.Get_Fragment(FMars_Fragment_BodyPart_Roster).Parts;
    }

    private void Take_Monster(FCk_Handle InRoot, FCk_Handle_Monster InMonster, TArray<FCk_Handle_BodyPart> InParts)
    {
        _MonsterRoot = InRoot;
        _Monster = InMonster;
        _Parts = InParts;
        _PartSignals.SetNum(_Parts.Num());

        for (int32 Index = 0; Index < _Parts.Num(); ++Index)
        {
            auto Part = _Parts[Index];
            Part.BindTo_OnConditionChanged(FMars_Delegate_BodyPart_OnConditionChanged(this, n"OnPartConditionChanged"));
            Part.BindTo_OnBroken(FMars_Delegate_BodyPart_OnBroken(this, n"OnPartBroken"));
            Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnPartSevered"));
        }

        if (Get_IsServer())
        { Track_ForCleanup(InRoot); }
    }

    protected bool Get_IsPartState(int32 InPart, EMars_BodyPart_State InState)
    {
        return _Parts.IsValidIndex(InPart) && ck::IsValid(_Parts[InPart]) && _Parts[InPart].Get_State() == InState;
    }

    protected bool Get_IsPartCondition(int32 InPart, EMars_BodyPart_Condition InCondition)
    {
        return _Parts.IsValidIndex(InPart) && ck::IsValid(_Parts[InPart]) && _Parts[InPart].Get_Condition() == InCondition;
    }

    protected bool Get_IsPartZoneEnabled(int32 InPart)
    {
        return _Parts[InPart].Get_Zone().Get_IsEnabled();
    }

    protected bool Get_IsBodyCurrent(float32 InExpected)
    {
        return ck::IsValid(_Monster) && Math::IsNearlyEqual(_Monster.Get_BodyHealth().Get_Current(), InExpected, 0.01f);
    }

    // This machine's copy of the ledger on the monster's root; empty when there is none.
    protected FMars_Fragment_BodyPart_Net Get_Ledger()
    {
        if (ck::Is_NOT_Valid(_MonsterRoot) || _MonsterRoot.Has_Fragment(FMars_Fragment_BodyPart_Net) == false)
        { return FMars_Fragment_BodyPart_Net(); }

        return _MonsterRoot.Get_Fragment(FMars_Fragment_BodyPart_Net);
    }

    // Server: a hit of InAmount Sever on its copy of part InPart's zone.
    protected void Request_ServerPartHit(int32 InPart, float32 InAmount)
    {
        auto Zone = _Parts[InPart].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Claiming a part
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ClientReadyToClaimAPart(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsMonsterFound());
    }

    // Part InPart's zone address on this machine, the cleaver, the point of the part's hurtbox nearest the hand, +X.
    protected FMars_HeldItemUse_Strike Make_PartClaim(int32 InPart)
    {
        const auto Address = _Parts[InPart].Get_Zone().Get_Address();
        const auto PartNode = _Parts[InPart].As_Transform();
        const auto Center = utils_transform::Get_EntityCurrentLocation(PartNode);

        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = Center + FVector(-k_PartHurtboxHalfExtent, 0.0, k_PartHurtboxHalfExtent);
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        return Claim;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line
    //----------------------------------------------------------------------------------------------------------------------

    protected FString Describe_Parts()
    {
        FString Text = "";
        for (int32 Index = 0; Index < _Parts.Num(); ++Index)
        {
            const auto Part = _Parts[Index];
            if (ck::Is_NOT_Valid(Part))
            {
                Text += f"[{Index} invalid] ";
                continue;
            }

            const auto Address = Part.Get_Zone().Get_Address();
            const auto IsRootTheMonster = Address.Root == _MonsterRoot;
            const auto Signals = _PartSignals[Index];
            Text += f"[{Index} {Part.Get_State() :n} {Part.Get_Condition() :n} roster={Part.Get_RosterIndex()} zoneEnabled={Get_IsPartZoneEnabled(Index)} address=[rootIsMonster {IsRootTheMonster} {Address.Index}] conditionChanged={Signals.ConditionChanged} ({Signals.LastOld :n}->{Signals.LastNew :n}) broken={Signals.Broken} brokenFrame={Signals.BrokenFrame} severed={Signals.Severed}] ";
        }

        return Text;
    }

    protected FString Describe_Ledger()
    {
        const auto Ledger = Get_Ledger();
        FString Text = f"{Ledger.Parts.Num()}:";
        for (const auto& Entry : Ledger.Parts)
        { Text += f" {Entry.State :n}/{Entry.Condition :n}"; }

        return Text;
    }

    // The row's one log line on this machine.
    protected void Log_PartRow(FString InRow, FString InExtra)
    {
        const auto IsFound = ck::IsValid(_Monster);
        const auto BodyCurrent = IsFound ? _Monster.Get_BodyHealth().Get_Current() : -1.0f;
        const auto Attached = IsFound ? _Monster.Get_AttachedPartCount() : -1;
        const auto PartsText = Describe_Parts();
        const auto LedgerText = Describe_Ledger();
        const auto Line = f"[BodyPartNetTest] {InRow} {Get_MachineName()} parts={_Parts.Num()} {PartsText}body={BodyCurrent} attached={Attached} ledger=[{LedgerText}] ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    private int32 Get_PartIndex(FCk_Handle_BodyPart InPart) const
    {
        for (int32 Index = 0; Index < _Parts.Num(); ++Index)
        {
            if (_Parts[Index] == InPart)
            { return Index; }
        }

        return -1;
    }

    UFUNCTION()
    private void OnPartConditionChanged(FCk_Handle_BodyPart InPart, EMars_BodyPart_Condition InOld, EMars_BodyPart_Condition InNew)
    {
        const auto Index = Get_PartIndex(InPart);
        if (Index < 0)
        { return; }

        _PartSignals[Index].ConditionChanged += 1;
        _PartSignals[Index].LastOld = InOld;
        _PartSignals[Index].LastNew = InNew;
    }

    UFUNCTION()
    private void OnPartBroken(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause)
    {
        const auto Index = Get_PartIndex(InPart);
        if (Index < 0)
        { return; }

        _PartSignals[Index].Broken += 1;
        if (_PartSignals[Index].BrokenFrame < 0)
        { _PartSignals[Index].BrokenFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnPartSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        const auto Index = Get_PartIndex(InPart);
        if (Index < 0)
        { return; }

        _PartSignals[Index].Severed += 1;
    }
}
