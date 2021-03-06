csrc = $(wildcard src/*.c) $(wildcard src/libc/*.c) $(wildcard src/test/*.c)
ssrc = $(wildcard src/*.s) $(wildcard src/libc/*.s) $(wildcard src/boot/*.s)
Ssrc = $(wildcard src/*.S)
obj = $(csrc:.c=.o) $(ssrc:.s=.o) $(Ssrc:.S=.o)
dep = $(obj:.o=.d)
elf = test
bin = test.bin

warn = -pedantic -Wall
#opt = -O2
dbg = -g
inc = -Isrc -Isrc/libc -Isrc/test
gccopt = -fno-pic -ffreestanding -nostdinc -fno-builtin

CFLAGS = $(ccarch) -march=i386 $(warn) $(opt) $(dbg) $(gccopt) $(inc) $(def)
ASFLAGS = $(asarch) -march=i386 $(dbg) -nostdinc -fno-builtin $(inc)
LDFLAGS = $(ldarch) -nostdlib -T pcboot.ld -print-gc-sections


ifneq ($(shell uname -m), i386)
	ccarch = -m32
	asarch = --32
	ldarch = -m elf_i386
endif

floppy.img: boot.img
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ conv=notrunc

boot.img: bootldr.bin $(bin)
	cat bootldr.bin $(bin) >$@

# bootldr.bin will contain only .boot and .boot2
bootldr.bin: $(elf)
	objcopy -O binary -j '.boot*' $< $@

# the main binary will contain every section *except* .boot and .boot2
$(bin): $(elf)
	objcopy -O binary -R '.boot*' $< $@

$(elf): $(obj)
	$(LD) -o $@ $(obj) -Map link.map $(LDFLAGS)

%.o: %.S
	$(CC) -o $@ $(CFLAGS) -c $<

-include $(dep)

%.d: %.c
	@$(CPP) $(CFLAGS) $< -MM -MT $(@:.d=.o) >$@

.PHONY: clean
clean:
	rm -f $(obj) $(bin) boot.img floppy.img link.map

.PHONY: cleandep
cleandep:
	rm -f $(dep)

.PHONY: disasm
disasm: bootldr.disasm $(elf).disasm

bootldr.disasm: $(elf)
	objdump -d $< -j .boot -j .boot2 -m i8086 >$@

$(elf).disasm: $(elf)
	objdump -d $< -j .startup -j .text -m i386 >$@

$(elf).sym: $(elf)
	objcopy --only-keep-debug $< $@

.PHONY: run
run: $(bin)
	qemu-system-i386 -fda floppy.img -serial file:serial.log

.PHONY: debug
debug: $(bin) $(elf).sym
	qemu-system-i386 -fda floppy.img -serial file:serial.log -s -S

.PHONY: sym
sym: $(elf).sym
