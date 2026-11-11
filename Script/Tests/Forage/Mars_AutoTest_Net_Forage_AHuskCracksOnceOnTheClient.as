// A Bellnut husk spawned on the listen host is depleted there by one Blunt hit: the server releases its kernel and tears
// the husk down. On the client the shell breaks exactly once - the debris count rises by the definition's piece count
// once, whether the mirrored release or the husk's end arrives first - and the kernel lies in the world on both machines.
// Surface: Ck.Forage.Net.AS_Forage_AHuskCracksOnceOnTheClient
class UCk_AutoTest_Net_Forage_AHuskCracksOnceOnTheClient : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(72000.0, 0.0, 5000.0);
    private const float32 k_CrackDamage = 50.0f;

    private int32 _Pieces = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        const UCk_InventoryItem_Definition Bellnut = mars_items::Bellnut();
        const UMars_ItemTrait_Husk Husk = Bellnut.Get_ItemTraitByClass(UMars_ItemTrait_Husk);
        if (ck::Is_NOT_Valid(Husk))
        { FinishFailure("the Bellnut has no Husk trait"); return; }

        _Pieces = Husk.Debris.Pieces;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrackedWithAKernel", n"OnClientCracked", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_WorldItem_Husk_EntityScript::Params();
        Params.Definition = mars_items::Bellnut();
        Params.Mode = EMars_WorldItem_Mode::World;
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        utils_world_item::Request_SpawnWorldEntity(ck::TransientEntity(), UMars_WorldItem_Husk_EntityScript, Params);
        WaitUntil(n"Is_HuskComposed", n"OnServerHuskComposed", k_SlowPolls);
    }

    // The server's husk is a seeded world item with its zone and forage.
    UFUNCTION()
    private void Is_HuskComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsWorldItem") && _Source.Is_HitZone() && ck::IsValid(_Source.As_WorldItem().Get_HeldItem()));
    }

    // Long enough for the client to have its copy before the server cracks it.
    UFUNCTION()
    private void OnServerHuskComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToCrack");
    }

    UFUNCTION()
    private void OnServerReadyToCrack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Zone = _Source.As_HitZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(k_CrackDamage, GameplayTags::DamageType_Mars_Blunt)));
        WaitUntil(n"Is_CrackedWithAKernel", n"OnServerCracked", k_SlowPolls);
    }

    // This machine has its shell debris and a kernel near the base.
    UFUNCTION()
    private void Is_CrackedWithAKernel(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Count_DebrisNear() >= _Pieces && Count_WorldItemsNear(mars_items::BellnutKernel()) > 0);
    }

    UFUNCTION()
    private void OnServerCracked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Cracked("server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    // Settles so a second crack would have landed.
    UFUNCTION()
    private void OnClientCracked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Cracked("client");
        FinishSuccess();
    }

    // Debris near the base, each tracked for cleanup: the pieces are local to the machine that cracked.
    private int32 Count_DebrisNear()
    {
        auto Count = 0;
        for (auto Piece : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsForageDebris"))
        {
            if (Get_IsNear(Piece) == false)
            { continue; }

            Track_ForCleanup(Piece);
            Count += 1;
        }

        return Count;
    }

    // Only the client logs: one line per test.
    private void Check_Cracked(FString InMachine)
    {
        const auto Debris = Count_DebrisNear();
        const auto Kernels = Count_WorldItemsNear(mars_items::BellnutKernel());
        const auto Ensures = Get_NewEnsures();
        Assert_Equals_Int(Debris, _Pieces, f"the {InMachine}'s shell broke exactly once");
        Assert_Equals_Int(Kernels, 1, f"one kernel lies on the {InMachine}");
        Assert_Equals_Int(Ensures, 0, f"no ensure on the {InMachine}");
        if (Get_IsServer() == false)
        { Log(f"[ForageNetTest] AHuskCracksOnceOnTheClient {InMachine} debris={Debris} pieces={_Pieces} kernels={Kernels} ensures={Ensures}"); }
    }
}
