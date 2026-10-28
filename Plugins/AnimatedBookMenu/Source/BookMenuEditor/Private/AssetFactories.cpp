// Copyright 2024 Suricoon. All Rights Reserved.


#include "AssetFactories.h"

#include "DataAssets/BookMenuData.h"

UBookMenuDataFactory::UBookMenuDataFactory()
{
	SupportedClass = UBookMenuData::StaticClass();
	bCreateNew = true;
}

UObject* UBookMenuDataFactory::FactoryCreateNew(UClass* Class, UObject* InParent, FName Name, EObjectFlags Flags,
                                                UObject* Context, FFeedbackContext* Warn)
{
	UBookMenuData* Data =  NewObject<UBookMenuData>(InParent, Class, Name, Flags | RF_Transactional);
	return Data;
}
	