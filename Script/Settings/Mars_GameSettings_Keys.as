// Setting keys and category names, declared once so the registry, the settings screen and every consumer agree.
// A category name is the ROOT segment of the definition's category tag (DefaultGameplayTags.ini: Audio.*, Video,
// Controls); the settings screen derives its tabs from it.
namespace constants_settings
{
    const FName k_Category_Audio = n"Audio";
    const FName k_Category_Video = n"Video";
    const FName k_Category_Controls = n"Controls";

    // Registered by the audio pack from DefaultCkFoundation.ini (_AudioCategories).
    const FName k_AudioMaster = n"audio.master";
    const FName k_AudioMusic = n"audio.music";
    const FName k_AudioSfx = n"audio.sfx";
    const FName k_AudioVoice = n"audio.voice";

    // Registered by Mars with Mars presentation; the video pack binds their UGameUserSettings accessors afterwards.
    const FName k_VideoQualityPreset = n"video.quality_preset";
    const FName k_VideoVSync = n"video.vsync";
    const FName k_VideoFpsCap = n"video.fps_cap";
    const FName k_VideoViewDistance = n"video.sg.view_distance";
    const FName k_VideoShadow = n"video.sg.shadow";
    const FName k_VideoEffects = n"video.sg.effects";

    // The last key the video pack registers; its presence means the pack has run.
    const FName k_VideoFoliage = n"video.sg.foliage";

    const FName k_LookSensitivity = n"controls.look_sensitivity";
    const FName k_InvertY = n"controls.invert_y";
    const FName k_SprintToggle = n"controls.sprint_toggle";

    // UGameUserSettings::GetOverallScalabilityLevel reports this when the scalability groups sit at different levels.
    const int32 k_MixedQualityPreset = -1;

    // Scalability level "Epic": the engine default every sg.* group boots at.
    const int32 k_EpicQualityLevel = 3;
}
