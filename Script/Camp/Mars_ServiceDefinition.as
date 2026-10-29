class UMars_ServiceDefinition : UDataAsset
{
    UPROPERTY(EditAnywhere)
    FName Id;

    UPROPERTY(EditAnywhere)
    FText Title;

    UPROPERTY(EditAnywhere)
    FText Summary;

    UPROPERTY(EditAnywhere)
    TSoftObjectPtr<UWorld> Destination;
}

class UMars_ServiceCatalog : UDataAsset
{
    UPROPERTY(EditAnywhere)
    TArray<UMars_ServiceDefinition> Services;

    UMars_ServiceDefinition Find(FName InId) const
    {
        if (InId.IsNone())
        { return nullptr; }

        for (auto Service : Services)
        {
            if (ck::IsValid(Service) && Service.Id == InId)
            { return Service; }
        }
        return nullptr;
    }
}

namespace mars
{
    // Dish orders share the Warrens expedition for now; destination remains data, not a widget branch.
    asset Mars_Service_DillBroth of UMars_ServiceDefinition
    {
        Id = n"DillBroth";
        Title = NSLOCTEXT("MarsCamp", "DillBrothTitle", "Dill broth");
        Summary = NSLOCTEXT("MarsCamp", "DillBrothSummary", "Forage greens in the Warrens.");
        Destination = TSoftObjectPtr<UWorld>(FSoftObjectPath("/Game/Mars/Maps/Warrens_Mars_MAP.Warrens_Mars_MAP"));
    }

    asset Mars_Service_PanSearedRoots of UMars_ServiceDefinition
    {
        Id = n"PanSearedRoots";
        Title = NSLOCTEXT("MarsCamp", "PanSearedRootsTitle", "Pan-seared roots");
        Summary = NSLOCTEXT("MarsCamp", "PanSearedRootsSummary", "Gather roots for the pan.");
        Destination = TSoftObjectPtr<UWorld>(FSoftObjectPath("/Game/Mars/Maps/Warrens_Mars_MAP.Warrens_Mars_MAP"));
    }

    asset Mars_Service_MushroomPie of UMars_ServiceDefinition
    {
        Id = n"MushroomPie";
        Title = NSLOCTEXT("MarsCamp", "MushroomPieTitle", "Mushroom pie");
        Summary = NSLOCTEXT("MarsCamp", "MushroomPieSummary", "Find fungi in the Warrens.");
        Destination = TSoftObjectPtr<UWorld>(FSoftObjectPath("/Game/Mars/Maps/Warrens_Mars_MAP.Warrens_Mars_MAP"));
    }

    asset Mars_Service_ProperDinner of UMars_ServiceDefinition
    {
        Id = n"ProperDinner";
        Title = NSLOCTEXT("MarsCamp", "ProperDinnerTitle", "Proper dinner");
        Summary = NSLOCTEXT("MarsCamp", "ProperDinnerSummary", "Forage a supper for the party.");
        Destination = TSoftObjectPtr<UWorld>(FSoftObjectPath("/Game/Mars/Maps/Warrens_Mars_MAP.Warrens_Mars_MAP"));
    }

    asset Mars_Service_Sandbox of UMars_ServiceDefinition
    {
        Id = n"Sandbox";
        Title = NSLOCTEXT("MarsCamp", "ServiceSandboxTitle", "Sandbox service");
        Summary = NSLOCTEXT("MarsCamp", "ServiceSandboxSummary", "Explore the existing foraging grounds with your party. Return to camp when you are ready.");
        Destination = assets::Sandbox_Mars_MAP();
    }

    asset Mars_Service_BrokenCistern of UMars_ServiceDefinition
    {
        Id = n"BrokenCistern";
        Title = NSLOCTEXT("MarsCamp", "BrokenCisternTitle", "Broken Cistern");
        Summary = NSLOCTEXT("MarsCamp", "BrokenCisternSummary", "Forage the flooded courts, outwit the porter and cook at the old hearth.");
        Destination = assets::BrokenCistern_Mars_MAP();
    }

    asset Mars_ServiceCatalog_Default of UMars_ServiceCatalog
    {
        Services.Add(Mars_Service_DillBroth);
        Services.Add(Mars_Service_PanSearedRoots);
        Services.Add(Mars_Service_MushroomPie);
        Services.Add(Mars_Service_ProperDinner);
        Services.Add(Mars_Service_Sandbox);
        Services.Add(Mars_Service_BrokenCistern);
    }
}
