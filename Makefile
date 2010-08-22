export GO_EASY_ON_ME=1

ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init --recursive
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

# ProSwitcher.dylib (/Library/MobileSubstrate/DynamicLibraries)
TWEAK_NAME = ProSwitcher
ProSwitcher_OBJC_FILES = PSWApplication.mm PSWDisplayStacks.mm PSWProSwitcherIcon.mm PSWPageView.mm PSWSpringBoardApplication.mm PSWApplicationController.mm PSWResources.mm PSWSnapshotView.mm PSWController.mm PSWContainerView.mm PSWSurface.mm
ProSwitcher_FRAMEWORKS = AudioToolbox CoreGraphics Foundation QuartzCore UIKit
ADDITIONAL_CFLAGS = -I./Headers
ADDITIONAL_LDFLAGS=-ggdb

LOCALIZATION_PROJECT_NAME = ProSwitcher
LOCALIZATION_DEST_PATH = /Library/PreferenceLoader/Preferences/ProSwitcher/

include framework/makefiles/common.mk

ProSwitcher_PRIVATE_FRAMEWORKS = IOSurface

include framework/makefiles/tweak.mk
include Localization/makefiles/common.mk

endif
