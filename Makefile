ASM=nasm
CC=gcc

SRC_DIR=src
BUILD_DIR=build
TOOLS_DIR=tools

.PHONY: all image kernel bootloader

# Image
image: ${BUILD_DIR}/myos.img

${BUILD_DIR}/myos.img: kernel bootloader
	dd if=/dev/zero of=${BUILD_DIR}/myos.img bs=512 count=2880
	newfs_msdos -F 12 -f 2880 $(BUILD_DIR)/myos.img
	dd if=${BUILD_DIR}/bootloader.bin of=${BUILD_DIR}/myos.img conv=notrunc
	mcopy -i ${BUILD_DIR}/myos.img ${BUILD_DIR}/kernel.bin "::kernel.bin"

# Bootloader
bootloader: ${BUILD_DIR}/bootloader.bin

${BUILD_DIR}/bootloader.bin: always
	${ASM} ${SRC_DIR}/bootloader/main.asm -f bin -o ${BUILD_DIR}/bootloader.bin

# Kernel
bootloader: ${BUILD_DIR}/kernel.bin

${BUILD_DIR}/kernel.bin: always
	${ASM} ${SRC_DIR}/kernel/main.asm -f bin -o ${BUILD_DIR}/kernel.bin

# Tools
tools_fat: ${BUILD_DIR}/tools/fat
${BUILD_DIR}/tools/fat: always ${TOOLS_DIR}/fat/fat.c
	mkdir -p ${BUILD_DIR}/tools
	${CC} -g -o ${BUILD_DIR}/tools/fat ${TOOLS_DIR}/fat/fat.c

# Always
always:
	mkdir -p ${BUILD_DIR}

# Clean
clean:
	rm -rf ${BUILD_DIR}/*