local Server = WAY.Server
Server.Repository = Server.Repository or {}

local Repo = Server.Repository

-- DB共通: 複数行取得。
function Repo.fetchAll(query, params)
    return MySQL.query.await(query, params or {}) or {}
end

-- DB共通: 1行取得。
function Repo.fetchOne(query, params)
    local rows = Repo.fetchAll(query, params)
    return rows[1]
end

-- DB共通: 更新系クエリ。
function Repo.execute(query, params)
    return MySQL.update.await(query, params or {})
end
