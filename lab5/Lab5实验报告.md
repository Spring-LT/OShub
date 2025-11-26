# LAB5 用户程序

**23级信息安全  2310411 李听泉**

**23级信息安全  2313876 李子凝**

**23级信息安全  2312092 李朝阳**

> [!NOTE] 
>
> **小组分工：**
>
> 李子凝：负责练习3分析以及OS与实验之间的知识点
>
> 李朝阳：负责练习2实现以及Copy on Write设计
>
> 李听泉：负责练习1实现以及练习0代码填写

----

## 实验目的

- 了解第一个用户进程创建过程
- 了解系统调用框架的实现机制
- 了解ucore如何实现系统调用sys_fork/sys_exec/sys_exit/sys_wait来进行进程管理

## 练习0：填写已有实验

本实验依赖实验2/3/4。需要把之前实验的代码填入本实验中代码中有"LAB2"/"LAB3"/"LAB4"的注释相应部分。

### LAB4代码填写

#### alloc_proc函数

`alloc_proc`函数负责分配并初始化一个进程控制块。在Lab5中，需要额外初始化`wait_state`和进程关系指针（`cptr`、`yptr`、`optr`）。

```c
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
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
```

#### do_fork函数

`do_fork`函数是创建子进程的核心函数。在Lab5中，需要使用`set_links`函数来设置进程关系链接，并确保父进程的`wait_state`为0。

```c
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    if (nr_process >= MAX_PROCESS)
    {
        goto fork_out;
    }
    ret = -E_NO_MEM;

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
    // ... 错误处理代码
}
```

#### proc_run函数

`proc_run`函数负责进程切换，包括切换页表和上下文。

```c
void proc_run(struct proc_struct *proc)
{
    if (proc != current)
    {
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
```

### LAB3代码填写

时钟中断处理：

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;
    if (ticks % TICK_NUM == 0) {
        print_ticks();
    }
    if (current != NULL) {
        current->need_resched = 1;
    }
    break;
```

## 练习1: 加载应用程序并执行（需要编码）

### 设计实现过程

`load_icode`函数的第6步需要设置trapframe，以便用户进程能够正确返回用户态执行。需要设置三个关键字段：

1. **tf->gpr.sp**：用户栈顶指针，设置为`USTACKTOP`
2. **tf->epc**：程序入口点，设置为ELF文件的入口地址`elf->e_entry`
3. **tf->status**：sstatus寄存器值，需要清除`SSTATUS_SPP`位使sret返回用户态，设置`SSTATUS_SPIE`位使返回后中断使能

```c
//(6) setup trapframe for user environment
struct trapframe *tf = current->tf;
// Keep sstatus
uintptr_t sstatus = tf->status;
memset(tf, 0, sizeof(struct trapframe));

// 设置用户栈顶指针
tf->gpr.sp = USTACKTOP;
// 设置程序入口点（ELF文件的入口地址）
tf->epc = elf->e_entry;
// 设置sstatus寄存器：
// - 清除SSTATUS_SPP位，使得sret返回到U模式（用户态）
// - 设置SSTATUS_SPIE位，使得返回后中断使能
tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;
```

### 用户态进程执行流程分析

用户态进程从被ucore选择占用CPU执行（RUNNING态）到具体执行应用程序第一条指令的整个经过：

1. **调度选择**：`schedule()`函数选择一个RUNNABLE状态的进程，调用`proc_run()`

2. **进程切换**：`proc_run()`执行以下操作：
   - 切换`current`指针到新进程
   - 通过`lsatp()`切换页表到新进程的地址空间
   - 调用`switch_to()`进行上下文切换

3. **forkret执行**：新进程第一次被调度时，`context.ra`指向`forkret`函数，`switch_to`返回后执行`forkret()`

4. **trapret执行**：`forkret()`调用`forkrets(current->tf)`，该函数在`trapentry.S`中定义，负责恢复trapframe中保存的寄存器状态

5. **sret返回用户态**：`trapentry.S`中执行`sret`指令：
   - 由于`tf->status`的`SSTATUS_SPP`位为0，CPU切换到U模式（用户态）
   - `sepc`寄存器值（即`tf->epc`，程序入口地址）被加载到PC
   - `sp`寄存器被设置为`tf->gpr.sp`（用户栈顶）

6. **执行用户程序**：CPU开始从ELF入口地址执行用户程序的第一条指令

## 练习2: 父进程复制自己的内存空间给子进程（需要编码）

### 设计实现过程

`copy_range`函数负责将父进程的内存内容复制到子进程。实现步骤：

```c
// (1) 获取源页面的内核虚拟地址
void *src_kvaddr = page2kva(page);
// (2) 获取目标页面的内核虚拟地址
void *dst_kvaddr = page2kva(npage);
// (3) 将源页面内容复制到目标页面
memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
// (4) 建立目标页面物理地址与线性地址start的映射关系
ret = page_insert(to, npage, start, perm);
```

**实现原理**：
1. 使用`page2kva()`将Page结构转换为内核虚拟地址，这样可以直接访问物理页面内容
2. 使用`memcpy()`复制整个页面（PGSIZE = 4KB）
3. 使用`page_insert()`在子进程的页表中建立虚拟地址到物理页面的映射

### Copy on Write机制设计

#### 概要设计

Copy on Write (COW) 是一种延迟复制优化技术，其核心思想是：

1. **fork时共享页面**：父进程fork子进程时，不立即复制内存页面，而是让父子进程共享同一物理页面，并将页面标记为只读

2. **写时复制**：当任一进程尝试写入共享页面时，触发页面错误（page fault），此时才真正复制页面

#### 详细设计

**数据结构修改**：
```c
// 在Page结构中添加引用计数
struct Page {
    int ref;                    // 引用计数
    uint64_t flags;             // 标志位
    // ...
};

// PTE标志位
#define PTE_COW  0x100          // COW标志位（使用保留位）
```

**fork时的处理**：
```c
int copy_range_cow(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end) {
    do {
        pte_t *ptep = get_pte(from, start, 0);
        if (ptep != NULL && (*ptep & PTE_V)) {
            // 获取父进程的页面
            struct Page *page = pte2page(*ptep);
            uint32_t perm = (*ptep & PTE_USER);
            
            // 如果页面可写，设置为只读并标记COW
            if (perm & PTE_W) {
                perm = (perm & ~PTE_W) | PTE_COW;
                // 更新父进程的PTE
                *ptep = pte_create(page2ppn(page), PTE_V | perm);
            }
            
            // 子进程共享同一页面
            page_ref_inc(page);
            pte_t *nptep = get_pte(to, start, 1);
            *nptep = pte_create(page2ppn(page), PTE_V | perm);
        }
        start += PGSIZE;
    } while (start < end);
    return 0;
}
```

**页面错误处理**：
```c
int do_cow_fault(struct mm_struct *mm, uintptr_t addr) {
    pte_t *ptep = get_pte(mm->pgdir, addr, 0);
    if (ptep == NULL || !(*ptep & PTE_COW)) {
        return -1;  // 不是COW页面
    }
    
    struct Page *old_page = pte2page(*ptep);
    
    // 如果只有一个引用，直接修改权限
    if (page_ref(old_page) == 1) {
        *ptep = (*ptep & ~PTE_COW) | PTE_W;
        tlb_invalidate(mm->pgdir, addr);
        return 0;
    }
    
    // 分配新页面并复制内容
    struct Page *new_page = alloc_page();
    if (new_page == NULL) {
        return -E_NO_MEM;
    }
    
    memcpy(page2kva(new_page), page2kva(old_page), PGSIZE);
    page_ref_dec(old_page);
    
    // 更新页表项
    uint32_t perm = (*ptep & PTE_USER & ~PTE_COW) | PTE_W;
    page_insert(mm->pgdir, new_page, addr, perm);
    
    return 0;
}
```

**状态转换图**：
```
                    fork()
    [Private RW] ─────────────> [Shared RO + COW]
         │                            │
         │                            │ write fault
         │                            ▼
         │                    ┌───────────────┐
         │                    │ ref_count > 1 │
         │                    └───────┬───────┘
         │                            │
         │              ┌─────────────┴─────────────┐
         │              │                           │
         │              ▼                           ▼
         │      [Copy & Private RW]         [Shared RO + COW]
         │         (写入进程)                  (其他进程)
         │              │                           │
         │              │ ref_count == 1            │
         │              ▼                           │
         └──────> [Private RW] <────────────────────┘
                    (直接修改权限)
```

## 练习3: 阅读分析源代码，理解进程执行 fork/exec/wait/exit 的实现

### fork/exec/wait/exit执行流程分析

#### fork流程

```
用户态                          内核态
  │                               │
  │ fork() ──────────────────────>│
  │                               │ sys_fork()
  │                               │   └─> do_fork()
  │                               │         ├─> alloc_proc()
  │                               │         ├─> setup_kstack()
  │                               │         ├─> copy_mm()
  │                               │         │     └─> dup_mmap()
  │                               │         │           └─> copy_range()
  │                               │         ├─> copy_thread()
  │                               │         ├─> set_links()
  │                               │         └─> wakeup_proc()
  │<──────────────────────────────│
  │ 返回子进程pid(父)/0(子)        │
```

#### exec流程

```
用户态                          内核态
  │                               │
  │ exec() ──────────────────────>│
  │                               │ sys_exec()
  │                               │   └─> do_execve()
  │                               │         ├─> exit_mmap() (释放旧内存)
  │                               │         ├─> put_pgdir()
  │                               │         └─> load_icode()
  │                               │               ├─> 解析ELF
  │                               │               ├─> 建立新内存映射
  │                               │               └─> 设置trapframe
  │<──────────────────────────────│
  │ 开始执行新程序                 │
```

#### wait流程

```
用户态                          内核态
  │                               │
  │ wait() ──────────────────────>│
  │                               │ sys_wait()
  │                               │   └─> do_wait()
  │                               │         ├─> 查找ZOMBIE子进程
  │                               │         │   ├─> 找到: 回收资源
  │                               │         │   └─> 未找到: 设置SLEEPING
  │                               │         │              └─> schedule()
  │                               │         └─> 返回子进程退出码
  │<──────────────────────────────│
  │ 返回                          │
```

#### exit流程

```
用户态                          内核态
  │                               │
  │ exit() ──────────────────────>│
  │                               │ sys_exit()
  │                               │   └─> do_exit()
  │                               │         ├─> exit_mmap() (释放内存)
  │                               │         ├─> put_pgdir()
  │                               │         ├─> 设置ZOMBIE状态
  │                               │         ├─> wakeup_proc(parent)
  │                               │         └─> schedule()
  │                               │
  │ (进程终止，不返回)             │
```

### 用户态与内核态交互分析

1. **用户态操作**：调用库函数（如`fork()`），库函数通过`ecall`指令触发系统调用

2. **内核态操作**：
   - 保存用户态上下文到trapframe
   - 执行系统调用处理函数
   - 恢复上下文，通过`sret`返回用户态

3. **返回值传递**：通过trapframe的`a0`寄存器传递返回值

### 用户态进程执行状态生命周期图

```
                          fork()/kernel_thread()
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                      PROC_UNINIT                            │
    │                    (alloc_proc创建)                          │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  │ wakeup_proc()
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                     PROC_RUNNABLE                           │
    │                   (就绪态，等待调度)                          │
    │                                                             │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │                    RUNNING                           │   │
    │  │                 (正在CPU执行)                         │   │
    │  │                                                      │   │
    │  │    proc_run()          schedule()                    │   │
    │  │  ────────────>       <────────────                   │   │
    │  └──────────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────────┘
           │                                    ▲
           │ do_wait()/do_sleep()               │ wakeup_proc()
           ▼                                    │
    ┌─────────────────────────────────────────────────────────────┐
    │                     PROC_SLEEPING                           │
    │                   (等待某事件发生)                            │
    └─────────────────────────────────────────────────────────────┘
           │
           │ do_exit()
           ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                      PROC_ZOMBIE                            │
    │                (等待父进程回收资源)                           │
    └─────────────────────────────────────────────────────────────┘
           │
           │ do_wait() (父进程回收)
           ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                       进程终止                               │
    │                   (资源完全释放)                              │
    └─────────────────────────────────────────────────────────────┘
```

## 测试结果

执行`make grade`，所有测试通过：

```
badsegment:              (1.0s)
  -check result:                             OK
  -check output:                             OK
divzero:                 (1.0s)
  -check result:                             OK
  -check output:                             OK
softint:                 (1.0s)
  -check result:                             OK
  -check output:                             OK
faultread:               (1.0s)
  -check result:                             OK
  -check output:                             OK
faultreadkernel:         (1.0s)
  -check result:                             OK
  -check output:                             OK
hello:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
testbss:                 (1.0s)
  -check result:                             OK
  -check output:                             OK
pgdir:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
yield:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
badarg:                  (1.0s)
  -check result:                             OK
  -check output:                             OK
exit:                    (1.0s)
  -check result:                             OK
  -check output:                             OK
spin:                    (1.0s)
  -check result:                             OK
  -check output:                             OK
forktest:                (1.0s)
  -check result:                             OK
  -check output:                             OK
Total Score: 130/130
```

## 重要知识点

### 实验中的知识点

1. **用户进程创建**：通过`load_icode`加载ELF文件，设置用户态执行环境
2. **系统调用机制**：通过`ecall`指令从用户态陷入内核态，执行系统服务
3. **进程内存复制**：`copy_range`实现父子进程内存空间的复制
4. **特权级切换**：通过设置`sstatus`寄存器的SPP位控制返回的特权级

### 对应的OS原理知识点

1. **进程创建与执行**：fork-exec模型是Unix系统创建进程的经典方式
2. **系统调用**：用户态程序获取内核服务的标准接口
3. **进程状态转换**：UNINIT→RUNNABLE→RUNNING→SLEEPING→ZOMBIE的生命周期
4. **Copy on Write**：延迟复制优化，提高fork效率

### 实验与原理的关系

- 实验中的`do_fork`对应进程创建原理
- 实验中的`do_execve`对应程序加载执行原理
- 实验中的`do_wait/do_exit`对应进程同步与终止原理
- trapframe的设置体现了特权级切换的硬件机制

### OS原理中重要但实验未涉及的知识点

1. **进程间通信（IPC）**：管道、消息队列、共享内存等
2. **信号机制**：异步事件通知
3. **线程**：轻量级进程，共享地址空间
4. **进程优先级调度**：实验中使用简单的轮转调度