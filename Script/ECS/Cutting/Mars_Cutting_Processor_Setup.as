// One-shot per Cutting entity: binds the cleaver Mover's OnArrived, where a chop lands. At the end pose (contact) the chop
// lands and the cleaver goes back up; at the start pose (back up) the next press may chop. The Mover finds its Cutting
// through FMars_Fragment_Cutting_ChopLink (stamped by Add on the Mover entity).
class UMars_Processor_Cutting_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Cutting_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cutting);
        Query.Require(FMars_Tag_Cutting_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Cutting& InState)
    {
        auto Self = InHandle.As_Cutting();

        auto Mover = Self.Get_Spec().Nodes.ChopMover;
        Mover.BindTo_OnArrived(FMars_Delegate_Mover_OnArrived(this, n"OnChopMoverArrived"));

        Self.Request_TryRemove(FMars_Tag_Cutting_NeedsSetup);
    }

    UFUNCTION()
    private void OnChopMoverArrived(FCk_Handle_Mover InMover, EMars_Mover_Pose InPose)
    {
        if (ck::EnsureIfNot(InMover.Has_Fragment(FMars_Fragment_Cutting_ChopLink),
            f"[Cutting] chop Mover [{InMover.ToString()}] carries no ChopLink"))
        { return; }

        // The station is being torn down with its cleaver.
        auto Cutting = InMover.Get_Fragment(FMars_Fragment_Cutting_ChopLink).Cutting;
        if (ck::Is_NOT_Valid(Cutting))
        { return; }

        auto& State = Cutting.Get_Fragment(FMars_Fragment_Cutting);
        if (State.IsChopping == false)
        { return; }

        if (InPose == EMars_Mover_Pose::Start)
        {
            State.IsChopping = false;
            return;
        }

        auto ChopMover = InMover;
        ChopMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start));

        ck::Trace(f"[Cutting] [{Cutting.ToString()}] chop landed at {State.HandLateral} uu");

        if (Cutting.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Cutting.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Broadcast(Cutting); }
    }
}
