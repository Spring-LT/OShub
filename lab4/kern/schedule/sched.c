#include <list.h>
#include <sync.h>
#include <proc.h>
#include <sched.h>
#include <assert.h>

// wakeup_proc - 唤醒进程，将其状态设置为 PROC_RUNNABLE
// 对应指导书"练习2"中 do_fork 的步骤6
// 功能：将进程状态从 SLEEPING/UNINIT 改为 RUNNABLE，使其可被调度
// 实现位置：kern/schedule/sched.c:8
void
wakeup_proc(struct proc_struct *proc) {
    assert(proc->state != PROC_ZOMBIE && proc->state != PROC_RUNNABLE);
    proc->state = PROC_RUNNABLE;
}

// schedule - 调度器主函数，实现 FIFO 调度策略
// 对应指导书"实验执行流程概述"和"内核线程管理"章节
// 功能：从 proc_list 中按 FIFO 顺序找下一个 RUNNABLE 进程，调用 proc_run 切换
// 实现位置：kern/schedule/sched.c:14
void
schedule(void) {
    bool intr_flag;
    list_entry_t *le, *last;
    struct proc_struct *next = NULL;
    local_intr_save(intr_flag);  // 关中断，保护调度过程的原子性
    {
        current->need_resched = 0;  // 清除调度标志
        // 从当前进程的下一个开始查找（如果是 idleproc 则从链表头开始）
        last = (current == idleproc) ? &proc_list : &(current->list_link);
        le = last;
        do {
            if ((le = list_next(le)) != &proc_list) {
                next = le2proc(le, list_link);
                if (next->state == PROC_RUNNABLE) {
                    break;  // 找到第一个 RUNNABLE 进程
                }
            }
        } while (le != last);
        // 如果没找到可运行进程，选择 idleproc
        if (next == NULL || next->state != PROC_RUNNABLE) {
            next = idleproc;
        }
        next->runs ++;  // 增加运行次数计数
        if (next != current) {
            proc_run(next);  // 切换到选中的进程，这个代码在 proc.h中实现的
        }
    }
    local_intr_restore(intr_flag);  // 恢复中断
}

