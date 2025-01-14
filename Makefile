# indicate the Hardware Image file
HDA_IMG = ./hdc-0.11-new.img

# indicate the path of the calltree
CALLTREE=$(shell find tools/ -name "calltree" -perm 755 -type f)

# indicate the path of the bochs
#BOCHS=$(shell find tools/ -name "bochs" -perm 755 -type f)
BOCHS=bochs

#
# if you want the ram-disk device, define this to be the
# size in blocks.
#
RAMDISK =  #-DRAMDISK=512

# This is a basic Makefile for setting the general configuration
include Makefile.header

LDFLAGS	+= -Ttext 0 -e startup_32
CFLAGS	+= $(RAMDISK) -Iinclude
CPP	+= -Iinclude

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#
ROOT_DEV= #FLOPPY 

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
DRIVERS =kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
MATH	=kernel/math/math.a
LIBS	=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) -S -o $*.s $<
.s.o:
	$(AS)  -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) -c -o $*.o $<


# 终极目标是构建出一个linux0.11的映像文件
# 之所以成为映像文件，是因为Image需要在真机或者模拟器中才能运行
# 因为Image中包含有bootsect、setup这样的依靠BIOS软件才能运行的启动内容
all:	Image	

# Image依赖于bootsect、setup、system
# bootsect和setup与操作系统的加载有关
# 其中system是真正的内核部分，包括了head（开启分页）、main(第一个C语言也是整个操作系统最重要的函数)
# 这里制作Image文件的步骤是：
# 1. 将system内核拷贝为system.tmp
# 2. 使用strip去除system.tmp中的符号表等调试信息，减小文件大小
# 3. 使用objcopy工具，将system.tmp文件中的.note段和.comment段去除，将结果输出到/tools/kernel
# 4. 运行build.sh脚本，将bootsect和setup以及去除了调试信息的tools/kernel整合为Image，
#			其中ROOT_DEV在本文件中是空的
# 5. 删除system.tmp，tools/kernel
# 6. sync是shell命令，确保在删除 system.tmp 和 tools/kernel 文件之前，将所有的数据写入磁盘
Image: boot/bootsect boot/setup tools/system
	cp -f tools/system system.tmp
	strip system.tmp
	objcopy -O binary -R .note -R .comment system.tmp tools/kernel
	tools/build.sh boot/bootsect boot/setup tools/kernel Image $(ROOT_DEV)
	rm system.tmp
	rm tools/kernel -f
	sync

# disk是将制作的Image拷贝到当前主机的软盘上，linux上软盘的设备文件是/dev/fd0
disk: Image
	dd bs=8192 if=Image of=/dev/fd0

boot/head.o: boot/head.s
	make head.o -C boot/

tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(DRIVERS) \
	$(MATH) \
	$(LIBS) \
	-o tools/system 
	nm tools/system | grep -v '\(compiled\)\|\(\.o$$\)\|\( [aU] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)'| sort > System.map 

init/main.o:init/main.c
	$(CC) $(CFLAGS) -fcf-protection=none -mmanual-endbr -c -o $*.o $<

kernel/math/math.a:
	make -C kernel/math

kernel/blk_drv/blk_drv.a:
	make -C kernel/blk_drv

kernel/chr_drv/chr_drv.a:
	make -C kernel/chr_drv

kernel/kernel.o:FORCE
	make -C kernel

mm/mm.o:FORCE
	make -C mm

fs/fs.o:FORCE
	make -C fs

lib/lib.a:
	make -C lib

boot/setup: boot/setup.s
	make setup -C boot

boot/bootsect: boot/bootsect.s
	make bootsect -C boot

tmp.s:	boot/bootsect.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/bootsect.s >> tmp.s

clean:
	rm -f Image System.map tmp_make core boot/bootsect boot/setup
	rm -f init/*.o tools/system boot/*.o typescript* info bochsout.txt
	for i in mm fs kernel lib boot; do make clean -C $$i; done 
info:
	make clean
	script -q -c "make all"
	cat typescript | col -bp | grep -E "warning|Error" > info
	cat info

distclean: clean
	rm -f tag cscope* linux-0.11.* $(CALLTREE)
	(find tools/calltree-2.3 -name "*.o" | xargs -i rm -f {})
	make clean -C tools/calltree-2.3
	make clean -C tools/bochs/bochs-2.3.7

backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
	sync

.PHONY: FORCE

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	for i in fs kernel mm; do make dep -C $$i; done

tag: tags
tags:
	ctags -R

cscope:
	cscope -Rbkq

run:
#	qemu -m 16M -boot a -fda Image -hda $(HDA_IMG)
	qemu -m 16M -boot a -drive if=floppy,file=Image,format=raw -drive file=$(HDA_IMG),format=raw

debug:
#	qemu -m 16M -boot a -fda Image -hda $(HDA_IMG) -s -S -nographic -serial '/dev/ttyS0'
#	qemu -m 16M -boot a -fda Image -hda $(HDA_IMG) -s -S 
	qemu -m 16M -boot a -drive if=floppy,file=Image,format=raw -drive file=$(HDA_IMG),format=raw -s -S

bochs-run:
	bochs -q -f tools/bochs/bochsrc/bochsrc-hd.bxrc	

bochs-debug:
	bochsgdb -q -f tools/bochs/bochsrc/bochsrc-hd-dbg.bxrc	


cg: callgraph
callgraph:
	calltree -b -np -m init/main.c | tools/tree2dotx > linux-0.11.dot
	dot -Tjpg linux-0.11.dot -o linux-0.11.jpg

help:
	@echo "<<<<This is the basic help info of linux-0.11>>>"
	@echo ""
	@echo "Usage:"
	@echo "     make --generate a kernel floppy Image with a fs on hda1"
	@echo "     make run -- start the kernel in qemu"
	@echo "     make debug -- debug the kernel in qemu & gdb at port 1234"
	@echo "     make disk  -- generate a kernel Image & copy it to floppy"
	@echo "     make cscope -- genereate the cscope index databases"
	@echo "     make tags -- generate the tag file"
	@echo "     make cg -- generate callgraph of the system architecture"
	@echo "     make clean -- clean the object files"
	@echo "     make distclean -- only keep the source code files"
	@echo ""
	@echo "Note!:"
	@echo "     * You need to install the following basic tools:"
	@echo "          ubuntu|debian, qemu|bochs, ctags, cscope, calltree, graphviz "
	@echo "          vim-full, build-essential, hex, dd, gcc 4.3.2..."
	@echo "     * Becarefull to change the compiling options, which will heavily"
	@echo "     influence the compiling procedure and running result."
	@echo ""
	@echo "Author:"
	@echo "     * 1991, linus write and release the original linux 0.95(linux 0.11)."
	@echo "     * 2005, jiong.zhao<gohigh@sh163.net> release a new version "
	@echo "     which can be used in RedHat 9 along with the book 'Explaining "
	@echo "     Linux-0.11 Completly', and he build a site http://www.oldlinux.org"
	@echo "     * 2008, falcon<wuzhangjin@gmail.com> release a new version which can be"
	@echo "     used in ubuntu|debian 32bit|64bit with gcc 4.3.2, and give some new "
	@echo "     features for experimenting. such as this help info, boot/bootsect.s and"
	@echo "     boot/setup.s with AT&T rewritting, porting to gcc 4.3.2 :-)"
	@echo ""
	@echo "<<<Be Happy To Play With It :-)>>>"

### Dependencies:
init/main.o: init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/signal.h include/asm/system.h \
  include/asm/io.h include/stddef.h include/stdarg.h include/fcntl.h
