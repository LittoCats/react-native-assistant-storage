var sql = require('./persistence.store.sql');
var SQLite3 = require('./sqlite3').default;
var db, username, password;

function log(o) {
  console.log(o);
}
exports.config = function(persistence, dbPath) {
  exports.getSession = function(cb) {
    var that = {};
    cb = cb || function() {};
    var conn = new SQLite3(dbPath);
    var session = new persistence.Session(that);
    session.transaction = function(explicitCommit, fn) {
      if (typeof explicitCommit === "function") {
        fn = explicitCommit;
        explicitCommit = false;
      }
      var tx = transaction(conn);
      if (explicitCommit) {
        tx.executeSql("START TRANSACTION", null, function() {
          fn(tx)
        });
      } else {
        fn(tx);
      }
    };
    session.close = function(cb) {
      cb = cb || function() {};
      conn.close().then(cb).catch(cb);
    };
    return session;
  };

  function transaction(conn) {
    var that = {};
    // TODO: add check for db opened or closed
    that.executeSql = function(query, args, successFn, errorFn) {
      if (persistence.debug) {
        log(query);
        args && args.length > 0 && log(args.join(","))
      }
      if (!args) {
        args = []
      }
      args.unshift(query);
      conn.execute.apply(conn, args).then(function(queryResult) {
        if (successFn) {
          if (!queryResult) {
            queryResult = [];
          }
          successFn(queryResult);
        }
      }).catch(function(err) {
        log(err.message);
        that.errorHandler && that.errorHandler(err);
        errorFn && errorFn(null, err);
      });
    }
    that.commit = function(session, callback) {
      session.flush(that, function() {
        that.executeSQL("COMMIT", [], function() {}, callback);
      })
    }
    that.rollback = function(session, callback) {
      that.executeSQL("ROLLBACK", [], function() {}, function() {
        session.clean();
        callback();
      });
    }
    return that;
  }
  ///////////////////////// SQLite dialect
  persistence.sqliteDialect = {
    // columns is an array of arrays, e.g.
    // [["id", "VARCHAR(32)", "PRIMARY KEY"], ["name", "TEXT"]]
    createTable: function(tableName, columns) {
      var tm = persistence.typeMapper;
      var sql = "CREATE TABLE IF NOT EXISTS `" + tableName + "` (";
      var defs = [];
      for (var i = 0; i < columns.length; i++) {
        var column = columns[i];
        defs.push("`" + column[0] + "` " + tm.columnType(column[1]) + (column[2] ? " " + column[2] : ""));
      }
      sql += defs.join(", ");
      sql += ')';
      return sql;
    },
    // columns is array of column names, e.g.
    // ["id"]
    createIndex: function(tableName, columns, options) {
      options = options || {};
      return "CREATE " + (options.unique ? "UNIQUE " : "") + "INDEX IF NOT EXISTS `" + tableName + "__" + columns.join("_") + "` ON `" + tableName + "` (" + columns.map(function(col) {
        return "`" + col + "`";
      }).join(", ") + ")";
    }
  };
  sql.config(persistence, persistence.sqliteDialect);
  return exports;
};