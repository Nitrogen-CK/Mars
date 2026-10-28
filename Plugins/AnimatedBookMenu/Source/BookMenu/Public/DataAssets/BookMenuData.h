// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "Animation/BookMenuAnimInstance.h"
#include "UObject/Object.h"
#include "BookMenuData.generated.h"

class UBookMenuStatics;
/**
 * Configuration Data Object to configure a Book Menu Actor
 */
UCLASS()
class BOOKMENU_API UBookMenuData : public UObject
{
	GENERATED_BODY()

	friend class UBookMenuStatics;
	
	UPROPERTY()
		bool bIsRuntimeCreated;
	
public:

	/**
	 * The Skeletal Mesh to be set after Begin Play
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Mesh")
		USkeletalMesh * SkeletalMesh;

	/**
	 * The Animation Blueprint class to be set after Begin Play
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Mesh")
		TSubclassOf<UBookMenuAnimInstance> AnimInstanceClass;

	/**
	 * Mapping that tells us which Material Index of the Skeletal Mesh shall be used for which Page
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Mesh")
		FPageMaterialIndexMapping PageMaterialIndexMapping;
	
	/**
	 * The Default Page Section to be used if no concrete Page Section is defined
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Pages")
		FPageSectionDataStruct DefaultPageSection;
	
	/**
	 * List of Page Sections to be used inside the Book Menu Actor
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Pages")
		TArray<FPageSectionDataStruct> PageSections;

	/**
	 * Material for the Cover
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pages")
		UMaterialInterface * CoverMaterial;

	/**
	 * If the book shall begin play in an open state or closed state
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pages")
		bool bBookBeginsPlayOpen;

	/**
	 * If the book shall begin play in an open state, this is the page section to open the book at. Can also be accessed
	 * by the Book Menu Actor to handle respective behavior.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pages")
		int32 StartPageSection;
	
	/**
	 * Draw Size of the Render Targets and the Widgets. Used to set the Draw Size on all involved Actors and components
	 */
	UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Rendering")
		FVector2D DrawSize = FVector2d(2048, 2048);

	/**
	 * Time between redraws. if 0 we would redraw every frame. 
	 */
	UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Rendering")
		float RedrawTime = 0;
	
};
	