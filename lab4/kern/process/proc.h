#ifndef __KERN_PROCESS_PROC_H__
#define __KERN_PROCESS_PROC_H__

#include <defs.h>
#include <list.h>
#include <trap.h>
#include <memlayout.h>

// process's state in his life cycle
// 进程状态枚举
// 对应指导书"设计关键数据结构"中的进程状态转换图
enum proc_state
{
    PROC_UNINIT = 0, // uninitialized - 未初始化状态，alloc_proc 后的初始状态
    PROC_SLEEPING,   // sleeping - 睡眠状态，等待某个事件
    PROC_RUNNABLE,   // runnable(maybe running) - 就绪状态，可被调度执行
    PROC_ZOMBIE,     // almost dead - 僵尸状态，等待父进程回收资源
};

// 进程上下文结构，用于进程切换时保存/恢复寄存器
// 对应指导书"练习1"中关于 context 的说明
// 功能：保存调度级别的上下文，由 switch_to() 使用
// 只保存 callee-saved 寄存器：ra(返回地址), sp(栈指针), s0-s11
struct context
{
    uintptr_t ra;   // 返回地址寄存器
    uintptr_t sp;   // 栈指针寄存器
    uintptr_t s0;   // callee-saved 寄存器 s0-s11
    uintptr_t s1;
    uintptr_t s2;
    uintptr_t s3;
    uintptr_t s4;
    uintptr_t s5;
    uintptr_t s6;
    uintptr_t s7;
    uintptr_t s8;
    uintptr_t s9;
    uintptr_t s10;
    uintptr_t s11;
};

#define PROC_NAME_LEN 15
#define MAX_PROCESS 4096
#define MAX_PID (MAX_PROCESS * 2)

extern list_entry_t proc_list;

// 进程控制块（PCB）
// 对应指导书"设计关键数据结构 - 进程控制块"章节
// 功能：存储进程/线程的所有管理信息
struct proc_struct
{
    enum proc_state state;        // Process state - 进程状态（UNINIT/SLEEPING/RUNNABLE/ZOMBIE）
    int pid;                      // Process ID - 进程 ID，由 get_pid() 分配
    int runs;                     // the running times of Proces - 运行次数计数
    uintptr_t kstack;             // Process kernel stack - 内核栈的虚拟地址
    volatile bool need_resched;   // bool value: need to be rescheduled to release CPU? - 是否需要调度
    struct proc_struct *parent;   // the parent process - 父进程指针
    struct mm_struct *mm;         // Process's memory management field - 进程的内存管理信息（内核线程为 NULL）
    struct context context;       // Switch here to run process - 调度上下文，用于 switch_to
    struct trapframe *tf;         // Trap frame for current interrupt - 中断帧，保存陷入内核时的 CPU 状态
    uintptr_t pgdir;              // the base addr of Page Directroy Table(PDT) - 页表基址（物理地址）
    uint32_t flags;               // Process flag - 进程标志位
    char name[PROC_NAME_LEN + 1]; // Process name - 进程名称
    list_entry_t list_link;       // Process link list - 挂在 proc_list 上的链表节点
    list_entry_t hash_link;       // Process hash list - 挂在 hash_list 上的链表节点
};

#define le2proc(le, member) \
    to_struct((le), struct proc_struct, member)

extern struct proc_struct *idleproc, *initproc, *current;

void proc_init(void);
void proc_run(struct proc_struct *proc);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);

char *set_proc_name(struct proc_struct *proc, const char *name);
char *get_proc_name(struct proc_struct *proc);
void cpu_idle(void) __attribute__((noreturn));

struct proc_struct *find_proc(int pid);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
int do_exit(int error_code);

#endif /* !__KERN_PROCESS_PROC_H__ */
