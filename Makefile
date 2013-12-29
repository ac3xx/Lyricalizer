export THEOS_DEVICE_IP=10.0.0.5
export TARGET = iphone:clang:7.0
export GO_EASY_ON_ME=1
export ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

TWEAK_NAME = Lyricalizer
Lyricalizer_FILES = Tweak.xm
Lyricalizer_FRAMEWORKS = MediaPlayer UIKit
Lyricalizer_PRIVATE_FRAMEWORKS = MusicUI
Lyricalizer_LDFLAGS = -lMobileGestalt

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Music MobileMusic"