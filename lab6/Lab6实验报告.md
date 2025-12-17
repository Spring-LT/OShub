# LAB6 进程调度

**23级信息安全  2310411 李听泉**

**23级信息安全  2313876 李子凝**

**23级信息安全  2312092 李朝阳**

> [!NOTE] 
>
> **小组分工：**
>
> 李子凝：负责练习1调度框架分析以及OS与实验之间的知识点
>
> 李朝阳：负责练习2 RR调度器实现以及Challenge 2多调度算法设计
>
> 李听泉：负责练习0代码填写以及Challenge 1 Stride调度器实现

----

## 实验目的

- 理解操作系统的调度管理机制
- 熟悉 ucore 的系统调度器框架，实现缺省的Round-Robin 调度算法
- 基于调度器框架实现Stride Scheduling调度算法来替换缺省的调度算法

## 练习0：填写已有实验

本实验依赖实验2/3/4/5。需要把之前实验的代码填入本实验中代码中有"LAB2"/"LAB3"/"LAB4"/"LAB5"的注释相应部分。

### LAB4/LAB5/LAB6代码填写

#### alloc_proc函数

`alloc_proc`函数负责分配并初始化一个进程控制块。在Lab6中，需要额外初始化调度相关字段（`rq`、`run_link`、`time_slice`、`lab6_run_pool`、`lab6_stride`、`lab6_priority`）。

```c
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        // LAB4 初始化
        proc->state = PROC_UNINIT;
        proc->pid = -1;
        proc->runs = 0;
        proc->kstack = 0;
        proc->need_resched = 0;
        proc->parent = NULL;
        proc->mm = NULL;
        memset(&(proc->context), 0, sizeof(struct context));
        proc->tf = NULL;
        proc->pgdir = boot_pgdir_pa;
        proc->flags = 0;
        memset(proc->name, 0, PROC_NAME_LEN + 1);

        // LAB5 新增初始化
        proc->wait_state = 0;
        proc->cptr = NULL;
        proc->yptr = NULL;
        proc->optr = NULL;

        // LAB6 新增初始化
        proc->rq = NULL;
        list_init(&(proc->run_link));
        proc->time_slice = 0;
        skew_heap_init(&(proc->lab6_run_pool));
        proc->lab6_stride = 0;
        proc->lab6_priority = 1;  // 默认优先级为1，避免除零
    }
    return proc;
}
```

#### do_fork函数

`do_fork`函数是创建子进程的核心函数，沿用Lab5实现。

```c
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    if (nr_process >= MAX_PROCESS) {
        goto fork_out;
    }
    ret = -E_NO_MEM;

    if ((proc = alloc_proc()) == NULL) {
        goto fork_out;
    }

    proc->parent = current;
    assert(current->wait_state == 0);

    if (setup_kstack(proc) != 0) {
        goto bad_fork_cleanup_proc;
    }
    if (copy_mm(clone_flags, proc) != 0) {
        goto bad_fork_cleanup_kstack;
    }
    copy_thread(proc, stack, tf);

    bool intr_flag;
    local_intr_save(intr_flag);
    {
        proc->pid = get_pid();
        hash_proc(proc);
        set_links(proc);
    }
    local_intr_restore(intr_flag);

    wakeup_proc(proc);
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

#### proc_run函数

`proc_run`函数负责进程切换，包括切换页表和上下文。

```c
void proc_run(struct proc_struct *proc)
{
    if (proc != current)
    {
        bool intr_flag;
        struct proc_struct *prev = current, *next = proc;
        local_intr_save(intr_flag);
        {
            current = proc;
            lsatp(next->pgdir);
            switch_to(&(prev->context), &(next->context));
        }
        local_intr_restore(intr_flag);
    }
}
```

### LAB3代码填写

时钟中断处理（更新为Lab6版本，调用`sched_class_proc_tick`）：

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;

#ifndef DEBUG_GRADE
    if (ticks % TICK_NUM == 0) {
        print_ticks();
    }
#endif
    if (current != NULL) {
        sched_class_proc_tick(current);
    }
    break;
```

### LAB5代码填写

#### copy_range函数

```c
void *src_kvaddr = page2kva(page);
void *dst_kvaddr = page2kva(npage);
memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
ret = page_insert(to, npage, start, perm);
```

#### load_icode中的trapframe设置

```c
tf->gpr.sp = USTACKTOP;
tf->epc = elf->e_entry;
tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;
```

## 练习1: 理解调度器框架的实现（不需要编码）

### sched_class结构体分析

`sched_class`结构体定义了调度器的接口：

```c
struct sched_class {
    const char *name;                                           // 调度类名称
    void (*init)(struct run_queue *rq);                         // 初始化运行队列
    void (*enqueue)(struct run_queue *rq, struct proc_struct *proc);  // 入队
    void (*dequeue)(struct run_queue *rq, struct proc_struct *proc);  // 出队
    struct proc_struct *(*pick_next)(struct run_queue *rq);     // 选择下一个进程
    void (*proc_tick)(struct run_queue *rq, struct proc_struct *proc); // 时钟tick处理
};
```

**为什么使用函数指针？**
- **解耦**：调度框架与具体算法分离，便于扩展
- **多态**：运行时可切换不同调度算法（RR、Stride等）
- **模块化**：新增调度算法只需实现接口，无需修改框架代码

### run_queue结构体分析

**Lab5 vs Lab6对比：**

| 字段 | Lab5 | Lab6 |
|------|------|------|
| `run_list` | 简单链表 | 链表（RR用） |
| `proc_num` | 进程数 | 进程数 |
| `max_time_slice` | 无 | 最大时间片 |
| `lab6_run_pool` | 无 | Skew Heap（Stride用） |

**为什么需要两种数据结构？**
- **链表**：适合RR调度，O(1)入队出队
- **Skew Heap**：适合Stride调度，O(log n)获取最小stride进程

### 调度器框架函数分析

#### sched_init()

```c
void sched_init(void) {
    list_init(&timer_list);
    sched_class = &default_sched_class;  // 绑定RR调度器
    rq = &__rq;
    rq->max_time_slice = MAX_TIME_SLICE;
    sched_class->init(rq);
    cprintf("sched class: %s\n", sched_class->name);
}
```

#### wakeup_proc()

```c
void wakeup_proc(struct proc_struct *proc) {
    assert(proc->state != PROC_ZOMBIE);
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        if (proc->state != PROC_RUNNABLE) {
            proc->state = PROC_RUNNABLE;
            proc->wait_state = 0;
            if (proc != current) {
                sched_class_enqueue(proc);  // 加入运行队列
            }
        }
    }
    local_intr_restore(intr_flag);
}
```

#### schedule()

```c
void schedule(void) {
    bool intr_flag;
    struct proc_struct *next;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        if (current->state == PROC_RUNNABLE) {
            sched_class_enqueue(current);  // 当前进程重新入队
        }
        if ((next = sched_class_pick_next()) != NULL) {
            sched_class_dequeue(next);     // 选中进程出队
        }
        if (next == NULL) {
            next = idleproc;
        }
        next->runs++;
        if (next != current) {
            proc_run(next);
        }
    }
    local_intr_restore(intr_flag);
}
```

### 进程调度流程图

```
                    时钟中断触发
                         │
                         ▼
              ┌─────────────────────┐
              │   interrupt_handler │
              │   IRQ_S_TIMER       │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │ sched_class_proc_tick│
              │   (current)         │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │  RR_proc_tick /     │
              │  stride_proc_tick   │
              │  time_slice--       │
              └──────────┬──────────┘
                         │
            time_slice == 0?
                   │
         ┌─────────┴─────────┐
         │ Yes               │ No
         ▼                   ▼
  need_resched = 1      继续执行
         │
         ▼
  ┌──────────────┐
  │ trap返回前   │
  │ 检查need_    │
  │ resched      │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │  schedule()  │
  └──────┬───────┘
         │
         ▼
  ┌──────────────────────────────────────┐
  │ 1. enqueue(current) 当前进程入队     │
  │ 2. pick_next() 选择下一个进程        │
  │ 3. dequeue(next) 选中进程出队        │
  │ 4. proc_run(next) 切换到新进程       │
  └──────────────────────────────────────┘
```

### need_resched标志位的作用

`need_resched`是进程控制块中的布尔标志，用于标记当前进程是否需要被调度：

1. **设置时机**：`proc_tick`中时间片耗尽时设置为1
2. **检查时机**：中断/系统调用返回前检查
3. **清除时机**：`schedule()`开始时清除
4. **作用**：延迟调度决策，避免在中断处理中直接调度

### 调度算法切换机制

要添加新调度算法（如Stride），需要：

1. **实现调度类**：在`default_sched_stride.c`中实现5个接口函数
2. **声明调度类**：在`default_sched.h`中声明`stride_sched_class`
3. **切换调度器**：修改`sched_init()`中的绑定

```c
// sched.c
void sched_init(void) {
    // sched_class = &default_sched_class;  // RR
    sched_class = &stride_sched_class;      // Stride
    // ...
}
```

**设计优点**：
- 只需修改一行代码即可切换调度算法
- 新算法无需修改框架代码
- 便于测试和比较不同算法

## 练习2: 实现 Round Robin 调度算法（需要编码）

### Lab5与Lab6的schedule函数对比

**Lab5的schedule函数**（FIFO调度）：
```c
void schedule(void) {
    list_entry_t *le, *last;
    struct proc_struct *next = NULL;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        last = (current == idleproc) ? &proc_list : &(current->list_link);
        le = last;
        do {
            le = list_next(le);
            if (le != &proc_list) {
                next = le2proc(le, list_link);
                if (next->state == PROC_RUNNABLE) {
                    break;
                }
            }
        } while (le != last);
        // ...
    }
}
```

**Lab6的schedule函数**（使用调度类）：
```c
void schedule(void) {
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        if (current->state == PROC_RUNNABLE) {
            sched_class_enqueue(current);
        }
        if ((next = sched_class_pick_next()) != NULL) {
            sched_class_dequeue(next);
        }
        // ...
    }
}
```

**改动原因**：
- Lab5直接遍历`proc_list`，调度逻辑与框架耦合
- Lab6通过`sched_class`接口调用，实现解耦
- 不做此改动会导致无法切换调度算法

### RR调度器实现

#### RR_init

```c
static void RR_init(struct run_queue *rq)
{
    list_init(&(rq->run_list));
    rq->proc_num = 0;
}
```

**设计思路**：初始化空的循环链表作为运行队列。

#### RR_enqueue

```c
static void RR_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
    assert(proc->rq == NULL);  // 边界检查：确保进程未在队列中
    proc->rq = rq;
    if (proc->time_slice <= 0) {
        proc->time_slice = rq->max_time_slice;  // 重置时间片
    }
    list_add_before(&(rq->run_list), &(proc->run_link));  // 插入队尾
    rq->proc_num++;
}
```

**设计思路**：
- 使用`list_add_before`插入到头结点之前，实现队尾插入
- 时间片耗尽的进程重新获得完整时间片
- 使用`assert`检查进程是否已在队列中

**边界处理**：
- `proc->rq == NULL`：确保不重复入队
- `time_slice <= 0`：处理新进程或时间片耗尽的进程

#### RR_dequeue

```c
static void RR_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
    assert(proc->rq == rq);  // 边界检查：确保进程在正确队列中
    list_del_init(&(proc->run_link));
    proc->rq = NULL;
    rq->proc_num--;
}
```

**设计思路**：从链表中删除进程，并清理`rq`指针。

#### RR_pick_next

```c
static struct proc_struct *RR_pick_next(struct run_queue *rq)
{
    if (list_empty(&(rq->run_list))) {
        return NULL;  // 边界处理：空队列
    }
    list_entry_t *le = list_next(&(rq->run_list));
    return le2proc(le, run_link);
}
```

**设计思路**：从队头选择进程，配合队尾入队实现FIFO。

**边界处理**：空队列返回NULL，由`schedule()`处理。

#### RR_proc_tick

```c
static void RR_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
    if (proc->time_slice > 0) {
        proc->time_slice--;
    }
    if (proc->time_slice == 0) {
        proc->need_resched = 1;
    }
}
```

**设计思路**：
- 每次时钟中断递减时间片
- 时间片耗尽时设置`need_resched`标志
- 不直接调用`schedule()`，延迟到中断返回时处理

**为什么在proc_tick中设置need_resched？**
- 避免在中断处理中直接调度（可能导致死锁）
- 统一调度入口，便于管理
- 符合"延迟调度"的设计模式

### make grade输出结果

```
priority:                (3.1s)
  -check result:                             OK
  -check output:                             OK
Total Score: 50/50
```

### RR调度算法分析

**优点**：
- 公平性：每个进程获得相等的CPU时间
- 简单：实现简单，开销小
- 响应性：时间片较小时响应较快

**缺点**：
- 无优先级：不区分进程重要性
- 上下文切换开销：时间片过小会增加切换开销
- 不适合I/O密集型：I/O进程可能浪费时间片

**时间片大小优化**：
- 过大：响应时间长，退化为FIFO
- 过小：上下文切换开销大
- 建议：10-100ms，根据系统负载调整

### 拓展思考

**优先级RR调度实现**：
1. 维护多个运行队列，每个优先级一个
2. `pick_next`从最高优先级非空队列选择
3. 可选：高优先级进程获得更长时间片

**多核调度支持**：
1. 每个CPU维护独立的运行队列
2. 实现负载均衡机制
3. 添加`rq_lock`保护运行队列
4. 考虑缓存亲和性

## 扩展练习 Challenge 1: 实现 Stride Scheduling 调度算法

### Stride调度算法原理

Stride调度是一种比例份额调度算法，核心思想：

1. 每个进程有`stride`值（当前调度权）和`pass`值（步进值）
2. 每次选择`stride`最小的进程执行
3. 执行后更新：`stride += pass = BIG_STRIDE / priority`
4. 优先级高的进程`pass`小，`stride`增长慢，被调度更频繁

### Stride调度器实现

#### BIG_STRIDE定义

```c
#define BIG_STRIDE 0x7fffffffU
```

**为什么取0x7fffffff？**
- 32位无符号整数最大值的一半
- 保证`STRIDE_MAX - STRIDE_MIN <= BIG_STRIDE`
- 使用有符号比较处理溢出：`(int32_t)(a - b)`

#### stride_init

```c
static void stride_init(struct run_queue *rq)
{
    list_init(&(rq->run_list));
    rq->lab6_run_pool = NULL;
    rq->proc_num = 0;
}
```

#### stride_enqueue

```c
static void stride_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
    assert(proc->rq == NULL);
    if (proc->time_slice <= 0) {
        proc->time_slice = rq->max_time_slice;
    }
    if (proc->lab6_priority == 0) {
        proc->lab6_priority = 1;  // 防止除零
    }
    rq->lab6_run_pool = skew_heap_insert(rq->lab6_run_pool, 
                                          &(proc->lab6_run_pool), 
                                          proc_stride_comp_f);
    list_add_before(&(rq->run_list), &(proc->run_link));
    proc->rq = rq;
    rq->proc_num++;
}
```

#### stride_dequeue

```c
static void stride_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
    assert(proc->rq == rq);
    list_del_init(&(proc->run_link));
    rq->lab6_run_pool = skew_heap_remove(rq->lab6_run_pool, 
                                          &(proc->lab6_run_pool), 
                                          proc_stride_comp_f);
    proc->rq = NULL;
    rq->proc_num--;
}
```

#### stride_pick_next

```c
static struct proc_struct *stride_pick_next(struct run_queue *rq)
{
    if (rq->lab6_run_pool == NULL) {
        return NULL;
    }
    struct proc_struct *proc = le2proc(rq->lab6_run_pool, lab6_run_pool);
    uint32_t priority = proc->lab6_priority == 0 ? 1 : proc->lab6_priority;
    proc->lab6_stride += BIG_STRIDE / priority;
    return proc;
}
```

#### stride_proc_tick

```c
static void stride_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
    if (proc->time_slice > 0) {
        proc->time_slice--;
    }
    if (proc->time_slice == 0) {
        proc->need_resched = 1;
    }
}
```

#### 比较函数

```c
static int proc_stride_comp_f(void *a, void *b)
{
    struct proc_struct *p = le2proc(a, lab6_run_pool);
    struct proc_struct *q = le2proc(b, lab6_run_pool);
    int32_t c = p->lab6_stride - q->lab6_stride;  // 有符号比较处理溢出
    if (c > 0) return 1;
    else if (c == 0) return 0;
    else return -1;
}
```

### Stride算法正比性证明

**命题**：经过足够多的时间片后，每个进程分配到的时间片数目与其优先级成正比。

**证明**：

设有n个进程，优先级分别为$P_1, P_2, ..., P_n$，步进值为$pass_i = \frac{BIG\_STRIDE}{P_i}$。

经过T轮调度后，进程i被调度$N_i$次，则其stride增量为：
$$\Delta stride_i = N_i \times pass_i = N_i \times \frac{BIG\_STRIDE}{P_i}$$

由于Stride调度总是选择stride最小的进程，在稳态下所有进程的stride趋于相等：
$$stride_1 \approx stride_2 \approx ... \approx stride_n$$

因此：
$$N_1 \times \frac{BIG\_STRIDE}{P_1} \approx N_2 \times \frac{BIG\_STRIDE}{P_2}$$

化简得：
$$\frac{N_1}{P_1} \approx \frac{N_2}{P_2}$$

即：
$$N_1 : N_2 : ... : N_n \approx P_1 : P_2 : ... : P_n$$

**结论**：每个进程获得的调度次数与其优先级成正比。

### 多级反馈队列调度算法设计

#### 概要设计

多级反馈队列（MLFQ）结合了优先级调度和时间片轮转：

1. **多级队列**：维护多个优先级队列（如8级）
2. **时间片递增**：低优先级队列时间片更长
3. **动态降级**：进程用完时间片后降到下一级队列
4. **周期性提升**：防止饥饿，定期将所有进程提升到最高优先级

#### 详细设计

```c
#define MLFQ_LEVELS 8

struct mlfq_run_queue {
    list_entry_t queues[MLFQ_LEVELS];  // 8级队列
    int time_slices[MLFQ_LEVELS];       // 各级时间片：1,2,4,8,16,32,64,128
    int proc_num;
    int boost_ticks;                    // 提升计数器
};

// 入队：新进程进入最高优先级队列
void mlfq_enqueue(struct mlfq_run_queue *rq, struct proc_struct *proc) {
    if (proc->mlfq_level < 0) {
        proc->mlfq_level = 0;  // 新进程
    }
    proc->time_slice = rq->time_slices[proc->mlfq_level];
    list_add_before(&rq->queues[proc->mlfq_level], &proc->run_link);
}

// 选择：从最高优先级非空队列选择
struct proc_struct *mlfq_pick_next(struct mlfq_run_queue *rq) {
    for (int i = 0; i < MLFQ_LEVELS; i++) {
        if (!list_empty(&rq->queues[i])) {
            return le2proc(list_next(&rq->queues[i]), run_link);
        }
    }
    return NULL;
}

// 时钟tick：时间片耗尽则降级
void mlfq_proc_tick(struct mlfq_run_queue *rq, struct proc_struct *proc) {
    proc->time_slice--;
    if (proc->time_slice == 0) {
        if (proc->mlfq_level < MLFQ_LEVELS - 1) {
            proc->mlfq_level++;  // 降级
        }
        proc->need_resched = 1;
    }
    
    // 周期性提升
    rq->boost_ticks++;
    if (rq->boost_ticks >= BOOST_INTERVAL) {
        mlfq_boost_all(rq);
        rq->boost_ticks = 0;
    }
}
```

## 扩展练习 Challenge 2: 实现多种调度算法

### FIFO调度算法

```c
// 最简单的调度：先来先服务
static void FIFO_enqueue(struct run_queue *rq, struct proc_struct *proc) {
    list_add_before(&(rq->run_list), &(proc->run_link));
    proc->rq = rq;
    rq->proc_num++;
}

static struct proc_struct *FIFO_pick_next(struct run_queue *rq) {
    if (list_empty(&(rq->run_list))) return NULL;
    return le2proc(list_next(&(rq->run_list)), run_link);
}

// proc_tick不做任何事，进程运行直到主动让出
static void FIFO_proc_tick(struct run_queue *rq, struct proc_struct *proc) {
    // 不设置need_resched，进程持续运行
}
```

### SJF调度算法（概要设计）

```c
// 最短作业优先：需要预估执行时间
struct proc_struct {
    // ...
    int estimated_time;  // 预估执行时间
};

static int sjf_comp_f(void *a, void *b) {
    struct proc_struct *p = le2proc(a, lab6_run_pool);
    struct proc_struct *q = le2proc(b, lab6_run_pool);
    return p->estimated_time - q->estimated_time;
}

// 使用Skew Heap维护，选择estimated_time最小的进程
```

### 调度算法对比

| 算法 | 公平性 | 响应时间 | 吞吐量 | 实现复杂度 | 适用场景 |
|------|--------|----------|--------|------------|----------|
| FIFO | 差 | 差 | 中 | 低 | 批处理 |
| RR | 好 | 好 | 中 | 低 | 交互式 |
| SJF | 差 | 好 | 高 | 中 | 批处理 |
| Stride | 可控 | 中 | 中 | 中 | 比例份额 |
| MLFQ | 好 | 好 | 高 | 高 | 通用 |

## 测试结果

执行`make grade`，所有测试通过：

```
priority:                (3.1s)
  -check result:                             OK
  -check output:                             OK
Total Score: 50/50
```

## 重要知识点

### 实验中的知识点

1. **调度类抽象**：通过函数指针实现调度算法的多态
2. **运行队列**：链表（RR）和优先队列（Stride）两种实现
3. **时间片管理**：`time_slice`与`need_resched`协同工作
4. **Skew Heap**：自调节堆，O(log n)操作复杂度

### 对应的OS原理知识点

1. **进程调度**：CPU资源分配的核心机制
2. **调度算法**：FIFO、RR、优先级、多级反馈队列
3. **比例份额调度**：Stride、彩票调度
4. **抢占式调度**：时钟中断触发的调度

### 实验与原理的关系

- `sched_class`对应调度器框架设计模式
- `RR_proc_tick`对应时间片轮转原理
- `stride_pick_next`对应比例份额调度原理
- `need_resched`对应延迟调度机制

### OS原理中重要但实验未涉及的知识点

1. **多核调度**：负载均衡、缓存亲和性
2. **实时调度**：EDF、RM算法
3. **优先级反转**：优先级继承、优先级天花板
4. **公平调度**：CFS（完全公平调度器）

---

## 总结

通过本次实验，我们完成了：

1. **调度框架理解**：掌握了`sched_class`抽象和`run_queue`数据结构
2. **RR调度实现**：实现了时间片轮转调度的5个核心函数
3. **Stride调度实现**：基于Skew Heap实现了比例份额调度
4. **多调度算法设计**：给出了MLFQ、FIFO、SJF的概要设计

实验加深了对操作系统调度机制的理解，特别是调度框架的设计模式和不同调度算法的权衡。
