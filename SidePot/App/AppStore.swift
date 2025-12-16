import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var me: UserProfile = UserProfile(id: UUID(), username: "me", displayName: "Me")
    @Published var groups: [Group] = []
    @Published var friends: [Friend] = []

    private let api = MockAPI.shared

    func bootstrap() async {
        me = api.getMe()
        refreshAll()
    }

    func refreshAll() {
        groups = api.listGroups()
        friends = api.listFriends()
    }

    func createGroup(name: String) {
        api.createGroup(name: name)
        refreshAll()
    }

    func addFriend(username: String, displayName: String) {
        api.addFriend(username: username, displayName: displayName)
        refreshAll()
    }

    func addMember(groupId: UUID, username: String, displayName: String) {
        let u = api.ensureUser(username: username, displayName: displayName)
        api.addMember(groupId: groupId, userId: u.id)
        refreshAll()
    }

    func isLockedOut() -> Bool {
        api.isLockedOut(userId: me.id)
    }
}
