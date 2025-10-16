#include <mmu.h>
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid # hartid当前运行的线程ID
    sd a0, 0(t0) # 保存当前运行的线程ID
    la t0, boot_dtb # 设备树blob的物理地址
    sd a1, 0(t0) # 保存设备树blob的物理地址到$a1

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39) # 存储了根页表的虚拟地址
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12 # 去除页内偏移

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60 # 8 表示 Sv39 模式
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1 # 页表物理页号与模式位组合成完整的 satp 值
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0 # 写入 satp 寄存器，切换到新的页表
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma # 刷新 TLB，使新的页表生效
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop) # 设置栈指针为 bootstacktop，即栈的顶部
    addi sp, sp, %lo(bootstacktop) # 栈指针加上页内偏移，指向栈的顶部

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init) # 加载 kern_init 的高 20 位到 t0
    addi t0, t0, %lo(kern_init) # 加载 kern_init 的低 12 位到 t0
    jr t0 # 跳转到 t0 指向的地址，即 kern_init

.section .data
    # .align 2^12
    .align PGSHIFT
    .global bootstack
bootstack:
    .space KSTACKSIZE
    .global bootstacktop
bootstacktop:

.section .data
    # 由于我们要把这个页表放到一个页里面，因此必须 12 位对齐
    .align PGSHIFT
    .global boot_page_table_sv39
# 分配 4KiB 内存给预设的三级页表
boot_page_table_sv39:
    # 0xffffffff_c0000000 map to 0x80000000 (1G)
    # 前 511 个页表项均设置为 0 ，因此 V=0 ，意味着是空的(unmapped)
    .zero 8 * 511
    # 设置最后一个页表项，PPN=0x80000，标志位 VRWXAD 均为 1
    .quad (0x80000 << 10) | 0xcf # VRWXAD

    .global boot_hartid
boot_hartid:
    .quad 0
    .global boot_dtb
boot_dtb:
    .quad 0
