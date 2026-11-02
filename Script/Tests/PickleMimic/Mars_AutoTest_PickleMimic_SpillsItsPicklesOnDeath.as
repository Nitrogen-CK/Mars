// A mimic whose Spec spills 3 pickles (not the default 8, so the count is the Spec's) dies to one lethal blow: OnSpill
// goes out once with 3, and 3 pickle foods (world items of mars_items::Food_Pickle) appear round the broken jar and stay
// there; nothing spills while it lives.
class UMars_AutoTest_PickleMimic_SpillsItsPicklesOnDeath : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 210000.0, 600.0);

    private const int32 k_Pickles = 3;
    private const float64 k_SearchRadius = 500.0;

    private TArray<int32> _Spills;
    private int32 _PicklesBeforeDeath = -1;
    private float64 _DiedAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_PickleMimic_Spec();
        Spec.Vitals.SpilledPickles = k_Pickles;
        SpawnFloorAndMimic(InHandle, Spec);

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step("listen for the spill, then a lethal blow", n"Step_Kill");
        Add_Step_WaitUntil("it is dead and has spilled", n"Check_Spilled", 0, 4.0f);
        Add_Step_WaitUntil("a second for the pickles to land", n"Check_Settled", 0, 4.0f);
        Add_Step("the Spec's count of pickles spilled, once", n"Step_AssertSpill");
        Run_Steps(InHandle);
    }

    // The pickle foods within k_SearchRadius of the jar.
    private int32 Get_PickleCount()
    {
        const auto Pickle = mars_items::Food_Pickle();
        auto Count = 0;
        for (auto Entity : Get_WorldItemsNearOrigin(k_SearchRadius))
        {
            const auto Item = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Item) && Item.Get_Definition() != Pickle)
            { continue; }

            ++Count;
        }

        return Count;
    }

    UFUNCTION()
    private void Step_Kill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mimic.BindTo_OnSpill(FMars_Delegate_PickleMimic_OnSpill(this, n"OnSpill"));
        _PicklesBeforeDeath = Get_PickleCount();
        auto Health = _Mimic.Get_Monster().Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void OnSpill(FCk_Handle_PickleMimic InMimic, int32 InCount)
    {
        _Spills.Add(InCount);
    }

    UFUNCTION()
    private void Check_Spilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Done = _Mimic.Get_IsDead() && _Mimic.Get_Hurt().Spilled;
        if (Done)
        { _DiedAt = System::GetGameTimeInSeconds(); }

        Res.Set(Done);
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _DiedAt >= 1.0);
    }

    UFUNCTION()
    private void Step_AssertSpill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PicklesBeforeDeath, 0, "nothing had spilled while it lived");
        Assert_Equals_Int(_Spills.Num(), 1, "OnSpill went out once");
        if (_Spills.Num() > 0)
        { Assert_Equals_Int(_Spills[0], k_Pickles, "OnSpill carried the Spec's count"); }

        Assert_Equals_Int(Get_PickleCount(), k_Pickles, "the Spec's count of pickle foods lie round the broken jar");
        Track_SpilledPickles();
    }
}
