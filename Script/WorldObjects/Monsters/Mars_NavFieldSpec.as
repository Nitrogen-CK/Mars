namespace utils_surface_navigator
{
    // The monster rooms' ground-nav volume (Room 5, the expedition courts): a crawler-sized agent capsule and no ledge
    // demotion, because the field is clipped to the volume, whose edges are not ledges. AutoBuildOnSetup stays enabled.
    FCk_GroundNavVolume_Spec Make_NavFieldSpec(FBox InBounds)
    {
        auto Config = FCk_GroundNav_BakeConfig(25.0f, 10.0f);
        Config.Set_TileSizeUu(500.0f);

        auto Profile = FCk_GroundNav_AgentProfile(utils_shapes::Make_Capsule(FCk_ShapeCapsule_Dimensions(40.0f, 40.0f)));
        Profile.Set_LedgeSensitivity(0.0f);

        return FCk_GroundNavVolume_Spec(InBounds, Config, Profile);
    }
}
