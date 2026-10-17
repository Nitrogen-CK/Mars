class UMars_AutoTest_CrawlerMelee_EndpointPhysicsMiss : UMars_AutoTest_CrawlerMelee_EndpointPhysics
{
    default _Origin = FVector(-610000.0, -180000.0, 600.0);
    default _Miss = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsDual : UMars_AutoTest_CrawlerMelee_EndpointPhysics
{
    default _Origin = FVector(-620000.0, -180000.0, 600.0);
    default _Dual = true;
    default _ExpectedEndpointId = GameplayTags::Attack_Mars_Pincer;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsDualReversed : UMars_AutoTest_CrawlerMelee_EndpointPhysicsDual
{
    default _Origin = FVector(-630000.0, -180000.0, 600.0);
    default _ReverseEmitters = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterWall : UMars_AutoTest_CrawlerMelee_EndpointPhysicsDual
{
    default _Origin = FVector(-640000.0, -180000.0, 600.0);
    default _WorldBlocker = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterBystander : UMars_AutoTest_CrawlerMelee_EndpointPhysicsDual
{
    default _Origin = FVector(-650000.0, -180000.0, 600.0);
    default _BystanderBlocker = true;
}
// The physical placement is deliberately strict. If it contacts an earlier accepted sample, the test fails and the
// measured fixture must be reviewed; a prior contact cannot substitute for interval-at-closure evidence.
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsDamageClosure : UMars_AutoTest_CrawlerMelee_EndpointPhysics
{
    default _Origin = FVector(-660000.0, -180000.0, 600.0);
    default _AnchorLastDamage = true;
    default _RequireDamageExitContact = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsFinalCandidateCancel : UMars_AutoTest_CrawlerMelee_EndpointPhysicsDamageClosure
{
    default _Origin = FVector(-670000.0, -180000.0, 600.0);
    default _CancelFinalCandidate = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointPhysicsHitch : UMars_AutoTest_CrawlerMelee_EndpointPhysics
{
    default _Origin = FVector(-680000.0, -180000.0, 600.0);
    default _Hitch = true;
}
