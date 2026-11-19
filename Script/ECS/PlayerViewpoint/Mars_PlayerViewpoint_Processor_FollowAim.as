// On every copy that is not locally controlled, snaps the camera's boom each frame to the aim source's base aim rotation
// (GetBaseAimRotation: the controller's rotation on the authority, the replicated yaw and view pitch elsewhere), so the
// view anchor and everything hung off it or read from it (the interaction trace, a devourer's look at its victim, a blow
// or a launch aimed by the view) point where that player looks. Runs before the camera composes the view in
// FGroup_Transform_Derived, so the anchor follows in the same frame. The locally controlled copy is left to its own look
// input; the predicate is read every frame, so a copy that becomes locally controlled after composition stops following
// from that frame on (utils_net::Get_IsEntityLocallyControlled_ByPlayer, the pawn's live predicate,
// AMars_PlayerCharacter::Get_IsLocalPlayerView). A viewpoint without an aim source or a camera (a test rig's) is left as
// it is.
class UMars_Processor_PlayerViewpoint_FollowAim : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlayerViewpoint);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PlayerViewpoint_Params& InParams,
                       FMars_Fragment_PlayerViewpoint& InState)
    {
        // The source is the player's own pawn; the entity outlives it only while both are torn down.
        auto Source = InParams.AimSource.Get();
        if (ck::Is_NOT_Valid(Source) || ck::Is_NOT_Valid(InState.Camera))
        { return; }

        const auto Control = utils_net::Get_IsEntityLocallyControlled_ByPlayer(InHandle);
        if (Control == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { return; }

        // Normalized: a controller's pitch reads 0..360, the director's pitch limits -90..90.
        auto Camera = InState.Camera;
        utils_camera::Request_SnapBoomRotation(Camera, Source.GetBaseAimRotation().GetNormalized());
    }
}
