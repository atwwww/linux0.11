# ubuntu22.04 gdb bochs2.6快速搭建linux0.11调试环境 
- 此版本是对原作者的步骤的细化，快速稳定的搭建linux0.11内核调试环境

# 环境：
- ubuntu 22.04 
- gcc 9.5 （sudo apt install gcc-9 g++-9  #之后自行创建gcc软链接）
- make 4.x
- gdb 12.1
- bochs 2.6 (源码自编译而来，带有--enale-gdb-stub)

# 步骤：
## 1. 编译可用于gdb远程连接的bochs
- 链接：https://sourceforge.net/projects/bochs/files/bochs/2.6.11/

- 选择：bochs-2.6.11.tar.gz

- 配置bochs编译参数：
  ```bash
  cd bochs-2.6.11
  
  ./configure --enable-gdb-stub --enable-disasm --prefix='bochs安装目录'
  # 如果是ubuntu的server，即没有图形化界面，则可以加上参数--with-nogui，这样就不会要求图形化库了
  # configure过程中可能会出现缺少软件包，自行搜索安装
  
  make

  make install

  # 现在已经安装好了bochs
  # 可以将bochs可执行文件所在的bin文件添加到环境变量
  export PATH=$PAHT:bochs安装目录/bin

  #创建一个bochsgdb软链接到bochs，这是因为linux0.11中的makefile的bochs-debug指令使用的是bochsgdb
  ln -s bochs安装目录/bin/bochs bochs安装目录/bin/bochsgdb
  ```

## 2. 下载linux0.11源码并进行编译调试
  ```bash
  git clone https://github.com/atwwww/linux0.11.git

  cd linux0.11

  make #编译内核

  tar -xvf hdc-0.11-new.tar.gz #这个文件需要用到

  #《重要，修改 "linux0.11/tools/bochs/bochsrc" 下的 bochsrc-hd-dbg.bxrc 文件》
  “romimage”改为bochs安装目录下的share/bochs/BIOS-bochs-latest
  “vgaromimage”改为bochs安装目录下的share/bochs/VGABIOS-elpin-2.40

  #回到linux0.11执行make子命令，使用bochs提供运行环境
  make bochs-debug

  ################下面需要新开启一个terminal################
  #进入linux源码目录，因为需要用到tools/system文件
  cd linux0.11 

  gdb tools/system #让gdb读取system文件中的符号，并进入gdb

  #以下命令在gdb中
  #设置main断点
  b main 
  
  target remote localhost:1234

  #gdb跳到main断点处
  continue

  #以后就可以愉快的调试了

  #enjoy yourself ^_^
  ```



