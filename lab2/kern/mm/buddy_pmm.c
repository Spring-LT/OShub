#include <pmm.h>
#include <list.h>
#include <string.h>
#include <buddy_pmm.h>
#include <stdio.h>

/* ==================== Buddy System 伙伴系统实现 ==================== 
 * 
 * 算法原理：
 * 1. 将内存按 2^n 页大小进行管理（1, 2, 4, 8, 16, ...）
 * 2. 维护多个空闲链表，free_area[k] 管理大小为 2^k 页的空闲块
 * 3. 分配时：如果没有合适大小的块，从更大的块中分裂
 * 4. 释放时：尝试与伙伴块合并成更大的块
 * 
 * 数据结构：
 * - free_area[MAX_ORDER]：每个元素管理特定大小的空闲块链表
 * - Page->property：存储该块的阶数（order），表示块大小为 2^order 页
 */

// ==================== 新增：Buddy System 专用数据结构 ====================
#define MAX_ORDER 11  // 支持最大 2^10 = 1024 页的块

static free_area_t free_area[MAX_ORDER];  // 每个阶数对应一个空闲链表

#define free_list(order) (free_area[order].free_list)
#define nr_free(order) (free_area[order].nr_free)

// ==================== 新增：辅助函数 ====================

/* 计算大于等于 n 的最小 2 的幂次的指数
 * 例如：n=5 返回 3 (因为 2^3=8 >= 5)
 *       n=8 返回 3 (因为 2^3=8 >= 8)
 */
static unsigned int log2_ceil(size_t n) {
    unsigned int order = 0;
    size_t size = 1;
    while (size < n) {
        order++;
        size <<= 1;
    }
    return order;
}

/* 计算 2^order */
static inline size_t pow2(unsigned int order) {
    return 1 << order;
}

/* 判断页号是否为 2^order 的整数倍（用于判断是否是该阶的起始地址）*/
static inline int is_aligned(size_t page_idx, unsigned int order) {
    return (page_idx & ((1 << order) - 1)) == 0;
}

/* 计算伙伴块的页索引
 * 伙伴地址计算：page_idx XOR 2^order
 */
static inline size_t buddy_idx(size_t page_idx, unsigned int order) {
    return page_idx ^ (1 << order);
}

// ==================== 新增：初始化函数 ====================
static void buddy_init(void) {
    // 初始化所有阶数的空闲链表
    for (int i = 0; i < MAX_ORDER; i++) {
        list_init(&free_list(i));
        nr_free(i) = 0;
    }
}

// ==================== 新增：初始化内存映射 ====================
static void buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    
    // 初始化所有页的基本属性
    struct Page *p = base;
    for (; p != base + n; p++) {
        assert(PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }
    
    // 将内存块分解成 2 的幂次大小的块，加入对应的空闲链表
    size_t remaining = n;
    size_t offset = 0;
    
    while (remaining > 0) {
        // 找到最大的 2^order <= remaining
        unsigned int order = 0;
        while (pow2(order + 1) <= remaining && order + 1 < MAX_ORDER) {
            order++;
        }
        
        size_t block_size = pow2(order);
        struct Page *block = base + offset;
        
        // 设置块的属性
        block->property = order;  // 存储块的阶数
        SetPageProperty(block);   // 标记为空闲块头部
        
        // 加入对应阶数的空闲链表
        list_add_before(&free_list(order), &(block->page_link));
        nr_free(order)++;
        
        offset += block_size;
        remaining -= block_size;
    }
}

// ==================== 新增：分配页面 ====================
static struct Page *buddy_alloc_pages(size_t n) {
    assert(n > 0);
    
    // 计算需要的阶数
    unsigned int order = log2_ceil(n);
    
    if (order >= MAX_ORDER) {
        return NULL;  // 请求的块太大
    }
    
    // 从 order 开始查找可用的块
    unsigned int current_order = order;
    while (current_order < MAX_ORDER) {
        if (!list_empty(&free_list(current_order))) {
            // 找到可用块
            break;
        }
        current_order++;
    }
    
    if (current_order >= MAX_ORDER) {
        return NULL;  // 没有足够大的空闲块
    }
    
    // 从链表中取出块
    list_entry_t *le = list_next(&free_list(current_order));
    struct Page *page = le2page(le, page_link);
    list_del(le);
    nr_free(current_order)--;
    
    // 如果找到的块比需要的大，需要分裂
    while (current_order > order) {
        current_order--;
        
        // 分裂成两个伙伴块，右半部分放回空闲链表
        size_t half_size = pow2(current_order);
        struct Page *buddy = page + half_size;
        
        buddy->property = current_order;
        SetPageProperty(buddy);
        
        list_add(&free_list(current_order), &(buddy->page_link));
        nr_free(current_order)++;
    }
    
    // 清除分配块的标记
    ClearPageProperty(page);
    page->property = order;  // 记录分配的阶数，用于释放时恢复
    
    return page;
}

// ==================== 新增：释放页面 ====================
static void buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    
    unsigned int order = log2_ceil(n);
    
    if (order >= MAX_ORDER) {
        return;  // 阶数超出范围
    }
    
    // 重置页面属性
    struct Page *p = base;
    for (; p != base + pow2(order); p++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    
    base->property = order;
    SetPageProperty(base);
    
    // 尝试合并伙伴块
    while (order < MAX_ORDER - 1) {
        // 计算当前块和伙伴块的页索引
        size_t page_idx = base - pages;
        size_t buddy_page_idx = buddy_idx(page_idx, order);
        
        // 检查伙伴是否存在且在有效范围内
        if (buddy_page_idx >= npage) {
            break;
        }
        
        struct Page *buddy_page = &pages[buddy_page_idx];
        
        // 检查伙伴是否空闲且大小相同
        if (!PageProperty(buddy_page) || buddy_page->property != order) {
            break;  // 伙伴不满足合并条件
        }
        
        // 从空闲链表中移除伙伴块
        list_del(&(buddy_page->page_link));
        nr_free(order)--;
        
        // 合并：保留低地址的块
        if (buddy_page < base) {
            base = buddy_page;
        }
        
        // 清除高地址块的标记
        ClearPageProperty(buddy_page < base ? base : buddy_page);
        
        // 更新合并后的块
        order++;
        base->property = order;
    }
    
    // 将合并后的块加入对应的空闲链表
    list_add(&free_list(order), &(base->page_link));
    nr_free(order)++;
}

// ==================== 新增：获取空闲页数 ====================
static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i < MAX_ORDER; i++) {
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
    }
    return total;
}

// ==================== 新增：基础检查函数 ====================
static void buddy_basic_check(void) {
    cprintf("buddy_system: basic_check begin\n");
    
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
    
    // 测试1：分配单页
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);
    
    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
    
    // 释放页面
    free_page(p0);
    free_page(p1);
    free_page(p2);
    
    // 测试2：分配多页
    struct Page *p3 = alloc_pages(4);
    assert(p3 != NULL);
    
    struct Page *p4 = alloc_pages(8);
    assert(p4 != NULL);
    
    free_pages(p3, 4);
    free_pages(p4, 8);
    
    cprintf("buddy_system: basic_check passed\n");
}

// ==================== 新增：完整检查函数 ====================
static void buddy_check(void) {
    cprintf("==================== Buddy System Check Start ====================\n");
    
    buddy_basic_check();
    
    // 保存当前状态
    size_t total_free_pages = buddy_nr_free_pages();
    cprintf("Total free pages: %d\n", total_free_pages);
    
    // ============ 测试1：块分裂 ============
    cprintf("\n[Test 1] Block splitting test\n");
    struct Page *p0 = alloc_pages(1);
    assert(p0 != NULL);
    cprintf("  Allocated 1 page: PASS\n");
    
    struct Page *p1 = alloc_pages(2);
    assert(p1 != NULL);
    cprintf("  Allocated 2 pages: PASS\n");
    
    struct Page *p2 = alloc_pages(4);
    assert(p2 != NULL);
    cprintf("  Allocated 4 pages: PASS\n");
    
    // ============ 测试2：块合并 ============
    cprintf("\n[Test 2] Block merging test\n");
    size_t free_before = buddy_nr_free_pages();
    
    free_pages(p0, 1);
    free_pages(p1, 2);
    free_pages(p2, 4);
    
    size_t free_after = buddy_nr_free_pages();
    assert(free_after == free_before + 1 + 2 + 4);
    cprintf("  Free pages increased by %d: PASS\n", 1 + 2 + 4);
    
    // ============ 测试3：分配不是2的幂次的大小 ============
    cprintf("\n[Test 3] Non-power-of-2 allocation\n");
    struct Page *p3 = alloc_pages(3);  // 应该分配 4 页
    assert(p3 != NULL);
    cprintf("  Allocated 3 pages (rounded to 4): PASS\n");
    
    struct Page *p4 = alloc_pages(5);  // 应该分配 8 页
    assert(p4 != NULL);
    cprintf("  Allocated 5 pages (rounded to 8): PASS\n");
    
    free_pages(p3, 3);
    free_pages(p4, 5);
    
    // ============ 测试4：大块分配 ============
    cprintf("\n[Test 4] Large block allocation\n");
    struct Page *p5 = alloc_pages(64);
    assert(p5 != NULL);
    cprintf("  Allocated 64 pages: PASS\n");
    
    free_pages(p5, 64);
    
    // ============ 测试5：连续分配释放 ============
    cprintf("\n[Test 5] Sequential alloc/free\n");
    struct Page *pages[10];
    for (int i = 0; i < 10; i++) {
        pages[i] = alloc_pages(1);
        assert(pages[i] != NULL);
    }
    cprintf("  Allocated 10 single pages: PASS\n");
    
    for (int i = 0; i < 10; i++) {
        free_pages(pages[i], 1);
    }
    cprintf("  Freed 10 single pages: PASS\n");
    
    // ============ 测试6：验证最终空闲页数 ============
    cprintf("\n[Test 6] Final free pages check\n");
    size_t final_free = buddy_nr_free_pages();
    cprintf("  Initial free pages: %d\n", total_free_pages);
    cprintf("  Final free pages:   %d\n", final_free);
    assert(final_free == total_free_pages);
    cprintf("  Free pages match: PASS\n");
    
    cprintf("\n==================== Buddy System Check PASSED ====================\n");
}

// ==================== 新增：导出 pmm_manager 结构 ====================
const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};

