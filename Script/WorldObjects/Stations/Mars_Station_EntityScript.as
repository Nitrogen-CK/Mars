// Base placeable station: composes the transform and the Station feature (see FMars_Station_Spec for the frame: the root
// is the station's origin on the floor; the operator stands at StandLocal facing its +X). Concrete stations fill in the
// geometry-bound spec fields (stand, grips), the Use probe, the visuals and the nodes their grips name. The visuals are
// built first so the grip nodes exist when the station resolves its grips.
UCLASS(Abstract)
class UMars_Station_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Not a `default` in subclasses: set geometry-bound fields in Configure_Spec (the spawn-params generator emits a
    // non-default script struct as a positional constructor call).
    UPROPERTY(ExposeOnSpawn)
    FMars_Station_Spec Station;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        auto Spec = Station;
        Configure_Spec(Spec);
        AddVisuals(Root);

        auto Setup = FMars_Station_Setup();
        Setup.Probe = Make_Probe();
        Register_GripNodes(Setup.GripNodes);

        // A rejected spec or grip already ensured in utils_station::Add.
        utils_station::Add(Root, Spec, Setup);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec)
    {
    }

    // Unset = a transform-only Use interactable (no view-trace focus).
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const
    {
        return TOptional<FMars_Interactable_ProbeInfo>();
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot)
    {
    }

    // Called after AddVisuals: publish, under its Station.Node.* tag, every node a spec grip names.
    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes)
    {
    }
}
