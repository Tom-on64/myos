ASM=nasm

SRC_DIR=src
BUILD_DIR=build

${BUILD_DIR}/myos.img: ${BUILD_DIR}/main.bin
	cp ${BUILD_DIR}/main.bin ${BUILD_DIR}/myos.img
	truncate -s 1440k ${BUILD_DIR}/myos.img

${BUILD_DIR}/main.bin: ${SRC_DIR}/main.asm
	${ASM} -f bin ${SRC_DIR}/main.asm -o ${BUILD_DIR}/main.bin