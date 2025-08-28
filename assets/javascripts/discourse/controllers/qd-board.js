import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class QdBoardController extends Controller {
  @tracked isLoading = false;
  @tracked nextUpdateMinutes = 3;
  @tracked countdownTimer = null;

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

  // 排序后的前五
  get sortedTop() {
    return (this.model?.top || []).slice().sort((a, b) => a.rank - b.rank).slice(0, 5);
  }

  // 前三名选择器，便于模板定点布局
  get firstUser() {
    return this.sortedTop.find((u) => u.rank === 1) || this.sortedTop[0];
  }
  get secondUser() {
    return this.sortedTop.find((u) => u.rank === 2) || this.sortedTop[1];
  }
  get thirdUser() {
    return this.sortedTop.find((u) => u.rank === 3) || this.sortedTop[2];
  }

  // 其余 4-5 名
  get restList() {
    return this.sortedTop.filter((u) => u.rank > 3);
  }

  medalClass(rank) {
    if (rank === 1) return "board-medal board-medal--gold";
    if (rank === 2) return "board-medal board-medal--silver";
    if (rank === 3) return "board-medal board-medal--bronze";
    return "board-medal board-medal--none";
  }

  // 启动倒计时
  startCountdown() {
    // 清除之前的定时器
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
    }

    // 设置初始倒计时为3分钟
    this.nextUpdateMinutes = 3;

    // 每分钟更新一次倒计时
    this.countdownTimer = setInterval(() => {
      this.nextUpdateMinutes--;
      if (this.nextUpdateMinutes <= 0) {
        this.nextUpdateMinutes = 3; // 重置为3分钟
      }
    }, 60000); // 60秒
  }

  // 清理定时器
  willDestroy() {
    super.willDestroy();
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
    }
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
        // 更新模型数据
        this.model.top = result.leaderboard || [];
        this.model.updatedAt = result.updated_at;
        
        // 重启倒计时
        this.startCountdown();
        
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
}