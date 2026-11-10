// A parent that requests a Replicates child in its own DoConstruct, its spawn executed in the script group's main pass
// (forced by a processor ordered before the spawn processor), once under the replicated spawn owner and once under the
// subject: the child's spawn executes in the settle barrier, and parent and child both replicate and reach the client.
// Surface: Ck.NetSpawn.Net.AS_NetSpawn_ChildrenOfAMainPassParentReachTheClient
class UCk_AutoTest_Net_NetSpawn_ChildrenOfAMainPassParentReachTheClient : UMars_AutoTestRig_NetSpawnParent
{
    default _Pass = EMars_TESTONLY_NetSpawn_Pass::Main;
    default _PayloadBase = 3600;
    default _Location = FVector(30000.0, 0.0, 0.0);
}
