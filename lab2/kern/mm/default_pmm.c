#include <pmm.h>
#include <list.h>
#include <string.h>
#include <default_pmm.h>

/* 在first fit算法中，分配器维护一个空闲块列表（称为空闲链表），当收到内存请求时，
   会沿着列表扫描，找到第一个足够大的能够满足请求的块。如果选中的块明显大于请求的大小，
   通常会将其分割，剩余部分作为另一个空闲块添加到列表中。
   请参阅严蔚敏《数据结构--C语言版》第196~198页，第8.2节
*/
// LAB2 练习1：你的代码
// 你需要重写这些函数：default_init, default_init_memmap, default_alloc_pages, default_free_pages
/*
 * 首次适应内存分配算法（FFMA）的详细说明
 * (1) 准备工作：为了实现首次适应内存分配算法（FFMA），我们需要使用某种链表来管理空闲内存块。
 *              free_area_t结构体用于管理空闲内存块。首先，你需要熟悉list.h中的list结构体，
 *              这是一个简单的双向链表实现。你应该知道如何使用：list_init, list_add(list_add_after), list_add_before, list_del, list_next, list_prev
 *              另一个重要的技巧是将通用链表结构转换为特定结构体（如struct page）：
 *              你可以找到一些宏：le2page（在memlayout.h中），（在未来的实验中：le2vma（在vmm.h中），le2proc（在proc.h中）等）
 * 
 * (2) default_init：你可以复用示例代码中的default_init函数来初始化free_list并将nr_free设为0。
 *              free_list用于记录空闲内存块。nr_free是空闲内存块的总页数。
 * 
 * (3) default_init_memmap：调用图：kern_init --> pmm_init-->page_init-->init_memmap--> pmm_manager->init_memmap
 *              此函数用于初始化一个空闲块（参数：addr_base，page_number）。
 *              首先，你需要初始化该空闲块中的每个页（在memlayout.h中定义），包括：
 *                  p->flags应设置PG_property位（表示此页有效。在pmm_init函数（在pmm.c中）中，
 *                  PG_reserved位已经被设置在p->flags中）
 *                  如果该页是空闲的且不是空闲块的第一页，则p->property应设为0。
 *                  如果该页是空闲的且是空闲块的第一页，则p->property应设为块的总页数。
 *                  p->ref应设为0，因为该页当前是空闲的，没有引用。
 *                  我们可以使用p->page_link将此页链接到free_list，（例如：list_add_before(&free_list, &(p->page_link));）
 *              最后，我们需要累加空闲块的数量：nr_free += n
 * 
 * (4) default_alloc_pages：在空闲链表中查找第一个空闲块（块大小 >=n）并调整空闲块大小，返回分配块的地址。
 *              (4.1) 你应该像这样搜索空闲链表：
 *                       list_entry_t le = &free_list;
 *                       while((le=list_next(le)) != &free_list) {
 *                       ....
 *                 (4.1.1) 在while循环中，获取page结构体并检查p->property（记录空闲块的页数）是否 >=n？
 *                       struct Page *p = le2page(le, page_link);
 *                       if(p->property >= n){ ...
 *                 (4.1.2) 如果找到这样的p，意味着我们找到了一个空闲块（块大小 >=n），并且前n页可以被分配。
 *                     应该设置该页的一些标志位：PG_reserved =1，PG_property =0
 *                     将这些页从free_list中解除链接
 *                     (4.1.2.1) 如果 (p->property >n)，我们应该重新计算剩余空闲块的页数，
 *                           （例如：le2page(le,page_link))->property = p->property - n;）
 *                 (4.1.3) 重新计算nr_free（剩余所有空闲块的页数）
 *                 (4.1.4) 返回p
 *               (4.2) 如果找不到足够大的空闲块（块大小 >=n），则返回NULL
 * 
 * (5) default_free_pages：将页重新链接到空闲链表中，可能会将小空闲块合并成大空闲块。
 *               (5.1) 根据要释放的块的基地址，搜索空闲链表，找到正确的位置
 *                     （按地址从低到高），并插入这些页。（可能使用list_next, le2page, list_add_before）
 *               (5.2) 重置页的字段，如p->ref, p->flags（PageProperty）
 *               (5.3) 尝试与低地址或高地址的块合并。注意：应正确更改某些页的p->property。
 */
static free_area_t free_area;

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
}

static void
default_init_memmap(struct Page *base, size_t n) {
    assert(n > 0); // 确保初始化的内存块至少包含一个物理页
    struct Page *p = base;

    // 初始化内存块中的所有页
    for (; p != base + n; p ++) {
        assert(PageReserved(p)); // 检查当前的页面是否已经被标记为保留状态
        p->flags = p->property = 0; // 清除页的标志位
        set_page_ref(p, 0); // 准备好被分配
    }
    base->property = n; //设置块的大小，在内存块的第一个页中记录整个块的页数
    SetPageProperty(base); // 标记为属性页，表示是空闲块的头部页
    nr_free += n; // 更新空闲页的计数
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link)); // 链表为空，则直接将内存块添加到链表中
    } else {
        list_entry_t* le = &free_list;
        // 不空的时候，首先遍历空闲链表，找到第一个物理地址大于当前内存块的页
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link)); // 如果遍历完整个链表都没有找到更大的页，则将内存块添加到链表末尾
            }
        }
    }
}

static struct Page *
default_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > nr_free) {
        return NULL; // 没有足够的空闲页
    }
    struct Page *page = NULL; // 存储找到的空闲块的指针，初始化为NULL
    list_entry_t *le = &free_list; //le是链表遍历指针，初始化指向空闲链表的头部
    // first-fit核心算法：找到第一个足够大的空闲块
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        if (p->property >= n) {
            page = p;
            break;
        }
    }
    // 找到了合适的空闲块
    if (page != NULL) {
        list_entry_t* prev = list_prev(&(page->page_link));
        list_del(&(page->page_link));

        // 块分裂：如果空闲块的大小 大于 请求的页数
        if (page->property > n) {
            struct Page *p = page + n; // 计算剩余部分的起始页地址
            p->property = page->property - n; // 设置剩余部分的块大小
            SetPageProperty(p); // 标记剩余部分为空闲块头部
            list_add(prev, &(p->page_link)); // 将剩余部分重新插入到空闲链表中
        }
        nr_free -= n;
        ClearPageProperty(page); // 清除已经分配块的属性位
    }
    return page;
}

static void
default_free_pages(struct Page *base, size_t n) {
    // 传人的参数中，base是要释放的物理页块的起始页指针，n是要释放的页数
    assert(n > 0);
    struct Page *p = base;
    // 重置页面属性
    for (; p != base + n; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    nr_free += n;

    // 释放块插入空闲链表
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }

    // 空闲块合并
    // 向前合并
    list_entry_t* le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (p + p->property == base) { // 检查地址是否连续
            p->property += base->property; // 更新前一块的页表数的值
            ClearPageProperty(base);
            list_del(&(base->page_link)); // 链表中删除当前块
            base = p;
        }
    }
    // 向后合并
    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (base + base->property == p) {
            base->property += p->property;
            ClearPageProperty(p);
            list_del(&(p->page_link));
        }
    }
}

static size_t
default_nr_free_pages(void) {
    return nr_free;
}

static void
basic_check(void) {
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

    assert(page2pa(p0) < npage * PGSIZE);
    assert(page2pa(p1) < npage * PGSIZE);
    assert(page2pa(p2) < npage * PGSIZE);

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    assert(alloc_page() == NULL);

    free_page(p0);
    free_page(p1);
    free_page(p2);
    assert(nr_free == 3);

    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(alloc_page() == NULL);

    free_page(p0);
    assert(!list_empty(&free_list));

    struct Page *p;
    assert((p = alloc_page()) == p0);
    assert(alloc_page() == NULL);

    assert(nr_free == 0);
    free_list = free_list_store;
    nr_free = nr_free_store;

    free_page(p);
    free_page(p1);
    free_page(p2);
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
        count ++, total += p->property;
    }
    assert(total == nr_free_pages());

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
    assert(p0 != NULL);
    assert(!PageProperty(p0));

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
    assert(alloc_pages(4) == NULL);
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
    assert((p1 = alloc_pages(3)) != NULL);
    assert(alloc_page() == NULL);
    assert(p0 + 2 == p1);

    p2 = p0 + 1;
    free_page(p0);
    free_pages(p1, 3);
    assert(PageProperty(p0) && p0->property == 1);
    assert(PageProperty(p1) && p1->property == 3);

    assert((p0 = alloc_page()) == p2 - 1);
    free_page(p0);
    assert((p0 = alloc_pages(2)) == p2 + 1);

    free_pages(p0, 2);
    free_page(p2);

    assert((p0 = alloc_pages(5)) != NULL);
    assert(alloc_page() == NULL);

    assert(nr_free == 0);
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
    }
    assert(count == 0);
    assert(total == 0);
}

const struct pmm_manager default_pmm_manager = {
    .name = "default_pmm_manager",
    .init = default_init,
    .init_memmap = default_init_memmap,
    .alloc_pages = default_alloc_pages,
    .free_pages = default_free_pages,
    .nr_free_pages = default_nr_free_pages,
    .check = default_check,
};

