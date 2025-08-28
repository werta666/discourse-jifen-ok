import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class QdBoardController extends Controller {
  @tracked isLoading = false;

  // 检查是否需要登录
  get requiresLogin() {
    return this.model?.requires_login || false;
  }

  get loginMessage() {
    return this.model?.message || "请登录后查看积分排行榜";
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

  @action
  async refreshBoard() {
    // 预留：后续用 ajax 拉取最新排行榜
    this.isLoading = true;
    try {
      // no-op, 使用路由模型中的模拟数据
    } finally {
      this.isLoading = false;
    }
  }
}