BUILD_DIR=_build
KERNEL_DIR=$(BUILD_DIR)/kernel
KERNEL_VERSION=linux-5.12.10
KERNEL=$(KERNEL_DIR)/$(KERNEL_VERSION)
KERNEL_ARCHIVE=$(KERNEL_VERSION).tar.xz
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_ARCHIVE)
BZIMAGE=$(KERNEL)/arch/x86_64/boot/bzImage
ROOTFS=docker_diff.qcow2
LOCALHOST_SSH_PORT=2210

.PHONY: all
all: build

.PHONY: build
build: $(BUILD_DIR)/$(ROOTFS) $(BZIMAGE)

$(BZIMAGE): $(KERNEL)/.config
	cd $(KERNEL) && \
	make olddefconfig && \
	make -j8

$(KERNEL)/.config: $(KERNEL)
	wget -O $(KERNEL)/.config https://mergeboard.com/files/blog/qemu-microvm/defconfig

$(KERNEL): $(KERNEL_DIR)/$(KERNEL_ARCHIVE)
	cd $(KERNEL_DIR) && \
	tar -xf $(KERNEL_ARCHIVE)

$(KERNEL_DIR)/$(KERNEL_ARCHIVE):
	mkdir -p $(KERNEL_DIR)
	cd $(KERNEL_DIR) && \
	wget $(KERNEL_URL) 

$(BUILD_DIR)/$(ROOTFS): Dockerfile $(BUILD_DIR)/init
	cd $(BUILD_DIR) && \
	DOCKER_BUILDKIT=1 docker build --output "type=tar,dest=docker.tar" .. && \
	virt-make-fs --format=qcow2 --size=+200M docker.tar docker_large.qcow2 && \
	qemu-img convert docker_large.qcow2 -O qcow2 docker.qcow2 && \
	qemu-img create -f qcow2 -b docker.qcow2 -F qcow2 docker_diff.qcow2

$(BUILD_DIR)/init: init.c
	mkdir -p $(BUILD_DIR)
	gcc -Wall -o $@ -static $<

.PHONY: launch
launch: $(BUILD_DIR)/$(ROOTFS) $(BZIMAGE)
	qemu-system-x86_64 \
		-M microvm,x-option-roms=off,isa-serial=off,rtc=off \
		-m 512 \
		-no-acpi \
		-enable-kvm \
		-cpu host \
		-nodefaults \
		-no-user-config \
		-nographic \
		-no-reboot \
		-device virtio-serial-device \
		-chardev stdio,id=virtiocon0 \
		-device virtconsole,chardev=virtiocon0 \
		-kernel $(BZIMAGE) \
		-append "console=hvc0 root=/dev/vda rw acpi=off reboot=t panic=-1 quiet" \
		-drive id=root,file=$(BUILD_DIR)/$(ROOTFS),format=qcow2,if=none \
		-device virtio-blk-device,drive=root \
		-netdev user,id=mynet0,hostfwd=tcp:127.0.0.1:$(LOCALHOST_SSH_PORT)-10.0.2.15:22 \
		-device virtio-net-device,netdev=mynet0 \
		-fsdev local,path=share,security_model=none,id=share,readonly \
		-device virtio-9p-device,fsdev=share,mount_tag=share \
		-device virtio-rng-device

.PHONY: run
run: share/tests
	ssh root@localhost -p $(LOCALHOST_SSH_PORT) 'cd /mnt/share/tests && pytest -o cache_dir=/tmp'

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
