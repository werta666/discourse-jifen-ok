import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class QdBoardController extends Controller {
  @tracked isLoading = false;
  @tracked currentPage = 1;

  // 检查是否需要登录
  get requiresLogin() {
    return this.model?.requires_login || false;
  }

  get loginMessage() {
    return this.model?.message || "请登录后查看积分排行榜";
  }

  // 检查是否为管理员
  get isAdmin() {
    return this.model?.is_admin || false;
  }

  // 获取距离下次更新的分钟数
  get minutesUntilNextUpdate() {
    return this.model?.minutes_until_next_update || 0;
  }

  // 获取更新间隔分钟数
  get updateIntervalMinutes() {
    return this.model?.update_interval_minutes || 5;
  }

  // 分页信息
  get pagination() {
    return this.model?.pagination || {};
  }

  get totalPages() {
    return this.pagination.total_pages || 1;
  }

  get totalCount() {
    return this.pagination.total_count || 0;
  }

  get displayCount() {
    return this.pagination.display_count || 30;
  }

  get pageSize() {
    return this.pagination.page_size || 10;
  }

  get hasPrevPage() {
    return this.currentPage > 1;
  }

  get hasNextPage() {
    return this.currentPage < this.totalPages;
  }

  get pageNumbers() {
    const pages = [];
    const start = Math.max(1, this.currentPage - 2);
    const end = Math.min(this.totalPages, this.currentPage + 2);
    
    for (let i = start; i <= end; i++) {
      pages.push(i);
    }
    return pages;
  }

  // 当前页的排行榜数据
  get currentPageData() {
    return (this.model?.top || []).slice().sort((a, b) => a.rank - b.rank);
  }

  // 前三名选择器（仅在第一页且有前三名时显示）
  get showPodium() {
    return this.currentPage === 1 && this.currentPageData.length >= 3;
  }

  get firstUser() {
    return this.showPodium ? this.currentPageData.find((u) => u.rank === 1) : null;
  }
  get secondUser() {
    return this.showPodium ? this.currentPageData.find((u) => u.rank === 2) : null;
  }
  get thirdUser() {
    return this.showPodium ? this.currentPageData.find((u) => u.rank === 3) : null;
  }

  // 列表显示的数据（第一页时排除前三名，其他页显示全部）
  get listData() {
    if (this.showPodium) {
      return this.currentPageData.filter((u) => u.rank > 3);
    } else {
      return this.currentPageData;
    }
  }

  medalClass(rank) {
    if (rank === 1) return "board-medal board-medal--gold";
    if (rank === 2) return "board-medal board-medal--silver";
    if (rank === 3) return "board-medal board-medal--bronze";
    return "board-medal board-medal--none";
  }

  @action
  async refreshBoard() {
    if (!this.isAdmin) {
      return; // 非管理员不显示刷新按钮，这里作为保护
    }

    this.isLoading = true;
    try {
      const result = await ajax("/qd/force_refresh_board.json", {
        type: "POST"
      });
      
      if (result.success) {
        // 强制刷新后重新加载当前页数据
        await this.loadPage(this.currentPage);
        
        // 显示成功提示
        if (this.appEvents) {
          this.appEvents.trigger("modal-body:flash", {
            text: result.message || "排行榜已刷新",
            messageClass: "success"
          });
        }
      }
    } catch (error) {
      console.error("强制刷新排行榜失败:", error);
      if (this.appEvents) {
        this.appEvents.trigger("modal-body:flash", {
          text: "刷新失败，请稍后重试",
          messageClass: "error"
        });
      }
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async loadPage(page) {
    if (page < 1 || page > this.totalPages) return;
    
    this.isLoading = true;
    this.currentPage = page;
    
    try {
      const result = await ajax(`/qd/board.json?page=${page}`);
      
      // 更新模型数据
      this.model.top = result.top || [];
      this.model.pagination = result.pagination || {};
      this.model.minutes_until_next_update = result.minutes_until_next_update;
      this.model.update_interval_minutes = result.update_interval_minutes;
      this.model.updatedAt = result.updatedAt;
      
    } catch (error) {
      console.error("加载页面数据失败:", error);
      if (this.appEvents) {
        this.appEvents.trigger("modal-body:flash", {
          text: "加载数据失败，请稍后重试",
          messageClass: "error"
        });
      }
    } finally {
      this.isLoading = false;
    }
  }

  @action
  goToPage(page) {
    this.loadPage(page);
  }

  @action
  prevPage() {
    if (this.hasPrevPage) {
      this.loadPage(this.currentPage - 1);
    }
  }

  @action
  nextPage() {
    if (this.hasNextPage) {
      this.loadPage(this.currentPage + 1);
    }
  }
}