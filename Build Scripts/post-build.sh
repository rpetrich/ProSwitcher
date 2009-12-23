#!/bin/sh

# Assembles File System Layout for all platforms
# For Device, additionally creates package if DebMaker is installed
#     and copies to /Volumes/iPhone/ if available
# For Simulator, copies dylib into DynamicLibraries and restarts the
#     simulator app with MobileSubstrate activated

rm -rf "${TARGET_BUILD_DIR}/File System/"
cp -R "${PROJECT_DIR}/File System/" "${TARGET_BUILD_DIR}/File System/"
find "${TARGET_BUILD_DIR}/File System/" -name '._*' -or -name '.DS_Store' -delete
cp "${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}" "${TARGET_BUILD_DIR}/File System/Library/MobileSubstrate/DynamicLibraries/${EXECUTABLE_NAME}.dylib"

if [ "${PLATFORM_NAME}" == "iphoneos" ]; then
	if [ -e /Applications/DebMaker.app/Contents/Resources/dpkg-deb ]; then
		mkdir "${TARGET_BUILD_DIR}/File System/DEBIAN"
		cp "${PROJECT_DIR}/Packaging/control" "${PROJECT_DIR}/Packaging/preinst" "${PROJECT_DIR}/Packaging/prerm" "${TARGET_BUILD_DIR}/File System/DEBIAN/"
		PACKAGE_NAME=$(grep ^Package: ${PROJECT_DIR}/Packaging/control | cut -d ' ' -f 2)
		PACKAGE_VERSION=$(grep ^Version: ${PROJECT_DIR}/Packaging/control | cut -d ' ' -f 2)
		rm -rf "${TARGET_BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_iphoneos-arm.deb"
		/Applications/DebMaker.app/Contents/Resources/dpkg-deb -b "${TARGET_BUILD_DIR}/File System" "${TARGET_BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_iphoneos-arm.deb" 2> /dev/null
		rm -rf "${PROJECT_DIR}/${PACKAGE_NAME}_latest_iphoneos-arm.deb"
		ln -s "${TARGET_BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_iphoneos-arm.deb" "${PROJECT_DIR}/${PACKAGE_NAME}_latest_iphoneos-arm.deb"
		if [ -e /Volumes/iPhone/ ]; then
			rm -rf "/Volumes/iPhone/${PACKAGE_NAME}_latest_iphoneos-arm.deb"
			cp "${PROJECT_DIR}/${PACKAGE_NAME}_latest_iphoneos-arm.deb" /Volumes/iPhone/
		fi
	fi
fi

if [ "${PLATFORM_NAME}" == "iphonesimulator" ]; then
	if [ -e /Library/MobileSubstrate/ ]; then
		rm -rf /Library/MobileSubstrate/DynamicLibraries/${EXECUTABLE_NAME}.dylib;
		ln -s "${TARGET_BUILD_DIR}/File System/Library/MobileSubstrate/DynamicLibraries/${EXECUTABLE_NAME}.dylib" /Library/MobileSubstrate/DynamicLibraries/${EXECUTABLE_NAME}.dylib;
		killall "iPhone Simulator"
		export DYLD_INSERT_LIBRARIES=/Library/MobileSubstrate/MobileSubstrate.dylib
		open "/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone Simulator.app"
	fi
fi