-include config.mk

BOARD ?= rpi4
PLATFORM ?= v2-hdmi
STAGES ?= __init__ os pikvm-repo watchdog ro no-audit pikvm ssh-keygen __cleanup__

HOSTNAME ?= pikvm
LOCALE ?= en_US
TIMEZONE ?= Europe/Moscow
REPO_URL ?= http://mirror.yandex.ru/archlinux-arm
BUILD_OPTS ?=

WIFI_ESSID ?=
WIFI_PASSWD ?=
WIFI_IFACE ?= wlan0

ROOT_PASSWD ?= root
WEBUI_ADMIN_PASSWD ?= admin
IPMI_ADMIN_PASSWD ?= admin

CARD ?= /dev/mmcblk0


# =====
_BUILDER_DIR = ./.pi-builder

_OS_TARGETS = v0-vga-rpi2 v0-hdmi-rpi2 v0-vga-rpi3 v0-hdmi-rpi3 \
	v1-vga-rpi2 v1-hdmi-rpi2 v1-vga-rpi3 v1-hdmi-rpi3 v2-hdmi-rpi4 v2-hdmi-zerow

define fetch_version
$(shell curl --silent "https://pikvm.org/repos/$(BOARD)/latest/$(1)")
endef


# =====
all:
	@ echo "Available commands:"
	@ echo "    make                # Print this help"
	@ echo
	@ echo "    make os             # Build OS with your default config"
	@ for target in $(_OS_TARGETS); do echo "    make $$target"; done
	@ echo
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make install        # Install rootfs to partitions on $(CARD)"
	@ echo "    make scan           # Find all RPi devices in the local network"
	@ echo "    make clean          # Remove the generated rootfs"
	@ echo "    make clean-all      # Remove the generated rootfs and pi-builder toolchain"


define make_os_target
$1: BOARD:=$(word 3,$(subst -, ,$1))
$1: PLATFORM:=$(word 1,$(subst -, ,$1))-$(word 2,$(subst -, ,$1))
endef
$(foreach target,$(_OS_TARGETS),$(eval $(call make_os_target,$(target))))
$(_OS_TARGETS): os


shell: $(_BUILDER_DIR)
	make -C $(_BUILDER_DIR) shell


os: $(_BUILDER_DIR)
	rm -rf $(_BUILDER_DIR)/stages/pikvm
	cp -a pikvm $(_BUILDER_DIR)/stages
	make -C $(_BUILDER_DIR) os \
		NC=$(NC) \
		BUILD_OPTS=" $(BUILD_OPTS) \
			--build-arg PLATFORM=$(PLATFORM) \
			--build-arg USTREAMER_VERSION=$(call fetch_version,ustreamer) \
			--build-arg KVMD_VERSION=$(call fetch_version,kvmd) \
			--build-arg KVMD_WEBTERM_VERSION=$(call fetch_version,kvmd-webterm) \
			--build-arg WIFI_ESSID='$(WIFI_ESSID)' \
			--build-arg WIFI_PASSWD='$(WIFI_PASSWD)' \
			--build-arg WIFI_IFACE='$(WIFI_IFACE)' \
			--build-arg ROOT_PASSWD='$(ROOT_PASSWD)' \
			--build-arg WEBUI_ADMIN_PASSWD='$(WEBUI_ADMIN_PASSWD)' \
			--build-arg IPMI_ADMIN_PASSWD='$(IPMI_ADMIN_PASSWD)' \
			--build-arg NEW_HTTPS_CERT=$(shell uuidgen) \
		" \
		PROJECT=pikvm-os \
		BOARD=$(BOARD) \
		STAGES='$(STAGES)' \
		HOSTNAME=$(HOSTNAME) \
		LOCALE=$(LOCALE) \
		TIMEZONE=$(TIMEZONE) \
		REPO_URL=$(REPO_URL)


$(_BUILDER_DIR):
	git clone --depth=1 https://github.com/mdevaev/pi-builder $(_BUILDER_DIR)


update: $(_BUILDER_DIR)
	cd $(_BUILDER_DIR) && git pull --rebase
	git pull --rebase


install: $(_BUILDER_DIR)
	make -C $(_BUILDER_DIR) install \
		CARD=$(CARD) \
		CARD_DATA_FS_TYPE=$(if $(findstring v2-hdmi,$(PLATFORM)),ext4,) \
		CARD_DATA_FS_FLAGS=-m0


scan: $(_BUILDER_DIR)
	make -C $(_BUILDER_DIR) scan


clean: $(_BUILDER_DIR)
	make -C $(_BUILDER_DIR) clean


clean-all:
	- make -C $(_BUILDER_DIR) clean-all
	rm -rf $(_BUILDER_DIR)
