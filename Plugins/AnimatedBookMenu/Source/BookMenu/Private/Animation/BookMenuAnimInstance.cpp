// Copyright 2024 Suricoon. All Rights Reserved.

#include "Animation/BookMenuAnimInstance.h"
#include "BookMenuStatics.h"
#include "Actors/BookMenuActor.h"
#include "Actors/BookMenuInteractionActor.h"
#include "Blueprint/UserWidget.h"
#include "DataAssets/BookMenuData.h"
#include "Widgets/BookPageWidget.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "TimerManager.h"
#include "Components/SkeletalMeshComponent.h"

#define LOCTEXT_NAMESPACE "BookMenuPlugin"

void UBookMenuAnimInstance::RenderCallback()
{
	//render widgets without 3D widgets
	if(CurrentPageSectionIndex != PendingPageSectionIndex)
	{
		//if page is turning all 4 Pages must be rendered
		RenderPageSection(PageSectionAIndex, PageTextureA, PageTextureB);
		RenderPageSection(PageSectionBIndex, PageTextureC, PageTextureD);
	}
	else
	{
		//if page is not turning only page one and two must be rendered
		RenderPageSection(PageSectionAIndex, PageTextureA, PageTextureB);
	}
}

void UBookMenuAnimInstance::NativeBeginPlay()
{
	Super::NativeBeginPlay();

	PageSectionAIndex = -1;
	PageSectionBIndex = -1;
	CurrentPageSectionIndex = 0;
	bBookShouldOpen = false;
	bBookShouldClose = false;
}

void UBookMenuAnimInstance::NativeUpdateAnimation(float DeltaSeconds)
{
	Super::NativeUpdateAnimation(DeltaSeconds);

	if(!bIsInitialized || bIsPaused)
	{
		return;
	}
	
	if(PageSections.Num() == 0)
	{
		return;
	}

	if(BookMenuActor == nullptr)
	{
		return;
	}

	if(PageTextureA == nullptr || PageTextureB == nullptr || PageTextureC == nullptr || PageTextureD == nullptr)
	{
		return;
	}

	if(InteractionActor == nullptr)
	{
		if(RedrawTime == 0.f)
		{
			//render every frame
			RenderCallback();
		}
		else
		{
			if (!GetWorld()->GetTimerManager().IsTimerActive(TimerHandle))
			{
				GetWorld()->GetTimerManager().SetTimer(TimerHandle, this, &UBookMenuAnimInstance::RenderCallback, RedrawTime, true);
			}
		}
	}
	else
	{
		//render widgets using 3D Widgets
		if(CurrentPageSectionIndex != PendingPageSectionIndex)
		{
			//if page is turning all 4 Pages must be rendered
			UpdatePageSectionOneWidgets();
			UpdatePageSectionTwoWidgets();
			InteractionActor->ActiveWidgetComponent = nullptr;
		}
		else
		{
			//if page is not turning only page one and two must be rendered
			UpdatePageSectionOneWidgets();
			ClearPageSectionTwoWidgets();

			if(CurrentPageIndex == 0)
			{
				InteractionActor->ActiveWidgetComponent = InteractionActor->PageWidgetComponentA;
			}
			else if(CurrentPageIndex == 1)
			{
				InteractionActor->ActiveWidgetComponent = InteractionActor->PageWidgetComponentB;
			}
		}

		if(bBookShouldSetKeyboardFocus == true)
		{
			if(InteractionActor->ActiveWidgetComponent->GetWidget() != nullptr)
			{
				InteractionActor->ActiveWidgetComponent->GetWidget()->SetKeyboardFocus();
				UBookPageWidget * userWidget = Cast<UBookPageWidget>(InteractionActor->ActiveWidgetComponent->GetWidget());

				if(userWidget != nullptr)
				{
					userWidget->OnSetKeyboardFocus();
				}
			}
			bBookShouldSetKeyboardFocus = false;
		}
		
	}
}

void UBookMenuAnimInstance::Pause()
{
	bIsPaused = true;
	OnPaused();
}

void UBookMenuAnimInstance::Resume()
{
	bIsPaused = false;
	OnResumed();
}

void UBookMenuAnimInstance::RenderPageSection(const int32 InPageSectionIndex,
                                              UTextureRenderTarget2D* InTextureRenderTargetPageOne, UTextureRenderTarget2D* InTextureRenderTargetPageTwo)
{
	if(!PageSections.Contains(InPageSectionIndex))
	{
		return;
	}

	if(InPageSectionIndex < 0)
	{
		if(DefaultPageSection.PageOneWidgetClass != nullptr)
		{
			if(DefaultPageSection.PageOneWidgetInstance == nullptr)
			{
				DefaultPageSection.PageOneWidgetInstance = CreateWidget<UBookPageWidget>(GetWorld(), DefaultPageSection.PageOneWidgetClass);
				DefaultPageSection.PageOneWidgetInstance->Init(BookMenuActor,-1,0);
			}
			if(InTextureRenderTargetPageOne != nullptr)
			{
				UBookMenuStatics::DrawUserWidgetToRenderTarget2D(DefaultPageSection.PageOneWidgetInstance, InTextureRenderTargetPageOne, DrawSize);
			}
		}

		if(DefaultPageSection.PageTwoWidgetClass != nullptr)
		{
			if(DefaultPageSection.PageTwoWidgetInstance == nullptr)
			{
				DefaultPageSection.PageTwoWidgetInstance = CreateWidget<UBookPageWidget>(GetWorld(), DefaultPageSection.PageTwoWidgetClass);
				DefaultPageSection.PageTwoWidgetInstance->Init(BookMenuActor, -1,1);
			}

			if(InTextureRenderTargetPageTwo != nullptr)
			{
				UBookMenuStatics::DrawUserWidgetToRenderTarget2D(DefaultPageSection.PageTwoWidgetInstance, InTextureRenderTargetPageTwo, DrawSize);
			}
			
		}
	}
	else
	{
		if(PageSections[InPageSectionIndex].PageOneWidgetClass != nullptr)
		{
			if(PageSections[InPageSectionIndex].PageOneWidgetInstance == nullptr)
			{
				PageSections[InPageSectionIndex].PageOneWidgetInstance = CreateWidget<UBookPageWidget>(GetWorld(), PageSections[InPageSectionIndex].PageOneWidgetClass);
				PageSections[InPageSectionIndex].PageOneWidgetInstance->Init(BookMenuActor, InPageSectionIndex, 0);
				
			}
			if(InTextureRenderTargetPageOne != nullptr)
			{
				UBookMenuStatics::DrawUserWidgetToRenderTarget2D(PageSections[InPageSectionIndex].PageOneWidgetInstance, InTextureRenderTargetPageOne, DrawSize);
			}
			
		}

		if(PageSections[InPageSectionIndex].PageTwoWidgetClass != nullptr)
		{
			if(PageSections[InPageSectionIndex].PageTwoWidgetInstance == nullptr)
			{
				PageSections[InPageSectionIndex].PageTwoWidgetInstance = CreateWidget<UBookPageWidget>(GetWorld(), PageSections[InPageSectionIndex].PageTwoWidgetClass);
				PageSections[InPageSectionIndex].PageTwoWidgetInstance->Init(BookMenuActor, InPageSectionIndex, 1);
			}

			if(InTextureRenderTargetPageTwo != nullptr)
			{
				UBookMenuStatics::DrawUserWidgetToRenderTarget2D(PageSections[InPageSectionIndex].PageTwoWidgetInstance, InTextureRenderTargetPageTwo, DrawSize);
			}
		}
	}	
}

void UBookMenuAnimInstance::UpdatePageSectionOneWidgets()
{
	if(!PageSections.Contains(PageSectionAIndex))
	{
		return;
	}

	if(PageSectionAIndex < 0)
	{
		if(InteractionActor->PageWidgetComponentA->GetWidget() != DefaultPageSection.PageOneWidgetInstance)
		{
			InteractionActor->PageWidgetComponentA->SetWidget(DefaultPageSection.PageOneWidgetInstance);
		}

		if(InteractionActor->PageWidgetComponentB->GetWidget() != DefaultPageSection.PageTwoWidgetInstance)
		{
			InteractionActor->PageWidgetComponentB->SetWidget(DefaultPageSection.PageTwoWidgetInstance);
		}
	}
	else
	{
		if(InteractionActor->PageWidgetComponentA->GetWidget() != PageSections[PageSectionAIndex].PageOneWidgetInstance)
		{
			InteractionActor->PageWidgetComponentA->SetWidget(PageSections[PageSectionAIndex].PageOneWidgetInstance);

			if(MaterialPageA != nullptr)
			{
				MaterialPageA->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InteractionActor->PageWidgetComponentA->GetRenderTarget()));
			}
		}

		if(InteractionActor->PageWidgetComponentB->GetWidget() != PageSections[PageSectionAIndex].PageTwoWidgetInstance)
		{
			InteractionActor->PageWidgetComponentB->SetWidget(PageSections[PageSectionAIndex].PageTwoWidgetInstance);

			if(MaterialPageB != nullptr)
			{
				MaterialPageB->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InteractionActor->PageWidgetComponentB->GetRenderTarget()));
			}
		}
	}	
}

void UBookMenuAnimInstance::UpdatePageSectionTwoWidgets()
{
	if(!PageSections.Contains(PageSectionBIndex))
	{
		return;
	}

	if(PageSectionBIndex < 0)
	{
		if(InteractionActor->PageWidgetComponentC->GetWidget() != DefaultPageSection.PageOneWidgetInstance)
		{
			InteractionActor->PageWidgetComponentC->SetWidget(DefaultPageSection.PageOneWidgetInstance);
		}

		if(InteractionActor->PageWidgetComponentD->GetWidget() != DefaultPageSection.PageTwoWidgetInstance)
		{
			InteractionActor->PageWidgetComponentD->SetWidget(DefaultPageSection.PageTwoWidgetInstance);
		}
	}
	else
	{
		if(InteractionActor->PageWidgetComponentC->GetWidget() != PageSections[PageSectionBIndex].PageOneWidgetInstance)
		{
			InteractionActor->PageWidgetComponentC->SetWidget(PageSections[PageSectionBIndex].PageOneWidgetInstance);

			if(MaterialPageC != nullptr)
			{
				MaterialPageC->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InteractionActor->PageWidgetComponentC->GetRenderTarget()));
			}
		}

		if(InteractionActor->PageWidgetComponentD->GetWidget() != PageSections[PageSectionBIndex].PageTwoWidgetInstance)
		{
			InteractionActor->PageWidgetComponentD->SetWidget(PageSections[PageSectionBIndex].PageTwoWidgetInstance);

			if(MaterialPageD != nullptr)
			{
				MaterialPageD->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InteractionActor->PageWidgetComponentD->GetRenderTarget()));
			}
		}
	}	
}

void UBookMenuAnimInstance::ClearPageSectionOneWidgets() const
{
	if(InteractionActor == nullptr)
	{
		return;
	}

	if(InteractionActor->PageWidgetComponentA->GetWidget() != nullptr)
	{
		InteractionActor->PageWidgetComponentA->SetWidget(nullptr);
		if(MaterialPageA != nullptr)
		{
			MaterialPageA->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureA));
		}
	}
	
	if(InteractionActor->PageWidgetComponentB->GetWidget() != nullptr)
	{
		InteractionActor->PageWidgetComponentB->SetWidget(nullptr);

		if(MaterialPageB != nullptr)
		{
			MaterialPageB->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureB));
		}
	}
}

void UBookMenuAnimInstance::ClearPageSectionTwoWidgets() const
{
	if(InteractionActor == nullptr)
	{
		return;
	}

	if(InteractionActor->PageWidgetComponentC->GetWidget() != nullptr)
	{
		InteractionActor->PageWidgetComponentC->SetWidget(nullptr);
		if(MaterialPageC != nullptr)
		{
			MaterialPageC->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureC));
		}
	}
	
	if(InteractionActor->PageWidgetComponentD->GetWidget() != nullptr)
	{
		InteractionActor->PageWidgetComponentD->SetWidget(nullptr);

		if(MaterialPageD != nullptr)
		{
			MaterialPageD->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureD));
		}
	}
}

void UBookMenuAnimInstance::Init(UBookMenuData* InData, ABookMenuActor * InBookMenuActor)
{
	if(InData == nullptr)
	{
		return;
	}

	BookMenuActor = InBookMenuActor;
	DefaultPageSection = InData->DefaultPageSection;

	if(!bIsInitialized)
	{
		DrawSize = InData->DrawSize;
		RedrawTime = InData->RedrawTime;
		
		if(RedrawTime < 0)
		{
			RedrawTime = 0.f;
		}
	
		if(DrawSize == FVector2D(0,0))
		{
			DrawSize = FVector2D(2048,2048);
		}

		PageTextureA = UBookMenuStatics::CreateTextureRenderTarget2D(DrawSize);
		PageTextureB = UBookMenuStatics::CreateTextureRenderTarget2D(DrawSize);
		PageTextureC = UBookMenuStatics::CreateTextureRenderTarget2D(DrawSize);
		PageTextureD = UBookMenuStatics::CreateTextureRenderTarget2D(DrawSize);
	
		USkeletalMeshComponent * Mesh = GetSkelMeshComponent();
		OriginalPageMaterialIndexMapping = InData->PageMaterialIndexMapping;
		UMaterialInterface * MatA = Mesh->GetMaterial(InData->PageMaterialIndexMapping.PageAMaterialIndex);
		UMaterialInterface * MatB = Mesh->GetMaterial(InData->PageMaterialIndexMapping.PageBMaterialIndex);
		UMaterialInterface * MatC = Mesh->GetMaterial(InData->PageMaterialIndexMapping.PageCMaterialIndex);
		UMaterialInterface * MatD = Mesh->GetMaterial(InData->PageMaterialIndexMapping.PageDMaterialIndex);

		if(MatA != nullptr)
		{
			MaterialPageA = Cast<UMaterialInstanceDynamic>(MatA);

			if(MaterialPageA == nullptr)
			{
				MaterialPageA = UMaterialInstanceDynamic::Create(MatA, Mesh);
			}
		
			MaterialPageA->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureA));
			Mesh->SetMaterial(InData->PageMaterialIndexMapping.PageAMaterialIndex, MaterialPageA);
		}
		else
		{
			const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
			FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuAnimInstanceMatANotFound", "Could not get Material for Page A at given index. Please check the PageMaterialMapping - {0}"), FText::FromString(Message)));
		}
	
		if(MatB != nullptr)
		{
			MaterialPageB = Cast<UMaterialInstanceDynamic>(MatB);

			if(MaterialPageB == nullptr)
			{
				MaterialPageB = UMaterialInstanceDynamic::Create(MatB, Mesh);
			}
			
			MaterialPageB->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureB));
			Mesh->SetMaterial(InData->PageMaterialIndexMapping.PageBMaterialIndex, MaterialPageB);
		}
		else
		{
			const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
			FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuAnimInstanceMatBNotFound", "Could not get Material for Page B at given index. Please check the PageMaterialMapping - {0}"), FText::FromString(Message)));
	
		}
	
		if(MatC != nullptr)
		{
			MaterialPageC = Cast<UMaterialInstanceDynamic>(MatC);

			if(MaterialPageC == nullptr)
			{
				MaterialPageC = UMaterialInstanceDynamic::Create(MatC, Mesh);
			}
			
			MaterialPageC->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureC));
			Mesh->SetMaterial(InData->PageMaterialIndexMapping.PageCMaterialIndex, MaterialPageC);
		}
		else
		{
			const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
			FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuAnimInstanceMatCNotFound", "Could not get Material for Page C at given index. Please check the PageMaterialMapping - {0}"), FText::FromString(Message)));
	
		}

		if(MatD != nullptr)
		{
			MaterialPageD = Cast<UMaterialInstanceDynamic>(MatD);

			if(MaterialPageD == nullptr)
			{
				MaterialPageD = UMaterialInstanceDynamic::Create(MatD, Mesh);
			}
			
			MaterialPageD->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureD));
			Mesh->SetMaterial(InData->PageMaterialIndexMapping.PageDMaterialIndex, MaterialPageD);
		}
		else
		{
			const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
			FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuAnimInstanceMatDNotFound", "Could not get Material for Page D at given index. Please check the PageMaterialMapping - {0}"), FText::FromString(Message)));
	
		}

		if(InData->CoverMaterial != nullptr)
		{
			MaterialCover = UMaterialInstanceDynamic::Create(InData->CoverMaterial, Mesh);
			Mesh->SetMaterial(InData->PageMaterialIndexMapping.CoverMaterialIndex, MaterialCover);
		}
		else
		{
			const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
			FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuAnimInstanceMatCoverNotFound", "Could not get Material forCover at given index. Please check the PageMaterialMapping - {0}"), FText::FromString(Message)));
	
		}
	}

	SetPageSections(InData->PageSections);

	for(int i = 0; i < PageSections.Num(); i++)
	{
		PageSections[i].PageOneWidgetInstance = CreateWidget<UBookPageWidget>(UBookMenuStatics::GetLocalPlayerController(GetWorld()), PageSections[i].PageOneWidgetClass);

		if(PageSections[i].PageOneWidgetInstance != nullptr)
		{
			PageSections[i].PageOneWidgetInstance->Init(BookMenuActor, i, 0);
		}
		
		PageSections[i].PageTwoWidgetInstance = CreateWidget<UBookPageWidget>(UBookMenuStatics::GetLocalPlayerController(GetWorld()),PageSections[i].PageTwoWidgetClass);

		if(PageSections[i].PageTwoWidgetInstance != nullptr)
		{
			PageSections[i].PageTwoWidgetInstance->Init(BookMenuActor, i, 1);
		}
	}

	
	bIsInitialized = true;

	if(!bBookIsOpen)
	{
		Pause();
	}
}

void UBookMenuAnimInstance::SetInteractionActor(ABookMenuInteractionActor* InInteractionActor)
{
	if(InInteractionActor == InteractionActor)
	{
		return;
	}

	if(InInteractionActor == nullptr && InteractionActor != nullptr)
	{
		ClearPageSectionOneWidgets();
		ClearPageSectionTwoWidgets();
	}

	InteractionActor = InInteractionActor;

	if(InteractionActor == nullptr)
	{
		
		if(MaterialPageA != nullptr)
		{
			MaterialPageA->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureA));
		}

		if(MaterialPageB != nullptr)
		{
			MaterialPageB->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureB));
		}

		if(MaterialPageC != nullptr)
		{
			MaterialPageC->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureC));
		}

		if(MaterialPageD != nullptr)
		{
			MaterialPageD->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(PageTextureD));
		}
	}
	else
	{
		//Cleaer "manual" render Timer if Interaction actor gets set.
		if (GetWorld()->GetTimerManager().IsTimerActive(TimerHandle))
		{
			GetWorld()->GetTimerManager().ClearTimer(TimerHandle);
		}

		

		InteractionActor->PageWidgetComponentA->SetRedrawTime(RedrawTime);
		InteractionActor->PageWidgetComponentB->SetRedrawTime(RedrawTime);
		InteractionActor->PageWidgetComponentC->SetRedrawTime(RedrawTime);
		InteractionActor->PageWidgetComponentD->SetRedrawTime(RedrawTime);
		
	}
}

void UBookMenuAnimInstance::SetPageSections(TArray<FPageSectionDataStruct> InPageSections)
{
	if(InPageSections.Num() <= 0)
	{
		PageSections = TMap<int32,FPageSectionDataStruct>();
		PageSectionAIndex = -1;
		PageSectionBIndex = -1;
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceNoPageSections", "InPageSections on call SetPageSections was empty - {0}"), FText::FromString(Message)));
		return;
	}

	for(int i = 0; i < InPageSections.Num(); i++)
	{
		PageSections.Add(i,InPageSections[i]);
	}
	
	CurrentPageSectionIndex = 0;
	
	PageSectionAIndex = 0;

	if(PageSections.Num() >= 2)
	{
		PageSectionBIndex = 1;
	}
	else
	{
		PageSectionBIndex = -1;
	}
}



void UBookMenuAnimInstance::JumpToPageSection(int32 SectionIndex)
{
	if(bIsPaused || !bBookIsOpen || bBookShouldClose)
	{
		return;
	}

	if(SectionIndex < 0)
	{
		SectionIndex = 0;
	}

	if(!PageSections.Contains(SectionIndex))
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceJumpToPageSection", "JumpToPageSection: Index of the given Page Section is was out of range - {0}"), FText::FromString(Message)));
		return;
	}

	if(CurrentPageSectionIndex == SectionIndex)
	{
		return;
	}

	if(CurrentPageSectionIndex > SectionIndex)
	{
		//Turning Backwards
		PageSectionBIndex = PageSectionAIndex;
		PageSectionAIndex = SectionIndex;
		PendingPageSectionIndex = SectionIndex;
		PlayPageTurnReverseAnim();
	}
	else if(CurrentPageSectionIndex < SectionIndex)
	{
		//Turning Forward
		PageSectionBIndex = SectionIndex;
		PendingPageSectionIndex = SectionIndex;
		PlayPageTurnForwardAnim();
	}
}

void UBookMenuAnimInstance::SetRenderTargetPageOne(UTextureRenderTarget2D* InRenderTarget)
{
	if(MaterialPageA != nullptr)
	{
		MaterialPageA->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InRenderTarget));
	}
}

void UBookMenuAnimInstance::SetRenderTargetPageTwo(UTextureRenderTarget2D* InRenderTarget)
{
	if(MaterialPageB != nullptr)
	{
		MaterialPageB->SetTextureParameterValue(FName(TEXT("BC")), Cast<UTexture>(InRenderTarget));
	}
}

void UBookMenuAnimInstance::OpenBookAt(int32 SectionIndex)
{

	if(!bIsInitialized)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceOpenBookAtInit", "OpenBookAt: Cannot call this function before the Anim Instance was Initialized. Please don't call this function from BeginPlay of the parent Actor of this Anim Instance - {0}"), FText::FromString(Message)));
		return;
	}
	
	if(SectionIndex < 0)
	{
		SectionIndex = 0;
	}

	if(!PageSections.Contains(SectionIndex))
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceOpenBookAt", "OpenBookAt: Index of the given Page Section is was out of range - {0}"), FText::FromString(Message)));
		return;
	}

	//It is important to resume updating the animation before any animation starts
	Resume();
	
	//if already open jump to page section instead of opening
	if(bBookIsOpen)
	{
		JumpToPageSection(SectionIndex);
		return;
	}

	//Set Pages that will show up while opening
	PageSectionAIndex = SectionIndex;
	CurrentPageSectionIndex = SectionIndex;
	PendingPageSectionIndex = SectionIndex;
	
	
	//Play Open Book animation
	bBookShouldOpen = true;
	bBookShouldClose = false;
	PlayOpenBookAnim();
}

void UBookMenuAnimInstance::OpenBookAtWithoutAnimation(int32 SectionIndex)
{
	if(!bIsInitialized)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceOpenBookAtWithoutAnimationInit", "OpenBookAtWithoutAnimation: Cannot call this function before the Anim Instance was Initialized. Please don't call this function from BeginPlay of the parent Actor of this Anim Instance - {0}"), FText::FromString(Message)));
		return;
	}
	
	if(SectionIndex < 0)
	{
		SectionIndex = 0;
	}

	if(!PageSections.Contains(SectionIndex))
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceOpenBookAtWithoutAnimation", "OpenBookAtWithoutAnimation: Index of the given Page Section is was out of range - {0}"), FText::FromString(Message)));
		return;
	}

	bBookIsOpen = true;
	PageSectionAIndex = SectionIndex;
	CurrentPageSectionIndex = SectionIndex;
	PendingPageSectionIndex = SectionIndex;
	
	bBookShouldOpen = false;
	bBookShouldClose = false;

	Resume();

}

void UBookMenuAnimInstance::CloseBook()
{
	if(!bIsInitialized)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuAnimInstanceCloseBookInit", "CloseBook: Cannot call this function before the Anim Instance was Initialized. Please don't call this function from BeginPlay of the parent Actor of this Anim Instance - {0}"), FText::FromString(Message)));
		return;
	}
	
	//Close Book animation if open
	if(bBookIsOpen)
	{
		bBookShouldOpen = false;
		bBookShouldClose = true;
		PlayCloseBookAnim();
	}
}

void UBookMenuAnimInstance::OnResumed_Implementation()
{
}

void UBookMenuAnimInstance::OnPaused_Implementation()
{
}

void UBookMenuAnimInstance::OnBookIdleAnimEnd_Implementation()
{
}

void UBookMenuAnimInstance::OnBookCloseAnimEnd_Implementation()
{
	bBookIsOpen = false;
	bBookShouldOpen = false;
	bBookShouldClose = false;

	//A closed book does not require update of the pages
	Pause();
}

void UBookMenuAnimInstance::OnBookOpenAnimEnd_Implementation()
{
	bBookIsOpen = true;
	bBookShouldOpen = false;
	bBookShouldClose = false;
}

void UBookMenuAnimInstance::OnPageTurnAnimEnd_Implementation(const bool bIsTurnForward)
{

	CurrentPageSectionIndex = PendingPageSectionIndex;
	
	if(bIsTurnForward)
	{
		PageSectionAIndex = PageSectionBIndex;
		PageSectionBIndex = -1;
	}
}

void UBookMenuAnimInstance::PlayIdleBookAnim_Implementation()
{
}

void UBookMenuAnimInstance::PlayCloseBookAnim_Implementation()
{
}

void UBookMenuAnimInstance::PlayOpenBookAnim_Implementation()
{
}

void UBookMenuAnimInstance::PlayPageTurnReverseAnim_Implementation()
{
}

void UBookMenuAnimInstance::PlayPageTurnForwardAnim_Implementation()
{
}

#undef LOCTEXT_NAMESPACE