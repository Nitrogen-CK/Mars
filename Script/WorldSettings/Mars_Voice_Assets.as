// Mars voice: the proximity channel every chef speaks and hears on. The channel is composed on the GameState's entity on
// every machine (AMars_Master_GameState::Request_ComposeEntity); each chef's talker joins it by name (its Spec lists the
// channel in _AutoJoinChannels and this Spec enables _AutoJoinTalkers), so Mars writes no join or leave code. Mars owns no
// voice state: it composes the CkVoiceChat features directly (Plugins/CkFoundation/Source/CkVoiceChat/Claude.md).
class UMars_Voice_Config : UDataAsset
{
    // Positional3D: the server sends a chef's voice only to chefs inside _AudibleRange (held to range + the module's
    // hysteresis margin), and each listener plays it from the speaker's body through _Attenuation.
    UPROPERTY(Category = "Voice")
    FCk_VoiceChannel_Spec ProximityChannel;
}

namespace mars
{
    asset Mars_Voice_Config of UMars_Voice_Config
    {
        ProximityChannel = FCk_VoiceChannel_Spec(GameplayTags::VoiceChat_Channel_Mars_Proximity);
        ProximityChannel.Set_SpatializationPolicy(ECk_VoiceChat_SpatializationPolicy::Positional3D);
        // Keep equal to Mars_Voice_ProximityAttenuation's inner radius + falloff distance, so a voice fades to silence
        // where the server stops sending it (the attenuation-resolves net test checks the two agree).
        ProximityChannel.Set_AudibleRange(4000.0f);
        ProximityChannel.Set_AutoJoinTalkers(ECk_EnableDisable::Enable);
        // A script asset is created the first time its accessor runs: naming the object here (not its path) is what makes
        // it exist before the channel's CkResourceLoader batch looks for /Script/AngelscriptAssets.Mars_Voice_ProximityAttenuation.
        ProximityChannel.Set_Attenuation(TSoftObjectPtr<USoundAttenuation>(mars::Mars_Voice_ProximityAttenuation));
    }

    // How a chef's voice falls off with distance on the listener's machine. Full volume within the inner sphere, then
    // the natural-sound curve down to -60 dB at the end of the falloff, which is the channel's audible range.
    asset Mars_Voice_ProximityAttenuation of USoundAttenuation
    {
        Attenuation.bAttenuate = true;
        Attenuation.bSpatialize = true;
        Attenuation.AttenuationShape = EAttenuationShape::Sphere;
        Attenuation.AttenuationShapeExtents = FVector(200.0, 0.0, 0.0);
        Attenuation.FalloffDistance = 3800.0f;
        Attenuation.DistanceAlgorithm = EAttenuationDistanceModel::NaturalSound;
        Attenuation.dBAttenuationAtMax = -60.0f;
    }
}
