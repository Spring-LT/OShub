## lab5:用户程序

实验4完成了内核线程，但到目前为止，所有的运行都在内核态执行。实验5将创建用户进程，让用户进程在用户态执行，且在需要ucore支持时，可通过系统调用来让ucore提供服务。

## 实验目的

- 了解第一个用户进程创建过程
- 了解系统调用框架的实现机制
- 了解ucore如何实现系统调用sys_fork/sys_exec/sys_exit/sys_wait来进行进程管理

## 实验内容

实验4完成了内核线程，但到目前为止，所有的运行都在内核态执行。实验5将创建用户进程，让用户进程在用户态执行，且在需要ucore支持时，可通过系统调用来让ucore提供服务。为此需要构造出第一个用户进程，并通过系统调用`sys_fork`/`sys_exec`/`sys_exit`/`sys_wait`来支持运行不同的应用程序，完成对用户进程的执行过程的基本管理。

### 练习

对实验报告的要求：

- 基于markdown格式来完成，以文本方式为主
- 填写各个基本练习中要求完成的报告内容
- 列出你认为本实验中重要的知识点，以及与对应的OS原理中的知识点，并简要说明你对二者的含义，关系，差异等方面的理解（也可能出现实验中的知识点没有对应的原理知识点）
- 列出你认为OS原理中很重要，但在实验中没有对应上的知识点

#### 练习0：填写已有实验

本实验依赖实验2/3/4。请把你做的实验2/3/4的代码填入本实验中代码中有“LAB2”/“LAB3”/“LAB4”的注释相应部分。注意：为了能够正确执行lab5的测试应用程序，可能需对已完成的实验2/3/4的代码进行进一步改进。

#### 练习1: 加载应用程序并执行（需要编码）

**do_execv**函数调用`load_icode`（位于kern/process/proc.c中）来加载并解析一个处于内存中的ELF执行文件格式的应用程序。你需要补充`load_icode`的第6步，建立相应的用户内存空间来放置应用程序的代码段、数据段等，且要设置好`proc_struct`结构中的成员变量trapframe中的内容，确保在执行此进程后，能够从应用程序设定的起始执行地址开始执行。需设置正确的trapframe内容。

请在实验报告中简要说明你的设计实现过程。

- 请简要描述这个用户态进程被ucore选择占用CPU执行（RUNNING态）到具体执行应用程序第一条指令的整个经过。

#### 练习2: 父进程复制自己的内存空间给子进程（需要编码）

创建子进程的函数`do_fork`在执行中将拷贝当前进程（即父进程）的用户内存地址空间中的合法内容到新进程中（子进程），完成内存资源的复制。具体是通过`copy_range`函数（位于kern/mm/pmm.c中）实现的，请补充`copy_range`的实现，确保能够正确执行。

请在实验报告中简要说明你的设计实现过程。

- 如何设计实现`Copy on Write`机制？给出概要设计，鼓励给出详细设计。

> Copy-on-write（简称COW）的基本概念是指如果有多个使用者对一个资源A（比如内存块）进行读操作，则每个使用者只需获得一个指向同一个资源A的指针，就可以该资源了。若某使用者需要对这个资源A进行写操作，系统会对该资源进行拷贝操作，从而使得该“写操作”使用者获得一个该资源A的“私有”拷贝—资源B，可对资源B进行写操作。该“写操作”使用者对资源B的改变对于其他的使用者而言是不可见的，因为其他使用者看到的还是资源A。

#### 练习3: 阅读分析源代码，理解进程执行 fork/exec/wait/exit 的实现，以及系统调用的实现（不需要编码）

请在实验报告中简要说明你对 fork/exec/wait/exit函数的分析。并回答如下问题：

- 请分析fork/exec/wait/exit的执行流程。重点关注哪些操作是在用户态完成，哪些是在内核态完成？内核态与用户态程序是如何交错执行的？内核态执行结果是如何返回给用户程序的？
- 请给出ucore中一个用户态进程的执行状态生命周期图（包执行状态，执行状态之间的变换关系，以及产生变换的事件或函数调用）。（字符方式画即可）

执行：make grade。如果所显示的应用程序检测都输出ok，则基本正确。（使用的是qemu-1.0.1）

#### 扩展练习 Challenge

1. 实现 Copy on Write （COW）机制

   给出实现源码,测试用例和设计报告（包括在cow情况下的各种状态转换（类似有限状态自动机）的说明）。

   这个扩展练习涉及到本实验和上一个实验“虚拟内存管理”。在ucore操作系统中，当一个用户父进程创建自己的子进程时，父进程会把其申请的用户空间设置为只读，子进程可共享父进程占用的用户内存空间中的页面（这就是一个共享的资源）。当其中任何一个进程修改此用户内存空间中的某页面时，ucore会通过page fault异常获知该操作，并完成拷贝内存页面，使得两个进程都有各自的内存页面。这样一个进程所做的修改不会被另外一个进程可见了。请在ucore中实现这样的COW机制。

   由于COW实现比较复杂，容易引入bug，请参考 https://dirtycow.ninja/ 看看能否在ucore的COW实现中模拟这个错误和解决方案。需要有解释。

   这是一个big challenge.

2. 说明该用户程序是何时被预先加载到内存中的？与我们常用操作系统的加载有何区别，原因是什么？

### 项目组成

```
├── boot  
├── kern   
│ ├── debug  
│ │ ├── kdebug.c   
│ │ └── ……  
│ ├── mm  
│ │ ├── memlayout.h   
│ │ ├── pmm.c  
│ │ ├── pmm.h  
│ │ ├── ......  
│ │ ├── vmm.c  
│ │ └── vmm.h  
│ ├── process  
│ │ ├── proc.c  
│ │ ├── proc.h  
│ │ └── ......  
│ ├── schedule  
│ │ ├── sched.c  
│ │ └── ......  
│ ├── sync  
│ │ └── sync.h   
│ ├── syscall  
│ │ ├── syscall.c  
│ │ └── syscall.h  
│ └── trap  
│ ├── trap.c  
│ ├── trapentry.S  
│ ├── trap.h  
│ └── vectors.S  
├── libs  
│ ├── elf.h  
│ ├── error.h  
│ ├── printfmt.c  
│ ├── unistd.h  
│ └── ......  
├── tools  
│ ├── user.ld  
│ └── ......  
└── user  
├── hello.c  
├── libs  
│ ├── initcode.S  
│ ├── syscall.c  
│ ├── syscall.h  
│ └── ......  
└── ......
```

相对与实验四，主要增加和修改的文件如上图所示。主要改动如下：

◆ kern/debug/

kdebug.c：修改：解析用户进程的符号信息表示（可不用理会）

◆ kern/mm/ （与本次实验有较大关系）

memlayout.h：修改：增加了用户虚存地址空间的图形表示和宏定义 （需仔细理解）。

pmm.[ch]：修改：添加了用于进程退出（do_exit）的内存资源回收的page_remove_pte、unmap_range、exit_range函数和用于创建子进程（do_fork）中拷贝父进程内存空间的copy_range函数，修改了pgdir_alloc_page函数

vmm.[ch]：修改：扩展了mm_struct数据结构，增加了一系列函数

- mm_map/dup_mmap/exit_mmap：设定/取消/复制/删除用户进程的合法内存空间
- copy_from_user/copy_to_user：用户内存空间内容与内核内存空间内容的相互拷贝的实现
- user_mem_check：搜索vma链表，检查是否是一个合法的用户空间范围

◆ kern/process/ （与本次实验有较大关系）

proc.[ch]：修改：扩展了proc_struct数据结构。增加或修改了一系列函数

- setup_pgdir/put_pgdir：创建并设置/释放页目录表
- copy_mm：复制用户进程的内存空间和设置相关内存管理（如页表等）信息
- do_exit：释放进程自身所占内存空间和相关内存管理（如页表等）信息所占空间，唤醒父进程，好让父进程收了自己，让调度器切换到其他进程
- load_icode：被do_execve调用，完成加载放在内存中的执行程序到进程空间，这涉及到对页表等的修改，分配用户栈
- do_execve：先回收自身所占用户空间，然后调用load_icode，用新的程序覆盖内存空间，形成一个执行新程序的新进程
- do_yield：让调度器执行一次选择新进程的过程
- do_wait：父进程等待子进程，并在得到子进程的退出消息后，彻底回收子进程所占的资源（比如子进程的内核栈和进程控制块）
- do_kill：给一个进程设置PF_EXITING标志（“kill”信息，即要它死掉），这样在trap函数中，将根据此标志，让进程退出
- KERNEL_EXECVE/__KERNEL_EXECVE/__KERNEL_EXECVE2：被user_main调用，执行一用户进程

◆ kern/trap/

trap.c：修改：在idt_init函数中，对IDT初始化时，设置好了用于系统调用的中断门（idt[T_SYSCALL]）信息。这主要与syscall的实现相关

◆ user/*

新增的用户程序和用户库

## 用户进程管理

### 实验流程概述

我们在 lab1 中已经讲解过 RISC-V 的特权级。这里简要回顾一下：

- M态（Machine）：最高权限，运行固件OpenSBI，负责早期引导并向 S 态提供服务接口。
- S态（Supervisor）：内核态，操作系统内核运行在此级别，管理内存、中断等。
- U态（User）：用户态，运行普通用户程序，权限受限。

之前我们已经实现了内存的管理和内核进程的建立，但是那都是在内核态，接下来我们将在用户态运行一些程序。

用户程序，也就是我们在计算机系前几年课程里一直在写的那些程序，到底怎样在操作系统上跑起来？

首先需要编译器把用户程序的源代码编译为可以在CPU执行的目标程序，这个目标程序里，既要有执行的代码，又要有关于内存分配的一些信息，告诉我们应该怎样为这个程序分配内存。

我们先不考虑怎样在ucore里运行编译器（编译器其实也是用户程序的一种~~感兴趣的同学可以研究一下怎么把编译原理的课设项目运行在ucore中~~），只考虑ucore如何把编译好的用户程序运行起来。这需要给它分配一些内存，把程序代码加载进来，建立一个进程，然后通过调度让这个用户进程开始执行。

用户程序与内核程序有着本质区别：它们运行在受限制的用户态，无法直接分配内存、访问硬件或执行特权指令。这就产生了一个核心问题：用户程序如何安全地获取操作系统服务？

**系统调用**正是连接用户态与内核态的桥梁。它为用户程序提供了一套标准化的服务接口，使得用户程序能够通过受控的方式使用内核功能。

当用户程序需要操作系统提供服务时，比如一个C程序调用printf()函数进行输出，标准库会将输出请求转换为write系统调用。这个过程涉及从用户态到内核态的特权级切换，具体通过ecall指令实现。ecall指令会触发一个异常事件，使CPU从用户态提升到内核态，并跳转到预设的中断处理程序trap中，在其中层层转发到系统调用函数write进行处理，之后再通过sret指令返回到用户态，到此，中断处理程序的纸飞机终于飞到系统调用手里。

当我们将视线转回到ucore的时候，就会遇到一个**鸡生蛋还是蛋生鸡**的问题，也就是，我们应该如何第一次从S态进入到U态的用户进程呢？

我们之前的内容提到的都是从用户态主动或被动地进入内核态，然后再从内核态返回到用户态的完整流程。但是在ucore的初始化进程中，我们始终处于内核态，因此，我们并不能像之后的用户进程一样完成这样一次完整的特权级切换循环，而是需要在**内核态**触发一个异常，从而借助异常处理机制的返回流程进行上下文的切换，从而第一次进入到用户进程。

关于用户进程的理论讲解可查看附录`用户进程的特征`。

### 用户进程

我们在`proc_init()`函数里初始化进程的时候, 认为启动时运行的ucore程序, 是一个内核进程("第0个"内核进程), 并将其初始化为`idleproc`进程。然后我们新建了一个内核进程执行`init_main()`函数。

我们比较lab4和lab5的`init_main()`有何不同。

```c
// kern/process/proc.c (lab4)
static int init_main(void *arg) {
    cprintf("this initproc, pid = %d, name = \"%s\"\n", current->pid, get_proc_name(current));
    cprintf("To U: \"%s\".\n", (const char *)arg);
    cprintf("To U: \"en.., Bye, Bye. :)\"\n");
    return 0;
}

// kern/process/proc.c (lab5)
static int init_main(void *arg) {
    size_t nr_free_pages_store = nr_free_pages();
    size_t kernel_allocated_store = kallocated();

    int pid = kernel_thread(user_main, NULL, 0);
    if (pid <= 0) {
        panic("create user_main failed.\n");
    }

    while (do_wait(0, NULL) == 0) {
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
```

注意到，lab5新建了一个内核进程，执行函数`user_main()`,这个内核进程里我们将要开始执行用户进程。

`do_wait(0, NULL)`等待子进程退出，也就是等待`user_main()`退出。

我们来看`user_main()`和`do_wait()`里做了什么

```c
// kern/process/proc.c
#define __KERNEL_EXECVE(name, binary, size) ({                          \
            cprintf("kernel_execve: pid = %d, name = \"%s\".\n",        \
                    current->pid, name);                                \
            kernel_execve(name, binary, (size_t)(size));                \
        })

#define KERNEL_EXECVE(x) ({                                             \
            extern unsigned char _binary_obj___user_##x##_out_start[],  \
                _binary_obj___user_##x##_out_size[];                    \
            __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,     \
                            _binary_obj___user_##x##_out_size);         \
        })

#define __KERNEL_EXECVE2(x, xstart, xsize) ({                           \
            extern unsigned char xstart[], xsize[];                     \
            __KERNEL_EXECVE(#x, xstart, (size_t)xsize);                 \
        })

#define KERNEL_EXECVE2(x, xstart, xsize)        __KERNEL_EXECVE2(x, xstart, xsize)

// user_main - kernel thread used to exec a user program
static int
user_main(void *arg) {
#ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    KERNEL_EXECVE(exit);
#endif
    panic("user_main execve failed.\n");
}
```

lab5的Makefile进行了改动， 把用户程序编译到我们的镜像里。

`_binary_obj___user_##x##_out_start`和`_binary_obj___user_##x##_out_size`都是编译的时候自动生成的符号。注意这里的`##x##`，按照C语言宏的语法，会直接把x的变量名代替进去。

于是，我们在`user_main()`所做的，就是执行了

```
kern_execve("exit", _binary_obj___user_exit_out_start,_binary_obj___user_exit_out_size)
```

这么一个函数。

如果你熟悉`execve()`函数，或许已经猜到这里我们做了什么。

实际上，就是加载了存储在这个位置的程序`exit`并在`user_main`这个进程里开始执行。这时`user_main`就从内核进程变成了用户进程。我们在下一节介绍`kern_execve()`的实现。

我们在`user`目录下存储了一些用户程序，在编译的时候放到生成的镜像里。

```c
// user/exit.c
#include <stdio.h>
#include <ulib.h>

int magic = -0x10384;

int main(void) {
    int pid, code;
    cprintf("I am the parent. Forking the child...\n");
    if ((pid = fork()) == 0) {
        cprintf("I am the child.\n");
        yield();
        yield();
        yield();
        yield();
        yield();
        yield();
        yield();
        exit(magic);
    }
    else {
        cprintf("I am parent, fork a child pid %d\n",pid);
    }
    assert(pid > 0);
    cprintf("I am the parent, waiting now..\n");

    assert(waitpid(pid, &code) == 0 && code == magic);
    assert(waitpid(pid, &code) != 0 && wait() != 0);
    cprintf("waitpid %d ok.\n", pid);

    cprintf("exit pass.\n");
    return 0;
}
```

这个用户程序`exit`里我们测试了`fork()` `wait()`这些函数。这些函数都是`user/libs/ulib.h`对系统调用的封装。

```c
// user/libs/ulib.c
#include <defs.h>
#include <syscall.h>
#include <stdio.h>
#include <ulib.h>
void exit(int error_code) {
    sys_exit(error_code);
    //执行完sys_exit后，按理说进程就结束了，后面的语句不应该再执行，
    //所以执行到这里就说明exit失败了
    cprintf("BUG: exit failed.\n"); 
    while (1);
}
int fork(void) { return sys_fork(); }
int wait(void) { return sys_wait(0, NULL); }
int waitpid(int pid, int *store) { return sys_wait(pid, store); }
void yield(void) { sys_yield();}
int kill(int pid) { return sys_kill(pid); }
int getpid(void) { return sys_getpid(); }
```

在用户程序里使用的`cprintf()`也是在`user/libs/stdio.c`重新实现的，和之前比最大的区别是，打印字符的时候需要经过系统调用`sys_putc()`，而不能直接调用`sbi_console_putchar()`。这是自然的，因为只有在Supervisor Mode才能通过`ecall`调用Machine Mode的OpenSBI接口，而在用户态(U Mode)就不能直接使用M mode的接口，而是要通过系统调用。

```c
// user/libs/stdio.c
#include <defs.h>
#include <stdio.h>
#include <syscall.h>

/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
    sys_putc(c);//系统调用
    (*cnt) ++;
}

/* *
 * vcprintf - format a string and writes it to stdout
 *
 * The return value is the number of characters which would be
 * written to stdout.
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
    //注意这里复用了vprintfmt, 但是传入了cputch函数指针
    return cnt;
}
```

下面我们来看这些系统调用的实现。

### 系统调用实现

系统调用，是用户态(U mode)的程序获取内核态（S mode)服务的方法，所以需要在用户态和内核态都加入对应的支持和处理。我们也可以认为用户态只是提供一个调用的接口，真正的处理都在内核态进行。

> **须知**
>
> 在用户进程管理中，有几个关键的系统调用尤为重要：
>
> - sys_fork()用于创建当前进程的副本，生成子进程。父子进程都会从sys_fork()返回，但返回值不同：子进程得到0，父进程得到子进程的PID，这使得两个进程可以执行不同的代码路径。
> - sys_exec()在当前进程内启动一个新程序，保持PID不变但替换整个内存空间和执行代码。fork()和exec()的组合是Unix-like系统中创建新进程的经典方式。
> - sys_exit()用于终止当前进程，释放其占用的资源。
> - sys_wait()使当前进程挂起，等待特定条件（如子进程退出）满足后再继续执行。

首先我们在头文件里定义一些系统调用的编号。

```c
// libs/unistd.h

#endif /* !__LIBS_UNISTD_H__ */
```

我们注意在用户态进行系统调用的核心操作是，通过内联汇编进行`ecall`环境调用。这将产生一个trap, 进入S mode进行异常处理。

```c
// user/libs/syscall.c

```

我们下面看看trap.c是如何转发这个系统调用的。

```c
// kern/trap/trap.c
void exception_handler(struct trapframe *tf) {

    }
}
// kern/syscall/syscall.c
#include <unistd.h>


//这里把系统调用进一步转发给proc.c的do_exit(), do_fork()等函数
static int sys_exit(uint64_t arg[]) {
    int error_code = (int)arg[0];

}
//这里定义了函数指针的数组syscalls, 把每个系统调用编号的下标上初始化为对应的函数指针
static int (*syscalls[])(uint64_t arg[]) = {

};

#define NUM_SYSCALLS        ((sizeof(syscalls)) / (sizeof(syscalls[0])))

void syscall(void) {
    struct trapframe *tf = current->tf;

}
```

这样我们就完成了系统调用的转发。接下来就是在`do_exit(), do_execve()`等函数中进行具体处理了。

我们看看`do_execve()`函数

```c
// kern/mm/vmm.c
bool user_mem_check(struct mm_struct *mm, uintptr_t addr, size_t len, bool write) {
    //检查从addr开始长为len的一段内存能否被用户态程序访问
}
// kern/process/proc.c
// do_execve - call exit_mmap(mm)&put_pgdir(mm) to reclaim memory space of current process
//           - call load_icode to setup new memory space accroding binary prog.
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size) {

}
```

那么我们如何实现`kernel_execve()`函数？

能否直接调用`do_execve()`?

```c
// kern/process/proc.c
static int kernel_execve(const char *name, unsigned char *binary, size_t size) {

}
```

很不幸。这么做行不通。`do_execve()` `load_icode()`里面只是构建了用户程序运行的上下文，但是并没有完成切换。上下文切换实际上要借助中断处理的返回来完成。直接调用`do_execve()`是无法完成上下文切换的。如果是在用户态调用`exec()`, 系统调用的`ecall`产生的中断返回时， 就可以完成上下文切换。

由于目前我们在S mode下，所以不能通过`ecall`来产生中断。我们这里采取一个取巧的办法，用`ebreak`产生断点中断进行处理，通过设置`a7`寄存器的值为10说明这不是一个普通的断点中断，而是要转发到`syscall()`, 这样用一个不是特别优雅的方式，实现了在内核态使用系统调用。

```c
// kern/process/proc.c
// kernel_execve - do SYS_exec syscall to exec a user program called by user_main kernel_thread
static int kernel_execve(const char *name, unsigned char *binary, size_t size) {
    
}
// kern/trap/trap.c
void exception_handler(struct trapframe *tf) {
          /* other cases ... */
    }
}
```

注意我们需要让CPU进入U mode执行`do_execve()`加载的用户程序。进行系统调用`sys_exec`之后，我们在trap返回的时候调用了`sret`指令，这时只要`sstatus`寄存器的`SPP`二进制位为0，就会切换到U mode，但`SPP`存储的是“进入trap之前来自什么特权级”，也就是说我们这里ebreak之后`SPP`的数值为1，sret之后会回到S mode在内核态执行用户程序。所以`load_icode()`函数在构造新进程的时候，会把`SSTATUS_SPP`设置为0，使得`sret`的时候能回到U mode。

### 中断处理

由于用户进程比起内核进程多了一个"用户栈"，也就是每个用户进程会有两个栈，一个内核栈一个用户栈，所以中断处理的代码`trapentry.S`要有一些小变化。关注用户态产生中断时，内核栈和用户栈两个栈顶指针的移动。

```asm
# kern/trap/trapentry.S

#include <riscv.h>

# 若在中断之前处于 U mode(用户态)
# 则 sscratch 保存的是内核栈地址
# 否则中断之前处于 S mode(内核态)，sscratch 保存的是 0

_restore_kernel_sp:
    csrr sp, sscratch #刚才把内核栈指针换到了sscratch, 需要再拿回来
_save_context:
   
_save_kernel_sp:
    # Save unwound kernel stack pointer in sscratch
    addi s0, sp, 36 * REGBYTES
    csrw sscratch, s0
_restore_context:
    

    .globl __alltraps
__alltraps:
    SAVE_ALL

    move  a0, sp
    jal trap
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
   
    .globl forkrets
forkrets:
   
```

### 进程退出

当进程执行完它的工作后，就需要执行退出操作，释放进程占用的资源。ucore分了两步来完成这个工作，首先由进程本身完成大部分资源的占用内存回收工作，然后由此进程的父进程完成剩余资源占用内存的回收工作。为何不让进程本身完成所有的资源回收工作呢？这是因为进程要执行回收操作，就表明此进程还存在，还在执行指令，这就需要内核栈的空间不能释放，且表示进程存在的进程控制块不能释放。所以需要父进程来帮忙释放子进程无法完成的这两个资源回收工作。

为此在用户态的函数库中提供了exit函数，此函数最终访问sys_exit系统调用接口让操作系统来帮助当前进程执行退出过程中的部分资源回收。我们来看看ucore是如何做进程退出工作的。

```c
// /user/libs/ulib.c

void
exit(int error_code) {
    sys_exit(error_code);
    cprintf("BUG: exit failed.\n");
    while (1);
}

// /kern/syscall/syscall.c
static int
sys_exit(uint64_t arg[]) {
    int error_code = (int)arg[0];
    return do_exit(error_code);
}
```

首先，exit函数会把一个退出码error_code传递给ucore，ucore通过执行位于`/kern/process/proc.c`中的内核函数`do_exit`来完成对当前进程的退出处理，主要工作简单地说就是回收当前进程所占的大部分内存资源，并通知父进程完成最后的回收工作，具体流程如下：

```c
// /kern/process/proc.c

int
do_exit(int error_code) {
    // 检查当前进程是否为idleproc或initproc，如果是，发出panic


    // 如果执行到这里，表示代码执行出现错误，发出panic
    panic("do_exit will not return!! %d.\n", current->pid);
}
```

## 实验报告要求

从oslab网站上取得实验代码后，进入目录labcodes/lab5，完成实验要求的各个练习。在实验报告中回答所有练习中提出的问题。在目录labcodes/lab5下存放实验报告，推荐用**markdown**格式。每个小组建一个gitee或者github仓库，对于lab5中编程任务，完成编写之后，再通过git push命令把代码和报告上传到仓库。最后请一定提前或按时提交到git网站。

注意有“LAB5”的注释，代码中所有需要完成的地方（challenge除外）都有“LAB5”和“YOUR CODE”的注释，请在提交时特别注意保持注释，并将“YOUR CODE”替换为自己的学号，并且将所有标有对应注释的部分填上正确的代码。

