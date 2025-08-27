import Route from "@ember/routing/route";
// TODO: 后续接入接口：import { ajax } from "discourse/lib/ajax";

export default class QdBoardRoute extends Route {
  async model() {
    // TODO: 替换为后端接口：await ajax("/qd/board.json")
    return {
      top: [
        { username: "alice", points: 520, rank: 1 },
        { username: "bob", points: 460, rank: 2 },
        { username: "charlie", points: 420, rank: 3 },
        { username: "david", points: 380, rank: 4 },
        { username: "eve", points: 350, rank: 5 }
      ],
      updatedAt: new Date().toISOString()
    };
  }
}