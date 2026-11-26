// The proximity channel's attenuation is a script asset (mars::Mars_Voice_ProximityAttenuation, an AngelScript literal
// under /Script/AngelscriptAssets) named by soft pointer in the channel's Spec. The channel resolves it through
// CkResourceLoader at setup on every machine; on the client (and the server) it resolves to that very asset, with no
// ensure, and the asset's inner radius plus falloff equals the channel's audible range, so a voice fades to silence where
// the server stops sending it. The channel is the production Spec on the test subject (see
// Mars_AutoTestRig_NetRealPawnVoice.as).
// Surface: Ck.RealPawn.Net.AS_RealPawn_TheProximityChannelResolvesItsAttenuationOnTheClient
class UCk_AutoTest_Net_RealPawn_TheProximityChannelResolvesItsAttenuationOnTheClient : UMars_AutoTestRig_NetRealPawnVoice
{
    private const FVector k_Base = FVector(964000.0, 0.0, 5000.0);
    private const FString k_Row = "TheProximityChannelResolvesItsAttenuationOnTheClient";
    private const float64 k_RangeToleranceCm = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_VoiceRig();
        Mark_Deadline(15.0);
        WaitUntil(n"Is_AttenuationResolved", n"OnAttenuationResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_AttenuationResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (ck::IsValid(_Channel) && ck::IsValid(utils_voice_channel::Get_ResolvedAttenuation(_Channel))));
    }

    UFUNCTION()
    private void OnAttenuationResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Expected = mars::Mars_Voice_ProximityAttenuation;
        const auto Resolved = utils_voice_channel::Get_ResolvedAttenuation(_Channel);
        const auto Range = float64(utils_voice_channel::Get_AudibleRange(_Channel));
        const auto Silent = ck::IsValid(Resolved)
            ? Resolved.Attenuation.AttenuationShapeExtents.X + float64(Resolved.Attenuation.FalloffDistance)
            : -1.0;
        const auto ResolvedPath = ck::IsValid(Resolved) ? Resolved.GetPathName() : "none";

        Log_VoiceRow(k_Row, f"resolved={ResolvedPath} expected={Expected.GetPathName()} silentAt={Silent :.0} range={Range :.0} policy={utils_voice_channel::Get_SpatializationPolicy(_Channel) :n}");
        Assert_True(ck::IsValid(Resolved), f"the {Get_MachineName()}'s proximity channel resolved its authored attenuation");
        Assert_True(Resolved == Expected, f"the {Get_MachineName()}'s proximity channel resolved the script attenuation asset ({Expected.GetPathName()})");
        Assert_True(Math::Abs(Silent - Range) <= k_RangeToleranceCm,
            f"the attenuation goes silent where the channel's audible range ends (inner radius + falloff {Silent :.0} cm, range {Range :.0} cm)");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        FinishSuccess();
    }
}
