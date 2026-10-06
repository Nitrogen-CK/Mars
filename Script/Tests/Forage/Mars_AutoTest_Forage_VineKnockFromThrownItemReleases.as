// The real fig vine (KnockMinSpeed 300): a Rock dropped 20 uu onto its fruit body closes too slowly and releases nothing;
// a Rock launched down at the fruit from 200 uu above knocks it down (Knock) and the one-charge vine is exhausted.
class UMars_AutoTest_Forage_VineKnockFromThrownItemReleases : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(-60000.0, 8000.0, -60000.0);
    private const float32 k_HangHeight = 220.0f;
    private const float32 k_FruitRadius = 22.0f;
    private const float32 k_KnockMinSpeed = 300.0f;
    // The Rock is the engine sphere at 0.3.
    private const float64 k_RockRadius = 15.0;
    private const float64 k_SlowDropGap = 20.0;
    // Off the fruit's crown, so the slow Rock rolls off rather than balancing on it.
    private const float64 k_SlowDropOffsetX = 8.0;
    private const float64 k_FastDropHeight = 200.0;
    private const FVector k_FastLaunch = FVector(0.0, 0.0, -600.0);

    private FCk_Handle _SlowRock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_Forage_FigVine_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        SpawnParams.WithVisuals = false;
        SpawnParams.HangHeight = k_HangHeight;
        SpawnParams.FruitRadius = k_FruitRadius;
        SpawnParams.KnockMinSpeed = k_KnockMinSpeed;

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Forage_FigVine_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnSourceConstructed"));

        Add_Step_WaitUntil("the vine composed its forage and zone", n"Check_Composed");
        Add_Step("bind the forage; drop a Rock 20 uu onto the fruit", n"Step_DropSlowRock");
        Add_Step_WaitUntil("the slow Rock rolled off and fell past the fruit", n"Check_SlowRockFell", 0, 4.0f);
        Add_Step("nothing released; launch a Rock down at the fruit from 200 uu", n"Step_LaunchFastRock");
        Add_Step_WaitUntil("the fruit is knocked down", n"Check_Knocked", 0, 4.0f);
        Add_Step("the one-charge vine is exhausted", n"Step_AssertExhausted");
        Run_Steps(InHandle);
    }

    private FVector Get_FruitCentre() const
    {
        return k_Origin + FVector(0.0, 0.0, k_HangHeight);
    }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSourceComposed());
    }

    UFUNCTION()
    private void Step_DropSlowRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        BindSignals(_Source.As_Forage());
        const auto Above = FVector(k_SlowDropOffsetX, 0.0, k_FruitRadius + k_RockRadius + k_SlowDropGap);
        _SlowRock = SpawnRock(Get_FruitCentre() + Above, FVector::ZeroVector);
    }

    UFUNCTION()
    private void Check_SlowRockFell(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_SlowRock) || _SlowRock.Is_Transform() == false)
        {
            Res.Set(false);
            return;
        }

        const auto RockZ = utils_transform::Get_EntityCurrentLocation(_SlowRock.As_Transform()).Z;
        Res.Set(RockZ < Get_FruitCentre().Z - 100.0);
    }

    UFUNCTION()
    private void Step_LaunchFastRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 0, "a Rock closing under KnockMinSpeed releases nothing");
        Assert_False(_Forage.Get_IsExhausted(), "the vine still holds its fruit");
        SpawnRock(Get_FruitCentre() + FVector(0.0, 0.0, k_FastDropHeight), k_FastLaunch);
    }

    UFUNCTION()
    private void Check_Knocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1 && _ReleaseReasons[0] == EMars_Forage_ReleaseReason::Knock);
    }

    UFUNCTION()
    private void Step_AssertExhausted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Forage.Get_IsExhausted(), "the knock took the only charge");
        Assert_Equals_Int(_ExhaustedCount, 1, "exhausted once");
    }
}
