// A separate navigation island for the 30 x 24 m expedition hunt courts.
class UMars_Expedition_NavField_EntityScript : UCk_GroundNavVolume_EntityScript
{
    default _Params = utils_surface_navigator::Make_NavFieldSpec(FBox(FVector(-1400.0, -1100.0, -100.0), FVector(1400.0, 1100.0, 600.0)));
}
