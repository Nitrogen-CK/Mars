// Stance D: nothing here replicates. Every pass, on every machine, after the hotbar's own sync: the held item follows the
// hotbar's selected slot and its item (both replicated with the hotbar). A change releases the old presentation, presents
// the new item and broadcasts OnHeldItemChanged; an unchanged item only records the (possibly different, empty) selected
// slot.
//
// A Persistent item (one whose item carries FMars_Fragment_Item_PersistentWorldItem) is never respawned: its own World-mode
// world item is a Borrowed presentation, never destroyed here, and it mounts on the hand or back from where its item lives
// (UMars_Processor_WorldItem_Reconcile). Any other item with a Presentation gets a Visual-mode world item under the Hand on
// every machine, spawned at a requested start pose (UMars_Processor_HeldItem_HandleRequests) when one waits. The Hand is
// whatever the carrier publishes (a character's hand mount: first-person on its player's own view, the body's hand on
// every other copy); how the visual is drawn there is the visual's own (Mars_FPHands_View.as walks its parents), and where
// a start pose has no gloves to carry it in, the visual's entity script places it at HeldOffset.
//
// A Persistent item's presentation is its body on every machine once this machine has linked it (the authority where
// the holder seeded or adopted it, a client from the replicated ledger); an Owned visual is spawned only for a Transient
// item. A Persistent item not linked here yet has no presentation (an Owned visual would sit beside its replicated
// body); when its link appears while it is still held, its body is adopted as the presentation and OnHeldItemChanged is
// broadcast with the same item as previous and new (a refresh).
class UMars_Processor_HeldItem_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_HeldItem_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Hotbar_Sync");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HeldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_HeldItem& InState)
    {
        const auto Hotbar = InState.Hotbar;
        const auto NewItem = Hotbar.Get_SelectedItem();
        InState.CurrentInventory = Hotbar.Get_SelectedSlot();

        const auto PrevItem = InState.CurrentItem;
        if (NewItem == PrevItem && Get_AdoptsLinkedBody(InState, NewItem) == false)
        { return; }

        auto Self = InHandle.As_HeldItem();
        Release_Presentation(InState);
        InState.CurrentItem = NewItem;
        // A linked body adopted for the same item is not a change.
        if (NewItem != PrevItem)
        { InState.ItemChangeCount += 1; }

        auto Item = NewItem;
        if (ck::IsValid(Item) && Item.Has_PersistentWorldItem())
        {
            // Without authority over the item, a body that is gone (or not resolved yet) means no presentation; it is
            // adopted if it becomes valid while the item is still held.
            const auto WorldItem = Item.Get_PersistentWorldItem();
            if (utils_net::Get_HasAuthority(Item))
            { ck::EnsureIfNot(ck::IsValid(WorldItem), f"[HeldItem] Persistent item [{Item.ToString()}] has lost its world item"); }

            if (ck::IsValid(WorldItem))
            {
                InState.PresentationEntity = WorldItem;
                InState.PresentationOwnership = EMars_HeldItem_PresentationOwnership::Borrowed;
            }
        }
        else if (ck::IsValid(Item) && Item.Has_Presentation() && Get_IsPersistent(Item) == false)
        {
            InState.PresentationEntity = Spawn_Visual(Self, InState, Item);
            InState.PresentationOwnership = EMars_HeldItem_PresentationOwnership::Owned;
        }

        // InState is not read past this line: a listener may add a request fragment to the carrier.
        if (Self.Has_Fragment(FMars_Fragment_HeldItem_Signals))
        { Self.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged.Broadcast(Self, PrevItem, NewItem); }
    }

    // The held item is unchanged, has no presentation yet, and is a Persistent item whose body this machine has since
    // linked: the link arrived after the selection.
    private bool Get_AdoptsLinkedBody(const FMars_Fragment_HeldItem& InState, const FCk_Handle_Item& InItem) const
    {
        if (ck::IsValid(InState.PresentationEntity) || ck::Is_NOT_Valid(InItem) || InItem.Has_PersistentWorldItem() == false)
        { return false; }

        return ck::IsValid(InItem.Get_PersistentWorldItem());
    }

    private bool Get_IsPersistent(const FCk_Handle_Item& InItem) const
    {
        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();
        return Presentation.Mounting.Persistence == EMars_WorldItem_Persistence::Persistent;
    }

    // Owned: destroyed. Borrowed: the world item stays; where it goes is its own reconcile's.
    private void Release_Presentation(FMars_Fragment_HeldItem& InState)
    {
        auto Presentation = InState.PresentationEntity;
        InState.PresentationEntity = FCk_Handle();

        if (ck::IsValid(Presentation) && InState.PresentationOwnership == EMars_HeldItem_PresentationOwnership::Owned)
        { utils_entity_lifetime::Request_DestroyEntity(Presentation); }
    }

    // Two one-shot start poses, exclusive: the gloves' NextSpawnFrom (a pickup riding in; the hold offset then carries
    // that pose) wins over this item's NextArrival (taken from a cargo slot; lerps to HeldOffset). Both are consumed
    // here either way, so neither animates a later spawn.
    private FCk_Handle Spawn_Visual(FCk_Handle_HeldItem& InHeldItem, FMars_Fragment_HeldItem& InState, FCk_Handle_Item& InItem)
    {
        auto Hand = InHeldItem.Get_HandAttachPoint();
        if (ck::EnsureIfNot(ck::IsValid(Hand), f"[HeldItem] [{InHeldItem.ToString()}] has no hand attach point"))
        { return FCk_Handle(); }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        auto Arrival = FMars_WorldItem_Arrival();
        if (InState.NextArrival.IsSet() && InState.NextArrival.GetValue().Item == InItem)
        {
            Arrival = utils_world_item::Get_FreshArrival(InState.NextArrival.GetValue());
            InState.NextArrival.Reset();
        }

        // AttachOffset stays HeldOffset under a start pose: the rest the visual takes where nothing carries it in.
        auto Visual = FMars_WorldItem_VisualSpec(InItem, Hand, Presentation.Mounting.HeldOffset);
        if (InState.NextSpawnFrom.IsSet())
        {
            // Where the item lay: the gloves carry it in from there where they hold the hand; elsewhere the visual's
            // entity script places it at HeldOffset at once.
            Visual.SpawnAtWorld = InState.NextSpawnFrom;
            InState.NextSpawnFrom.Reset();
        }
        else
        { Visual.ArriveFrom = Arrival; }

        FCk_Handle Owner = InHeldItem;
        return utils_world_item::Request_SpawnVisual(Owner, Visual);
    }
}
