import md5 from './md5'
import SQLite3, {Home} from './sqlite3'

function execute(sql, ... args) {
  args.unshift(sql);

  if (!this.connection) {
    return this.init().then(()=>{
      return execute.apply(this, args);
    });
  }

  return this.connection.execute.apply(this.connection, args);
}

export default class KVStore {
  constructor(store) {
    this.__store__ = Home+ '/' + md5(store) + '.db' 
  }

  init() {
    Object.defineProperty(this, 'connection', {
      value: new SQLite3(this.__store__)
    });
    return execute.call(this, 'CREATE TABLE IF NOT EXISTS MAIN (ID TEXT PRIMARY KEY NOT NULL, AT INTEGER NOT NULL, DATA TEXT);');
  }

  put(key, value) {
    if ('string' != typeof value) value = JSON.stringify(value);

    return execute.call(this, "REPLACE INTO MAIN (ID, AT, DATA) VALUES(?,?,?);", md5(key), new Date().getTime(), value);
  }

  puts(pairs) {
    pairs = 'object' === typeof pairs ? pairs : {};
    var values = [];
    let at = new Date().getTime();
    for (let key in pairs) {
      let value = pairs[key];
      if ('string' != typeof value) value = JSON.stringify(value);

      values.push("('"+ md5(key) +"',"+ at +","+ JSON.stringify(value) +")");
    }

    if (values.length === 0) return Promise.resolve(true);

    let sql = "REPLACE INTO MAIN (ID, AT, DATA) VALUES "+values.join(', ')+';';

    return execute.call(this, sql);
  }

  get(key) {
    return execute.call(this, 'SELECT DATA FROM MAIN WHERE ID = \'' + md5(key) + '\';').then(function (result) {
        return Promise.resolve(result && result.length ? result[0].DATA : undefined);
      });
  }

  gets(keys) {
    var keyMap = {};
    var conditions = [];
    for (key of keys) {
      let vkey = md5(key);
      keyMap[vkey] = key;
      conditions.push("ID = '" + vkey + "'");
    }

    let sql = "SELECT ID, DATA FROM MAIN WHERE " + conditions.join(' or ') + ';';
    return execute.call(this, sql).then(function (results) {
      results = Array.isArray(results) ? results : [];
      var pairs = {};
      for (result of results) {
        pairs[keyMap[result.ID]] = result.DATA;
      }
      return Promise.resolve(pairs);
    });
  }

  remove(key) {
    return execute.call(this, "DELETE FROM MAIN WHERE ID = '" + md5(key) + "';");
  }

  removeBefore(date) {
    return execute.call(this, "DELETE FROM MAIN WHERE AT < " + date.getTime() + ";");
  }

  removeBetween(s, e) {
    var start = s.getTime();
    var end = e.getTime();
    if (start > end) {e = start; start = end; end = e;}
    return execute.call(this, "DELETE FROM MAIN WHERE AT > " + start + " AND AT < " + end + ";");
  }

  count() {
    return execute.call(this, "SELECT COUNT() FROM MAIN;").then(function (result) {
      return Promise.resolve(result[0]['COUNT()']);
    });
  }

  static defaultStore() {
    return DefaultStore;
  }
}

const DefaultStore = new KVStore();

// var store = KVStore.defaultStore();

// store.init().then(function () {
//   // return store.put('username'+Math.random(), 'Littocats'+Math.floor(Math.random()*1000000));
//   return store.puts({username: 'Littocats', password: 'dujuanhuakai', token: md5()});
// }).then(function () {
//   return store.gets(['username', 'password', 'token']);
// }).then(function (result) {

//   console.log(result);

// }).then(function () {
//   return store.count()
// }).then(function (count) {
//   console.log(count);
// }).catch(function (error) {
//   console.log(error);
// })

// SessionManager.Get('/Users/Littocats/Desktop/StorageAssistant.sqlite3')
// .then(function (session) {
//   console.log(session);
// }).catch(function (error) {
//   console.warn(error);
// });

