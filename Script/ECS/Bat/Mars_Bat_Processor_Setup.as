// Wires a new bat to its kernel, once: every hit its body zone routes becomes a TakeHit; the crowd agent's goal signals and
// the voxel path's failures become RouteResults (so every FlyTo ends in an explicit outcome); a perch owner given in the
// spec is claimed. The zone, the agent and the path are all on the bat's root.
class UMars_Processor_Bat_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Bat_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bat);
        Query.Require(FMars_Tag_Bat_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Bat = InHandle.As_Bat();

        auto Zone = Bat.Get_Monster().Get_BodyZone();
        Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnBodyHit"));

        auto Agent = Bat.Get_Agent();
        utils_crowd_agent::BindTo_OnGoalReached(Agent, FCk_Delegate_CrowdAgent_OnGoalReached(this, n"OnGoalReached"),
            ECk_Signal_BindingPolicy::IgnorePayloadInFlight, ECk_Signal_PostFireBehavior::DoNothing);
        utils_crowd_agent::BindTo_OnGoalFailed(Agent, FCk_Delegate_CrowdAgent_OnGoalFailed(this, n"OnGoalFailed"),
            ECk_Signal_BindingPolicy::IgnorePayloadInFlight, ECk_Signal_PostFireBehavior::DoNothing);
        utils_crowd_agent::BindTo_OnGoalBlocked(Agent, FCk_Delegate_CrowdAgent_OnGoalBlocked(this, n"OnGoalBlocked"),
            ECk_Signal_BindingPolicy::IgnorePayloadInFlight, ECk_Signal_PostFireBehavior::DoNothing);

        auto Path = Bat.Get_Path();
        utils_voxel_nav_path::BindTo_OnPathFailed(Path, FCk_Delegate_VoxelNavPath_OnPathFailed(this, n"OnPathFailed"),
            ECk_Signal_BindingPolicy::IgnorePayloadInFlight, ECk_Signal_PostFireBehavior::DoNothing);

        const auto Owner = Bat.Get_RoostOwner();
        if (ck::IsValid(Owner))
        {
            if (ck::EnsureIfNot(utils_bat::Get_IsRoost(Owner), f"[Bat] [{Bat.ToString()}] was given a PerchOwner [{Owner.ToString()}] that is not a roost (utils_bat::Add_Roost)") == false)
            { utils_bat::Request_ClaimRoost(Owner, FMars_Request_BatRoost_Claim(Bat)); }
        }

        Bat.Request_TryRemove(FMars_Tag_Bat_NeedsSetup);
    }

    UFUNCTION()
    private void OnBodyHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        auto Bat = InZone.As_Bat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Bat))
        { Bat.Request_TakeHit(FMars_Request_Bat_TakeHit(InScaledEvent)); }
    }

    UFUNCTION()
    private void OnGoalReached(FCk_Handle_CrowdAgent InAgent)
    {
        ReportStamped(InAgent, EMars_Bat_RouteOutcome::Reached);
    }

    UFUNCTION()
    private void OnGoalFailed(FCk_Handle_CrowdAgent InAgent, FCk_CrowdAgent_GoalFailedInfo InInfo)
    {
        ReportStamped(InAgent, EMars_Bat_RouteOutcome::GoalFailed);
    }

    UFUNCTION()
    private void OnGoalBlocked(FCk_Handle_CrowdAgent InAgent, FCk_CrowdAgent_GoalBlockedInfo InInfo)
    {
        ReportStamped(InAgent, EMars_Bat_RouteOutcome::GoalBlocked);
    }

    UFUNCTION()
    private void OnPathFailed(FCk_Handle_VoxelNavPath InPath, ECk_VoxelNav_PathSearchOutcome InOutcome)
    {
        FCk_Handle Entity = InPath;
        auto Bat = Entity.As_Bat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Bat))
        { Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(utils_bat::Get_RouteOutcome(InOutcome))); }
    }

    // No goal payload carries the MoveTo's correlation id, so every agent answer (reached, failed, blocked) is stamped with
    // the agent's active move correlation id (= the route generation Issue_Move set; only an accepted MoveTo changes it).
    // Reached is stamped too: in PIE the launch's late OnGoalReached was credited to the Approach route issued the frame
    // before, the voxel path's Unreachable for that route then found it no longer Pending, the agent was never stopped and
    // followed CkCrowd's fallback through the floor.
    private void ReportStamped(FCk_Handle_CrowdAgent InAgent, EMars_Bat_RouteOutcome InOutcome)
    {
        FCk_Handle Entity = InAgent;
        auto Bat = Entity.As_Bat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Bat))
        { Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(InOutcome, utils_crowd_agent::Get_ActiveMoveCorrelationId(InAgent))); }
    }
}

namespace utils_bat
{
    EMars_Bat_RouteOutcome Get_RouteOutcome(ECk_VoxelNav_PathSearchOutcome InOutcome)
    {
        if (InOutcome == ECk_VoxelNav_PathSearchOutcome::NoBake)
        { return EMars_Bat_RouteOutcome::NoBake; }

        if (InOutcome == ECk_VoxelNav_PathSearchOutcome::EndpointUnresolvable)
        { return EMars_Bat_RouteOutcome::EndpointUnresolvable; }

        if (InOutcome == ECk_VoxelNav_PathSearchOutcome::Unreachable)
        { return EMars_Bat_RouteOutcome::Unreachable; }

        if (InOutcome == ECk_VoxelNav_PathSearchOutcome::Succeeded)
        { return EMars_Bat_RouteOutcome::Reached; }

        return EMars_Bat_RouteOutcome::SearchFailed;
    }
}
