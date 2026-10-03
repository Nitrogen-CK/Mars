// Placeable ladder. The origin is the foot on the floor; local +X points out of the ladder toward the climber (place it
// against a wall or platform face with +X facing the room). Walk into it to climb; see FMars_Ladder_Spec for the frame.
// Visuals: two rails and a rung every 30 uu, from engine cubes. The rails block; the rungs do not (the climber's capsule
// rides the climb line, and rung collision would fight it).
class UMars_Ladder_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Not a `default` in subclasses: set non-default fields in their DoConstruct (the spawn-params generator emits a
    // non-default script struct as a positional constructor call).
    UPROPERTY(ExposeOnSpawn)
    FMars_Ladder_Spec Ladder;

    private const float64 RungSpacing = 30.0;
    private const float64 RailThickness = 8.0;
    private const float64 RungThickness = 6.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto LadderRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_ladder::Add(LadderRoot, Ladder);

        AddVisuals(LadderRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine cube is 100 uu with its pivot at the centre.
        const auto Height = float64(Ladder.Height);
        const auto HalfWidth = float64(Ladder.Width) * 0.5;
        const auto RailScale = FVector(RailThickness, RailThickness, Height) * 0.01;
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, -HalfWidth, Height * 0.5), RailScale),
            CubeMesh, Material, collision::profile::BlockAll, n"Ladder_Part"));
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, HalfWidth, Height * 0.5), RailScale),
            CubeMesh, Material, collision::profile::BlockAll, n"Ladder_Part"));

        const auto RungScale = FVector(RungThickness, Ladder.Width, RungThickness) * 0.01;
        for (float64 RungZ = RungSpacing; RungZ <= Height; RungZ += RungSpacing)
        {
            InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, RungZ), RungScale),
                CubeMesh, Material, collision::profile::NoCollision, n"Ladder_Part"));
        }
    }
}
