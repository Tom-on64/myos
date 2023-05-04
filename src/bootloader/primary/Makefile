ASM?=nasm
BUILD_DIR?=build

.PHONY: all primary clean

all: primary

primary: ${BUILD_DIR}/prim.bin

${BUILD_DIR}/prim.bin:
	${ASM} boot.asm -f bin -o ${BUILD_DIR}/prim.bin

clean:
	rm -f ${BUILD_DIR}/prim.bin