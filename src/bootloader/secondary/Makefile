ASM?=nasm
BUILD_DIR?=build

.PHONY: all secondary clean

all: secondary

secondary: ${BUILD_DIR}/second.bin

${BUILD_DIR}/second.bin:
	${ASM} main.asm -f bin -o ${BUILD_DIR}/second.bin

clean:
	rm -f ${BUILD_DIR}/second.bin