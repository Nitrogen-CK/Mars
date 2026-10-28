// Fill out your copyright notice in the Description page of Project Settings.


#include "Widgets/BookPageWidget.h"

void UBookPageWidget::Init(ABookMenuActor* InBookMenuActor, const int32 InPageSectionIndex, const int32 InPageIndex)
{
	BookMenuActor = InBookMenuActor;
	PageSectionIndex = InPageSectionIndex;
	PageIndex = InPageIndex;
}

void UBookPageWidget::OnSetKeyboardFocus_Implementation()
{
	
}
