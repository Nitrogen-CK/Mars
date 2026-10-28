// Copyright 2024 Suricoon. All Rights Reserved.

#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "BookPageWidget.generated.h"

class ABookMenuActor;
/**
 * Widget Class for user widgets to be used on book menu actor pages
 */
UCLASS()
class BOOKMENU_API UBookPageWidget : public UUserWidget
{
	GENERATED_BODY()

public:

	/**
	 * The Owning Book Menu Actor of the widget. Can be used to control the Book Menu actor from the widget 
	 */
	UPROPERTY(BlueprintReadOnly, Category = "Book Menu")
		ABookMenuActor * BookMenuActor;
	
	/**
	 * The page section index of this widget. Can be used for navigation.
	 */
	UPROPERTY(BlueprintReadOnly, Category = "Book Menu")
		int32 PageSectionIndex;

	/**
	 * The page index. 0 = Left page, 1 = Right page
	 */
	UPROPERTY(BlueprintReadOnly, Category = "Book Menu")
		int32 PageIndex;

	/**
	 * Method to initialize the most important data in the Widget
	 * @param InBookMenuActor The Owning Book Menu Actor of the widget. Can be used to control the Book Menu actor from the widget 
	 * @param InPageSectionIndex The page section index of this widget. Can be used for navigation.
	 * @param InPageIndex  The page index. 0 = Left page, 1 = Right page
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages")
		void Init(ABookMenuActor * InBookMenuActor, int32 InPageSectionIndex, int32 InPageIndex);

	/**
	 * Gets called when the anim instance sets the focus on this widget
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages")
		void OnSetKeyboardFocus();
	
};
