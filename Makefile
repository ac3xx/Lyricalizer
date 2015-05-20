export THEOS_DEVICE_IP=129.31.183.149
export TARGET = iphone:clang:8.3
export GO_EASY_ON_ME=1
export ARCHS = armv7 arm64
export THEOS_BUILD_DIR = ./debs
export PACKAGE_VERSION = 1.4.2

include theos/makefiles/common.mk

TWEAK_NAME = Lyricalizer
Lyricalizer_FILES = Tweak.xm LYManager.m
Lyricalizer_FRAMEWORKS = MediaPlayer UIKit
Lyricalizer_PRIVATE_FRAMEWORKS = MusicUI MediaPlayerUI

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Music MobileMusic Spotify"