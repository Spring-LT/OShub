## lab4: 进程管理

在前面的实验中，我们已经完成了物理内存管理和基础页表机制的实现，使内核具备了对物理内存页的分配与管理能力，并能够建立起虚拟地址到物理地址的基本映射结构。本实验将在此基础上进一步扩展，完成以下两方面内容：首先，通过引入虚拟内存描述结构，管理进程或线程的虚拟地址空间布局，为每个执行实体提供逻辑上的运行空间；其次，本实验将实现线程控制块、上下文切换和调度器等内容，从而实现多线程并发执行，使内核能够调度多个执行实体轮流使用 CPU 运行。

## 实验目的

- 了解虚拟内存管理的基本结构，掌握虚拟内存的组织与管理方式
- 了解内核线程创建/执行的管理过程
- 了解内核线程的切换和基本调度过程

## 实验内容

在前面的实验中，我们已经完成了物理内存管理和基础页表机制的实现，使内核具备了对物理内存页的分配与管理能力，并能够建立起虚拟地址到物理地址的基本映射结构。但当前系统仍然只能以单一执行流的方式运行，无法并发执行多个任务，也尚未体现虚拟内存机制在进程或线程隔离中的作用。

本实验将在此基础上进一步扩展，完成以下两方面内容：

首先，**进一步完善虚拟内存管理，实现基本的地址空间结构**。通过引入虚拟内存描述结构，管理进程或线程的虚拟地址空间布局，为每个执行实体提供逻辑上的运行空间。与后续实验中的缺页异常和页面置换不同，本实验中的虚拟内存仍采用**预映射方式**，即在建立地址空间时一次性完成所有需要的页表映射，不涉及按需分配或页面置换。

其次，**引入内核线程机制，实现多执行流并发运行能力**。内核线程是一种特殊形式的“进程”。当一个程序加载到内存中运行时，首先通过ucore OS的内存管理子系统分配合适的空间，然后就需要考虑如何分时使用CPU来“并发”执行多个程序，让每个运行的程序（这里用线程或进程表示）“感到”它们各自拥有“自己”的CPU。本实验将实现线程控制块、上下文切换和调度器等内容，从而实现多线程并发执行，使内核能够调度多个执行实体轮流使用 CPU 运行。

内核线程与用户进程的区别如下：

| 比较项   | 内核线程         | 用户进程                   |
| -------- | ---------------- | -------------------------- |
| 运行模式 | 仅在内核态运行   | 在用户态和内核态之间切换   |
| 地址空间 | 共享内核地址空间 | 拥有独立的用户虚拟地址空间 |

通过本实验，系统将从“单一执行流的内核”发展为“支持多线程调度的内核”，并完成基本的虚拟内存环境框架搭建，为后续实现用户进程、系统调用、缺页异常处理和页面置换等功能奠定基础。

需要注意的是，在ucore的调度和执行管理中，**对线程和进程做了统一的处理**。且由于ucore内核中的所有内核线程共享一个内核地址空间和其他资源，所以这些内核线程从属于同一个唯一的内核进程，即ucore内核本身。

### 练习

对实验报告的要求：

- 基于markdown格式来完成，以文本方式为主
- 填写各个基本练习中要求完成的报告内容
- 列出你认为本实验中重要的知识点，以及与对应的OS原理中的知识点，并简要说明你对二者的含义，关系，差异等方面的理解（也可能出现实验中的知识点没有对应的原理知识点）
- 列出你认为OS原理中很重要，但在实验中没有对应上的知识点

#### 练习0：填写已有实验

本实验依赖实验2/3。请把你做的实验2/3的代码填入本实验中代码中有“LAB2”,“LAB3”的注释相应部分。

#### 练习1：分配并初始化一个进程控制块（需要编码）

alloc_proc函数（位于kern/process/proc.c中）负责分配并返回一个新的struct proc_struct结构，用于存储新建立的内核线程的管理信息。ucore需要对这个结构进行最基本的初始化，你需要完成这个初始化过程。

请在实验报告中简要说明你的设计实现过程。请回答如下问题：

- 请说明proc_struct中`struct context context`和`struct trapframe *tf`成员变量含义和在本实验中的作用是啥？（提示通过看代码和编程调试可以判断出来）

#### 练习2：为新创建的内核线程分配资源（需要编码）

创建一个内核线程需要分配和设置好很多资源。kernel_thread函数通过调用**do_fork**函数完成具体内核线程的创建工作。do_kernel函数会调用alloc_proc函数来分配并初始化一个进程控制块，但alloc_proc只是找到了一小块内存用以记录进程的必要信息，并没有实际分配这些资源。ucore一般通过do_fork实际创建新的内核线程。do_fork的作用是，创建当前内核线程的一个副本，它们的执行上下文、代码、数据都一样，但是存储位置不同。因此，我们**实际需要"fork"的东西就是stack和trapframe**。在这个过程中，需要给新内核线程分配资源，并且复制原进程的状态。你需要完成在kern/process/proc.c中的do_fork函数中的处理过程。它的大致执行步骤包括：

- 调用alloc_proc，首先获得一块用户信息块。
- 为进程分配一个内核栈。
- 复制原进程的内存管理信息到新进程（但内核线程不必做此事）
- 复制原进程上下文到新进程
- 将新进程添加到进程列表
- 唤醒新进程
- 返回新进程号

请在实验报告中简要说明你的设计实现过程。请回答如下问题：

- 请说明ucore是否做到给每个新fork的线程一个唯一的id？请说明你的分析和理由。

#### 练习3：编写proc_run 函数（需要编码）

proc_run用于将指定的进程切换到CPU上运行。它的大致执行步骤包括：

- 检查要切换的进程是否与当前正在运行的进程相同，如果相同则不需要切换。
- 禁用中断。你可以使用`/kern/sync/sync.h`中定义好的宏`local_intr_save(x)`和`local_intr_restore(x)`来实现关、开中断。
- 切换当前进程为要运行的进程。
- 切换页表，以便使用新进程的地址空间。`/libs/riscv.h`中提供了`lsatp(unsigned int pgdir)`函数，可实现修改SATP寄存器值的功能。
- 实现上下文切换。`/kern/process`中已经预先编写好了`switch.S`，其中定义了`switch_to()`函数。可实现两个进程的context切换。
- 允许中断。

请回答如下问题：

- 在本实验的执行过程中，创建且运行了几个内核线程？

完成代码编写后，编译并运行代码：make qemu

#### 扩展练习 Challenge：

1. 说明语句`local_intr_save(intr_flag);....local_intr_restore(intr_flag);`是如何实现开关中断的？

2. 深入理解不同分页模式的工作原理（思考题）

   get_pte()函数（位于`kern/mm/pmm.c`）用于在页表中查找或创建页表项，从而实现对指定线性地址对应的物理页的访问和映射操作。这在操作系统中的分页机制下，是实现虚拟内存与物理内存之间映射关系非常重要的内容。

   - get_pte()函数中有两段形式类似的代码， 结合sv32，sv39，sv48的异同，解释这两段代码为什么如此相像。
   - 目前get_pte()函数将页表项的查找和页表项的分配合并在一个函数里，你认为这种写法好吗？有没有必要把两个功能拆开？

### 项目组成

```
├── Makefile
├── kern
│   ├── debug
│   │   ├── assert.h
│   │   ├── kdebug.c
│   │   ├── kdebug.h
│   │   ├── kmonitor.c
│   │   ├── kmonitor.h
│   │   ├── panic.c
│   │   └── stab.h
│   ├── driver
│   │   ├── clock.c
│   │   ├── clock.h
│   │   ├── console.c
│   │   ├── console.h
│   │   ├── dtb.c
│   │   ├── dtb.h
│   │   ├── intr.c
│   │   ├── intr.h
│   │   ├── kbdreg.h
│   │   ├── picirq.c
│   │   └── picirq.h
│   ├── init
│   │   ├── entry.S
│   │   └── init.c
│   ├── libs
│   │   ├── readline.c
│   │   └── stdio.c
│   ├── mm
│   │   ├── default_pmm.c
│   │   ├── default_pmm.h
│   │   ├── kmalloc.c
│   │   ├── kmalloc.h
│   │   ├── memlayout.h
│   │   ├── mmu.h
│   │   ├── pmm.c
│   │   ├── pmm.h
│   │   ├── vmm.c
│   │   └── vmm.h
│   ├── process
│   │   ├── entry.S
│   │   ├── proc.c
│   │   ├── proc.h
│   │   └── switch.S
│   ├── schedule
│   │   ├── sched.c
│   │   └── sched.h
│   ├── sync
│   │   └── sync.h
│   └── trap
│       ├── trap.c
│       ├── trap.h
│       └── trapentry.S
├── libs
│   ├── atomic.h
│   ├── defs.h
│   ├── elf.h
│   ├── error.h
│   ├── hash.h
│   ├── list.h
│   ├── printfmt.c
│   ├── riscv.h
│   ├── sbi.h
│   ├── stdarg.h
│   ├── stdio.h
│   ├── stdlib.h
│   ├── string.c
│   └── string.h
└── tools
    ├── boot.ld
    ├── function.mk
    ├── gdbinit
    ├── grade.sh
    ├── kernel.ld
    ├── sign.c
    └── vector.c
```

相对与实验三，实验四中主要改动如下：

- kern/process/ （新增进程管理相关文件）
  - proc.[ch]：新增：实现进程、线程相关功能，包括：创建进程/线程，初始化进程/线程，处理进程/线程退出等功能
  - entry.S：新增：内核线程入口函数kernel_thread_entry的实现
  - switch.S：新增：上下文切换，利用堆栈保存、恢复进程上下文
- kern/init/
  - init.c：修改：完成虚拟内存管理初始化和进程系统初始化，并在内核初始化后切入idle进程
- kern/mm/ （基本上与本次实验没有太直接的联系，了解kmalloc和kfree如何使用即可）
  - kmalloc.[ch]：新增：定义和实现了新的kmalloc/kfree函数。具体实现是基于slab分配的简化算法 （只要求会调用这两个函数即可）
  - memlayout.h：增加slab物理内存分配相关的定义与宏 （可不用理会）。
  - pmm.[ch]：修改：加入完整的页表管理功能（get_pte/page_insert/page_remove等），实现虚拟内存映射与地址转换；在pmm.c中添加了调用kmalloc_init函数,取消了老的kmalloc/kfree的实现；在pmm.h中取消了老的kmalloc/kfree的定义
  - vmm.[ch]：新增：定义并实现虚拟内存区域（VMA）管理，包括 mm_struct（内存管理结构）和 vma_struct（虚拟内存区域结构），提供 VMA 的创建、查找、插入和销毁等功能
- kern/trap/
  - trapentry.S：增加了汇编写的函数forkrets，用于do_fork调用的返回处理。
- kern/schedule/
  - sched.[ch]：新增：实现FIFO策略的进程调度

## 实验执行流程概述

整个实验过程以 ucore 的总控函数 `init` 为起点。在初始化阶段，首先调用 `pmm_init` 函数完成物理内存管理初始化，建立空闲物理页管理机制，为后续页表建立和线程栈分配提供支持。接下来，执行中断和异常相关的初始化工作，此过程涉及调用 `pic_init` 和 `idt_init` 函数，用于初始化处理器中断控制器（PIC）和中断描述符表（IDT），与之前的 lab3 中断和异常初始化工作相同。随后，调用 `vmm_init` 函数进行虚拟内存管理机制的初始化。在此阶段，将建立内核的页表结构，并完成内核地址空间的虚拟地址到物理地址的静态映射。这里仅实现基础的页表映射机制，保证虚拟内存能够正常访问，并不会处理缺页异常，也**不涉及将页面换入或换出**。通过这些初始化工作，系统完成了内存的虚拟化，建立了基本的内存访问机制。

当内存的虚拟化完成后，整个控制流还是一条线串行执行，需要在此基础上进行 CPU 的虚拟化，即让 ucore 实现分时共享 CPU，使多条控制流能够并发执行。首先调用 `proc_init` 函数，完成进程管理的初始化，负责创建两个内核线程：第 0 个内核线程 `idleproc` 和第 1 个真正的内核线程 `initproc`。`idleproc` 是系统启动后的占位线程，主要任务是在没有其他可运行线程时进入空闲循环；而 `initproc` 则通过 `kernel_thread` 创建，是第一个实际执行任务的内核线程。在本实验中，它的任务是输出 “Hello World”，以验证内核线程的创建与调度机制是否正确。在完成上述初始化后，`idleproc` 会运行 `cpu_idle()`，当检测到需要调度时，系统通过`schedule()`选择可运行的线程并进行线程切换，从而让`initproc`获得 CPU 执行权并输出 “Hello World” 。

下面我们将首先分析如何使用多级页表进行虚拟内存管理，具体分析主要需要注意的关键问题和涉及的关键数据结构。

## 虚拟内存管理

### 基本原理概述

#### 虚拟内存

什么是虚拟内存？简单地说是指程序员或CPU“看到”的内存。但有几点需要注意：

1. 虚拟内存单元不一定有实际的物理内存单元对应，即实际的物理内存单元可能不存在；
2. 如果虚拟内存单元对应有实际的物理内存单元，那二者的地址一般是不相等的；
3. 通过操作系统实现的某种内存映射可建立虚拟内存与物理内存的对应关系，使得程序员或CPU访问的虚拟内存地址会自动转换为一个物理内存地址。

那么这个“**虚拟**”的作用或意义在哪里体现呢？在操作系统中，虚拟内存其实包含多个虚拟层次，在不同的层次体现了不同的作用。首先，在有了**分页机制**后，程序员或CPU“看到”的地址已经不是实际的物理地址了，这已经有一层虚拟化，我们可简称为**内存地址虚拟化**。有了**内存地址虚拟化**，我们就可以通过设置**页表项**来限定软件运行时的访问空间，确保软件运行不越界，完成**内存访问保护**的功能。

通过内存地址虚拟化，可以使得软件在没有访问某虚拟内存地址时不分配具体的物理内存，而只有在实际访问某虚拟内存地址时，操作系统再动态地分配物理内存，建立虚拟内存到物理内存的页映射关系，这种技术称为**按需分页**（demand paging）。把不经常访问的数据所占的内存空间临时写到硬盘上，这样可以腾出更多的空闲内存空间给经常访问的数据；当CPU访问到不经常访问的数据时，再把这些数据从硬盘读入到内存中，这种技术称为**页换入换出**（page　swap in/out）~~，但是这段我们目前的ucore中还没有实现~~。这种内存管理技术给了程序员更大的内存“空间”，从而可以让更多的程序在内存中并发运行。

### 页表项设计思路

我们定义一些对sv39页表项（Page Table Entry）进行操作的宏。这里的定义和我们在Lab2里介绍的定义一致。

有时候我们把多级页表中较高级别的页表（“页表的页表”）叫做`Page Directory`。在实验二中我们知道sv39中采用的是三级页表，那么在这里我们把页表项里从高到低三级页表的页码分别称作PDX1, PDX0和PTX(Page Table Index)。

```c
// kern/mm/mmu.h
#ifndef __KERN_MM_MMU_H__
#define __KERN_MM_MMU_H__

#ifndef __ASSEMBLER__
#include <defs.h>
#endif /* !__ASSEMBLER__ */

// A linear address 'la' has a four-part structure as follows:
//
// +--------9-------+-------9--------+-------9--------+---------12----------+
// | Page Directory | Page Directory |   Page Table   | Offset within Page  |
// |     Index 1    |    Index 2     |                |                     |
// +----------------+----------------+----------------+---------------------+
//  \-- PDX1(la) --/ \-- PDX0(la) --/ \--- PTX(la) --/ \---- PGOFF(la) ----/
//  \-------------------PPN(la)----------------------/
//
// The PDX1, PDX0, PTX, PGOFF, and PPN macros decompose linear addresses as shown.
// To construct a linear address la from PDX(la), PTX(la), and PGOFF(la),
// use PGADDR(PDX(la), PTX(la), PGOFF(la)).

// RISC-V uses 39-bit virtual address to access 56-bit physical address!
// Sv39 virtual address:
// +----9----+----9---+----9---+---12--+
// |  VPN[2] | VPN[1] | VPN[0] | PGOFF |
// +---------+----+---+--------+-------+
//
// Sv39 physical address:
// +----26---+----9---+----9---+---12--+
// |  PPN[2] | PPN[1] | PPN[0] | PGOFF |
// +---------+----+---+--------+-------+
//
// Sv39 page table entry:
// +----26---+----9---+----9---+---2----+-------8-------+
// |  PPN[2] | PPN[1] | PPN[0] |Reserved|D|A|G|U|X|W|R|V|
// +---------+----+---+--------+--------+---------------+

// page directory index
#define PDX1(la) ((((uintptr_t)(la)) >> PDX1SHIFT) & 0x1FF)
#define PDX0(la) ((((uintptr_t)(la)) >> PDX0SHIFT) & 0x1FF)

// page table index
#define PTX(la) ((((uintptr_t)(la)) >> PTXSHIFT) & 0x1FF)

// page number field of address
#define PPN(la) (((uintptr_t)(la)) >> PTXSHIFT)

// offset in page
#define PGOFF(la) (((uintptr_t)(la)) & 0xFFF)

// construct linear address from indexes and offset
#define PGADDR(d1, d0, t, o) ((uintptr_t)((d1) << PDX1SHIFT | (d0) << PDX0SHIFT | (t) << PTXSHIFT | (o)))

// address in page table or page directory entry
// 把页表项里存储的地址拿出来
#define PTE_ADDR(pte)   (((uintptr_t)(pte) & ~0x3FF) << (PTXSHIFT - PTE_PPN_SHIFT))
#define PDE_ADDR(pde)   PTE_ADDR(pde)

/* page directory and page table constants */
#define NPDEENTRY       512                    // page directory entries per page directory
#define NPTEENTRY       512                    // page table entries per page table

#define PGSIZE          4096                    // bytes mapped by a page
#define PGSHIFT         12                      // log2(PGSIZE)
#define PTSIZE          (PGSIZE * NPTEENTRY)    // bytes mapped by a page directory entry
#define PTSHIFT         21                      // log2(PTSIZE)

#define PTXSHIFT        12                      // offset of PTX in a linear address
#define PDX0SHIFT       21                      // offset of PDX0 in a linear address
#define PDX1SHIFT       30                      // offset of PDX0 in a linear address
#define PTE_PPN_SHIFT   10                      // offset of PPN in a physical address

// page table entry (PTE) fields
#define PTE_V     0x001 // Valid
#define PTE_R     0x002 // Read
#define PTE_W     0x004 // Write
#define PTE_X     0x008 // Execute
#define PTE_U     0x010 // User
```

上述代码定义了一些与内存管理单元（Memory Management Unit, MMU）相关的宏和常量，用于操作线性地址和物理地址，以及页表项的字段。

### 使用多级页表实现虚拟存储

要想实现虚拟存储，我们需要把页表放在内存里，并且需要有办法修改页表，比如在页表里增加一个页面的映射或者删除某个页面的映射。

要想实现页面映射，我们最主要需要修改的是两个接口：

- `page_insert()`，在页表里建立一个映射
- `page_remove()`，在页表里删除一个映射

这些内容都需要在`kern/mm/pmm.c`里面编写。然后我们可以在虚拟内存空间的第一个大大页(Giga Page)中建立一些映射来做测试。通过编写`page_ref()`函数用来检查映射关系是否实现，这个函数会返回一个物理页面被多少个虚拟页面所对应。

```c
static void check_pgdir(void) {
    // assert(npage <= KMEMSIZE / PGSIZE);
    // The memory starts at 2GB in RISC-V
    // so npage is always larger than KMEMSIZE / PGSIZE
    assert(npage <= KERNTOP / PGSIZE);
    //boot_pgdir是页表的虚拟地址
    assert(boot_pgdir != NULL && (uint32_t)PGOFF(boot_pgdir) == 0);
    assert(get_page(boot_pgdir, 0x0, NULL) == NULL);
    //get_page()尝试找到虚拟内存0x0对应的页，现在当然是没有的，返回NULL

    struct Page *p1, *p2;
    p1 = alloc_page();//拿过来一个物理页面
    assert(page_insert(boot_pgdir, p1, 0x0, 0) == 0);//把这个物理页面通过多级页表映射到0x0
    pte_t *ptep;
    assert((ptep = get_pte(boot_pgdir, 0x0, 0)) != NULL);
    assert(pte2page(*ptep) == p1);
    assert(page_ref(p1) == 1);

    ptep = (pte_t *)KADDR(PDE_ADDR(boot_pgdir[0]));
    ptep = (pte_t *)KADDR(PDE_ADDR(ptep[0])) + 1;
    assert(get_pte(boot_pgdir, PGSIZE, 0) == ptep);
    //get_pte查找某个虚拟地址对应的页表项，如果不存在这个页表项，会为它分配各级的页表

    p2 = alloc_page();
    assert(page_insert(boot_pgdir, p2, PGSIZE, PTE_U | PTE_W) == 0);
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
    assert(*ptep & PTE_U);
    assert(*ptep & PTE_W);
    assert(boot_pgdir[0] & PTE_U);
    assert(page_ref(p2) == 1);

    assert(page_insert(boot_pgdir, p1, PGSIZE, 0) == 0);
    assert(page_ref(p1) == 2);
    assert(page_ref(p2) == 0);
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
    assert(pte2page(*ptep) == p1);
    assert((*ptep & PTE_U) == 0);

    page_remove(boot_pgdir, 0x0);
    assert(page_ref(p1) == 1);
    assert(page_ref(p2) == 0);

    page_remove(boot_pgdir, PGSIZE);
    assert(page_ref(p1) == 0);
    assert(page_ref(p2) == 0);

    assert(page_ref(pde2page(boot_pgdir[0])) == 1);
    free_page(pde2page(boot_pgdir[0]));
    boot_pgdir[0] = 0;//清除测试的痕迹

    cprintf("check_pgdir() succeeded!\n");
}
```

在映射关系建立完成后，如何新增一个映射关系和删除一个映射关系也是非常重要的内容，我们来看`page_insert(),page_remove()`的实现。它们都涉及到调用两个对页表项进行操作的函数：`get_pte()`和`page_remove_pte()`

```c
int page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm) {
    //pgdir是页表基址(satp)，page对应物理页面，la是虚拟地址
    pte_t *ptep = get_pte(pgdir, la, 1);
    //先找到对应页表项的位置，如果原先不存在，get_pte()会分配页表项的内存
    if (ptep == NULL) {
        return -E_NO_MEM;
    }
    page_ref_inc(page);//指向这个物理页面的虚拟地址增加了一个
    if (*ptep & PTE_V) { //原先存在映射
        struct Page *p = pte2page(*ptep);
        if (p == page) {//如果这个映射原先就有
            page_ref_dec(page);
        } else {//如果原先这个虚拟地址映射到其他物理页面，那么需要删除映射
            page_remove_pte(pgdir, la, ptep);
        }
    }
    *ptep = pte_create(page2ppn(page), PTE_V | perm);//构造页表项
    tlb_invalidate(pgdir, la);//页表改变之后要刷新TLB
    return 0;
}
void page_remove(pde_t *pgdir, uintptr_t la) {
    pte_t *ptep = get_pte(pgdir, la, 0);//找到页表项所在位置
    if (ptep != NULL) {
        page_remove_pte(pgdir, la, ptep);//删除这个页表项的映射
    }
}
//删除一个页表项以及它的映射
static inline void page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep) {
    if (*ptep & PTE_V) {  //(1) check if this page table entry is valid
        struct Page *page = pte2page(*ptep);  //(2) find corresponding page to pte
        page_ref_dec(page);   //(3) decrease page reference
        if (page_ref(page) == 0) {  
            //(4) and free this page when page reference reachs 0
            free_page(page);
        }
        *ptep = 0;                  //(5) clear page table entry
        tlb_invalidate(pgdir, la);  //(6) flush tlb
    }
}
//寻找(有必要的时候分配)一个页表项
pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create) {
    /* LAB2 EXERCISE 2: YOUR CODE
     *
     * If you need to visit a physical address, please use KADDR()
     * please read pmm.h for useful macros
     *
     * Maybe you want help comment, BELOW comments can help you finish the code
     *
     * Some Useful MACROs and DEFINEs, you can use them in below implementation.
     * MACROs or Functions:
     *   PDX(la) = the index of page directory entry of VIRTUAL ADDRESS la.
     *   KADDR(pa) : takes a physical address and returns the corresponding
     * kernel virtual address.
     *   set_page_ref(page,1) : means the page be referenced by one time
     *   page2pa(page): get the physical address of memory which this (struct
     * Page *) page  manages
     *   struct Page * alloc_page() : allocation a page
     *   memset(void *s, char c, size_t n) : sets the first n bytes of the
     * memory area pointed by s
     *                                       to the specified value c.
     * DEFINEs:
     *   PTE_P           0x001                   // page table/directory entry
     * flags bit : Present
     *   PTE_W           0x002                   // page table/directory entry
     * flags bit : Writeable
     *   PTE_U           0x004                   // page table/directory entry
     * flags bit : User can access
     */
    pde_t *pdep1 = &pgdir[PDX1(la)];//找到对应的Giga Page
    if (!(*pdep1 & PTE_V)) {//如果下一级页表不存在，那就给它分配一页，创造新页表
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL) {
            return NULL;
        }
        set_page_ref(page, 1);
        uintptr_t pa = page2pa(page);
        memset(KADDR(pa), 0, PGSIZE);
        //我们现在在虚拟地址空间中，所以要转化为KADDR再memset.
        //不管页表怎么构造，我们确保物理地址和虚拟地址的偏移量始终相同，那么就可以用这种方式完成对物理内存的访问。
        *pdep1 = pte_create(page2ppn(page), PTE_U | PTE_V);//注意这里R,W,X全零
    }
    pde_t *pdep0 = &((pde_t *)KADDR(PDE_ADDR(*pdep1)))[PDX0(la)];//再下一级页表
    //这里的逻辑和前面完全一致，页表不存在就现在分配一个
    if (!(*pdep0 & PTE_V)) {
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL) {
                return NULL;
        }
        set_page_ref(page, 1);
        uintptr_t pa = page2pa(page);
        memset(KADDR(pa), 0, PGSIZE);
        *pdep0 = pte_create(page2ppn(page), PTE_U | PTE_V);
    }
    //找到输入的虚拟地址la对应的页表项的地址(可能是刚刚分配的)
    return &((pte_t *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)];
}
```

在`entry.S`里，我们虽然构造了一个简单映射使得内核能够运行在虚拟空间上，但是这个映射是比较粗糙的。

我们知道一个程序通常含有下面几段：

- `.text`段：存放代码，需要是可读、可执行的，但不可写。
- `.rodata` 段：存放只读数据，顾名思义，需要可读，但不可写亦不可执行。
- `.data` 段：存放经过初始化的数据，需要可读、可写。
- `.bss`段：存放经过零初始化的数据，需要可读、可写。与 `.data` 段的区别在于由于我们知道它被零初始化，因此在可执行文件中可以只存放该段的开头地址和大小而不用存全为 0的数据。在执行时由操作系统进行处理。

我们看到各个段需要的访问权限是不同的。但是现在使用一个大大页(Giga Page)进行映射时，它们都拥有相同的权限，那么在现在的映射下，我们甚至可以修改内核 `.text` 段的代码，因为我们通过一个标志位 `W=1` 的页表项就可以完成映射，但这显然会带来安全隐患。

因此，我们考虑对这些段分别进行重映射，使得他们的访问权限可以被正确设置。虽然还是每个段都还是映射以同样的偏移量映射到相同的地方，但实现过程需要更加精细。

这里还有一个小坑：对于我们最开始已经用特殊方式映射的一个大大页(Giga Page)，该怎么对那里面的地址重新进行映射？这个过程比较麻烦。但大家可以基本理解为放弃现有的页表，直接新建一个页表，在新页表里面完成重映射，然后把satp指向新的页表，这样就实现了重新映射。

## 内核线程管理

在真正进入本节的讨论前，我们先来谈一谈何为进程，为什么需要进程。

### 进程与线程

在操作系统中，我们经常谈到的两个概念就是进程与线程的概念。这两个概念虽然有许多相似的地方，但也有很多的不同。

我们平时编写的源代码，经过编译器编译就变成了可执行文件，我们管这一类文件叫做**程序**。而当一个程序被用户或操作系统启动，分配资源，装载进内存开始执行后，它就成为了一个**进程**。进程与程序之间最大的不同在于进程是一个“正在运行”的实体，而程序只是一个不动的文件。进程包含程序的内容，也就是它的静态的代码部分，也包括一些在运行时在可以体现出来的信息，比如堆栈，寄存器等数据，这些组成了进程“正在运行”的特性。

如果我们只关注于那些“正在运行”的部分，我们就从进程当中剥离出来了**线程**。一个进程可以对应一个线程，也可以对应很多线程。这些线程之间往往具有相同的代码，共享一块内存，但是却有不同的CPU执行状态。相比于线程，进程更多的作为一个资源管理的实体（因为操作系统分配网络等资源时往往是基于进程的），这样线程就作为可以被调度的最小单元，给了调度器更多的调度可能。

### 我们为什么需要进程

进程的一个重要特点在于其可以调度。在我们操作系统启动的时候，操作系统相当是一个初始的进程。之后，操作系统会创建不同的进程负责不同的任务。用户可以通过命令行启动进程，从而使用计算机。想想如果没有进程会怎么样？所有的代码可能需要在操作系统编译的时候就打包在一块，安装软件将变成一件非常难的事情，这显然对于用户使用计算机是不利的。

另一方面，从2000年开始，CPU越来越多的使用多核心的设计。这主要是因为芯片设计师们发现在一个核心上提高主频变得越来越难（这其中有许多原因，相信组成原理课上已经有过介绍），所以采用多个核心，将利用多核性能的任务交给了程序员。在这种环境下，操作系统也需要进行相应的调整，以适应这种多核的趋势。使用进程的概念有助于各个进程同时的利用CPU的各个核心，这是单进程系统往往做不到的。

但是，多进程的引入其实远早于多核心处理器。在计算机的远古时代，存在许多“巨无霸”计算机。但是，如果只让这些计算机服务于一个用户，有时候又有点浪费。有没有可能让一个计算机服务于多个用户呢（哪怕只有一个核心）？分时操作系统解决了这个问题，就是通过时间片轮转的方法使得多个用户可以“同时”使用计算资源。这个时候，引入进程的概念，成为操作系统调度的单元就显得十分必要了。

### 如何进行进程管理

综合以上可以看出，操作系统的确离不开进程管理。从某种程度上，我们可以把操作系统的控制流看作是一个内核线程。这次将首先接触的是内核线程的管理。内核线程是一种特殊的进程，内核线程与用户进程的区别有两个：内核线程只运行在内核态而用户进程会在在用户态和内核态交替运行；所有内核线程直接使用共同的ucore内核内存空间，不需为每个内核线程维护单独的内存空间而用户进程需要维护各自的用户内存空间。从内存空间占用情况这个角度上看，我们可以把线程看作是一种共享内存空间的轻量级进程。

为了管理这些线程，必须设计用于描述线程的数据结构，即进程控制块（在这里也可叫做线程控制块）。如果要让内核线程运行，我们首先要创建内核线程对应的进程控制块，还需把这些进程控制块通过链表连在一起，便于随时进行插入，删除和查找操作等进程管理事务。这个链表就是进程控制块链表。然后在通过调度器（scheduler）来让不同的内核线程在不同的时间段占用CPU执行，调度器会按照一定策略选择哪个线程获得CPU执行权，实现对CPU的分时共享。那lab4中是如何一步一步实现这个过程的呢？

接下来将主要介绍进程创建所需的重要数据结构--进程控制块proc_struct，以及ucore创建并执行内核线程idleproc和initproc的两种不同方式，特别是创建initproc的方式将被延续到后面的实验中，扩展为创建用户进程的主要方式。另外，还初步涉及了进程调度（后续实验涉及并会扩展）和进程切换内容。

### 设计关键数据结构

#### 进程控制块

在实验四中，进程管理信息用struct proc_struct表示，在*kern/process/proc.h*中定义如下：

```c
struct proc_struct {
    enum proc_state state;                  // Process state
    int pid;                                // Process ID
    int runs;                               // the running times of Proces
    uintptr_t kstack;                       // Process kernel stack
    volatile bool need_resched;             // bool value: need to be rescheduled to release CPU?
    struct proc_struct *parent;             // the parent process
    struct mm_struct *mm;                   // Process's memory management field
    struct context context;                 // Switch here to run process
    struct trapframe *tf;                   // Trap frame for current interrupt
    uintptr_t pgdir;                        // the base addr of Page Directroy Table(PDT)
    uint32_t flags;                         // Process flag
    char name[PROC_NAME_LEN + 1];           // Process name
    list_entry_t list_link;                 // Process link list 
    list_entry_t hash_link;                 // Process hash list
};
```

下面重点解释一下几个比较重要的成员变量：

- `mm`：这里面保存了内存管理的信息，包括内存映射，虚存管理等内容。具体内在实现可以参考之前的章节。
- `state`：进程所处的状态。uCore中进程状态有四种：分别是`PROC_UNINIT`、`PROC_SLEEPING`、`PROC_RUNNABLE`、`PROC_ZOMBIE`。
- `parent`：里面保存了进程的父进程的指针。在内核中，只有内核创建的idle进程没有父进程，其他进程都有父进程。进程的父子关系组成了一棵进程树，这种父子关系有利于维护父进程对于子进程的一些特殊操作。
- `context`：`context`中保存了进程执行的上下文，也就是几个关键的寄存器的值。这些寄存器的值用于在进程切换中还原之前进程的运行状态（进程切换的详细过程在后面会介绍）。切换过程的实现在`kern/process/switch.S`。
- `tf`：`tf`里保存了进程的中断帧。当进程从用户空间跳进内核空间的时候，进程的执行状态被保存在了中断帧中（注意这里需要保存的执行状态数量不同于上下文切换）。系统调用可能会改变用户寄存器的值，我们可以通过调整中断帧来使得系统调用返回特定的值。
- `pgdir`：即页目录（Page Directory）的基址。在 RISC-V 架构中，CPU 通过 `satp` 寄存器找到当前页表的根节点，从而进行地址翻译。`pgdir` 字段保存的就是每个进程的页表根节点的物理地址。当进行进程切换时，内核需要将下一个要运行进程的 `pgdir` 值加载到 `satp` 寄存器中，这样才能正确地切换到新的地址空间。
- `kstack`: 每个线程都有一个内核栈，并且位于内核地址空间的不同位置。对于内核线程，该栈就是运行时的程序使用的栈；而对于普通进程，该栈是发生特权级改变的时候使保存被打断的硬件信息用的栈。uCore在创建进程时分配了 2 个连续的物理页（参见memlayout.h中KSTACKSIZE的定义）作为内核栈的空间。这个栈很小，所以内核中的代码应该尽可能的紧凑，并且避免在栈上分配大的数据结构，以免栈溢出，导致系统崩溃。kstack记录了分配给该进程/线程的内核栈的位置。主要作用有以下几点。首先，当内核准备从一个进程切换到另一个的时候，需要根据kstack 的值正确的设置好 tss （可以回顾一下在实验一中讲述的 tss 在中断处理过程中的作用），以便在进程切换以后再发生中断时能够使用正确的栈。其次，内核栈位于内核地址空间，并且是不共享的（每个线程都拥有自己的内核栈），因此不受到 mm 的管理，当进程退出的时候，内核能够根据 kstack 的值快速定位栈的位置并进行回收。uCore 的这种内核栈的设计借鉴的是 linux 的方法（但由于内存管理实现的差异，它实现的远不如 linux 的灵活），它使得每个线程的内核栈在不同的位置，这样从某种程度上方便调试，但同时也使得内核对栈溢出变得十分不敏感，因为一旦发生溢出，它极可能污染内核中其它的数据使得内核崩溃。如果能够通过页表，将所有进程的内核栈映射到固定的地址上去，能够避免这种问题，但又会使得进程切换过程中对栈的修改变得相当繁琐。感兴趣的同学可以参考 linux kernel 的代码对此进行尝试。

为了管理系统中所有的进程控制块，uCore维护了如下全局变量（位于*kern/process/proc.c*）：

● static struct proc *current：当前占用CPU且处于“运行”状态进程控制块指针。通常这个变量是只读的，只有在进程切换的时候才进行修改，并且整个切换和修改过程需要保证操作的原子性，目前至少需要屏蔽中断。可以参考 switch_to 的实现。

● static struct proc *initproc：本实验中，指向一个内核线程。本实验以后，此指针将指向第一个用户态进程。

● static list_entry_t hash_list[HASH_LIST_SIZE]：所有进程控制块的哈希表，proc_struct中的成员变量hash_link将基于pid链接入这个哈希表中。

● list_entry_t proc_list：所有进程控制块的双向线性列表，proc_struct中的成员变量list_link将链接入这个链表中。

#### 进程上下文

在操作系统中，**进程上下文**指的是进程在某一时刻的运行现场。为了让进程在被打断后能够原样继续，我们需要把当下的 CPU 状态保存下来。直观地理解，可以先把它看作把所有寄存器的值都保存到内存里，稍后再原样恢复回寄存器。等该进程再次被调度时，再把这些值恢复回去，这个过程就叫做**上下文的保存与恢复**。实际实现中，为了避免不必要的开销，我们并不真的保存所有寄存器，而只保存足以恢复执行现场的那一部分。

进程上下文使用结构体`struct context`保存，其中包含了`ra`，`sp`，`s0~s11`共14个寄存器。

可能感兴趣的同学就会问了，为什么我们不需要保存所有的寄存器呢？这里我们巧妙地利用了编译器对于函数的处理。我们知道寄存器可以分为调用者保存（caller-saved）寄存器和被调用者保存（callee-saved）寄存器。因为线程切换在一个函数当中（我们下一小节就会看到），所以编译器会自动帮助我们生成保存和恢复调用者保存寄存器的代码，在实际的进程切换过程中我们只需要保存被调用者保存寄存器就好啦！

下一小节，我们来看一看到底如何进行进程的切换。

### 创建并执行内核线程

建立进程控制块（proc.c中的alloc_proc函数）后，现在就可以通过进程控制块来创建具体的进程/线程了。首先，考虑最简单的内核线程，它通常只是内核中的一小段代码或者函数，没有自己的“专属”空间。这是由于在uCore OS启动后，已经对整个内核内存空间进行了管理，通过设置页表建立了内核虚拟空间（即boot_pgdir指向的二级页表描述的空间）。所以uCore OS内核中的所有线程都不需要再建立各自的页表，只需共享这个内核虚拟空间就可以访问整个物理内存了。从这个角度看，内核线程被uCore OS内核这个大“内核进程”所管理。

#### 创建第 0 个内核线程 idleproc

`idleproc`是一个在操作系统中常见的概念，用于表示空闲进程。在操作系统中，空闲进程是一个特殊的进程，它的主要目的是在系统没有其他任务需要执行时，占用 CPU 时间，同时便于进程调度的统一化。

在init.c::kern_init函数调用了proc.c::proc_init函数。proc_init函数启动了创建内核线程的步骤。首先当前的执行上下文（从kern_init 启动至今）就可以看成是uCore内核（也可看做是内核进程）中的一个内核线程的上下文。为此，uCore通过给当前执行的上下文分配一个进程控制块以及对它进行相应初始化，将其打造成第0个内核线程 -- idleproc。具体步骤如下：

首先需要初始化进程链表。进程链表就是把所有进程控制块串联起来的数据结构，可以记录和追踪每一个进程。

随后，调用alloc_proc函数来通过kmalloc函数获得proc_struct结构的一块内存块-，作为第0个进程控制块。并把proc进行初步初始化（即把proc_struct中的各个成员变量清零）。但有些成员变量设置了特殊的值，比如：

```c
 proc->state = PROC_UNINIT;  设置进程为“初始”态
 proc->pid = -1;             设置进程pid的未初始化值
 proc->pgdir = boot_pgdir;       使用内核页目录表的基址
 ...
```

上述三条语句中,第一条设置了进程的状态为“初始”态，这表示进程已经 “出生”了，正在获取资源茁壮成长中；第二条语句设置了进程的pid为-1，这表示进程的“身份证号”还没有办好；第三条语句表明由于该内核线程在内核中运行，故采用为uCore内核已经建立的页表，即设置为在uCore内核页表的起始地址boot_pgdir。后续实验中可进一步看出所有内核线程的内核虚地址空间（也包括物理地址空间）是相同的。既然内核线程共用一个映射内核空间的页表，这表示内核空间对所有内核线程都是“可见”的，所以更精确地说，这些内核线程都应该是从属于同一个唯一的“大内核进程”—uCore内核。

接下来，proc_init函数对idleproc内核线程进行进一步初始化：

```c
idleproc->pid = 0;
idleproc->state = PROC_RUNNABLE;
idleproc->kstack = (uintptr_t)bootstack;
idleproc->need_resched = 1;
set_proc_name(idleproc, "idle");
```

需要注意前4条语句。第一条语句给了idleproc合法的身份证号--0，这名正言顺地表明了idleproc是第0个内核线程。通常可以通过pid的赋值来表示线程的创建和身份确定。“0”是第一个的表示方法是计算机领域所特有的，比如C语言定义的第一个数组元素的小标也是“0”。第二条语句改变了idleproc的状态，使得它从“出生”转到了“准备工作”，就差uCore调度它执行了。第三条语句设置了idleproc所使用的内核栈的起始地址。需要注意以后的其他线程的内核栈都需要通过分配获得，因为uCore启动时设置的内核栈直接分配给idleproc使用了。第四条很重要，因为uCore希望当前CPU应该做更有用的工作，而不是运行idleproc这个“无所事事”的内核线程，所以把idleproc->need_resched设置为“1”，结合idleproc的执行主体--cpu_idle函数的实现，可以清楚看出如果当前idleproc在执行，则只要此标志为1，马上就调用schedule函数要求调度器切换其他进程执行。

接下来，在下一小节中我们将对第一个真正的内核进程进行初始化（因为`idle`进程仅仅算是“继承了”ucore的运行）。我们的目标是使用新的内核进程进行一下内核初始化的工作。

#### 创建第 1 个内核线程 initproc

第0个内核线程主要工作是完成内核中各个子系统的初始化，然后就通过执行cpu_idle函数开始过退休生活了。所以uCore接下来还需创建其他进程来完成各种工作，但idleproc内核子线程自己不想做，于是就通过调用kernel_thread函数创建了一个内核线程init_main。在实验四中，这个子内核线程的工作就是输出一些字符串，然后就返回了（参看init_main函数）。但在后续的实验中，init_main的工作就是创建特定的其他内核线程或用户进程（实验五涉及）。

在操作系统中，进程的创建通常是通过“复制”现有进程的状态来完成的。我们称这种创建进程的方式为“复制进程”。每个新进程都会通过复制当前进程（也称为父进程）的资源（如进程控制块、内核栈等）来实现自身的初始化。所有进程的上下文（包括寄存器状态）都通过中断帧来保存。当新进程创建时，我们需要复制当前进程的中断帧，以确保新进程能够继承父进程的状态。这个过程非常重要，因为它保证了每个进程都可以独立运行并且正确地处理中断和上下文切换。

然而，在操作系统启动初期，系统并没有父进程可以用来复制。因此，为了能够“创造”第一个进程，我们需要手动构造一个空的进程中断帧，并将其作为“模板”来进行复制。这样做可以确保我们有一个有效的中断帧，供后续进程使用。

在uCore操作系统中，第一个内核线程的创建是通过 kernel_thread 函数来实现的。这个函数负责为新的内核线程创建一个初始化好的中断帧，并通过调用 do_fork 函数将其转化为一个新的进程。

下面我们来分析一下创建内核线程的函数kernel_thread：

```c
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags) {
    // 对trameframe，也就是我们程序的一些上下文进行一些初始化
    struct trapframe tf;
    memset(&tf, 0, sizeof(struct trapframe));

    // 设置内核线程的参数和函数指针
    tf.gpr.s0 = (uintptr_t)fn; // s0 寄存器保存函数指针
    tf.gpr.s1 = (uintptr_t)arg; // s1 寄存器保存函数参数

    // 设置 trapframe 中的 status 寄存器（SSTATUS）
    // SSTATUS_SPP：Supervisor Previous Privilege（设置为 supervisor 模式，因为这是一个内核线程）
    // SSTATUS_SPIE：Supervisor Previous Interrupt Enable（设置为启用中断，因为这是一个内核线程）
    // SSTATUS_SIE：Supervisor Interrupt Enable（设置为禁用中断，因为我们不希望该线程被中断）
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE;

    // 将入口点（epc）设置为 kernel_thread_entry 函数，作用实际上是将pc指针指向它(*trapentry.S会用到)
    tf.epc = (uintptr_t)kernel_thread_entry;

    // 使用 do_fork 创建一个新进程（内核线程），这样才真正用设置的tf创建新进程。
    return do_fork(clone_flags | CLONE_VM, 0, &tf);
}
```

在内核线程创建的过程中，kernel_thread 函数通过一个局部变量 tf 来放置保存内核线程的临时中断帧。这个中断帧保存了该进程的寄存器状态、栈指针、程序计数器（PC）等关键信息。由于第一个进程（initproc）是由操作系统手动创建的，并没有父进程可以供其复制，因此在创建这个进程时，我们需要使用一个“空的”中断帧模板来初始化。这样做的目的是为了后续的进程创建能够复用这个模板，从而实现代码的通用性和复用性。

随后，kernel_thread函数将中断帧的指针传递给do_fork函数，而do_fork函数会调用copy_thread函数来在新创建的进程内核栈上专门给进程的中断帧分配一块空间。

给中断帧分配完空间后，就需要构造新进程的中断帧，具体过程是：首先给tf进行清零初始化，随后设置设置内核线程的参数和函数指针。要特别注意对tf.status的赋值过程，其读取sstatus寄存器的值，然后根据特定的位操作，设置SPP和SPIE位，并同时清除SIE位，从而实现特权级别切换、保留中断使能状态并禁用中断的操作。

do_fork是创建线程的主要函数。kernel_thread函数通过调用do_fork函数最终完成了内核线程的创建工作。下面我们来分析一下do_fork函数的实现（练习2）。do_fork函数主要做了以下7件事情：

1. 分配并初始化进程控制块（`alloc_proc`函数）
2. 分配并初始化内核栈（`setup_stack`函数）
3. 根据`clone_flags`决定是复制还是共享内存管理系统（`copy_mm`函数）
4. 设置进程的中断帧和上下文（`copy_thread`函数）
5. 把设置好的进程加入链表
6. 将新建的进程设为就绪态
7. 将返回值设为线程id

这里需要注意的是，如果上述前3步执行没有成功，则需要做对应的出错处理，把相关已经占有的内存释放掉。copy_mm函数目前只是把current->mm设置为NULL，这是由于目前在实验四中只能创建内核线程，proc->mm描述的是进程用户态空间的情况，所以目前mm还用不上。

在这里我们需要尤其关注`copy_thread`函数（用于将当前进程的中断帧复制到新进程的内核栈中）：

```c
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf) {
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE - sizeof(struct trapframe));
    *(proc->tf) = *tf;

    // Set a0 to 0 so a child process knows it's just forked
    proc->tf->gpr.a0 = 0;
    proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;

    proc->context.ra = (uintptr_t)forkret;
    proc->context.sp = (uintptr_t)(proc->tf);
}
```

在这里我们首先在上面分配的内核栈上分配出一片空间来保存`trapframe`。然后，我们将`trapframe`中的`a0`寄存器（返回值）设置为0，说明这个进程是一个子进程。之后我们将上下文中的`ra`设置为了`forkret`函数的入口，并且把`trapframe`放在上下文的栈顶。在下一个小节，我们会看到这么做之后ucore是如何完成进程切换的。

#### 调度并执行内核线程 initproc

在 uCore 执行完 `proc_init` 函数后，就创建好了两个内核线程：`idleproc` 和 `initproc`。此时，uCore 当前的执行现场就是 `idleproc`。当执行到 `init` 函数的最后一个函数 `cpu_idle` 之前，uCore 的所有初始化工作就已经完成了。`idleproc` 将通过执行 `cpu_idle` 函数主动让出 CPU，让其他内核线程得以执行，具体过程如下：

```c
void
cpu_idle(void) {
    while (1) {
        if (current->need_resched) {
            schedule();
            ...
```

首先，判断当前内核线程 `idleproc` 的 `need_resched` 是否不为 0。回顾前面“创建第一个内核线程 `idleproc`”的描述，`proc_init` 函数在初始化 `idleproc` 时就把 `idleproc->need_resched` 置为 1，因此会马上调用 `schedule()` 函数去寻找其他处于“就绪态”（即 `PROC_RUNNABLE`）的进程执行。

> **须知：uCore 中的进程状态**
>
> 在 uCore 操作系统中，进程在其生命周期中会经历四种基本状态：
>
> - **PROC_UNINIT（未初始化）**：进程控制块刚被创建，尚未完成初始化
> - **PROC_RUNNABLE（就绪/运行）**：进程已准备好运行，可能正在等待 CPU 或正在 CPU 上执行
> - **PROC_SLEEPING（睡眠/阻塞）**：进程因等待某个事件或资源而暂时无法执行
> - **PROC_ZOMBIE（僵尸）**：进程已执行完毕，等待父进程回收其资源
>
> 在 `schedule` 函数中，只有处于 `PROC_RUNNABLE` 状态的进程才会被选中执行。进程状态的切换将在后续章节详细介绍。

进程调度是多线程系统并发执行的基础。调度器通过一定的调度算法，在特定的调度点上触发调度，最终完成进程切换。其核心思想是：在调度点到达时，从可运行线程（`PROC_RUNNABLE`）中选择一个线程，并通过 `switch_to` 完成上下文切换。

在实验四中，调度点唯一位于 `cpu_idle` 函数中。当 `idleproc` 发现 `need_resched == 1` 时，会调用 `schedule()` 来触发调度。

uCore 在这里实现的时一个最简单的 FIFO 调度器。`schedule()` 的执行逻辑可以概括为以下几步：

1. 将当前内核线程 `current->need_resched` 置为 0。
2. 在 `proc_list` 链表中查找下一个处于 `PROC_RUNNABLE` 状态的线程或进程 `next`。
3. 找到合适的进程后，调用 `proc_run()` 函数，保存当前进程`current`的执行现场（进程上下文），恢复新进程的执行现场，完成进程切换。

![img](http://oslab.mobisys.cc/lab2025/_book/lab4/find.png)

其中，在 `proc_list` 中查找下一个就绪进程时，会有三种情况：

1. **当前进程不是 `idleproc`**：从当前进程的下一个位置开始查找，实现 Round-Robin 轮转调度。
2. **当前进程是 `idleproc`**：从链表头开始查找，给所有进程平等机会。
3. **找不到就绪进程**：遍历整个链表都没找到，则最后使用 `idleproc` 保底。

至此，找到下一个就绪进程后，新的进程 `next` 就开始执行了。由于 `proc_list` 中当前只有两个内核线程，而 `idleproc` 需要让出 CPU 给 `initproc`。我们可以看到 `schedule()` 通过查找`proc_list` 进程队列，只会找到一个处于“就绪”态的 `initproc` 内核进程，并调用 `proc_run()`，最终通过 `switch_to` 完成两个执行现场的切换。具体流程如下：

1. 将当前运行的进程设置为要切换过去的进程。
2. 将页表切换到新进程的页表。
3. 使用 `switch_to` 切换到新进程的上下文。

`switch_to` 函数（位于 `switch.S`）会保存前一个进程的寄存器上下文，恢复新进程的上下文，从而完成真正的 CPU 上的切换。函数参数是前一个进程和后一个进程的执行现场：process context。在上一节“设计进程控制块”中，描述了`context`结构包含的要保存和恢复的寄存器。我们再看看`switch_to`函数的执行流程：

```assembly
.text
# void switch_to(struct proc_struct* from, struct proc_struct* to)
.globl switch_to
switch_to:
    # save from's registers
    STORE ra, 0*REGBYTES(a0)
    STORE sp, 1*REGBYTES(a0)
    STORE s0, 2*REGBYTES(a0)
    STORE s1, 3*REGBYTES(a0)
    STORE s2, 4*REGBYTES(a0)
    STORE s3, 5*REGBYTES(a0)
    STORE s4, 6*REGBYTES(a0)
    STORE s5, 7*REGBYTES(a0)
    STORE s6, 8*REGBYTES(a0)
    STORE s7, 9*REGBYTES(a0)
    STORE s8, 10*REGBYTES(a0)
    STORE s9, 11*REGBYTES(a0)
    STORE s10, 12*REGBYTES(a0)
    STORE s11, 13*REGBYTES(a0)

    # restore to's registers
    LOAD ra, 0*REGBYTES(a1)
    LOAD sp, 1*REGBYTES(a1)
    LOAD s0, 2*REGBYTES(a1)
    LOAD s1, 3*REGBYTES(a1)
    LOAD s2, 4*REGBYTES(a1)
    LOAD s3, 5*REGBYTES(a1)
    LOAD s4, 6*REGBYTES(a1)
    LOAD s5, 7*REGBYTES(a1)
    LOAD s6, 8*REGBYTES(a1)
    LOAD s7, 9*REGBYTES(a1)
    LOAD s8, 10*REGBYTES(a1)
    LOAD s9, 11*REGBYTES(a1)
    LOAD s10, 12*REGBYTES(a1)
    LOAD s11, 13*REGBYTES(a1)

    ret
```

可以看出来这段代码就是将需要保存的寄存器进行保存和调换。其中的a0和a1是RISC-V 架构中通用寄存器，它们用于传递参数，也就是说a0指向原进程，a1指向目的进程。

在之前我们也已经谈到过了，这里只需要调换被调用者保存寄存器即可。由于我们在初始化时把上下文的`ra`寄存器设定成了`forkret`函数的入口，所以这里会返回到`forkret`函数。`forkrets`函数很短，位于kern/trap/trapentry.S：

```assembly
    .globl forkrets
forkrets:
    # set stack to this new process's trapframe
    move sp, a0
    j __trapret
```

这里把传进来的参数，也就是进程的中断帧放在了`sp`，这样在`__trapret`中就可以直接从中断帧里面恢复所有的寄存器啦！我们在初始化的时候对于中断帧做了一点手脚，`epc`寄存器指向的是`kernel_thread_entry`，`s0`寄存器里放的是新进程要执行的函数，`s1`寄存器里放的是传给函数的参数。在`kernel_thread_entry`函数中：

```assembly
.text
.globl kernel_thread_entry
kernel_thread_entry:        # void kernel_thread(void)
    move a0, s1
    jalr s0

    jal do_exit
```

我们把参数放在了`a0`寄存器，并跳转到`s0`执行我们指定的函数！这样，一个进程的初始化就完成了。至此，我们实现了基本的进程管理，并且成功创建并切换到了我们的第一个内核进程。

## 实验报告要求

从oslab网站上取得实验代码后，进入目录labcodes/lab4，完成实验要求的各个练习。在实验报告中回答所有练习中提出的问题。在目录labcodes/lab4下存放实验报告，推荐用**markdown**格式。每个小组建一个gitee或者github仓库，对于lab4中编程任务，完成编写之后，再通过git push命令把代码和报告上传到仓库。最后请一定提前或按时提交到git网站。

注意有“LAB4”的注释，代码中所有需要完成的地方（challenge除外）都有“LAB4”和“YOUR CODE”的注释，请在提交时特别注意保持注释，并将“YOUR CODE”替换为自己的学号，并且将所有标有对应注释的部分填上正确的代码。

