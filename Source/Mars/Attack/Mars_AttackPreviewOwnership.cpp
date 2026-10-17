#include "Mars_AttackPreviewOwnership.h"

#include "Interfaces/Interface_AssetUserData.h"

#if WITH_EDITOR
#include "Editor.h"
#endif

void UMars_AttackPreviewPins::Set_Objects(UObject* InRig, UObject* InGait)
{
    _Rig = InRig;
    _Gait = InGait;
}

bool UMars_AttackPreviewOwnership::Attach_EmbeddedPreviewObjects(UObject* InAsset, UObject* InRig, UObject* InGait)
{
#if WITH_EDITOR
    if (GEditor == nullptr || GEditor->PlayWorld != nullptr || GIsPlayInEditorWorld || !IsValid(InAsset) ||
        !IsValid(InRig) || !IsValid(InGait) || !InRig->IsIn(InAsset) || !InGait->IsIn(InAsset))
    { return false; }

    IInterface_AssetUserData* UserData = Cast<IInterface_AssetUserData>(InAsset);
    if (UserData == nullptr) { return false; }
    InAsset->Modify();
    auto* Pins = Cast<UMars_AttackPreviewPins>(UserData->GetAssetUserDataOfClass(UMars_AttackPreviewPins::StaticClass()));
    if (Pins == nullptr)
    {
        Pins = NewObject<UMars_AttackPreviewPins>(InAsset, NAME_None, RF_Transactional);
        UserData->AddAssetUserData(Pins);
        if (UserData->GetAssetUserDataOfClass(UMars_AttackPreviewPins::StaticClass()) != Pins)
        { return false; }
    }
    Pins->Modify();
    Pins->Set_Objects(InRig, InGait);
    InAsset->MarkPackageDirty();
    return true;
#else
    return false;
#endif
}
