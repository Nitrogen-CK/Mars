// The placeable anchors and their candidate tables. A table is a script asset, visible only in this file, so other files
// reach it through the utils_anchor accessors below. Row order is part of the contract: a ledger names rows by index.

asset Mars_AnchorTable_Route of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Route;
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 4.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_LeverGate_EntityScript, 3.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_Rubble_EntityScript, 2.0f, EMars_Anchor_Role::Closed));
}

asset Mars_AnchorTable_Hunt of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Hunt;
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_QuarryCrawler4_EntityScript, 1.0f, EMars_Anchor_Role::Quarry));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 1.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Spawn of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Spawn;
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 1.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_Rubble_EntityScript, 1.0f, EMars_Anchor_Role::Closed));
}

namespace utils_anchor
{
    UMars_AnchorTable_Def Table_Route()
    { return Mars_AnchorTable_Route; }

    UMars_AnchorTable_Def Table_Hunt()
    { return Mars_AnchorTable_Hunt; }

    UMars_AnchorTable_Def Table_Spawn()
    { return Mars_AnchorTable_Spawn; }
}

// The placeable base. Each family preset names its family and table; the resolver decides the row.
UCLASS(Abstract)
class UMars_Anchor_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Anchor.Mars"))
    FGameplayTag AnchorId;

    // The mechanism channel a lever-gate candidate wires its levers and gate to; unique per placement.
    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Mechanism.Channel"))
    FGameplayTag Channel;

    UPROPERTY(ExposeOnSpawn)
    float32 SpanCm = 400.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 HomeRadiusCm = 1000.0f;

    // Debug: forces this row whatever the run solved; the ledger marks it.
    UPROPERTY(ExposeOnSpawn)
    TOptional<int32> PinnedRow;

    protected EMars_Anchor_Family Get_Family() const
    { return EMars_Anchor_Family::Route; }

    protected UMars_AnchorTable_Def Get_Table() const
    { return nullptr; }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Anchor_Spec();
        Spec.AnchorId = AnchorId;
        Spec.Family = Get_Family();
        Spec.Table = TSoftObjectPtr<UMars_AnchorTable_Def>(Get_Table());
        Spec.Transform = SpawnTransform;
        Spec.Channel = Channel;
        Spec.SpanCm = SpanCm;
        Spec.HomeRadiusCm = HomeRadiusCm;
        Spec.PinnedRow = PinnedRow;
        utils_anchor::Add(InHandle, Spec);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class UMars_Anchor_Route_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Route; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Route(); }
}

class UMars_Anchor_Hunt_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Hunt; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Hunt(); }
}

class UMars_Anchor_Spawn_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Spawn; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Spawn(); }
}
