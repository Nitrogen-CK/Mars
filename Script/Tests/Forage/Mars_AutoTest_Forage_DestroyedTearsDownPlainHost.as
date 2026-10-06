// A one-charge Destroyed source on a plain (non-world-item) entity destroys its host on the release; the released world
// item outlives it (owned by the transient entity, tracked for cleanup).
class UMars_AutoTest_Forage_DestroyedTearsDownPlainHost : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_Origin = FVector(-60000.0, 4000.0, -60000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddSource(InHandle, k_Origin);
        AddForage(Make_RockSpec(1, FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Destroyed)));

        Add_Step("request a release", n"Step_Release");
        Add_Step_WaitUntil("the host is gone and the released item lives", n"Check_HostGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestRelease(EMars_Forage_ReleaseReason::Hit);
    }

    UFUNCTION()
    private void Check_HostGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1 && _ExhaustedCount == 1 && ck::Is_NOT_Valid(_Source) && ck::IsValid(_Released[0]));
    }
}
