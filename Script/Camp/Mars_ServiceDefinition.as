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

    asset Mars_ServiceCatalog_Default of UMars_ServiceCatalog
    {
        Services.Add(Mars_Service_Sandbox);
    }
}
