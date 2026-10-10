// Finishes a Loose release of a piece that kept its own body: once the body's mirror reads Dynamic (the SetMotionType handler
// stamps it), the piece takes the release velocity. Never in the frame of the switch: a velocity sent beside the switch
// reaches a Kinematic body and is lost. The switch is asked again until it lands (the handler drops a request that reaches
// a body not added yet). A piece that is gone is dropped.
class UMars_Processor_FoodBoard_Loosen : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodBoard);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_FoodBoard& InState)
    {
        if (InState.PendingLoosens.Num() == 0)
        { return; }

        TArray<FMars_FoodBoard_PendingLoosen> StillPending;
        for (const auto& Pending : InState.PendingLoosens)
        {
            const auto Piece = Pending.Piece;
            if (ck::Is_NOT_Valid(Piece) || utils_entity_lifetime::Get_IsPendingDestroy(Piece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            FCk_Handle Entity = Piece;
            auto Body = Entity.As_JoltBody();
            if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
            {
                StillPending.Add(Pending);
                continue;
            }

            if (utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Dynamic)
            {
                utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
                StillPending.Add(Pending);
                continue;
            }

            utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(Pending.VelocityWorld));
            ck::Trace(f"[FoodBoard] [{InHandle.ToString()}] [{Piece.ToString()}] loosened on its own body at {Pending.VelocityWorld} cm/s");
        }

        InState.PendingLoosens = StillPending;
    }
}
