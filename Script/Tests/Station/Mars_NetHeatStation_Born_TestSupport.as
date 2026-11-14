// A harness fixture for the heat stations' net tests: each class is the real station whose authority, as it composes,
// issues its kernel's real requests, applied by the kernel's own drain in the spawn frame, so a copy is born into what
// that drain wrote. Every machine's copy carries the test tag TAG_MarsTestNetBornHeatStation from its construct, so the
// heat rig watches it whatever its docks.

// A copy is born into a dipped bowl holding the loose food beside it, one admission refused Duplicate (the same food
// released twice) and one take-out refused (it names no tray).
class UMars_TESTONLY_NetBatterStation_Born_EntityScript : UMars_BatterStation_EntityScript
{
    private const float64 k_FoodReachCm = 500.0;

    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Super::Compose_AfterKernel(InHandle);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetBornHeatStation");
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        const auto Food = Find_FoodBeside(InHandle);
        if (ck::EnsureIfNot(ck::IsValid(Food), f"[BatterNetTest] [{InHandle.ToString()}] found no loose food beside it"))
        { return; }

        // One drain applies them: the take-out first (an empty bowl hands none back), then the first release is adopted
        // and the second refused, then the dip.
        utils_cooking_feed::Request_StationTakeOut(InHandle, FMars_Request_StationTakeOut(4, FCk_Handle_Platter()));
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(_ReleaseNode);
        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto PieceId = FMars_CookingFeed_PieceId(constants_heat_station_net_autotest::k_RigGeneration + 1, Index);
            auto Release = FMars_CookingFeed_Release(PieceId, ReleaseWorld, FVector::ZeroVector);
            Release.Piece = Food;
            if (ck::EnsureIfNot(utils_cooking_feed::Request_Admit(InHandle, Release),
                f"[BatterNetTest] [{InHandle.ToString()}] did not take release {Index} into its inbox"))
            { return; }
        }

        auto Batter = InHandle.As_Batter();
        Batter.Request_Dip(FMars_Request_Batter_Dip());
    }

    // The live food piece world item within k_FoodReachCm of the spawn location; invalid when there is none.
    private FCk_Handle_FoodPiece Find_FoodBeside(FCk_Handle InContext)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InContext, n"TAG_MarsWorldItem"))
        {
            const auto IsLive = ck::IsValid(Candidate)
                && utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
            if (IsLive == false || Candidate.Is_Transform() == false || Candidate.Is_FoodPiece() == false)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform());
            if (Location.Distance(SpawnTransform.GetLocation()) <= k_FoodReachCm)
            { return Candidate.As_FoodPiece(); }
        }

        return FCk_Handle_FoodPiece();
    }
}

// A copy is born into a hot pan with one take-out refused (it names no tray).
class UMars_TESTONLY_NetSearingStation_Born_EntityScript : UMars_SearingStation_EntityScript
{
    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Super::Compose_AfterKernel(InHandle);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetBornHeatStation");
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto Searing = InHandle.As_Searing();
        Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        utils_cooking_feed::Request_StationTakeOut(InHandle, FMars_Request_StationTakeOut(4, FCk_Handle_Platter()));
    }
}

// A copy is born into a shut tumbler with one take-out refused (it names no tray) and one press refused (nothing is
// hovered before the tick has judged the cursor).
class UMars_TESTONLY_NetTumblerStation_Born_EntityScript : UMars_TumblerStation_EntityScript
{
    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Super::Compose_AfterKernel(InHandle);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetBornHeatStation");
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        utils_cooking_feed::Request_StationTakeOut(InHandle, FMars_Request_StationTakeOut(4, FCk_Handle_Platter()));
        auto Tumbler = InHandle.As_Tumbler();
        Tumbler.Request_Press(FMars_Request_Tumbler_Press());
    }
}
