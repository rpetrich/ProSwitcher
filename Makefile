ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init --recursive
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

# ProSwitcher.dylib (/Library/MobileSubstrate/DynamicLibraries)
TWEAK_NAME = ProSwitcher
ProSwitcher_OBJC_FILES = PSWApplication.m PSWDisplayStacks.m PSWProSwitcherIcon.m PSWPageView.m PSWSpringBoardApplication.m PSWApplicationController.m PSWResources.m PSWSnapshotView.m PSWController.m PSWContainerView.m
ProSwitcher_FRAMEWORKS = AudioToolbox CoreGraphics Foundation QuartzCore UIKit
ProSwitcher_USESUBSTRATE = 0
ifneq ($(TARGET),simulator)
ProSwitcher_PRIVATE_FRAMEWORKS = IOSurface
endif

ADDITIONAL_CFLAGS = -std=c99 -I./Headers

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

endif
