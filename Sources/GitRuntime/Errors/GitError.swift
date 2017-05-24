
public enum GitError: Error {
    case noRepo(String)
    case opFailed(String)
    case noRemote(String)
}
