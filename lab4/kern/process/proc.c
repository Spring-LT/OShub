#include <proc.h>
#include <kmalloc.h>
#include <string.h>
#include <sync.h>
#include <pmm.h>
#include <error.h>
#include <sched.h>
#include <elf.h>
#include <vmm.h>
#include <trap.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

/* ------------- process/thread mechanism design&implementation -------------
(an simplified Linux process/thread mechanism )
introduction:
  ucore implements a simple process/thread mechanism. process contains the independent memory sapce, at least one threads
for execution, the kernel data(for management), processor state (for context switch), files(in lab6), etc. ucore needs to
manage all these details efficiently. In ucore, a thread is just a special kind of process(share process's memory).
------------------------------
process state       :     meaning               -- reason
    PROC_UNINIT     :   uninitialized           -- alloc_proc
    PROC_SLEEPING   :   sleeping                -- try_free_pages, do_wait, do_sleep
    PROC_RUNNABLE   :   runnable(maybe running) -- proc_init, wakeup_proc,
    PROC_ZOMBIE     :   almost dead             -- do_exit

-----------------------------
process state changing:

  alloc_proc                                 RUNNING
      +                                   +--<----<--+
      +                                   + proc_run +
      V                                   +-->---->--+
PROC_UNINIT -- proc_init/wakeup_proc --> PROC_RUNNABLE -- try_free_pages/do_wait/do_sleep --> PROC_SLEEPING --
                                           A      +                                                           +
                                           |      +--- do_exit --> PROC_ZOMBIE                                +
                                           +                                                                  +
                                           -----------------------wakeup_proc----------------------------------
-----------------------------
process relations
parent:           proc->parent  (proc is children)
children:         proc->cptr    (proc is parent)
older sibling:    proc->optr    (proc is younger sibling)
younger sibling:  proc->yptr    (proc is older sibling)
-----------------------------
related syscall for process:
SYS_exit        : process exit,                           -->do_exit
SYS_fork        : create child process, dup mm            -->do_fork-->wakeup_proc
SYS_wait        : wait process                            -->do_wait
SYS_exec        : after fork, process execute a program   -->load a program and refresh the mm
SYS_clone       : create child thread                     -->do_fork-->wakeup_proc
SYS_yield       : process flag itself need resecheduling, -- proc->need_sched=1, then scheduler will rescheule this process
SYS_sleep       : process sleep                           -->do_sleep
SYS_kill        : kill process                            -->do_kill-->proc->flags |= PF_EXITING
                                                                 -->wakeup_proc-->do_wait-->do_exit
SYS_getpid      : get the process's pid

*/

// the process set's list
// 全局进程链表，用于顺序遍历所有进程（调度时使用）
// 对应指导书"内核线程管理"章节，用于进程管理
list_entry_t proc_list;

#define HASH_SHIFT 10
#define HASH_LIST_SIZE (1 << HASH_SHIFT)
#define pid_hashfn(x) (hash32(x, HASH_SHIFT))

// has list for process set based on pid
// 哈希表，用于快速根据 pid 查找进程
// 实现在 find_proc() 函数中，对应指导书"设计关键数据结构"部分
static list_entry_t hash_list[HASH_LIST_SIZE];

// idle proc
// 第0个内核线程 idleproc，在 proc_init() 中创建
// 对应指导书"实验执行流程概述"，作用是系统空闲时的占位线程
struct proc_struct *idleproc = NULL;
// init proc
// 第1个内核线程 initproc，通过 kernel_thread() 创建
// 对应指导书"实验执行流程概述"，用于验证线程创建和调度机制
struct proc_struct *initproc = NULL;
// current proc
// 当前正在运行的进程指针，在 proc_run() 中切换
struct proc_struct *current = NULL;

// 当前系统中的进程总数
static int nr_process = 0;

// 内核线程入口函数，定义在 kern/process/entry.S
// 对应指导书"项目组成"中的 entry.S 说明
void kernel_thread_entry(void);
// fork 返回处理函数，定义在 kern/trap/trapentry.S
// 对应指导书"项目组成"中的 trapentry.S 说明
void forkrets(struct trapframe *tf);
// 上下文切换函数，定义在 kern/process/switch.S
// 对应指导书"项目组成"，实现进程间的 context 切换
void switch_to(struct context *from, struct context *to);

// alloc_proc - alloc a proc_struct and init all fields of proc_struct
// 分配并初始化一个进程控制块
// 对应指导书"练习1：分配并初始化一个进程控制块"
// 功能：使用 kmalloc 分配 proc_struct，并初始化所有字段到合理的初始状态
// 实现位置：kern/process/proc.c:86
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        // LAB4:EXERCISE1 YOUR CODE
        /*
         * below fields in proc_struct need to be initialized
         *       enum proc_state state;                      // Process state
         *       int pid;                                    // Process ID
         *       int runs;                                   // the running times of Proces
         *       uintptr_t kstack;                           // Process kernel stack
         *       volatile bool need_resched;                 // bool value: need to be rescheduled to release CPU?
         *       struct proc_struct *parent;                 // the parent process
         *       struct mm_struct *mm;                       // Process's memory management field
         *       struct context context;                     // Switch here to run process
         *       struct trapframe *tf;                       // Trap frame for current interrupt
         *       uintptr_t pgdir;                            // the base addr of Page Directroy Table(PDT)
         *       uint32_t flags;                             // Process flag
         *       char name[PROC_NAME_LEN + 1];               // Process name
         */
        proc->state = PROC_UNINIT;                          // 设置进程为未初始化状态
        proc->pid = -1;                                     // 未初始化的进程id为-1
        proc->runs = 0;                                     // 初始化运行时间为0
        proc->kstack = 0;                                   // 内核栈地址初始化为0
        proc->need_resched = 0;                             // 不需要调度
        proc->parent = NULL;                                // 父进程为空
        proc->mm = NULL;                                    // 虚拟内存管理为空
        memset(&(proc->context), 0, sizeof(struct context)); // 初始化上下文
        proc->tf = NULL;                                    // 中断帧指针为空
        proc->pgdir = boot_pgdir_pa;                        // 页目录设为内核页目录的物理地址
        proc->flags = 0;                                    // 标志位为0
        memset(proc->name, 0, PROC_NAME_LEN + 1);          // 进程名初始化为0
    }
    return proc;
}

// set_proc_name - set the name of proc
char *
set_proc_name(struct proc_struct *proc, const char *name)
{
    memset(proc->name, 0, sizeof(proc->name));
    return memcpy(proc->name, name, PROC_NAME_LEN);
}

// get_proc_name - get the name of proc
char *
get_proc_name(struct proc_struct *proc)
{
    static char name[PROC_NAME_LEN + 1];
    memset(name, 0, sizeof(name));
    return memcpy(name, proc->name, PROC_NAME_LEN);
}

// get_pid - alloc a unique pid for process
// 为新进程分配唯一的 pid
// 对应指导书"练习2"中关于 pid 唯一性的问题
// 功能：遍历 proc_list，找到一个未被占用的 pid
// 实现位置：kern/process/proc.c:142
static int
get_pid(void)
{
    static_assert(MAX_PID > MAX_PROCESS);
    struct proc_struct *proc;
    list_entry_t *list = &proc_list, *le;
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID)
    {
        last_pid = 1;
        goto inside;
    }
    if (last_pid >= next_safe)
    {
    inside:
        next_safe = MAX_PID;
    repeat:
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid)
            {
                if (++last_pid >= next_safe)
                {
                    if (last_pid >= MAX_PID)
                    {
                        last_pid = 1;
                    }
                    next_safe = MAX_PID;
                    goto repeat;
                }
            }
            else if (proc->pid > last_pid && next_safe > proc->pid)
            {
                next_safe = proc->pid;
            }
        }
    }
    return last_pid;
}

// proc_run - make process "proc" running on cpu
// NOTE: before call switch_to, should load  base addr of "proc"'s new PDT
// 将指定进程切换到 CPU 上运行
// 对应指导书"练习3：编写 proc_run 函数"
// 功能：关中断 -> 切换 current -> 切换页表(satp) -> switch_to 切换上下文 -> 开中断
// 实现位置：kern/process/proc.c:185
void proc_run(struct proc_struct *proc)
{
    if (proc != current)
    {
        // LAB4:EXERCISE3 YOUR CODE
        /*
         * Some Useful MACROs, Functions and DEFINEs, you can use them in below implementation.
         * MACROs or Functions:
         *   local_intr_save():        Disable interrupts
         *   local_intr_restore():     Enable Interrupts
         *   lsatp():                   Modify the value of satp register
         *   switch_to():              Context switching between two processes
         */
        bool intr_flag;
        struct proc_struct *prev = current, *next = proc;
        
        // 禁用中断
        local_intr_save(intr_flag);
        {
            // 切换当前进程为要运行的进程
            current = proc;
            
            // 切换页表，以便使用新进程的地址空间
            lsatp(next->pgdir);
            
            // 实现上下文切换
            switch_to(&(prev->context), &(next->context));
        }
        // 允许中断
        local_intr_restore(intr_flag);
    }
}

// forkret -- the first kernel entry point of a new thread/process
// NOTE: the addr of forkret is setted in copy_thread function
//       after switch_to, the current proc will execute here.
// 新线程/进程的第一个内核入口点
// 对应指导书"内核线程管理"章节
// 功能：新进程第一次被调度时，从这里开始执行，调用 forkrets 恢复 trapframe
// 实现位置：kern/process/proc.c:222
static void
forkret(void)
{
    forkrets(current->tf);
}

// hash_proc - add proc into proc hash_list
// 将进程添加到 hash_list 中，便于通过 pid 快速查找
// 对应指导书"设计关键数据结构"中的哈希表管理
// 实现位置：kern/process/proc.c:229
static void
hash_proc(struct proc_struct *proc)
{
    list_add(hash_list + pid_hashfn(proc->pid), &(proc->hash_link));
}

// find_proc - find proc frome proc hash_list according to pid
// 根据 pid 从哈希表中查找进程
// 对应指导书"设计关键数据结构"，使用哈希表实现 O(1) 平均查找
// 实现位置：kern/process/proc.c:236
struct proc_struct *
find_proc(int pid)
{
    if (0 < pid && pid < MAX_PID)
    {
        list_entry_t *list = hash_list + pid_hashfn(pid), *le = list;
        while ((le = list_next(le)) != list)
        {
            struct proc_struct *proc = le2proc(le, hash_link);
            if (proc->pid == pid)
            {
                return proc;
            }
        }
    }
    return NULL;
}

// kernel_thread - create a kernel thread using "fn" function
// NOTE: the contents of temp trapframe tf will be copied to
//       proc->tf in do_fork-->copy_thread function
// 创建内核线程
// 对应指导书"内核线程管理"章节
// 功能：构造 trapframe，设置 epc 为 kernel_thread_entry，调用 do_fork 创建线程
// 实现位置：kern/process/proc.c:294
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
    struct trapframe tf; // 描述了CPU在某个时刻完整的状态快照，处理中断/异常
    memset(&tf, 0, sizeof(struct trapframe)); // 从“全0”状态开始够造
    tf.gpr.s0 = (uintptr_t)fn; // 将线程入口函数指针 fn 放到寄存器 s0；
    tf.gpr.s1 = (uintptr_t)arg; // 把参数 arg 放到寄存器 s1；
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE; // 设置初始状态

    /*
    SSTATUS_SPP：设置“从 S 模式返回时仍然回到 S 模式”（即内核模式），因为内核线程只在内核态跑；
    SSTATUS_SPIE：保证返回后中断是开启的；
    ~SSTATUS_SIE：当前陷入内核时先关中断。
    */

    tf.epc = (uintptr_t)kernel_thread_entry; // 设置起始PC，新线程第一次被恢复运行时，将从 kernel_thread_entry 这行指令开始执行；
    return do_fork(clone_flags | CLONE_VM, 0, &tf); // 调用 do_fork，这个函数在386行左右，下面
    /* 
    clone_flags | CLONE_VM：表示新内核线程和当前线程共享页表（CLONE_VM），这在内核线程间是合理的；
    stack = 0：说明是内核线程，不需要用户栈；
    &tf：把刚才构造好的 trapframe 传下去。
    */
}

// setup_kstack - alloc pages with size KSTACKPAGE as process kernel stack
// 为进程分配内核栈
// 对应指导书"练习2"中 do_fork 的步骤2
// 功能：分配 KSTACKPAGE 个页面作为内核栈，设置 proc->kstack
// 实现位置：kern/process/proc.c:307
static int
setup_kstack(struct proc_struct *proc)
{
    struct Page *page = alloc_pages(KSTACKPAGE);
    if (page != NULL)
    {
        proc->kstack = (uintptr_t)page2kva(page);
        return 0;
    }
    return -E_NO_MEM;
}

// put_kstack - free the memory space of process kernel stack
// 释放进程的内核栈
// 功能：释放 proc->kstack 对应的物理页面
// 实现位置：kern/process/proc.c:320
static void
put_kstack(struct proc_struct *proc)
{
    free_pages(kva2page((void *)(proc->kstack)), KSTACKPAGE);
}

// copy_mm - process "proc" duplicate OR share process "current"'s mm according clone_flags
//         - if clone_flags & CLONE_VM, then "share" ; else "duplicate"
// 复制或共享内存管理信息
// 对应指导书"练习2"中 do_fork 的步骤3
// 功能：根据 clone_flags 决定是复制还是共享 mm_struct（本实验中内核线程无 mm，直接返回0）
// 实现位置：kern/process/proc.c:328
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    assert(current->mm == NULL);
    /* do nothing in this project */
    return 0;
}

// copy_thread - setup the trapframe on the  process's kernel stack top and
//             - setup the kernel entry point and stack of process
// 设置进程的 trapframe 和 context
// 对应指导书"练习2"中 do_fork 的步骤4
// 功能：将 tf 拷贝到新进程内核栈顶，设置 a0=0（子进程返回值），context.ra=forkret
// 实现位置：kern/process/proc.c:338
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf)
{
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE - sizeof(struct trapframe));
    *(proc->tf) = *tf;

    // Set a0 to 0 so a child process knows it's just forked
    proc->tf->gpr.a0 = 0;
    proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;

    proc->context.ra = (uintptr_t)forkret;
    proc->context.sp = (uintptr_t)(proc->tf);
}

/* do_fork -     parent process for a new child process
 * @clone_flags: used to guide how to clone the child process
 * @stack:       the parent's user stack pointer. if stack==0, It means to fork a kernel thread.
 * @tf:          the trapframe info, which will be copied to child process's proc->tf
 */
// 创建子进程/线程的核心函数
// 对应指导书"练习2：为新创建的内核线程分配资源"
// 功能：完整的 fork 流程，包括分配 PCB、内核栈、复制 mm、设置上下文、加入链表、唤醒
// 实现位置：kern/process/proc.c:356
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    if (nr_process >= MAX_PROCESS)
    {
        goto fork_out;
    }
    ret = -E_NO_MEM;
    // LAB4:EXERCISE2 2312092
    /*
     * Some Useful MACROs, Functions and DEFINEs, you can use them in below implementation.
     * MACROs or Functions:
     *   alloc_proc:   create a proc struct and init fields (lab4:exercise1)
     *   setup_kstack: alloc pages with size KSTACKPAGE as process kernel stack
     *   copy_mm:      process "proc" duplicate OR share process "current"'s mm according clone_flags
     *                 if clone_flags & CLONE_VM, then "share" ; else "duplicate"
     *   copy_thread:  setup the trapframe on the  process's kernel stack top and
     *                 setup the kernel entry point and stack of process
     *   hash_proc:    add proc into proc hash_list
     *   get_pid:      alloc a unique pid for process
     *   wakeup_proc:  set proc->state = PROC_RUNNABLE
     * VARIABLES:
     *   proc_list:    the process set's list
     *   nr_process:   the number of process set
     */

    //    1. call alloc_proc to allocate a proc_struct
    //    2. call setup_kstack to allocate a kernel stack for child process
    //    3. call copy_mm to dup OR share mm according clone_flag
    //    4. call copy_thread to setup tf & context in proc_struct
    //    5. insert proc_struct into hash_list && proc_list
    //    6. call wakeup_proc to make the new child process RUNNABLE
    //    7. set ret vaule using child proc's pid
    
    // 1. 调用alloc_proc分配一个proc_struct
    if ((proc = alloc_proc()) == NULL) {
        goto fork_out;
    }
    
    // 设置父进程
    proc->parent = current;
    
    // 2. 调用setup_kstack为子进程分配内核栈
    if (setup_kstack(proc) != 0) {
        goto bad_fork_cleanup_proc;
    }
    
    // 3. 调用copy_mm根据clone_flag复制或共享内存管理信息
    if (copy_mm(clone_flags, proc) != 0) {
        goto bad_fork_cleanup_kstack;
    }
    
    // 4. 调用copy_thread设置进程的trapframe和context
    copy_thread(proc, stack, tf);
    
    // 5. 将proc_struct插入hash_list和proc_list
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        proc->pid = get_pid();
        hash_proc(proc);
        list_add(&proc_list, &(proc->list_link));
        nr_process++;
    }
    local_intr_restore(intr_flag);
    
    // 6. 调用wakeup_proc使新子进程变为RUNNABLE
    wakeup_proc(proc);
    
    // 7. 使用子进程的pid设置返回值
    ret = proc->pid;
    
fork_out:
    return ret;

bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}

// do_exit - called by sys_exit
//   1. call exit_mmap & put_pgdir & mm_destroy to free the almost all memory space of process
//   2. set process' state as PROC_ZOMBIE, then call wakeup_proc(parent) to ask parent reclaim itself.
//   3. call scheduler to switch to other process
// 进程退出函数（本实验未实现）
// 功能：释放进程资源，设置为 ZOMBIE 状态，唤醒父进程
// 实现位置：kern/process/proc.c:443
int do_exit(int error_code)
{
    panic("process exit!!.\n");
}

// init_main - the second kernel thread used to create user_main kernel threads
// initproc 的主函数
// 对应指导书"实验执行流程概述"，第1个真正的内核线程要执行的函数
// 功能：打印 "Hello world!!" 等信息，验证线程创建和调度机制
// 实现位置：kern/process/proc.c:450
static int
init_main(void *arg)
{
    cprintf("this initproc, pid = %d, name = \"%s\"\n", current->pid, get_proc_name(current));
    cprintf("To U: \"%s\".\n", (const char *)arg);
    cprintf("To U: \"en.., Bye, Bye. :)\"\n");
    return 0;
}

// proc_init - set up the first kernel thread idleproc "idle" by itself and
//           - create the second kernel thread init_main
// 进程管理初始化函数
// 对应指导书"实验执行流程概述"中的 proc_init() 调用
// 功能：初始化 proc_list 和 hash_list，创建 idleproc 和 initproc 两个内核线程
// 实现位置：kern/process/proc.c:460
void proc_init(void)
{
    int i;

    list_init(&proc_list); // 初始化全局链表，具体的实现在lab2/libs/list.h，
    for (i = 0; i < HASH_LIST_SIZE; i++) // 遍历进程哈希表的所有桶
    {
        list_init(hash_list + i);  // 每一个都初始化
    }

    // 调用challenge1中实现的函数 在上面的120行，如果内存为空了，那么就会分配失败
    if ((idleproc = alloc_proc()) == NULL)
    {
        panic("cannot alloc idleproc.\n");
    }

    // 检查进程的结构是否初始化
    int *context_mem = (int *)kmalloc(sizeof(struct context)); // 分配一块和struct context一样大小的内存
    memset(context_mem, 0, sizeof(struct context)); // 这块的内存全部填0，够造全0的模板
    int context_init_flag = memcmp(&(idleproc->context), context_mem, sizeof(struct context)); // 这里的将idleproc->context和全0模板逐字节比较

    // 检查进程名是不是被正确的置为全0
    int *proc_name_mem = (int *)kmalloc(PROC_NAME_LEN); // 分配一段等长的内存
    memset(proc_name_mem, 0, PROC_NAME_LEN); // 清零
    int proc_name_flag = memcmp(&(idleproc->name), proc_name_mem, PROC_NAME_LEN); // 进行比较

    // 验证我实现的alloc_proc()是不是正确的初始化了
    /*
    idleproc->pgdir == boot_pgdir_pa 页表基址应指向内核页表（内核线程共享同一地址空间）。
    idleproc->tf == NULL 初始没有 trapframe。
    !context_init_flag 即 context_init_flag == 0，说明 context 全 0。
    idleproc->state == PROC_UNINIT 状态为未初始化。
    idleproc->pid == -1 还没分配 pid，用 -1 标识。
    idleproc->runs == 0 运行次数为 0。
    idleproc->kstack == 0 还未分配内核栈。
    idleproc->need_resched == 0 初始不需要调度。
    idleproc->parent == NULL 父进程为空。
    idleproc->mm == NULL 内核线程无独立 mm。
    idleproc->flags == 0 标志位清零。
    !proc_name_flag （即 proc_name_flag == 0） 进程名数组全 0。
    */
    if (idleproc->pgdir == boot_pgdir_pa && idleproc->tf == NULL && !context_init_flag && idleproc->state == PROC_UNINIT && idleproc->pid == -1 && idleproc->runs == 0 && idleproc->kstack == 0 && idleproc->need_resched == 0 && idleproc->parent == NULL && idleproc->mm == NULL && idleproc->flags == 0 && !proc_name_flag)
    {
        cprintf("alloc_proc() correct!\n");
    }

    idleproc->pid = 0; // 约定pid名字为0
    idleproc->state = PROC_RUNNABLE; // 状态设置为就绪态，可以被调度执行
    idleproc->kstack = (uintptr_t)bootstack; // 启动内核的时候，内核准备好作为启动栈bootstack
    idleproc->need_resched = 1; // 标记当前需要调度，保证后续的 cpu_idle() 能够触发调度器，运行其他的线程
    set_proc_name(idleproc, "idle"); // 设置进程名，方便调试，具体函数的实现在该文件的145行左右
    nr_process++;

    current = idleproc; // 当前运行的进程指针修改

    // 调用kernel_thread()创建第二个内核的线程
    // 线程函数是init_main()，参与的字符串
    // 最后的返回值pid是新线程的pid

    int pid = kernel_thread(init_main, "Hello world!!", 0); // 具体的实现在当前函数的上面
    // 如果 pid <= 0，则说明线程创建失败
    if (pid <= 0)
    {
        panic("create init_main failed.\n");
    }

    initproc = find_proc(pid); // 调用这个函数，根据pid 在哈希表中找到刚创建的内核线程结构，将其保存到全局指针 initproc
    set_proc_name(initproc, "init"); // 将名称命名为init，方便调试和输出

    /*
    这些 assert 是最终一致性检查：
    idleproc 必须存在，且 pid == 0；
    initproc 必须存在，且 pid == 1；
    */
    assert(idleproc != NULL && idleproc->pid == 0); 
    assert(initproc != NULL && initproc->pid == 1);
}

// cpu_idle - at the end of kern_init, the first kernel thread idleproc will do below works
// idleproc 的主循环
// 功能：检测 need_resched 标志，需要时调用 schedule() 进行调度
// 实现位置：kern/process/proc.c:512
void cpu_idle(void)
{
    while (1)
    {
        if (current->need_resched)
        {
            schedule(); // 需要的时候调用，schedule调用的代码在lab4/kern/schedule/sched.c中实现的
        }
    }
}
