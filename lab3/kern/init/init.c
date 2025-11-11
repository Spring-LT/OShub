#include <clock.h>
#include <console.h>
#include <defs.h>
#include <intr.h>
#include <kdebug.h>
#include <kmonitor.h>
#include <pmm.h>
#include <stdio.h>
#include <string.h>
#include <trap.h>
#include <dtb.h>

int kern_init(void) __attribute__((noreturn));
void grade_backtrace(void);

int kern_init(void) {
    extern char edata[], end[];
    // 先清零 BSS，再读取并保存 DTB 的内存信息，避免被清零覆盖（为了解释变化 正式上传时我觉得应该删去这句话）
    memset(edata, 0, end - edata);
    dtb_init();
    cons_init();  // init the console
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);

    print_kerninfo();

    // grade_backtrace();
    idt_init();  // init interrupt descriptor table 第一次中断初始化

    pmm_init();  // init physical memory management 内存管理初始化

    idt_init();  // init interrupt descriptor table 第二次中断初始化

    clock_init();   // init clock interrupt 设置时钟中断和定时器
    intr_enable();  // enable irq interrupt 全局启用系统中断

    /* 触发异常进行测试 - 可以注释掉以禁用异常测试 */
    // 触发断点异常 (ebreak指令)
    cprintf("\n--- 开始测试断点异常 ---\n");
    asm volatile ("ebreak");
    cprintf("--- 断点异常测试完成，程序继续执行 --\n\n");
    
    // 触发非法指令异常 (使用一个RISC-V不支持的指令)
    //cprintf("\n--- 开始测试非法指令异常 ---\n");
    asm volatile (".word 0xdeadbeef");  // 这是一个非法指令
    //cprintf("--- 非法指令异常测试完成，程序继续执行 --\n\n");
    
    /* do nothing */
    while (1)
        ;
}

void __attribute__((noinline))
grade_backtrace2(int arg0, int arg1, int arg2, int arg3) {
    mon_backtrace(0, NULL, NULL);
}

void __attribute__((noinline)) grade_backtrace1(int arg0, int arg1) {
    grade_backtrace2(arg0, (uintptr_t)&arg0, arg1, (uintptr_t)&arg1);
}

void __attribute__((noinline)) grade_backtrace0(int arg0, int arg1, int arg2) {
    grade_backtrace1(arg0, arg2);
}

void grade_backtrace(void) { grade_backtrace0(0, (uintptr_t)kern_init, 0xffff0000); }

