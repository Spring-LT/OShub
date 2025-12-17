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
#include <unistd.h>

/* ------------- 进程/线程机制设计与实现（简化版Linux模型） -------------
 * 简介：
 *  ucore实现了一套简化的进程/线程机制。
 *  - 进程（process）具有独立的地址空间、至少一个执行流、内核用于管理它的数据结构、
 *    上下文切换需要保存的CPU现场，以及（lab6中）文件等资源。
 *  - 线程（thread）在ucore里可视为一种“特殊的进程”：多个线程可以共享同一个进程地址空间。
 *
 * 进程状态：含义 —— 典型触发原因
 *  PROC_UNINIT   未初始化     —— alloc_proc
 *  PROC_SLEEPING 睡眠态       —— try_free_pages / do_wait / do_sleep
 *  PROC_RUNNABLE 就绪态/可运行 —— proc_init / wakeup_proc
 *  PROC_ZOMBIE   僵尸态       —— do_exit
 *
 * 状态转换示意：
 *  alloc_proc                                 RUNNING
 *      +                                   +--<----<--+
 *      +                                   + proc_run +
 *      V                                   +-->---->--+
 *  PROC_UNINIT -- proc_init/wakeup_proc --> PROC_RUNNABLE -- try_free_pages/do_wait/do_sleep --> PROC_SLEEPING --
 *                                             A      +                                                           +
 *                                             |      +--- do_exit --> PROC_ZOMBIE                                +
 *                                             +                                                                  +
 *                                             -----------------------wakeup_proc----------------------------------
 *
 * 进程关系（父子与兄弟链）：
 *  parent:           proc->parent
 *  children:         proc->cptr
 *  older sibling:    proc->optr
 *  younger sibling:  proc->yptr
 *
 * 与进程相关的系统调用：
 *  SYS_exit   进程退出            --> do_exit
 *  SYS_fork   创建子进程/复制mm    --> do_fork --> wakeup_proc
 *  SYS_wait   等待子进程          --> do_wait
 *  SYS_exec   覆盖当前进程映像    --> load_icode（刷新mm）
 *  SYS_clone  创建线程（共享mm）  --> do_fork --> wakeup_proc
 *  SYS_yield  主动让出CPU         --> proc->need_resched=1
 *  SYS_sleep  进程睡眠            --> do_sleep
 *  SYS_kill   杀死进程            --> do_kill（设置PF_EXITING）
 *                               --> wakeup_proc --> do_wait --> do_exit
 *  SYS_getpid 获取当前pid
 */

// 全局进程链表，系统里所有进程都挂在这里（调度、遍历、找 pid 都会用到）
list_entry_t proc_list;

#define HASH_SHIFT 10
#define HASH_LIST_SIZE (1 << HASH_SHIFT)
#define pid_hashfn(x) (hash32(x, HASH_SHIFT)) // 决定pid落入哪个桶

// pid哈希表，为了快速pid->proc_struct*查找
static list_entry_t hash_list[HASH_LIST_SIZE];

// pid=0 CPU空转时跑它
struct proc_struct *idleproc = NULL;
// pid=1 init内核线程，负责创建用户进程并回收它们
struct proc_struct *initproc = NULL;
// 当前运行的进程
struct proc_struct *current = NULL;
// 记录当前正在运行的进程数量
static int nr_process = 0;

void kernel_thread_entry(void);
void forkrets(struct trapframe *tf);
void switch_to(struct context *from, struct context *to);

// alloc_proc - 分配并初始化一个新的进程块（PCB）
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        // LAB4:EXERCISE1 YOUR CODE
        /*
         * 需要初始化的proc_struct字段（LAB4）：
         *  enum proc_state state;          // 进程状态
         *  int pid;                        // 进程ID
         *  int runs;                       // 运行次数
         *  uintptr_t kstack;               // 内核栈地址
         *  volatile bool need_resched;     // 是否需要调度
         *  struct proc_struct *parent;     // 父进程
         *  struct mm_struct *mm;           // 内存管理结构（用户地址空间）
         *  struct context context;         // 上下文切换保存区
         *  struct trapframe *tf;           // trapframe
         *  uintptr_t pgdir;                // 页表根（satp需要的物理地址）
         *  uint32_t flags;                 // 标志位
         *  char name[PROC_NAME_LEN + 1];   // 进程名
         */

        // LAB5 YOUR CODE : (update LAB4 steps)
        /*
         * 需要初始化的proc_struct字段（LAB5新增）：
         *  uint32_t wait_state;                        // 等待状态
         *  struct proc_struct *cptr, *yptr, *optr;     // 父子/兄弟关系指针
         */
        // LAB4 初始化
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
        // LAB5 新增初始化
        proc->wait_state = 0;                               // 等待状态初始化为0
        proc->cptr = NULL;                                  // 子进程指针为空
        proc->yptr = NULL;                                  // 年轻兄弟指针为空
        proc->optr = NULL;                                  // 年长兄弟指针为空
    }
    return proc;
}

// set_proc_name - 设置进程名称
char *
set_proc_name(struct proc_struct *proc, const char *name)
{
    memset(proc->name, 0, sizeof(proc->name));
    return memcpy(proc->name, name, PROC_NAME_LEN);
}

// get_proc_name - 获取进程名称
char *
get_proc_name(struct proc_struct *proc)
{
    static char name[PROC_NAME_LEN + 1];
    memset(name, 0, sizeof(name));
    return memcpy(name, proc->name, PROC_NAME_LEN);
}

// set_links - 设置进程的关联链接
static void
set_links(struct proc_struct *proc)
{
    list_add(&proc_list, &(proc->list_link));
    proc->yptr = NULL;
    if ((proc->optr = proc->parent->cptr) != NULL)
    {
        proc->optr->yptr = proc;
    }
    proc->parent->cptr = proc;
    nr_process++;
}

// remove_links - 清除进程的关联链接
static void
remove_links(struct proc_struct *proc)
{
    list_del(&(proc->list_link));
    if (proc->optr != NULL)
    {
        proc->optr->yptr = proc->yptr;
    }
    if (proc->yptr != NULL)
    {
        proc->yptr->optr = proc->optr;
    }
    else
    {
        proc->parent->cptr = proc->optr;
    }
    nr_process--;
}

// get_pid - 为进程分配一个不冲突的pid
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
        while ((le = list_next(le)) != list) // 不断地循环，直到找到可用的pid
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

// proc_run - 让进程"proc"在CPU上运行
// 注意：在调用switch_to进行上下文切换之前，需要先切换到新进程的页表（lsatp）。
void proc_run(struct proc_struct *proc)
{
    if (proc != current) // 如果要运行的进程不是当前进程
    {
        // LAB4:EXERCISE3 YOUR CODE
        /*
         * 可用的宏/函数：
         *  local_intr_save()      关中断
         *  local_intr_restore()   开中断
         *  lsatp()                写satp切换页表
         *  switch_to()            进行上下文切换
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

// forkret -- 新创建的线程第一次被调度的时候从这里开始
// 注意：forkret的地址在copy_thread里被设置到proc->context.ra。
//      当进程第一次被调度并完成switch_to后，会从这里开始执行。
static void
forkret(void)
{
    forkrets(current->tf);// 这里是子进程初始化完成后返回到用户态的入口
    // lab5/kern/trap/trapentry.S 会跳转到这里136行左右的位置
}

// hash_proc - 将进程加入到进程哈希表
static void
hash_proc(struct proc_struct *proc)
{
    list_add(hash_list + pid_hashfn(proc->pid), &(proc->hash_link));
}

// unhash_proc - 从进程哈希表中删除进程
static void
unhash_proc(struct proc_struct *proc)
{
    list_del(&(proc->hash_link));
}

// find_proc - 根据pid在进程哈希表中查找进程
// 返回找到的进程结构体指针，如果未找到则返回NULL
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

// kernel_thread - 创建内核线程的包装器
// 注意：这里构造的临时trapframe tf，会在do_fork -> copy_thread中被复制到新进程的proc->tf。
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
    struct trapframe tf; // 创建临时trapframe
    memset(&tf, 0, sizeof(struct trapframe));
    tf.gpr.s0 = (uintptr_t)fn;        // 函数指针
    tf.gpr.s1 = (uintptr_t)arg;       // 函数参数（传给fn的参数）
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE; 
    /*
     * SSTATUS_SPP: 设置为S-mode，表示trap发生前是在S-mode
     * SSTATUS_SPIE: 使能中断，在sret后恢复中断使能
     * SSTATUS_SIE: 清除SIE位，禁用S-mode中断（在内核线程中通常不需要）
     */
    tf.epc = (uintptr_t)kernel_thread_entry;
    return do_fork(clone_flags | CLONE_VM, 0, &tf); // 创建新进程并执行fn(arg)，返回的值是新进程的pid
}

// setup_kstack - 分配 KSTACKPAGE 页作为内核栈
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

// put_kstack - 释放内核页
static void
put_kstack(struct proc_struct *proc)
{
    free_pages(kva2page((void *)(proc->kstack)), KSTACKPAGE);
}

// setup_pgdir - 分配一页作为页表根
static int
setup_pgdir(struct mm_struct *mm)
{
    struct Page *page;
    if ((page = alloc_page()) == NULL)
    {
        return -E_NO_MEM;
    }
    pde_t *pgdir = page2kva(page);
    memcpy(pgdir, boot_pgdir_va, PGSIZE);// 继承内核映射（内核空间的映射对每个进程都一样）

    mm->pgdir = pgdir;
    return 0;
}

// put_pgdir - 释放页表根目录的内存空间
static void
put_pgdir(struct mm_struct *mm)
{
    free_page(kva2page(mm->pgdir));
}

// copy_mm - process "proc" duplicate OR share process "current"'s mm according clone_flags
//         - if clone_flags & CLONE_VM, then "share" ; else "duplicate"
// fork 时复制/共享地址空间（fork 的内存部分入口）
// copy_mm -> dup_mmap -> copy_range
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    struct mm_struct *mm, *oldmm = current->mm;

    /* current is a kernel thread */
    // 如果current->mm == NULL：当前是内核线程，没有用户地址空间 → 返回 0
    if (oldmm == NULL)
    {
        return 0;
    }
    if (clone_flags & CLONE_VM) // 线程语义，直接共享 mm = oldmm
    {
        mm = oldmm;
        goto good_mm;
    }
    int ret = -E_NO_MEM;
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    if (setup_pgdir(mm) != 0) // 新建子进程 mm ，继承内核映射（包括内核空间的页表项，这样子进程就能访问内核数据）
    {
        goto bad_pgdir_cleanup_mm;
    }
    lock_mm(oldmm);
    {
        ret = dup_mmap(mm, oldmm);// 复制虚拟内存空间和页内容（用户空间），包括堆栈等（用户空间的页表项），这样子进程就能访问父进程的用户数据
    }
    unlock_mm(oldmm);

    if (ret != 0)
    {
        goto bad_dup_cleanup_mmap;
    }

good_mm:
    mm_count_inc(mm);
    proc->mm = mm;
    proc->pgdir = PADDR(mm->pgdir);
    return 0;
bad_dup_cleanup_mmap:
    exit_mmap(mm);
    put_pgdir(mm);
bad_pgdir_cleanup_mm:
    mm_destroy(mm);
bad_mm:
    return ret;
}

// copy_thread - 把 trapframe 和 context 设置好（fork 的 CPU现场部分入口）
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf)
{
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1;
    *(proc->tf) = *tf;

    // 将a0设为0，以满足fork语义：子进程fork返回值为0
    proc->tf->gpr.a0 = 0;
    proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;

    proc->context.ra = (uintptr_t)forkret; // 设置返回地址为forkret函数，用于子进程初始化后返回，执行上面的代码
    proc->context.sp = (uintptr_t)(proc->tf);
}

/* do_fork -     parent process for a new child process 
 * @clone_flags: used to guide how to clone the child process
 * @stack:       the parent's user stack pointer. if stack==0, It means to fork a kernel thread.
 * @tf:          the trapframe info, which will be copied to child process's proc->tf
 * 说明：fork 系统调用的入口，创建子进程
 */
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    if (nr_process >= MAX_PROCESS)
    {
        goto fork_out;
    }
    ret = -E_NO_MEM;
    // LAB4:EXERCISE2 YOUR CODE
    // LAB5 YOUR CODE : (update LAB4 steps)

    // 1. 调用alloc_proc分配一个proc_struct
    if ((proc = alloc_proc()) == NULL) {
        goto fork_out;
    }
    
    // 设置父进程，并确保父进程的wait_state为0 (LAB5更新)
    proc->parent = current;
    assert(current->wait_state == 0);
    
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
    
    // 5. 将proc_struct插入hash_list和proc_list，设置进程关系链接 (LAB5更新)
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        proc->pid = get_pid();
        hash_proc(proc); 
        set_links(proc);  // LAB5: 使用set_links代替直接操作链表
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

// do_exit - 退出进程
//   1. 释放进程的内存空间（页表、用户内存等）
//   2. 设置进程状态为PROC_ZOMBIE，唤醒父进程回收资源
//   3. 调度切换到其他进程
int do_exit(int error_code)
{
    // 不允许0号/1号进程
    if (current == idleproc)
    {
        panic("idleproc exit.\n");
    }
    if (current == initproc)
    {
        panic("initproc exit.\n");
    }
    struct mm_struct *mm = current->mm;
    if (mm != NULL)
    {
        lsatp(boot_pgdir_pa); // 先切换回内核页表（避免释放自己正在用的页表）
        if (mm_count_dec(mm) == 0) // 定义在 lab5/kern/mm/vmm.h 如果降到 0，说明没人共享了，可以安全释放
        {
            exit_mmap(mm);
            put_pgdir(mm);
            mm_destroy(mm);
        }
        current->mm = NULL;
    }
    current->state = PROC_ZOMBIE; // 进程标记为僵尸状态
    current->exit_code = error_code; // 退出
    bool intr_flag;
    struct proc_struct *proc;
    local_intr_save(intr_flag);
    {
        proc = current->parent;
        if (proc->wait_state == WT_CHILD) // 父进程在等待子进程结束
        {
            wakeup_proc(proc); // 则唤醒父进程
        }
        while (current->cptr != NULL)
        {
            proc = current->cptr;
            current->cptr = proc->optr;

            proc->yptr = NULL;
            if ((proc->optr = initproc->cptr) != NULL)
            {
                initproc->cptr->yptr = proc;
            }
            proc->parent = initproc;
            initproc->cptr = proc;
            if (proc->state == PROC_ZOMBIE)
            {
                if (initproc->wait_state == WT_CHILD)
                {
                    wakeup_proc(initproc); // 唤醒init进程来回收子进程资源
                }
            }
        }
    }
    local_intr_restore(intr_flag);
    schedule();
    panic("do_exit will not return!! %d.\n", current->pid);
}

/* load_icode - 加载二进制程序(ELF格式)作为当前进程的新内容
 * @binary:  二进制程序内容的内存地址
 * @size:  二进制程序内容的大小
 */
static int
load_icode(unsigned char *binary, size_t size)
{
    if (current->mm != NULL)
    {
        panic("load_icode: current->mm must be empty.\n");
    }

    int ret = -E_NO_MEM;
    struct mm_struct *mm;
    //(1) create a new mm for current process 创建进程的虚拟内存管理结构
    // lab5/kern/mm/vmm.c 创建mm_struct
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    //(2) create a new PDT, and mm->pgdir= kernel virtual addr of PDT 给这个进程建自己的页表
    // lab5/kern/process/proc.c 350行左右
    if (setup_pgdir(mm) != 0)
    {
        goto bad_pgdir_cleanup_mm;
    }
    //(3) copy TEXT/DATA section, build BSS parts in binary to memory space of process
    // 解析 ELF program header：
    struct Page *page;
    //(3.1) 获取binary程序的文件头 (ELF format)
    struct elfhdr *elf = (struct elfhdr *)binary;
    //(3.2) 获取ELF程序的段表入口 (ELF format)
    struct proghdr *ph = (struct proghdr *)(binary + elf->e_phoff);
    //(3.3) 检查程序是否有效
    if (elf->e_magic != ELF_MAGIC)
    {
        ret = -E_INVAL_ELF;
        goto bad_elf_cleanup_pgdir;
    }

    uint32_t vm_flags, perm;
    struct proghdr *ph_end = ph + elf->e_phnum;
    for (; ph < ph_end; ph++)
    {
        //(3.4) 遍历每个程序段头
        if (ph->p_type != ELF_PT_LOAD)
        {
            continue;
        }
        if (ph->p_filesz > ph->p_memsz)
        {
            ret = -E_INVAL_ELF;
            goto bad_cleanup_mmap;
        }
        if (ph->p_filesz == 0)
        {
            // continue ;
        }
        //(3.5) 调用 mm_map 函数建立新的 VMA ( ph->p_va, ph->p_memsz) 来映射程序段到进程地址空间
        vm_flags = 0, perm = PTE_U | PTE_V;
        if (ph->p_flags & ELF_PF_X)
            vm_flags |= VM_EXEC;
        if (ph->p_flags & ELF_PF_W)
            vm_flags |= VM_WRITE;
        if (ph->p_flags & ELF_PF_R)
            vm_flags |= VM_READ;
        // modify the perm bits here for RISC-V
        // 根据段的权限设置页表项权限位：只读、可写、可执行
        if (vm_flags & VM_READ)
            perm |= PTE_R;
        if (vm_flags & VM_WRITE)
            perm |= (PTE_W | PTE_R);
        if (vm_flags & VM_EXEC)
            perm |= PTE_X;
        // lab5/kern/mm/vmm.c mm_map 170行左右 建 VMA（记录合法区间与权限）
        if ((ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL)) != 0) // 建立 VMA（记录合法区间 + 权限）
        {
            goto bad_cleanup_mmap;
        }
        unsigned char *from = binary + ph->p_offset;
        size_t off, size;
        uintptr_t start = ph->p_va, end, la = ROUNDDOWN(start, PGSIZE);

        ret = -E_NO_MEM;

        //(3.6) 为程序段分配内存，并将二进制程序的每个段的内容复制到进程内存中 (la, la+end)
        end = ph->p_va + ph->p_filesz;
        //(3.6.1) 复制TEXT/DATA段
        while (start < end)
        {
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                goto bad_cleanup_mmap;
            }
            off = start - la, size = PGSIZE - off, la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            memcpy(page2kva(page) + off, from, size);
            start += size, from += size;
        }

        //(3.6.2) 构建BSS段：将未初始化的数据段清零
        end = ph->p_va + ph->p_memsz;
        if (start < la)
        {
            /* ph->p_memsz == ph->p_filesz */
            if (start == end)
            {
                continue;
            }
            off = start + PGSIZE - la, size = PGSIZE - off;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
            assert((end < la && start == end) || (end >= la && start == la));
        }
        while (start < end)
        {
            // lab5/kern/mm/pmm.c 530行左右， memset/memcopy 将TEXT/DATA/BSS 放进用户空间
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                goto bad_cleanup_mmap;
            }
            off = start - la, size = PGSIZE - off, la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
        }
    }
    //(4) 构建用户栈内存，分配至少4页栈页
    vm_flags = VM_READ | VM_WRITE | VM_STACK;
    if ((ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, vm_flags, NULL)) != 0)
    {
        goto bad_cleanup_mmap;
    }
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 2 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 3 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 4 * PGSIZE, PTE_USER) != NULL);

    //(5) 设置当前进程的内存管理结构、页表基地址，并将satp寄存器设置为页目录的物理地址
    mm_count_inc(mm);
    current->mm = mm;
    current->pgdir = PADDR(mm->pgdir);
    lsatp(PADDR(mm->pgdir));

    //(6) 设置用户环境的trapframe，初始化用户进程的trap上下文
    struct trapframe *tf = current->tf;
    // Keep sstatus
    uintptr_t sstatus = tf->status;
    memset(tf, 0, sizeof(struct trapframe));
    /* LAB5:EXERCISE1 YOUR CODE
     * 功能：
     *  设置用户进程返回用户态所需的trapframe关键字段，使得后续在__trapret中执行sret时
     *  能从内核态正确切换到用户态并从用户程序入口开始执行。
     * 输入：
     *  - elf->e_entry：用户程序入口地址
     *  - USTACKTOP：用户栈顶地址
     * 返回值：
     *  - 无（直接修改current->tf）
     * 需要设置：
     *  - tf->gpr.sp：用户栈指针
     *  - tf->epc：用户态PC（sepc）
     *  - tf->status：sstatus（清SPP返回U态，设置SPIE以便返回后中断使能）
     */
    // 设置用户栈顶指针
    tf->gpr.sp = USTACKTOP;
    // 设置程序入口点（ELF文件的入口地址）
    tf->epc = elf->e_entry;
    // 设置sstatus寄存器：
    // - 清除SSTATUS_SPP位，使得sret返回到U模式（用户态）
    // - 设置SSTATUS_SPIE位，使得返回后中断使能
    tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;

    ret = 0;
out:
    return ret;
bad_cleanup_mmap:
    exit_mmap(mm);
bad_elf_cleanup_pgdir:
    put_pgdir(mm);
bad_pgdir_cleanup_mm:
    mm_destroy(mm);
bad_mm:
    goto out;
}

// do_execve - 覆盖当前进程的执行映像
//  1. 回收旧的用户地址空间（exit_mmap/put_pgdir/mm_destroy）
//  2. 调用load_icode加载新的ELF并建立新的地址空间
// 用新程序覆盖当前的进程：释放旧内存，加载新程序
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size)
{
    struct mm_struct *mm = current->mm;
    // 检查name指针在用户空间是否合法
    if (!user_mem_check(mm, (uintptr_t)name, len, 0))
    {
        return -E_INVAL;
    }
    // 检查name字符串长度
    if (len > PROC_NAME_LEN)
    {
        len = PROC_NAME_LEN;
    }

    char local_name[PROC_NAME_LEN + 1];
    memset(local_name, 0, sizeof(local_name));
    memcpy(local_name, name, len);

    if (mm != NULL)
    {
        cputs("mm != NULL");
        lsatp(boot_pgdir_pa);
        if (mm_count_dec(mm) == 0)
        {
            exit_mmap(mm);
            put_pgdir(mm);
            mm_destroy(mm);
        }
        current->mm = NULL;
    }
    int ret;
    if ((ret = load_icode(binary, size)) != 0) // 核心 lab5/kern/process/proc.c 600行左右
    {
        goto execve_exit;
    }
    set_proc_name(current, local_name);
    return 0;

execve_exit:
    do_exit(ret);
    panic("already exit: %e.\n", ret);
}

// do_yield - ask the scheduler to reschedule 
// 让调度器重新调度，当前进程让出CPU
int do_yield(void)
{
    current->need_resched = 1;
    return 0;
}

// do_wait - 等待一个或任意子进程进入PROC_ZOMBIE状态，并回收其资源
// 注意：只有在do_wait中，子进程的内核栈与proc_struct才会被真正释放。
// 等待指定ID的子进程或任意子进程变为僵尸状态，并回收其资源
// 参数:
//   pid: 要等待的子进程ID，0表示等待任意子进程
//   code_store: 用于存储子进程退出状态的用户空间地址
// 返回值: 成功返回0，失败返回错误码
int do_wait(int pid, int *code_store)
{
    struct mm_struct *mm = current->mm;
    if (code_store != NULL)
    {
        if (!user_mem_check(mm, (uintptr_t)code_store, sizeof(int), 1))
        {
            return -E_INVAL;
        }
    }

    struct proc_struct *proc;
    bool intr_flag, haskid;
repeat:
    haskid = 0;
    if (pid != 0)
    {
        proc = find_proc(pid);
        if (proc != NULL && proc->parent == current)
        {
            haskid = 1;
            if (proc->state == PROC_ZOMBIE)
            {
                goto found;
            }
        }
    }
    else
    {
        proc = current->cptr;
        for (; proc != NULL; proc = proc->optr)
        {
            haskid = 1;
            if (proc->state == PROC_ZOMBIE)
            {
                goto found;
            }
        }
    }
    if (haskid)
    {
        current->state = PROC_SLEEPING;
        current->wait_state = WT_CHILD;
        schedule();
        if (current->flags & PF_EXITING)
        {
            do_exit(-E_KILLED);
        }
        goto repeat;
    }
    return -E_BAD_PROC;

found:
    if (proc == idleproc || proc == initproc)
    {
        panic("wait idleproc or initproc.\n");
    }
    if (code_store != NULL)
    {
        *code_store = proc->exit_code;
    }
    local_intr_save(intr_flag);
    {
        unhash_proc(proc);
        remove_links(proc);
    }
    local_intr_restore(intr_flag);
    put_kstack(proc);
    kfree(proc);
    return 0;
}

// do_kill - kill process with pid by set this process's flags with PF_EXITING
int do_kill(int pid)
{
    struct proc_struct *proc;
    if ((proc = find_proc(pid)) != NULL)
    {
        if (!(proc->flags & PF_EXITING))
        {
            proc->flags |= PF_EXITING;
            if (proc->wait_state & WT_INTERRUPTED)
            {
                wakeup_proc(proc);
            }
            return 0;
        }
        return -E_KILLED;
    }
    return -E_INVAL;
}

// kernel_execve - do SYS_exec syscall to exec a user program called by user_main kernel_thread
static int
kernel_execve(const char *name, unsigned char *binary, size_t size)
{
    int64_t ret = 0, len = strlen(name);
    // ret = do_execve(name, len, binary, size); a0 = SYS_exec; a1 = name; a2 = len; a3 = binary; a4 = size; a7 = 10(伪装成系统调用，转发到syscall); ebreak;
    // ebreak触发异常，借助trap返回路径进入用户态。_alltraps保存tf -> trap(tf) -> _trapsret
    asm volatile(
        "li a0, %1\n"
        "lw a1, %2\n"
        "lw a2, %3\n"
        "lw a3, %4\n"
        "lw a4, %5\n"
        "li a7, 10\n"
        "ebreak\n"
        "sw a0, %0\n"
        : "=m"(ret)
        : "i"(SYS_exec), "m"(name), "m"(len), "m"(binary), "m"(size)
        : "memory");
    cprintf("ret = %d\n", ret);
    return ret;
}

#define __KERNEL_EXECVE(name, binary, size) ({           \
    cprintf("kernel_execve: pid = %d, name = \"%s\".\n", \
            current->pid, name);                         \
    kernel_execve(name, binary, (size_t)(size));         \
})
// 
#define KERNEL_EXECVE(x) ({                                    \
    extern unsigned char _binary_obj___user_##x##_out_start[], \
        _binary_obj___user_##x##_out_size[];                   \
    __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,    \
                    _binary_obj___user_##x##_out_size);        \
})

#define __KERNEL_EXECVE2(x, xstart, xsize) ({   \
    extern unsigned char xstart[], xsize[];     \
    __KERNEL_EXECVE(#x, xstart, (size_t)xsize); \
})

#define KERNEL_EXECVE2(x, xstart, xsize) __KERNEL_EXECVE2(x, xstart, xsize)

// user_main - kernel thread used to exec a user program
static int
user_main(void *arg)
{
#ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    KERNEL_EXECVE(exit); // 不是从文件系统加载，而是通过连接脚本把用户程序二进制嵌入进kernel镜像
#endif
    panic("user_main execve failed.\n");
}

// init_main - 创建 user_main 并等待用户进程退出
static int
init_main(void *arg)
{
    size_t nr_free_pages_store = nr_free_pages();
    size_t kernel_allocated_store = kallocated();

    int pid = kernel_thread(user_main, NULL, 0); // 创建user_main内核线程，并等待所有用户进程退出
    if (pid <= 0)
    {
        panic("create user_main failed.\n");
    }

    while (do_wait(0, NULL) == 0) // 循环等待用户所有进程退出
    {
        schedule();
    }

    cprintf("all user-mode processes have quit.\n");
    assert(initproc->cptr == NULL && initproc->yptr == NULL && initproc->optr == NULL);
    assert(nr_process == 2);
    assert(list_next(&proc_list) == &(initproc->list_link));
    assert(list_prev(&proc_list) == &(initproc->list_link));

    cprintf("init check memory pass.\n");
    return 0;
}

// 创建idleproc 和 initproc
// idleproc：pid=0，CPU 空转时跑它（cpu_idle）。
// initproc：pid=1，是第二个内核线程，执行 init_main()。
void proc_init(void)
{
    int i;

    list_init(&proc_list);
    for (i = 0; i < HASH_LIST_SIZE; i++)
    {
        list_init(hash_list + i);
    }

    if ((idleproc = alloc_proc()) == NULL)
    {
        panic("cannot alloc idleproc.\n");
    }

    idleproc->pid = 0; // 分配并初始化idleproc，设置Pid=0
    idleproc->state = PROC_RUNNABLE;
    idleproc->kstack = (uintptr_t)bootstack;
    idleproc->need_resched = 1;
    set_proc_name(idleproc, "idle");
    nr_process++;

    current = idleproc;

    int pid = kernel_thread(init_main, NULL, 0);
    if (pid <= 0)
    {
        panic("create init_main failed.\n");
    }

    initproc = find_proc(pid);
    set_proc_name(initproc, "init");

    assert(idleproc != NULL && idleproc->pid == 0);
    assert(initproc != NULL && initproc->pid == 1);
}

// cpu_idle - at the end of kern_init, the first kernel thread idleproc will do below works
void cpu_idle(void)
{
    while (1)
    {
        if (current->need_resched)
        {
            schedule();
        }
    }
}
