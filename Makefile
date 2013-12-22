export THEOS_DEVICE_IP=10.0.0.14
export TARGET = iphone:clang:7.0
export GO_EASY_ON_ME=1
include theos/makefiles/common.mk

TWEAK_NAME = Lyricalizer
Lyricalizer_FILES = Tweak.xm
Lyricalizer_FRAMEWORKS = MediaPlayer UIKit
Lyricalizer_PRIVATE_FRAMEWORKS = MusicUI
Lyricalizer_LDFLAGS = -lMobileGestalt

include $(THEOS_MAKE_PATH)/tweak.mk
