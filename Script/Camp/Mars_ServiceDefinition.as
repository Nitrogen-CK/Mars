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

    asset Mars_Service_PilgrimsHollow of UMars_ServiceDefinition
    {
        Id = n"PilgrimsHollow";
        Title = NSLOCTEXT("MarsCamp", "PilgrimsHollowTitle", "Pilgrim's Hollow");
        Summary = NSLOCTEXT("MarsCamp", "PilgrimsHollowSummary", "Climb the terraces, follow the bells and provision a meal beneath the shrine.");
        Destination = assets::PilgrimsHollow_Mars_MAP();
    }

    asset Mars_Service_SevereredAqueduct of UMars_ServiceDefinition
    {
        Id = n"SevereredAqueduct";
        Title = NSLOCTEXT("MarsCamp", "SevereredAqueductTitle", "Severed Aqueduct");
        Summary = NSLOCTEXT("MarsCamp", "SevereredAqueductSummary", "Descend into the guarded riverbed and reconnect the two banks through the bell gallery.");
        Destination = assets::SevereredAqueduct_Mars_MAP();
    }

    asset Mars_Service_SunkenKitchens of UMars_ServiceDefinition
    {
        Id = n"SunkenKitchens";
        Title = NSLOCTEXT("MarsCamp", "SunkenKitchensTitle", "Sunken Kitchens");
        Summary = NSLOCTEXT("MarsCamp", "SunkenKitchensSummary", "Recover the buried kitchens through the porter's gate and prepare the harvest.");
        Destination = assets::SunkenKitchens_Mars_MAP();
    }

    asset Mars_ServiceCatalog_Default of UMars_ServiceCatalog
    {
        Services.Add(Mars_Service_Sandbox);
        Services.Add(Mars_Service_BrokenCistern);
        Services.Add(Mars_Service_PilgrimsHollow);
        Services.Add(Mars_Service_SevereredAqueduct);
        Services.Add(Mars_Service_SunkenKitchens);
    }
}
