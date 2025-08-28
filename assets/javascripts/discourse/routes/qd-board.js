import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class QdBoardRoute extends Route {
  async model() {
    try {
      const data = await ajax("/qd/board_data.json");
      return {
        top: data.leaderboard || [],
        updatedAt: data.updated_at || new Date().toISOString()
      };
    } catch (error) {
      console.error("获取排行榜失败:", error);
      // 返回空数据作为降级处理
      return {
        top: [],
        updatedAt: new Date().toISOString()
      };
    }
  }
}
