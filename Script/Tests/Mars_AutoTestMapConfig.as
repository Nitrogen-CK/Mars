// Points UCkAutoTestMapPopulator at the Mars AutoTests level. ClassScanRoot is left empty: a config under the
// project's Script/ auto-scopes to <ProjectDir>/Script (CkAutoTestMapPopulator.cpp:1754-1760, :1930-1950).
#if EDITOR
asset Mars_AutoTestMapConfig of UCkAutoTestMapConfig
{
    TargetMap = assets::AutoTests_Mars_MAP();
}
#endif
