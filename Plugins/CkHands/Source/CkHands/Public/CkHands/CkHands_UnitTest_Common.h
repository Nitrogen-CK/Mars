#pragma once

#include "Misc/AutomationTest.h"

// --------------------------------------------------------------------------------------------------------------------

namespace ck::hands::tests
{
    // The same flags as CkTests' ck::tests::kCkUnitTestFlags. An inline constexpr in a named namespace has one
    // definition across every translation unit, so unity builds can concatenate the spec files safely.
    inline constexpr auto kCkUnitTestFlags =
        EAutomationTestFlags::EditorContext |
        EAutomationTestFlags::ClientContext |
        EAutomationTestFlags::ProductFilter;
}

// --------------------------------------------------------------------------------------------------------------------
