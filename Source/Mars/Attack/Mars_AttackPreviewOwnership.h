#pragma once

#include "CoreMinimal.h"
#include "Engine/AssetUserData.h"
#include "Kismet/BlueprintFunctionLibrary.h"

#include "Mars_AttackPreviewOwnership.generated.h"

// Game-owned editor metadata. The clip's public asset-user-data interface stores this in its editor-only array.
UCLASS()
class MARS_API UMars_AttackPreviewPins : public UAssetUserData
{
    GENERATED_BODY()

public:
    void Set_Objects(UObject* InRig, UObject* InGait);

private:
    UPROPERTY(Instanced)
    TObjectPtr<UObject> _Rig;

    UPROPERTY(Instanced)
    TObjectPtr<UObject> _Gait;
};

UCLASS()
class MARS_API UMars_AttackPreviewOwnership : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    // Called only for a newly created clip, or an explicitly backed-up task-owned reference clip repair.
    // Hard references make embedded preview children reachable by save/export; no Ck header or module dependency.
    UFUNCTION(BlueprintCallable, Category = "Mars|Attack|Authoring")
    static bool Attach_EmbeddedPreviewObjects(UObject* InAsset, UObject* InRig, UObject* InGait);
};
