// Copyright 2024 Suricoon. All Rights Reserved.

#pragma once
#include "CoreMinimal.h"
#include "Animation/AnimInstance.h"
#include "Components/WidgetComponent.h"
#include "Engine/TextureRenderTarget2D.h"
#include "BookMenuAnimInstance.generated.h"

class ABookMenuInteractionActor;
class ABookMenuActor;
class UBookPageWidget;
class UBookMenuData;

/**
 * Structure to define the page sections
 */
USTRUCT(BlueprintType)
struct FPageSectionDataStruct
{
	GENERATED_USTRUCT_BODY()

public:

	/**
	 * Initialize the structure with default values
	 */
	FPageSectionDataStruct(): PageOneWidgetInstance(nullptr), PageTwoWidgetInstance(nullptr)
	{
	}

	/**
	 * The UserWidget Class of the Left Page of this Section
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		TSubclassOf<UBookPageWidget> PageOneWidgetClass;

	/**
	 * The UserWidget Class of the Right Page of this Section
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		TSubclassOf<UBookPageWidget> PageTwoWidgetClass;

	/**
	 * Reference to the Left Page Widget
	 */
	UPROPERTY(BlueprintReadOnly, Category="Book Menu")
		UBookPageWidget * PageOneWidgetInstance;

	/**
	 * Reference to the Right Page Widget
	 */
	UPROPERTY(BlueprintReadOnly, Category="Book Menu")
		UBookPageWidget * PageTwoWidgetInstance;

};

/**
 * Structure to define the Mapping of the Skeletal Mesh Materials to the different Pages
 */
USTRUCT(BlueprintType)
struct FPageMaterialIndexMapping
{
	GENERATED_USTRUCT_BODY()

public:

	/**
	 * Initialize the Structure with default values
	 */
	FPageMaterialIndexMapping(): PageAMaterialIndex(0), PageBMaterialIndex(0), PageCMaterialIndex(0),
	                             PageDMaterialIndex(0), FirstPageMaterialIndex(0), LastPageMaterialIndex(0),
	                             CoverMaterialIndex(0)
	{
	}

	/**
	 * Index of the Material of the Page one. Left side.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 PageAMaterialIndex;

	/**
	 * Index of the Material of the Page two. Right side.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 PageBMaterialIndex;

	/**
	 * Index of the Material of the Page three. Backside of Page two.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 PageCMaterialIndex;

	/**
	 * Index of the Material of the Page four. Backside of Page one.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 PageDMaterialIndex;

	/**
	 * Index of the Material of the first page. First Page after Cover.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 FirstPageMaterialIndex;

	/**
	 * Index of the Material of the last page. Last Page after Cover.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 LastPageMaterialIndex;

	/**
	 * Index of the Material of the Cover
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Book Menu")
		int32 CoverMaterialIndex;

};


/**
 * The Animation Instance of the Animated Book. Also cares about switching pages at the right time and takes care about
 * rendering the user widgets to the textures and materials of the book pages.
 */
UCLASS(Blueprintable)
class BOOKMENU_API UBookMenuAnimInstance : public UAnimInstance
{
	GENERATED_BODY()

	/**
	 * Saves the Original page material mapping so that it can be restored if needed by the logic
	 */
	UPROPERTY()
		FPageMaterialIndexMapping OriginalPageMaterialIndexMapping;

	UPROPERTY()
		ABookMenuInteractionActor *  InteractionActor;

	UPROPERTY()
		bool bIsInitialized;

	UPROPERTY()
		bool bIsPaused;

	UPROPERTY()
		FTimerHandle TimerHandle;

	UFUNCTION()
		void RenderCallback();
	
public:

	// Called when the game starts or when spawned
	virtual void NativeBeginPlay() override;

	// Called when the animation gets updated
	virtual void NativeUpdateAnimation(float DeltaSeconds) override;

	
	/**
	 * Helper to prevent the anim instance from updating animations
	 */
	UFUNCTION()
		void Pause();

	/**
	 * Helper to resume the animation update if anim instance is initialized
	 */
	UFUNCTION()
		void Resume();
	
	/**
	 * Renders the desired User Widgets to the textures of the book pages 
	 * @param InPageSectionIndex The Page Section Index that shall be rendered
	 * @param InTextureRenderTargetPageOne Texture Render Target where to render the left page widget to
	 * @param InTextureRenderTargetPageTwo Texture Render Target where to render the right page widget to
	 */
	UFUNCTION()
		void RenderPageSection(int32 InPageSectionIndex, UTextureRenderTarget2D* InTextureRenderTargetPageOne, UTextureRenderTarget2D* InTextureRenderTargetPageTwo);

	
	/**
	 * Helper for Rendering
	 */
	UFUNCTION()
		void UpdatePageSectionOneWidgets();

	/**
	 * Helper for Rendering
	 */
	UFUNCTION()
		void UpdatePageSectionTwoWidgets();

	/**
	 * Helper for Rendering
	 */
	UFUNCTION()
		void ClearPageSectionOneWidgets() const;

	/**
	 * Helper for Rendering
	 */
	UFUNCTION()
		void ClearPageSectionTwoWidgets() const;

	/**
	 * The RedrawTime of the pages 
	 */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Book Menu")
		float RedrawTime;
	
	/**
	 * The Owning Book Menu Actor 
	 */
	UPROPERTY(BlueprintReadOnly, Category = "Book Menu")
		ABookMenuActor * BookMenuActor;
		
	/**
	 * List of all available Page Sections of the current book
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		TMap<int32,FPageSectionDataStruct> PageSections;

	/**
	 * Texture Render Target of the page one. Left side.
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Textures")
		UTextureRenderTarget2D * PageTextureA;

	/**
	 * Texture Render Target of the page two. Right side.
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Textures")
		UTextureRenderTarget2D * PageTextureB;

	/**
	 * Texture Render Target of the page three. Backside of page two.
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Textures")
		UTextureRenderTarget2D * PageTextureC;

	/**
	 * Texture Render Target of the page four. Backside of page one.
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Textures")
		UTextureRenderTarget2D * PageTextureD;

	
	/**
	 * Dynamic Material Instance of page one. Must have a Texture Parameter called BC
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Materials")
		UMaterialInstanceDynamic * MaterialPageA;

	/**
	 * Dynamic Material Instance of page two. Must have a Texture Parameter called BC
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Materials")
		UMaterialInstanceDynamic * MaterialPageB;

	/**
	 * Dynamic Material Instance of page three. Must have a Texture Parameter called BC
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Materials")
		UMaterialInstanceDynamic * MaterialPageC;

	/**
	 * Dynamic Material Instance of page four. Must have a Texture Parameter called BC
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Materials")
		UMaterialInstanceDynamic * MaterialPageD;

	/**
	 * Dynamic Material Instance of The Cover.
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages | Materials")
		UMaterialInstanceDynamic * MaterialCover;
	
	/**
	 * Page Section Index for Pages one and two
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		int32 PageSectionAIndex;

	/**
	 * Page Section Index for Pages three and four
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		int32 PageSectionBIndex;

	
	/**
	 * Sets or replaces the current list of Page sections
	 * @param InPageSections List of Page Sections to be set.
	 */
	UFUNCTION(BlueprintCallable, Category="Pages")
		void SetPageSections(TArray<FPageSectionDataStruct> InPageSections);

	/**
	 * The Default Page Section in case there is no defined page section.
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		FPageSectionDataStruct DefaultPageSection;

	/**
	 * The Current Page Section Index to be displayed on page one and two
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		int32 CurrentPageSectionIndex;

	/**
	 * The current Page the Interaction point on. Can be either the Left or the Right Page.
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		int32 CurrentPageIndex;

	

	/**
	 * The Page Section Index that is pending while switching pages. 
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		int32 PendingPageSectionIndex;

	
	/**
	 * The Draw Size of the render targets. Must match the Widget Component Draw Size of the Book Interaction Actor.
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		FVector2D DrawSize;

	
	/**
	 * Indicates if the book is or shall be in an opened state
	 */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Pages")
		bool bBookIsOpen;

	/**
	 * Indicates if the book should open
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages")
		bool bBookShouldOpen;

	/**
	 * Indicates if the book should close
	 */
	UPROPERTY(BlueprintReadWrite, Category="Pages")
		bool bBookShouldClose;

	/**
	 * Indicates if the book should close
	 */
	UPROPERTY(BlueprintReadOnly, Category="Pages")
		bool bBookShouldSetKeyboardFocus;
	
	/**
	 * Method to Initialize the Animation Instance and set configurations such as Book Data.
	 * @param InData The Book Menu Data
	 * @param InBookMenuActor The Book Menu Actor
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages")
		void Init(UBookMenuData * InData, ABookMenuActor * InBookMenuActor);

	/**
	 * Sets the Interaction Actor
	 * @param InInteractionActor The Interaction Actor to set
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Rendering")
		void SetInteractionActor(ABookMenuInteractionActor * InInteractionActor);

	/**
	 * Determines if a forward or backward page turn need to be performed based on the current page section index.
	 * @param SectionIndex the index of the Page Section to be displayed
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Control")
		void JumpToPageSection(int32 SectionIndex);

	
	/**
	 * Sets the render target of page one to the given render target. Temporarily replace the rendered Widget by the
	 * render result of the Book Interaction Actor Widget. Needed to keep the UI responsive.
	 * @param InRenderTarget The Render Target to be set for the page one
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Rendering")
		void SetRenderTargetPageOne(UTextureRenderTarget2D * InRenderTarget);

	/**
	 * Sets the render target of page two to the given render target. Temporarily replace the rendered Widget by the
	 * render result of the Book Interaction Actor Widget. Needed to keep the UI responsive.
	 * @param InRenderTarget The Render Target to be set for the page two
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Rendering")
		void SetRenderTargetPageTwo(UTextureRenderTarget2D * InRenderTarget);
	
	/*UFUNCTION(BlueprintCallable, Category = "Pages")
		FPageSectionDataStruct GetCurrentPageSection();*/

	/**
	 * If the book is closed, this triggers the open book animation and upfront sets the correct section to display.
	 * @param SectionIndex The Page Section Index to be displayed while opening the book
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Control")
		void OpenBookAt(int32 SectionIndex);

	/**
	 * If the book is closed, this forces the book into open state without animation
	 * @param SectionIndex The Page Section Index to be displayed while opening the book
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Control")
		void OpenBookAtWithoutAnimation(int32 SectionIndex);
	
	/**
	 * Triggers the Close Book animation
	 */
	UFUNCTION(BlueprintCallable, Category = "Pages|Control")
		void CloseBook();

	/**
	 * Method to be overwritten in the Anim Blueprint. Shall start the Page Turn forward animation.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void PlayPageTurnForwardAnim();

	/**
	 * Method to be overwritten in the Anim Blueprint. Shall start the Page Turn backward animation.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void PlayPageTurnReverseAnim();

	/**
	 * Method to be overwritten in the Anim Blueprint. Shall start the Open Book animation.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void PlayOpenBookAnim();

	/**
	 * Method to be overwritten in the Anim Blueprint. Shall start the Close Book animation.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void PlayCloseBookAnim();

	/**
	 * Method to be overwritten in the Anim Blueprint. Shall start the Idle animation.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void PlayIdleBookAnim();

	
	/**
	 * Method to be called at the end of a page turn animation. You want to use Anim Notifies to find out when to call this Method. 
	 * @param bIsTurnForward Indicates if a page forward (true) or a page backward (false) animation was executed.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnPageTurnAnimEnd(bool bIsTurnForward = true);

	/**
	 * Method to be called at the end of the Open Book Animation. You want to use Anim Notifies to find out when to call this Method.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnBookOpenAnimEnd();

	/**
	 * Method to be called at the end of the Close Book Animation. You want to use Anim Notifies to find out when to call this Method.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnBookCloseAnimEnd();

	/**
	 * Method to be called at the end of the Idle Book Animation. e.g. to restart the Idle animation.
	 * You want to use Anim Notifies to find out when to call this Method.
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnBookIdleAnimEnd();

	/**
	 * Called when the Anim Blueprint gets Paused to do some "pausing" stuff in the Blueprint
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnPaused();

	/**
	 * Called when the Anim Blueprint gets Resumed to do some "resuming" stuff in the Blueprint
	 */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "Pages|Animation")
		void OnResumed();
	
};
