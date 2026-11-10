// The same parents as the main-pass test, their spawns executed in the script group's settle barrier (forced by a
// processor ordered after the framework's begin-play processor): both replicate with their DoConstruct children.
// Surface: Ck.NetSpawn.Net.AS_NetSpawn_ChildrenOfASettlePassParentReachTheClient
class UCk_AutoTest_Net_NetSpawn_ChildrenOfASettlePassParentReachTheClient : UMars_AutoTestRig_NetSpawnParent
{
    default _Pass = EMars_TESTONLY_NetSpawn_Pass::Settle;
    default _PayloadBase = 3640;
    default _Location = FVector(33000.0, 0.0, 0.0);
}
