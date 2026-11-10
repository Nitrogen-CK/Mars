// The same parents as the main-pass test, their spawns executed in the end-of-frame tail pump (forced by a processor in
// FGroup_Replication, after the script group): both replicate with their DoConstruct children.
// Surface: Ck.NetSpawn.Net.AS_NetSpawn_ChildrenOfATailPumpParentReachTheClient
class UCk_AutoTest_Net_NetSpawn_ChildrenOfATailPumpParentReachTheClient : UMars_AutoTestRig_NetSpawnParent
{
    default _Pass = EMars_TESTONLY_NetSpawn_Pass::Tail;
    default _PayloadBase = 3610;
    default _Location = FVector(31000.0, 0.0, 0.0);
}
