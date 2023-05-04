ASM=nasm
CC=gcc

SRC_DIR=src
BUILD_DIR=build
TOOLS_DIR=tools

.PHONY: all image kernel bootloader

#
# Image
#
image: ${BUILD_DIR}/myos.img

${BUILD_DIR}/myos.img: kernel bootloader
	dd if=/dev/zero of=${BUILD_DIR}/myos.img bs=512 count=2880
	newfs_msdos -F 12 -f 2880 $(BUILD_DIR)/myos.img
	dd if=${BUILD_DIR}/bootloader.bin of=${BUILD_DIR}/myos.img conv=notrunc
	mcopy -i ${BUILD_DIR}/myos.img ${BUILD_DIR}/second.bin "::second.bin"
	mcopy -i ${BUILD_DIR}/myos.img ${BUILD_DIR}/kernel.bin "::kernel.bin"

#
# Bootloader
#
bootloader: primary secondary

# PRIMARY
primary: ${BUILD_DIR}/prim.bin

${BUILD_DIR}/prim.bin: always
	${MAKE} -C ${SRC_DIR}/bootloader/primary BUILD_DIR=${abspath ${BUILD_DIR}}

# SECONDARY
secondary: ${BUILD_DIR}/second.bin

${BUILD_DIR}/second.bin: always
	${MAKE} -C ${SRC_DIR}/bootloader/secondary BUILD_DIR=${abspath ${BUILD_DIR}}

#
# Kernel
#
bootloader: ${BUILD_DIR}/kernel.bin

${BUILD_DIR}/kernel.bin: always
	${MAKE} -C ${SRC_DIR}/kernel BUILD_DIR=${abspath ${BUILD_DIR}}

#
# Tools
#
tools_fat: ${BUILD_DIR}/tools/fat
${BUILD_DIR}/tools/fat: always ${TOOLS_DIR}/fat/fat.c
	mkdir -p ${BUILD_DIR}/tools
	${CC} -g -o ${BUILD_DIR}/tools/fat ${TOOLS_DIR}/fat/fat.c

#
# Other
#

# Always
always:
	mkdir -p ${BUILD_DIR}

# Clean
clean:
	rm -rf ${BUILD_DIR}/*