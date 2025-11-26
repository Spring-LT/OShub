/*
 * COW (Copy on Write) 测试程序
 * 测试fork时的COW机制是否正常工作
 */
#include <ulib.h>
#include <stdio.h>

// 全局变量用于测试COW
int global_var = 100;

int main(void) {
    cprintf("COW Test Program\n");
    cprintf("================\n\n");
    
    // 在栈上分配一个数组
    int stack_var = 200;
    
    cprintf("Before fork:\n");
    cprintf("  global_var = %d (addr: %p)\n", global_var, &global_var);
    cprintf("  stack_var  = %d (addr: %p)\n", stack_var, &stack_var);
    
    int pid = fork();
    
    if (pid < 0) {
        panic("fork failed!\n");
    }
    
    if (pid == 0) {
        // 子进程
        cprintf("\n[Child Process] pid = %d\n", getpid());
        cprintf("  Before write: global_var = %d, stack_var = %d\n", 
                global_var, stack_var);
        
        // 修改变量 - 这应该触发COW
        global_var = 999;
        stack_var = 888;
        
        cprintf("  After write:  global_var = %d, stack_var = %d\n", 
                global_var, stack_var);
        cprintf("[Child] COW test passed!\n");
        exit(0);
    } else {
        // 父进程
        // 等待子进程完成
        int exit_code;
        int child_pid = wait();
        
        cprintf("\n[Parent Process] pid = %d\n", getpid());
        cprintf("  Child (pid=%d) exited\n", child_pid);
        cprintf("  global_var = %d (should still be 100)\n", global_var);
        cprintf("  stack_var  = %d (should still be 200)\n", stack_var);
        
        // 验证父进程的变量没有被修改
        if (global_var == 100 && stack_var == 200) {
            cprintf("\n[Parent] COW test PASSED!\n");
            cprintf("  Parent's variables are unchanged after child's modification.\n");
        } else {
            cprintf("\n[Parent] COW test FAILED!\n");
            cprintf("  Parent's variables were incorrectly modified!\n");
        }
    }
    
    cprintf("\nCOW Test Complete.\n");
    return 0;
}
