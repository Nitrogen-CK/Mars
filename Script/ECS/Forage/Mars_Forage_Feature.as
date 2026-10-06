//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ForageHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Forage";
    RequiredFragments.Add(FMars_Feature_Forage);
    Description = "A world source of an ingredient item: charges released on request, then exhausted, regrown or destroyed";
}
struct FMars_Feature_Forage {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What a source does once its last charge is released.
enum EMars_Forage_Exhaustion
{
    // Stays empty.
    Persists,
    // Replenishes after RegrowSeconds.
    Regrows,
    // Removes itself: a World-mode host's item is destroyed, any other host entity is destroyed.
    Destroyed
}

// What asked for the release; carried on the request and the OnReleased signal for logs and tests.
enum EMars_Forage_ReleaseReason
{
    Hit,
    Depleted,
    Knock,
    Plucked
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Forage_YieldSpec
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    int32 Charges = 1;

    FMars_Forage_YieldSpec() {}

    FMars_Forage_YieldSpec(TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, int32 InCharges)
    {
        Definition = InDefinition;
        Charges = InCharges;
    }
}

struct FMars_Forage_ExhaustionSpec
{
    UPROPERTY()
    EMars_Forage_Exhaustion Policy = EMars_Forage_Exhaustion::Persists;

    // Regrows only.
    UPROPERTY()
    float32 RegrowSeconds = 0.0f;

    FMars_Forage_ExhaustionSpec() {}

    FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion InPolicy)
    {
        Policy = InPolicy;
    }

    FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion InPolicy, float32 InRegrowSeconds)
    {
        Policy = InPolicy;
        RegrowSeconds = InRegrowSeconds;
    }
}

// In the release point's frame; rotated into world at release.
struct FMars_Forage_LaunchSpec
{
    UPROPERTY()
    FVector LinearVelocity = FVector(0.0, 0.0, -50.0);

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_Forage_LaunchSpec() {}

    FMars_Forage_LaunchSpec(FVector InLinearVelocity)
    {
        LinearVelocity = InLinearVelocity;
    }

    FMars_Forage_LaunchSpec(FVector InLinearVelocity, FVector InAngularVelocityDeg)
    {
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

// Built by the entity script before Add. Not UPROPERTYs: spawn params never carry handles.
struct FMars_Forage_Parts
{
    // Where the yield spawns, oriented as the launch's frame.
    FCk_Handle_Transform ReleasePoint;

    FMars_Forage_Parts() {}

    FMars_Forage_Parts(FCk_Handle_Transform InReleasePoint)
    {
        ReleasePoint = InReleasePoint;
    }
}

struct FMars_Forage_Spec
{
    UPROPERTY()
    FMars_Forage_YieldSpec Yield;

    UPROPERTY()
    FMars_Forage_ExhaustionSpec Exhaustion;

    UPROPERTY()
    FMars_Forage_LaunchSpec Launch;

    FMars_Forage_Parts Parts;
}

mixin FMars_Validation Validate(const FMars_Forage_Spec& Self)
{
    if (Self.Yield.Definition.IsNull())
    { return FMars_Validation("Forage has no Yield.Definition"); }

    if (Self.Yield.Charges < 1)
    { return FMars_Validation(f"Forage has Yield.Charges [{Self.Yield.Charges}] below 1"); }

    if (Self.Exhaustion.Policy == EMars_Forage_Exhaustion::Regrows && Self.Exhaustion.RegrowSeconds <= 0.0f)
    { return FMars_Validation(f"Forage regrows with a non-positive Exhaustion.RegrowSeconds [{Self.Exhaustion.RegrowSeconds}]"); }

    if (ck::Is_NOT_Valid(Self.Parts.ReleasePoint))
    { return FMars_Validation("Forage has no Parts.ReleasePoint: the yield has nowhere to spawn"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Forage_Params
{
    UPROPERTY()
    FMars_Forage_YieldSpec Yield;

    UPROPERTY()
    FMars_Forage_ExhaustionSpec Exhaustion;

    UPROPERTY()
    FMars_Forage_LaunchSpec Launch;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Forage processors (and composed by Add).
struct FMars_Fragment_Forage
{
    UPROPERTY()
    FCk_Handle_Transform ReleasePoint;

    UPROPERTY()
    int32 ChargesLeft = 0;

    UPROPERTY()
    bool IsExhausted = false;

    UPROPERTY()
    int32 ReleasedCount = 0;

    // Valid while a regrow is pending.
    UPROPERTY()
    FCk_Handle_Timer RegrowTimer;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// InWorldItem is the released world item's entity under construction (seeded a frame or more later).
delegate void FMars_Delegate_Forage_OnReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason);
event void FMars_Delegate_Forage_OnReleased_MC(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason);

delegate void FMars_Delegate_Forage_OnExhausted(FCk_Handle_Forage InForage);
event void FMars_Delegate_Forage_OnExhausted_MC(FCk_Handle_Forage InForage);

delegate void FMars_Delegate_Forage_OnReplenished(FCk_Handle_Forage InForage);
event void FMars_Delegate_Forage_OnReplenished_MC(FCk_Handle_Forage InForage);

struct FMars_Fragment_Forage_Signals
{
    FMars_Delegate_Forage_OnReleased_MC OnReleased;
    FMars_Delegate_Forage_OnExhausted_MC OnExhausted;
    FMars_Delegate_Forage_OnReplenished_MC OnReplenished;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Dropped (with a trace) while the source is exhausted, so a trigger adapter never needs to guard.
struct FMars_Request_Forage_Release
{
    UPROPERTY()
    EMars_Forage_ReleaseReason Reason = EMars_Forage_ReleaseReason::Hit;

    FMars_Request_Forage_Release() {}

    FMars_Request_Forage_Release(EMars_Forage_ReleaseReason InReason)
    {
        Reason = InReason;
    }
}

// Refills the charges and cancels a pending regrow.
struct FMars_Request_Forage_Replenish
{
    // AngelScript rejects a TArray of an empty struct.
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Forage_Replenish() {}
}

// Drained Replenish -> Release (see UMars_Processor_Forage_HandleRequests).
struct FMars_Fragment_Forage_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Forage_Replenish> ReplenishRequests;

    UPROPERTY()
    TArray<FMars_Request_Forage_Release> ReleaseRequests;
}
