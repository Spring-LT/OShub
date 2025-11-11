# Lab4 实验报告：进程管理

**23级信息安全  2310411 李听泉**

**23级信息安全  2313876 李子凝**

**23级信息安全  2312092 李朝阳**

> [!NOTE] 
>
> **小组分工：**
>
> 李子凝：负责练习2实现以及OS与实验之间的知识点
>
> 李朝阳：负责练习3实现以及扩展练习
>
> 李听泉：负责练习1以及实验报告整理

## 实验目的

通过本次实验，我学习并掌握了以下内容：
- 虚拟内存管理的基本结构，掌握虚拟内存的组织与管理方式
- 内核线程创建/执行的管理过程
- 内核线程的切换和基本调度过程

## 实验内容

### 练习0：填写已有实验

本实验依赖实验2/3。需要把实验2/3的代码填入本实验中代码中有"LAB2","LAB3"的注释相应部分。

#### Lab2代码迁移

Lab2中实现了物理内存管理的First-Fit算法，主要包括以下函数：
- `default_init()`: 初始化空闲链表
- `default_init_memmap()`: 初始化空闲内存块
- `default_alloc_pages()`: 分配指定数量的物理页
- `default_free_pages()`: 释放物理页并进行合并

这些代码已经在Lab4的`kern/mm/default_pmm.c`中实现完成。

#### Lab3代码迁移

Lab3中实现了时钟中断处理，需要在`kern/trap/trap.c`的`interrupt_handler`函数中添加时钟中断处理代码：

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;
    if (ticks % TICK_NUM == 0) {
        print_ticks();
    }
    break;
```

### 练习1：分配并初始化一个进程控制块（需要编码）

#### 设计实现过程

`alloc_proc`函数负责分配并返回一个新的`struct proc_struct`结构，用于存储新建立的内核线程的管理信息。需要对这个结构进行最基本的初始化。

实现代码如下：

```c
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
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
```

#### 字段初始化说明

1. **state**: 设置为`PROC_UNINIT`表示进程处于未初始化状态
2. **pid**: 设置为-1表示进程ID尚未分配
3. **runs**: 初始化为0，表示进程尚未运行
4. **kstack**: 初始化为0，内核栈将在后续的`setup_kstack`中分配
5. **need_resched**: 初始化为0，表示不需要立即调度
6. **parent**: 初始化为NULL，父进程将在`do_fork`中设置
7. **mm**: 初始化为NULL，内核线程不需要单独的内存管理结构
8. **context**: 清零，上下文将在`copy_thread`中设置
9. **tf**: 初始化为NULL，trapframe将在`copy_thread`中设置
10. **pgdir**: 设置为`boot_pgdir_pa`，内核线程共享内核页目录
11. **flags**: 初始化为0
12. **name**: 清零，进程名将在后续设置

#### 问题回答

**请说明proc_struct中`struct context context`和`struct trapframe *tf`成员变量含义和在本实验中的作用是啥？**

1. **struct context context**:
   - **含义**: `context`保存了进程的上下文信息，包括ra（返回地址）、sp（栈指针）和s0-s11（被调用者保存寄存器）
   - **作用**: 在进程切换时，通过`switch_to`函数保存和恢复这些寄存器的值，使得进程能够在切换后从正确的位置继续执行。具体来说：
     - `context.ra`保存了进程恢复执行时的返回地址
     - `context.sp`保存了进程的栈指针
     - 其他寄存器保存了进程的执行状态

2. **struct trapframe *tf**:
   - **含义**: `tf`指向进程的中断帧，保存了进程在中断/异常发生时的所有寄存器状态
   - **作用**: 
     - 在内核线程创建时，通过设置trapframe来指定线程的入口函数和参数
     - 在中断处理时，保存和恢复进程的完整状态
     - 对于内核线程，`tf`指向内核栈顶的trapframe结构，包含了线程的初始执行环境

### 练习2：为新创建的内核线程分配资源（需要编码）

#### 设计实现过程

`do_fork`函数负责创建一个新的内核线程，它会调用`alloc_proc`分配进程控制块，然后为新线程分配资源并复制父进程的状态。

实现代码如下：

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
```

#### 实现步骤说明

1. **分配进程控制块**: 调用`alloc_proc()`分配并初始化一个新的进程控制块
2. **设置父进程**: 将当前进程设置为新进程的父进程
3. **分配内核栈**: 调用`setup_kstack()`为新进程分配内核栈空间
4. **复制内存管理信息**: 调用`copy_mm()`，对于内核线程来说这个函数不做任何操作
5. **设置trapframe和context**: 调用`copy_thread()`设置新进程的中断帧和上下文
6. **分配PID并加入进程列表**: 
   - 关闭中断以保证原子性
   - 调用`get_pid()`分配唯一的进程ID
   - 调用`hash_proc()`将进程加入哈希表
   - 将进程加入进程链表
   - 增加进程计数
   - 恢复中断
7. **唤醒新进程**: 调用`wakeup_proc()`将新进程状态设置为`PROC_RUNNABLE`
8. **返回新进程PID**: 返回新创建进程的PID

#### 问题回答

**请说明ucore是否做到给每个新fork的线程一个唯一的id？请说明你的分析和理由。**

是的，ucore能够保证给每个新fork的线程分配一个唯一的ID。理由如下：

1. **get_pid()函数的设计**:
   - 使用静态变量`last_pid`记录上一次分配的PID
   - 使用静态变量`next_safe`记录下一个安全的PID范围
   - 每次分配PID时，会遍历进程链表检查是否有冲突

2. **分配算法**:
   ```c
   static int get_pid(void) {
       static_assert(MAX_PID > MAX_PROCESS);
       struct proc_struct *proc;
       list_entry_t *list = &proc_list, *le;
       static int next_safe = MAX_PID, last_pid = MAX_PID;
       if (++last_pid >= MAX_PID) {
           last_pid = 1;
           goto inside;
       }
       if (last_pid >= next_safe) {
       inside:
           next_safe = MAX_PID;
       repeat:
           le = list;
           while ((le = list_next(le)) != list) {
               proc = le2proc(le, list_link);
               if (proc->pid == last_pid) {
                   if (++last_pid >= next_safe) {
                       if (last_pid >= MAX_PID) {
                           last_pid = 1;
                       }
                       next_safe = MAX_PID;
                       goto repeat;
                   }
               }
               else if (proc->pid > last_pid && next_safe > proc->pid) {
                   next_safe = proc->pid;
               }
           }
       }
       return last_pid;
   }
   ```

3. **唯一性保证**:
   - 算法会检查`last_pid`是否与现有进程的PID冲突
   - 如果冲突，会递增`last_pid`并重新检查
   - 使用`next_safe`优化搜索范围，避免重复检查
   - 在关闭中断的情况下调用`get_pid()`，保证了原子性

4. **并发安全**:
   - 在`do_fork`中调用`get_pid()`时使用了`local_intr_save()`和`local_intr_restore()`
   - 这保证了在分配PID和将进程加入链表的过程中不会被中断
   - 因此不会出现两个进程获得相同PID的情况

### 练习3：编写proc_run函数（需要编码）

#### 设计实现过程

`proc_run`函数用于将指定的进程切换到CPU上运行。实现代码如下：

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

#### 实现步骤说明

1. **检查是否需要切换**: 如果要切换的进程与当前进程相同，则不需要切换
2. **禁用中断**: 使用`local_intr_save()`禁用中断，保证切换过程的原子性
3. **更新当前进程**: 将全局变量`current`更新为要运行的进程
4. **切换页表**: 调用`lsatp()`函数修改SATP寄存器，切换到新进程的页表
5. **上下文切换**: 调用`switch_to()`函数进行上下文切换，保存当前进程的寄存器状态并恢复新进程的寄存器状态
6. **允许中断**: 使用`local_intr_restore()`恢复中断状态

#### 关键函数说明

1. **lsatp()函数**:
   ```c
   static inline void lsatp(unsigned int pgdir)
   {
       write_csr(satp, SATP32_MODE | (pgdir >> RISCV_PGSHIFT));
   }
   ```
   - 修改SATP（Supervisor Address Translation and Protection）寄存器
   - 切换页表，使新进程能够访问自己的地址空间

2. **switch_to()函数**:
   - 在`kern/process/switch.S`中用汇编实现
   - 保存当前进程的context（ra, sp, s0-s11）
   - 恢复新进程的context
   - 通过修改ra寄存器实现执行流的切换

#### 问题回答

**在本实验的执行过程中，创建且运行了几个内核线程？**

在本实验中，创建并运行了**2个内核线程**：

1. **idleproc（第0个内核线程）**:
   - PID为0
   - 在`proc_init()`中直接创建
   - 是系统的第一个进程，也是唯一一个没有通过`do_fork`创建的进程
   - 作用是在没有其他进程需要运行时占用CPU
   - 执行`cpu_idle()`函数，不断检查是否需要调度

2. **initproc（第1个内核线程）**:
   - PID为1
   - 通过`kernel_thread(init_main, "Hello world!!", 0)`创建
   - 是第一个通过`do_fork`创建的内核线程
   - 执行`init_main()`函数，输出"Hello world!!"等信息
   - 是系统中第一个真正执行任务的内核线程

执行流程：
1. 系统启动后，在`kern_init()`中调用`proc_init()`
2. `proc_init()`创建idleproc并设置为当前进程
3. `proc_init()`调用`kernel_thread()`创建initproc
4. `kern_init()`最后调用`cpu_idle()`
5. `cpu_idle()`检测到需要调度，调用`schedule()`
6. `schedule()`选择initproc运行
7. `proc_run()`切换到initproc
8. initproc执行`init_main()`输出信息

## 扩展练习 Challenge

### Challenge 1：说明语句`local_intr_save(intr_flag);....local_intr_restore(intr_flag);`是如何实现开关中断的？

#### 实现机制

在`kern/sync/sync.h`中定义了这两个宏：

```c
static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
        intr_disable();
        return 1;
    }
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
    }
}

#define local_intr_save(x) \
    do {                   \
        x = __intr_save(); \
    } while (0)
    
#define local_intr_restore(x) __intr_restore(x);
```

#### 工作原理

1. **local_intr_save(intr_flag)**:
   - 读取`sstatus`寄存器的SIE（Supervisor Interrupt Enable）位
   - 如果中断当前是开启的（SIE=1），则：
     - 调用`intr_disable()`关闭中断
     - 返回1表示之前中断是开启的
   - 如果中断当前是关闭的（SIE=0），则：
     - 不做任何操作
     - 返回0表示之前中断是关闭的
   - 将返回值保存到`intr_flag`中

2. **local_intr_restore(intr_flag)**:
   - 检查`intr_flag`的值
   - 如果`intr_flag`为1（表示之前中断是开启的），则调用`intr_enable()`重新开启中断
   - 如果`intr_flag`为0（表示之前中断是关闭的），则不做任何操作

#### 使用场景

这种设计的优点是：
- **保存和恢复中断状态**：不是简单地关闭和开启中断，而是记住中断之前的状态并恢复
- **支持嵌套**：如果在中断已经关闭的情况下再次调用`local_intr_save()`，不会影响中断状态
- **原子操作保护**：在临界区代码执行期间禁止中断，防止并发访问导致的数据不一致

在本实验中的使用：
- `do_fork()`中保护进程列表的修改
- `proc_run()`中保护进程切换过程

### Challenge 2：深入理解不同分页模式的工作原理

#### get_pte()函数中两段相似代码的解释

在`kern/mm/pmm.c`中的`get_pte()`函数有两段形式类似的代码，这是因为RISC-V的多级页表结构。

以sv39为例（三级页表）：
- 第一段代码处理第一级页表（Page Directory）
- 第二段代码处理第二级页表（Page Middle Directory）
- 最后返回第三级页表（Page Table）中的页表项

这两段代码相似是因为：
1. **统一的页表结构**：sv32、sv39、sv48都使用相同的页表项格式
2. **递归的查找过程**：每一级页表的查找逻辑都是相同的
3. **按需分配**：如果某一级页表不存在，需要分配新页表

不同分页模式的异同：
- **sv32**：2级页表，32位虚拟地址
- **sv39**：3级页表，39位虚拟地址
- **sv48**：4级页表，48位虚拟地址

#### get_pte()函数设计的评价

**当前设计的优点**：
1. **简洁性**：将查找和分配合并在一个函数中，代码简洁
2. **便利性**：调用者不需要关心页表是否存在，函数会自动处理
3. **一致性**：保证了页表的一致性，避免了中间状态

**当前设计的缺点**：
1. **功能耦合**：查找和分配是两个不同的功能，混在一起降低了灵活性
2. **性能考虑**：有时候只需要查找而不需要分配，但函数总是会尝试分配
3. **错误处理**：分配失败时的处理不够清晰

**改进建议**：
可以考虑将功能拆分为两个函数：
```c
pte_t *find_pte(pde_t *pgdir, uintptr_t la);  // 只查找，不分配
pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create);  // 可选择是否分配
```

这样的设计：
- 提高了灵活性，调用者可以根据需求选择
- 更符合单一职责原则
- 便于性能优化和错误处理

但对于教学实验来说，当前的设计已经足够简洁和实用。

## 实验运行结果

编译并运行系统后，成功实现了预期功能：
- 成功创建了idleproc和initproc两个内核线程
- initproc输出了"Hello world!!"信息
- 进程切换机制工作正常

运行grading脚本的结果：
```
  -check alloc proc:                         OK
  -check initproc:                           OK
Total Score: 30/30
```

所有测试用例均通过，获得满分30分。

## 重要知识点总结

### 进程控制块（PCB）

1. **进程状态**：
   - `PROC_UNINIT`：未初始化
   - `PROC_SLEEPING`：睡眠状态
   - `PROC_RUNNABLE`：就绪状态
   - `PROC_ZOMBIE`：僵尸状态

2. **关键字段**：
   - `state`：进程状态
   - `pid`：进程ID
   - `kstack`：内核栈地址
   - `context`：进程上下文
   - `tf`：中断帧
   - `pgdir`：页目录基址

### 进程创建

1. **创建流程**：
   - 分配进程控制块
   - 分配内核栈
   - 复制内存管理信息
   - 设置trapframe和context
   - 分配PID并加入进程列表
   - 唤醒新进程

2. **关键函数**：
   - `alloc_proc()`：分配并初始化PCB
   - `setup_kstack()`：分配内核栈
   - `copy_thread()`：设置trapframe和context
   - `get_pid()`：分配唯一PID
   - `wakeup_proc()`：唤醒进程

### 进程切换

1. **切换流程**：
   - 禁用中断
   - 更新当前进程
   - 切换页表
   - 上下文切换
   - 允许中断

2. **关键机制**：
   - `context`保存进程的寄存器状态
   - `switch_to()`实现上下文切换
   - `lsatp()`切换页表

### 进程调度

1. **调度策略**：
   - 本实验使用简单的FIFO调度
   - `schedule()`函数选择下一个运行的进程
   - `proc_run()`执行进程切换

2. **调度时机**：
   - 时钟中断
   - 进程主动让出CPU
   - 进程阻塞

## OS原理与实验对比

### 实验中覆盖的OS原理知识点

1. **进程管理**：
   - 进程控制块的设计和实现
   - 进程的创建、切换和调度
   - 进程状态转换

2. **内存管理**：
   - 虚拟内存管理
   - 页表机制
   - 内核栈的分配和管理

3. **并发控制**：
   - 中断的开关
   - 临界区保护
   - 原子操作

4. **上下文切换**：
   - 寄存器的保存和恢复
   - 栈的切换
   - 执行流的转移

### OS原理中重要但实验中未覆盖的知识点

1. **进程间通信（IPC）**：
   - 管道
   - 消息队列
   - 共享内存
   - 信号量

2. **高级调度算法**：
   - 优先级调度
   - 多级反馈队列
   - 实时调度

3. **进程同步**：
   - 互斥锁
   - 条件变量
   - 读写锁

4. **用户进程**：
   - 用户态和内核态的切换
   - 系统调用机制
   - 用户进程的创建和管理

5. **进程资源管理**：
   - 文件描述符
   - 信号处理
   - 资源限制

## 实验心得

通过本次实验，我深入理解了操作系统中进程管理的核心机制。特别是：

1. **进程控制块的设计**：PCB是操作系统管理进程的核心数据结构，包含了进程的所有关键信息。合理的初始化对于进程的正确运行至关重要。

2. **进程创建的复杂性**：创建一个进程需要分配多种资源（PCB、内核栈等），设置多个状态（trapframe、context等），并且需要保证原子性。

3. **上下文切换的精妙**：通过保存和恢复寄存器状态，操作系统能够在多个进程之间快速切换，实现并发执行的假象。

4. **中断保护的重要性**：在修改共享数据结构（如进程列表）时，必须禁用中断以保证原子性，防止数据不一致。

5. **内核线程与用户进程的区别**：内核线程共享内核地址空间，不需要独立的内存管理结构，这简化了实现但也限制了隔离性。

本实验为后续实现用户进程、系统调用等功能奠定了坚实的基础。通过实际编码和调试，我对操作系统的进程管理有了更深刻的理解。
