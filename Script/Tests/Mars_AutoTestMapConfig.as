// Points UCkAutoTestMapPopulator at the Mars AutoTests level. ClassScanRoot is left empty: a config under the
// project's Script/ auto-scopes to <ProjectDir>/Script.
#if EDITOR
asset Mars_AutoTestMapConfig of UCkAutoTestMapConfig
{
    TargetMap = assets::AutoTests_Mars_MAP();
}
#endif
