// Named transform nodes a carrier publishes so other features can parent things to it (the held item under the Hand,
// the worn backpack on the Back). The carrier creates the nodes itself - it knows where its own hand and back are -
// and this feature only stores them, keyed by an AttachPoint.* gameplay tag.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_AttachPointsHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_AttachPoints";
    RequiredFragments.Add(FMars_Feature_AttachPoints);
    Description = "A carrier that publishes named transform attach points (hand, back) by gameplay tag for items to mount to";
}
struct FMars_Feature_AttachPoints {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_AttachPoint_Entry
{
    UPROPERTY()
    FGameplayTag Tag;

    UPROPERTY()
    FCk_Handle_Transform Node;

    FMars_AttachPoint_Entry() {}

    FMars_AttachPoint_Entry(FGameplayTag InTag, const FCk_Handle_Transform& InNode)
    {
        Tag = InTag;
        Node = InNode;
    }
}

struct FMars_AttachPoints_Spec
{
    UPROPERTY()
    TArray<FMars_AttachPoint_Entry> Points;
}

// All-or-nothing: at least one entry, every tag and node valid, no tag twice. Reports the first failing rule.
mixin FMars_Validation Validate(const FMars_AttachPoints_Spec& Self)
{
    if (Self.Points.Num() == 0)
    { return FMars_Validation("no entries"); }

    for (int32 Index = 0; Index < Self.Points.Num(); ++Index)
    {
        const auto& Entry = Self.Points[Index];
        if (Entry.Tag.IsValid() == false)
        { return FMars_Validation(f"entry [{Index}] has no tag"); }

        if (ck::Is_NOT_Valid(Entry.Node))
        { return FMars_Validation(f"entry [{Index}] [{Entry.Tag.ToString()}] has an invalid node"); }

        for (int32 Earlier = 0; Earlier < Index; ++Earlier)
        {
            if (Self.Points[Earlier].Tag == Entry.Tag)
            { return FMars_Validation(f"entry [{Index}] repeats the tag [{Entry.Tag.ToString()}] of entry [{Earlier}]"); }
        }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_AttachPoints_Params
{
    UPROPERTY()
    TArray<FMars_AttachPoint_Entry> Points;
}
