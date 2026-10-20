// The placeable anchors and their candidate tables. A table is a script asset, visible only in this file, so other files
// reach it through the utils_anchor accessors below. Row order is part of the contract: a ledger names rows by index.

// Row 3, the one-sided lever gate, is eligible only for an anchor with an authored lever side (a crawl beside it): there
// it takes 4 of 12 weight against the open arch's 4, the two-sided gate's 2 and rubble's 2; without a lever side the
// draw is over rows 0-2.
asset Mars_AnchorTable_Route of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Route;
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 4.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_LeverGate_EntityScript, 2.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_Rubble_EntityScript, 2.0f, EMars_Anchor_Role::Closed));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_OneSidedLeverGate_EntityScript, 4.0f, EMars_Anchor_Role::Open, EMars_AnchorRow_Need::LeverSide));
}

// The pocket (flavour) families. None is in the plan graph, so each resolves with Role None and draws from its Other
// rows (docs/design/expedition-maps-r02/ANCHOR_RULING.md: flavour colours the walk and never changes it), except the
// caches, which the plan budgets: Active within the run's MaxActiveCaches, Dormant beyond it.
asset Mars_AnchorTable_Forage of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Forage;
    Rows.Add(FMars_AnchorTable_Row(UMars_Forage_FigVine_EntityScript, 3.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(UMars_Forage_BellnutVine_EntityScript, 2.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(UMars_ForageCenser_EntityScript, 2.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(UMars_Expedition_MushroomBed_EntityScript, 3.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 2.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Cache of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Cache;
    Rows.Add(FMars_AnchorTable_Row(UMars_Sandbox_Tenderizer_EntityScript, 2.0f, EMars_Anchor_Role::Active));
    Rows.Add(FMars_AnchorTable_Row(UMars_Sandbox_Cleaver_EntityScript, 1.0f, EMars_Anchor_Role::Active));
    Rows.Add(FMars_AnchorTable_Row(UMars_WorldItem_Ration_EntityScript, 1.0f, EMars_Anchor_Role::Active));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 1.0f, EMars_Anchor_Role::Dormant));
}

asset Mars_AnchorTable_Omen of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Omen;
    Rows.Add(FMars_AnchorTable_Row(UMars_EyesDummy_EntityScript, 3.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_OmenLampBank_EntityScript, 2.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 2.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Threat of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Threat;
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_SentryCrawler4_EntityScript, 2.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 3.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Trap of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Trap;
    Rows.Add(FMars_AnchorTable_Row(UMars_SpikeTrap_EntityScript, 3.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(UMars_Vent_EntityScript, 2.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 3.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Rest of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Rest;
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_RestSconce_EntityScript, 3.0f, EMars_Anchor_Role::Other));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 1.0f, EMars_Anchor_Role::Other));
}

asset Mars_AnchorTable_Pack of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Pack;
    Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_PackPlinth_EntityScript, 1.0f, EMars_Anchor_Role::Other));
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

    UMars_AnchorTable_Def Table_Forage()
    { return Mars_AnchorTable_Forage; }

    UMars_AnchorTable_Def Table_Cache()
    { return Mars_AnchorTable_Cache; }

    UMars_AnchorTable_Def Table_Omen()
    { return Mars_AnchorTable_Omen; }

    UMars_AnchorTable_Def Table_Threat()
    { return Mars_AnchorTable_Threat; }

    UMars_AnchorTable_Def Table_Trap()
    { return Mars_AnchorTable_Trap; }

    UMars_AnchorTable_Def Table_Rest()
    { return Mars_AnchorTable_Rest; }

    UMars_AnchorTable_Def Table_Pack()
    { return Mars_AnchorTable_Pack; }

    // The pocket families in the order the greybox builder names them (F, C, O, T, X, N, P).
    TArray<UMars_AnchorTable_Def> Get_PocketTables()
    {
        auto Tables = TArray<UMars_AnchorTable_Def>();
        Tables.Add(Mars_AnchorTable_Forage);
        Tables.Add(Mars_AnchorTable_Cache);
        Tables.Add(Mars_AnchorTable_Omen);
        Tables.Add(Mars_AnchorTable_Threat);
        Tables.Add(Mars_AnchorTable_Trap);
        Tables.Add(Mars_AnchorTable_Rest);
        Tables.Add(Mars_AnchorTable_Pack);
        return Tables;
    }
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

    // Route anchors only: the side of the one lever (along the street, a -> b) and the crawl gap beside the gate as a
    // lateral offset in cm; set by the greybox builder from the plan data.
    UPROPERTY(ExposeOnSpawn)
    EMars_Anchor_LeverSide LeverSide = EMars_Anchor_LeverSide::None;

    UPROPERTY(ExposeOnSpawn)
    bool HasCrawl = false;

    // The crawl's centreline point nearest the gate, in the gate's local frame: along the street, then across it.
    UPROPERTY(ExposeOnSpawn)
    float32 CrawlAlongCm = 0.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 CrawlOffsetCm = 0.0f;

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
        Spec.LeverSide = LeverSide;
        if (HasCrawl)
        { Spec.CrawlOffsetCm = TOptional<FVector2D>(FVector2D(CrawlAlongCm, CrawlOffsetCm)); }
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

// The pocket placeables. The anchor stands at the pocket's centre facing its mouth (+X); SpanCm is the pocket's depth
// along that axis (wall-mounted candidates use it to find the back wall).
class UMars_Anchor_Forage_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Forage; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Forage(); }
}

class UMars_Anchor_Cache_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Cache; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Cache(); }
}

class UMars_Anchor_Omen_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Omen; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Omen(); }
}

class UMars_Anchor_Threat_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;
    default HomeRadiusCm = 600.0f;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Threat; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Threat(); }
}

class UMars_Anchor_Trap_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Trap; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Trap(); }
}

class UMars_Anchor_Rest_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Rest; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Rest(); }
}

class UMars_Anchor_Pack_EntityScript : UMars_Anchor_EntityScript
{
    default _ShowInPlaceActors = true;

    protected EMars_Anchor_Family Get_Family() const override
    { return EMars_Anchor_Family::Pack; }

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Pack(); }
}
