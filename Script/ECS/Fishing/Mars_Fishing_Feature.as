//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FishingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Fishing";
    RequiredFragments.Add(FMars_Feature_Fishing);
    Description = "A fishing spot: a bait cast onto the water, a bite to hook inside a window, a line reeled in against tension, a fish landed";
}
struct FMars_Feature_Fishing {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Where the line is. Idle: no line out. Casting: the bait is in the air. Waiting: the bait floats, a bite is due. Bite: a
// fish has the bait and the hook window is open. Hooked: the hook is setting. Reeling: the fish fights the reel. Landed: the
// fish is out of the water, flung toward the catch point, waiting to be collected. Snapped: the line broke.
enum EMars_Fishing_Phase
{
    Idle,
    Casting,
    Waiting,
    Bite,
    Hooked,
    Reeling,
    Landed,
    Snapped
}

// The spot's own life: fish are arriving, here, moving on, or gone. A cast is accepted only while Open.
enum EMars_Fishing_Presence
{
    Arriving,
    Open,
    Leaving,
    Gone
}

enum EMars_Fishing_Reel
{
    Released,
    Held
}

// How a bite ended: hooked inside the window, or the window closed on it.
enum EMars_Fishing_BiteResult
{
    Hooked,
    Missed
}

// The cast: a power 0..1 picks a distance between MinDistanceCm and MaxDistanceCm along the aim, launched at LaunchPitchDeg
// (plus the aim's pitch) so the bait lands exactly there on the water. The aim is clamped to YawHalfAngleDeg each side of
// the frame's facing and PitchRangeDeg each side of the launch pitch.
struct FMars_Fishing_CastSpec
{
    UPROPERTY()
    float32 MaxDistanceCm = 900.0f;

    UPROPERTY()
    float32 MinDistanceCm = 150.0f;

    UPROPERTY()
    float32 LaunchPitchDeg = 35.0f;

    UPROPERTY()
    float32 GravityCmPerS2 = 980.0f;

    UPROPERTY()
    float32 YawHalfAngleDeg = 45.0f;

    UPROPERTY()
    float32 PitchRangeDeg = 20.0f;
}

// A bite comes MinWaitSeconds..MaxWaitSeconds after the bait lands (MissPenaltySeconds more after a missed one), dips the
// bait DipCm, and holds for HookWindowSeconds.
struct FMars_Fishing_BiteSpec
{
    UPROPERTY()
    float32 MinWaitSeconds = 3.0f;

    UPROPERTY()
    float32 MaxWaitSeconds = 9.0f;

    UPROPERTY()
    float32 HookWindowSeconds = 0.6f;

    UPROPERTY()
    float32 MissPenaltySeconds = 2.0f;

    UPROPERTY()
    float32 DipCm = 6.0f;
}

// The fight. Holding the reel shortens the line by ReelSpeedCmPerS and raises the tension by TensionGainPerS (by
// RunTensionGainPerS while the fish runs); a released reel lets the tension recover by RecoveryPerS. Tension at SnapTension
// breaks the line. A hook sets over HookSetSeconds starting at HookTension.
struct FMars_Fishing_ReelSpec
{
    UPROPERTY()
    float32 ReelSpeedCmPerS = 180.0f;

    UPROPERTY()
    float32 TensionGainPerS = 0.25f;

    UPROPERTY()
    float32 RunTensionGainPerS = 0.9f;

    UPROPERTY()
    float32 RecoveryPerS = 0.5f;

    UPROPERTY()
    float32 SnapTension = 1.0f;

    UPROPERTY()
    float32 HookSetSeconds = 0.25f;

    UPROPERTY()
    float32 HookTension = 0.3f;
}

// The fish runs: MinGapSeconds..MaxGapSeconds of calm, then MinRunSeconds..MaxRunSeconds of pulling PullCmPerS of line
// back out (scaled by the fish's Fight).
struct FMars_Fishing_RunSpec
{
    UPROPERTY()
    float32 MinGapSeconds = 1.5f;

    UPROPERTY()
    float32 MaxGapSeconds = 3.5f;

    UPROPERTY()
    float32 MinRunSeconds = 0.6f;

    UPROPERTY()
    float32 MaxRunSeconds = 1.4f;

    UPROPERTY()
    float32 PullCmPerS = 120.0f;
}

// One fish the spot can give: the item it lands as, its draw weight in the table, and how hard it pulls.
struct FMars_Fishing_FishEntry
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Item;

    UPROPERTY()
    float32 Weight = 1.0f;

    UPROPERTY()
    float32 Fight = 1.0f;

    FMars_Fishing_FishEntry() {}

    FMars_Fishing_FishEntry(TSoftObjectPtr<UCk_InventoryItem_Definition> InItem, float32 InWeight, float32 InFight)
    {
        Item = InItem;
        Weight = InWeight;
        Fight = InFight;
    }
}

// The catch table and the landing: a landed fish flies from the water to the catch point over LandFlingSeconds, peaking
// LandArcHeightCm above the straight line.
struct FMars_Fishing_FishSpec
{
    UPROPERTY()
    TArray<FMars_Fishing_FishEntry> Table;

    UPROPERTY()
    float32 LandFlingSeconds = 0.6f;

    UPROPERTY()
    float32 LandArcHeightCm = 120.0f;
}

// The water the bait lands on: a world Z plane, with the floating bait's bob.
struct FMars_Fishing_WaterSpec
{
    UPROPERTY()
    float64 SurfaceZ = 0.0;

    UPROPERTY()
    float32 BobHz = 0.8f;

    UPROPERTY()
    float32 BobAmpCm = 1.5f;
}

// The spot's arrival and departure fades, and whether it starts Open or fades in.
struct FMars_Fishing_PresenceSpec
{
    UPROPERTY()
    float32 ArriveSeconds = 1.5f;

    UPROPERTY()
    float32 LeaveSeconds = 1.5f;

    UPROPERTY()
    bool StartOpen = true;
}

// Construction handles the caller builds (the station's own nodes), as the C++ specs carry handles. Not UPROPERTYs: the
// spawn params never carry handles. Frame: the aim's frame (its X is yaw 0). Anchor: the cast origin and the line's start
// (the rod tip). Catch: where a landed fish arrives.
struct FMars_Fishing_Setup
{
    FCk_Handle_Transform Frame;
    FCk_Handle_Transform Anchor;
    FCk_Handle_Transform Catch;
}

// Every clock is the kernel's: the bait's flight, the bite wait and window, the hook set, the runs, the tension, the
// landing fling and the presence fades. Whatever draws the rod, the line, the bait and the fish follows its state and
// signals.
struct FMars_Fishing_Spec
{
    UPROPERTY()
    FMars_Fishing_CastSpec Launch;

    UPROPERTY()
    FMars_Fishing_BiteSpec Bite;

    UPROPERTY()
    FMars_Fishing_ReelSpec Reel;

    UPROPERTY()
    FMars_Fishing_RunSpec Run;

    UPROPERTY()
    FMars_Fishing_FishSpec Fish;

    UPROPERTY()
    FMars_Fishing_WaterSpec Water;

    UPROPERTY()
    FMars_Fishing_PresenceSpec Presence;

    // Seeds the bite waits, the runs and the catch draws, so a spot replays headless.
    UPROPERTY()
    int32 Seed = 1;

    FMars_Fishing_Setup Setup;
}

mixin FMars_Validation Validate(const FMars_Fishing_Spec& Self)
{
    const auto Launch = Self.Launch;
    if (utils_fishing::Get_IsPositiveFinite(Launch.MaxDistanceCm) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Launch.MaxDistanceCm [{Launch.MaxDistanceCm}]"); }

    if (Math::IsFinite(Launch.MinDistanceCm) == false || Launch.MinDistanceCm < 0.0f || Launch.MinDistanceCm > Launch.MaxDistanceCm)
    { return FMars_Validation(f"Fishing has Launch.MinDistanceCm [{Launch.MinDistanceCm}] outside [0, MaxDistanceCm]"); }

    if (Math::IsFinite(Launch.LaunchPitchDeg) == false || Launch.LaunchPitchDeg <= 0.0f || Launch.LaunchPitchDeg >= 90.0f)
    { return FMars_Validation(f"Fishing has Launch.LaunchPitchDeg [{Launch.LaunchPitchDeg}] outside (0, 90)"); }

    if (utils_fishing::Get_IsPositiveFinite(Launch.GravityCmPerS2) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Launch.GravityCmPerS2 [{Launch.GravityCmPerS2}]"); }

    if (Math::IsFinite(Launch.YawHalfAngleDeg) == false || Launch.YawHalfAngleDeg <= 0.0f || Launch.YawHalfAngleDeg > 180.0f)
    { return FMars_Validation(f"Fishing has Launch.YawHalfAngleDeg [{Launch.YawHalfAngleDeg}] outside (0, 180]"); }

    if (Math::IsFinite(Launch.PitchRangeDeg) == false || Launch.PitchRangeDeg < 0.0f
        || Launch.LaunchPitchDeg - Launch.PitchRangeDeg <= 0.0f || Launch.LaunchPitchDeg + Launch.PitchRangeDeg >= 90.0f)
    { return FMars_Validation(f"Fishing has Launch.PitchRangeDeg [{Launch.PitchRangeDeg}] that takes the pitch outside (0, 90)"); }

    const auto Bite = Self.Bite;
    if (Math::IsFinite(Bite.MinWaitSeconds) == false || Bite.MinWaitSeconds < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Bite.MinWaitSeconds [{Bite.MinWaitSeconds}]"); }

    if (Math::IsFinite(Bite.MaxWaitSeconds) == false || Bite.MaxWaitSeconds < Bite.MinWaitSeconds)
    { return FMars_Validation(f"Fishing has Bite.MaxWaitSeconds [{Bite.MaxWaitSeconds}] below MinWaitSeconds or non-finite"); }

    if (utils_fishing::Get_IsPositiveFinite(Bite.HookWindowSeconds) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Bite.HookWindowSeconds [{Bite.HookWindowSeconds}]"); }

    if (Math::IsFinite(Bite.MissPenaltySeconds) == false || Bite.MissPenaltySeconds < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Bite.MissPenaltySeconds [{Bite.MissPenaltySeconds}]"); }

    if (Math::IsFinite(Bite.DipCm) == false || Bite.DipCm < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Bite.DipCm [{Bite.DipCm}]"); }

    const auto Reel = Self.Reel;
    if (utils_fishing::Get_IsPositiveFinite(Reel.ReelSpeedCmPerS) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Reel.ReelSpeedCmPerS [{Reel.ReelSpeedCmPerS}]"); }

    if (Math::IsFinite(Reel.TensionGainPerS) == false || Reel.TensionGainPerS < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Reel.TensionGainPerS [{Reel.TensionGainPerS}]"); }

    if (Math::IsFinite(Reel.RunTensionGainPerS) == false || Reel.RunTensionGainPerS < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Reel.RunTensionGainPerS [{Reel.RunTensionGainPerS}]"); }

    if (Math::IsFinite(Reel.RecoveryPerS) == false || Reel.RecoveryPerS < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Reel.RecoveryPerS [{Reel.RecoveryPerS}]"); }

    if (utils_fishing::Get_IsPositiveFinite(Reel.SnapTension) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Reel.SnapTension [{Reel.SnapTension}]"); }

    if (Math::IsFinite(Reel.HookTension) == false || Reel.HookTension < 0.0f || Reel.HookTension >= Reel.SnapTension)
    { return FMars_Validation(f"Fishing has Reel.HookTension [{Reel.HookTension}] outside [0, SnapTension)"); }

    if (Math::IsFinite(Reel.HookSetSeconds) == false || Reel.HookSetSeconds < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Reel.HookSetSeconds [{Reel.HookSetSeconds}]"); }

    const auto Run = Self.Run;
    if (Math::IsFinite(Run.MinGapSeconds) == false || Run.MinGapSeconds < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Run.MinGapSeconds [{Run.MinGapSeconds}]"); }

    if (Math::IsFinite(Run.MaxGapSeconds) == false || Run.MaxGapSeconds < Run.MinGapSeconds)
    { return FMars_Validation(f"Fishing has Run.MaxGapSeconds [{Run.MaxGapSeconds}] below MinGapSeconds or non-finite"); }

    if (Math::IsFinite(Run.MinRunSeconds) == false || Run.MinRunSeconds < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Run.MinRunSeconds [{Run.MinRunSeconds}]"); }

    if (Math::IsFinite(Run.MaxRunSeconds) == false || Run.MaxRunSeconds < Run.MinRunSeconds)
    { return FMars_Validation(f"Fishing has Run.MaxRunSeconds [{Run.MaxRunSeconds}] below MinRunSeconds or non-finite"); }

    if (Math::IsFinite(Run.PullCmPerS) == false || Run.PullCmPerS < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Run.PullCmPerS [{Run.PullCmPerS}]"); }

    const auto Fish = Self.Fish;
    if (Fish.Table.Num() == 0)
    { return FMars_Validation("Fishing has an empty Fish.Table"); }

    for (int32 Index = 0; Index < Fish.Table.Num(); ++Index)
    {
        const auto Entry = Fish.Table[Index];
        if (Entry.Item.IsNull())
        { return FMars_Validation(f"Fishing has no Item on Fish.Table[{Index}]"); }

        if (utils_fishing::Get_IsPositiveFinite(Entry.Weight) == false)
        { return FMars_Validation(f"Fishing has a non-positive or non-finite Weight on Fish.Table[{Index}] [{Entry.Weight}]"); }

        if (Math::IsFinite(Entry.Fight) == false || Entry.Fight < 0.0f)
        { return FMars_Validation(f"Fishing has a negative or non-finite Fight on Fish.Table[{Index}] [{Entry.Fight}]"); }
    }

    if (utils_fishing::Get_IsPositiveFinite(Fish.LandFlingSeconds) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Fish.LandFlingSeconds [{Fish.LandFlingSeconds}]"); }

    if (Math::IsFinite(Fish.LandArcHeightCm) == false || Fish.LandArcHeightCm < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Fish.LandArcHeightCm [{Fish.LandArcHeightCm}]"); }

    const auto Water = Self.Water;
    if (Math::IsFinite(Water.SurfaceZ) == false)
    { return FMars_Validation(f"Fishing has a non-finite Water.SurfaceZ [{Water.SurfaceZ}]"); }

    if (Math::IsFinite(Water.BobHz) == false || Water.BobHz < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Water.BobHz [{Water.BobHz}]"); }

    if (Math::IsFinite(Water.BobAmpCm) == false || Water.BobAmpCm < 0.0f)
    { return FMars_Validation(f"Fishing has a negative or non-finite Water.BobAmpCm [{Water.BobAmpCm}]"); }

    const auto Presence = Self.Presence;
    if (utils_fishing::Get_IsPositiveFinite(Presence.ArriveSeconds) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Presence.ArriveSeconds [{Presence.ArriveSeconds}]"); }

    if (utils_fishing::Get_IsPositiveFinite(Presence.LeaveSeconds) == false)
    { return FMars_Validation(f"Fishing has a non-positive or non-finite Presence.LeaveSeconds [{Presence.LeaveSeconds}]"); }

    if (ck::Is_NOT_Valid(Self.Setup.Frame))
    { return FMars_Validation("Fishing has no Setup.Frame"); }

    if (ck::Is_NOT_Valid(Self.Setup.Anchor))
    { return FMars_Validation("Fishing has no Setup.Anchor"); }

    if (ck::Is_NOT_Valid(Self.Setup.Catch))
    { return FMars_Validation("Fishing has no Setup.Catch"); }

    return FMars_Validation();
}

// On the Fishing entity while an operator works the spot: the cast, bite, hook, reel and landing clocks run only then.
struct FMars_Tag_Fishing_Engaged {}

// On the Fishing entity while the spot fades in or out: the one clock that runs with no operator.
struct FMars_Tag_Fishing_Transitioning {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Fishing_Params
{
    UPROPERTY()
    FMars_Fishing_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The aim in the frame: yaw each side of the frame's X, pitch above the launch pitch. Both clamped by the Cast spec.
struct FMars_Fishing_Aim
{
    UPROPERTY()
    float32 YawDeg = 0.0f;

    UPROPERTY()
    float32 PitchDeg = 0.0f;
}

// The bait, in world space, as the kernel places it: in flight while Casting, on the surface after. The bob and the dip are
// applied by Get_BaitWorld, not stored in Position.
struct FMars_Fishing_Bait
{
    UPROPERTY()
    FVector Position;

    UPROPERTY()
    FVector Velocity;

    // Radians of the float's bob, running while the bait is on the water.
    UPROPERTY()
    float32 BobPhase = 0.0f;

    // How far the bait is pulled under during a bite; 0 otherwise.
    UPROPERTY()
    float32 DipCm = 0.0f;
}

// The line: how much is still out (0 lands the fish) and how hard it is strained (SnapTension breaks it).
struct FMars_Fishing_Line
{
    UPROPERTY()
    float32 LengthCm = 0.0f;

    UPROPERTY()
    float32 Tension = 0.0f;
}

// The phase clocks. PhaseSeconds restarts at every phase change.
struct FMars_Fishing_Clock
{
    UPROPERTY()
    float32 PhaseSeconds = 0.0f;

    // Waiting: the phase second the bite comes at.
    UPROPERTY()
    float32 BiteAtSeconds = 0.0f;

    // Bite: seconds left to hook.
    UPROPERTY()
    float32 WindowLeft = 0.0f;

    // Hooked: seconds left before the reel takes over.
    UPROPERTY()
    float32 HookSetLeft = 0.0f;

    // Arriving / Leaving: seconds left in the fade.
    UPROPERTY()
    float32 PresenceLeft = 0.0f;
}

// The fish's runs while Reeling.
struct FMars_Fishing_Run
{
    UPROPERTY()
    bool Running = false;

    // Running: seconds left in the run. Calm: seconds until the next one.
    UPROPERTY()
    float32 SecondsLeft = 0.0f;
}

// The fish on the line (drawn at the hook) and, once Landed, the catch: where it left the water and its fling.
struct FMars_Fishing_Catch
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Item;

    UPROPERTY()
    float32 Fight = 1.0f;

    UPROPERTY()
    FVector LandedAt;

    // Seconds left of the fling from LandedAt to the catch point; 0 once it has arrived.
    UPROPERTY()
    float32 FlingLeft = 0.0f;
}

// Written only by the Fishing processors (and Add). The station SM and the operator only issue requests.
struct FMars_Fragment_Fishing
{
    UPROPERTY()
    EMars_Fishing_Phase Phase = EMars_Fishing_Phase::Idle;

    UPROPERTY()
    EMars_Fishing_Presence Presence = EMars_Fishing_Presence::Open;

    UPROPERTY()
    EMars_Fishing_Reel Reel = EMars_Fishing_Reel::Released;

    UPROPERTY()
    FMars_Fishing_Aim Aim;

    UPROPERTY()
    FMars_Fishing_Bait Bait;

    UPROPERTY()
    FMars_Fishing_Line Line;

    UPROPERTY()
    FMars_Fishing_Clock Clock;

    UPROPERTY()
    FMars_Fishing_Run Run;

    UPROPERTY()
    FMars_Fishing_Catch Catch;

    // The xorshift state behind every draw (never 0).
    UPROPERTY()
    uint32 Rng = 1;

    // Fish collected since the spot was made.
    UPROPERTY()
    int32 Tally = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Broadcast on every phase change, after the phase's own signal.
delegate void FMars_Delegate_Fishing_OnPhaseChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase);
event void FMars_Delegate_Fishing_OnPhaseChanged_MC(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase);

delegate void FMars_Delegate_Fishing_OnPresenceChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Presence InPresence);
event void FMars_Delegate_Fishing_OnPresenceChanged_MC(FCk_Handle_Fishing InFishing, EMars_Fishing_Presence InPresence);

// The bait leaves the anchor with this world velocity.
delegate void FMars_Delegate_Fishing_OnCast(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity);
event void FMars_Delegate_Fishing_OnCast_MC(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity);

// The bait hits the water here.
delegate void FMars_Delegate_Fishing_OnBaitLanded(FCk_Handle_Fishing InFishing, FVector InPoint);
event void FMars_Delegate_Fishing_OnBaitLanded_MC(FCk_Handle_Fishing InFishing, FVector InPoint);

delegate void FMars_Delegate_Fishing_OnBite(FCk_Handle_Fishing InFishing);
event void FMars_Delegate_Fishing_OnBite_MC(FCk_Handle_Fishing InFishing);

delegate void FMars_Delegate_Fishing_OnBiteEnded(FCk_Handle_Fishing InFishing, EMars_Fishing_BiteResult InResult);
event void FMars_Delegate_Fishing_OnBiteEnded_MC(FCk_Handle_Fishing InFishing, EMars_Fishing_BiteResult InResult);

// A run starts (true) or ends (false).
delegate void FMars_Delegate_Fishing_OnRun(FCk_Handle_Fishing InFishing, bool InStarted);
event void FMars_Delegate_Fishing_OnRun_MC(FCk_Handle_Fishing InFishing, bool InStarted);

delegate void FMars_Delegate_Fishing_OnSnapped(FCk_Handle_Fishing InFishing);
event void FMars_Delegate_Fishing_OnSnapped_MC(FCk_Handle_Fishing InFishing);

// The fish leaves the water: the catch, with where it left and the fling ahead.
delegate void FMars_Delegate_Fishing_OnLanded(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch);
event void FMars_Delegate_Fishing_OnLanded_MC(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch);

delegate void FMars_Delegate_Fishing_OnCollected(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch);
event void FMars_Delegate_Fishing_OnCollected_MC(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch);

struct FMars_Fragment_Fishing_Signals
{
    FMars_Delegate_Fishing_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_Fishing_OnPresenceChanged_MC OnPresenceChanged;
    FMars_Delegate_Fishing_OnCast_MC OnCast;
    FMars_Delegate_Fishing_OnBaitLanded_MC OnBaitLanded;
    FMars_Delegate_Fishing_OnBite_MC OnBite;
    FMars_Delegate_Fishing_OnBiteEnded_MC OnBiteEnded;
    FMars_Delegate_Fishing_OnRun_MC OnRun;
    FMars_Delegate_Fishing_OnSnapped_MC OnSnapped;
    FMars_Delegate_Fishing_OnLanded_MC OnLanded;
    FMars_Delegate_Fishing_OnCollected_MC OnCollected;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// An operator takes the spot: the clocks run. Payload-less: one placeholder field (request doctrine), as every
// payload-less request here.
struct FMars_Request_Fishing_Engage
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Engage() {}
}

// The operator leaves: the line comes in (a fish on it is lost, an uncollected catch is dropped) and the clocks stop.
struct FMars_Request_Fishing_Disengage
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Disengage() {}
}

// The fish move on: the spot fades out over Presence.LeaveSeconds and takes no more casts. Ignored once Leaving or Gone.
struct FMars_Request_Fishing_Leave
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Leave() {}
}

// Back to Idle from any phase (a snapped line is re-rigged, a line out is pulled in, an uncollected catch is dropped).
struct FMars_Request_Fishing_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Reset() {}
}

// Cheats and tests: a bite now, while Waiting.
struct FMars_Request_Fishing_ForceBite
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_ForceBite() {}
}

// Cheats and tests: the line runs out now, while Reeling (the Tick lands the fish).
struct FMars_Request_Fishing_ForceLand
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_ForceLand() {}
}

// The aim, clamped by the Cast spec. The last one in a drain wins.
struct FMars_Request_Fishing_Aim
{
    UPROPERTY()
    float32 YawDeg = 0.0f;

    UPROPERTY()
    float32 PitchDeg = 0.0f;

    FMars_Request_Fishing_Aim() {}

    FMars_Request_Fishing_Aim(float32 InYawDeg, float32 InPitchDeg)
    {
        YawDeg = InYawDeg;
        PitchDeg = InPitchDeg;
    }
}

// The bait is cast along the aim with Power 0..1 of the distance range. Accepted only Idle, engaged and Open. The last one
// in a drain wins.
struct FMars_Request_Fishing_Cast
{
    UPROPERTY()
    float32 Power = 1.0f;

    FMars_Request_Fishing_Cast() {}

    FMars_Request_Fishing_Cast(float32 InPower)
    {
        Power = InPower;
    }
}

// The hook is struck: inside a Bite it sets; otherwise ignored.
struct FMars_Request_Fishing_Hook
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Hook() {}
}

struct FMars_Request_Fishing_ReelHold
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_ReelHold() {}
}

struct FMars_Request_Fishing_ReelRelease
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_ReelRelease() {}
}

// A Landed catch is taken (the tally counts it) and the spot is Idle again. Ignored otherwise.
struct FMars_Request_Fishing_Collect
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Fishing_Collect() {}
}

// Applied Disengage -> Engage -> Leave -> Reset -> ForceBite -> ForceLand -> Aim -> Cast -> Hook -> ReelRelease ->
// ReelHold -> Collect, so a leave and the next operator's take, or a release and a fresh hold between two polls, share a
// drain.
struct FMars_Fragment_Fishing_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Fishing_Disengage> DisengageRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Engage> EngageRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Leave> LeaveRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_ForceBite> ForceBiteRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_ForceLand> ForceLandRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Aim> AimRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Cast> CastRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Hook> HookRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_ReelRelease> ReelReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_ReelHold> ReelHoldRequests;

    UPROPERTY()
    TArray<FMars_Request_Fishing_Collect> CollectRequests;
}
