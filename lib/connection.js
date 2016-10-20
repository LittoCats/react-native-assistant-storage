import {NativeModules} from 'react-native'
import md5 from './md5'

const _StorageAssistant = NativeModules.StorageAssistant

// function open(dbPath, callback)
// function callback(error, dbhandle)

// function execute(dbhandle, sql, paramsArray, callback)
// function callback(error[, dataArray])

// function close(dbhandle, callback)
// function callback(error)

const Home = _StorageAssistant.Home
export {Home};

console.log(Home);

var ConnMap = {};

export default class Connection {
  constructor(dbPath) {
    dbPath = Home + '/' + md5(dbPath) + '.db';

    var handle = [];

    Object.defineProperty(this, '__file__', {
      enumerable: true, 
      get: function () { return dbPath; }
    });

    Object.defineProperty(this, '__db__', {
      enumerable: true,
      get: function() { return ConnMap[this.__file__]; }
    });
  }
  isOpen() {
    return !!this.__db__;
  }
  open() {
    // 检查是否已经打开， 如果已经打开，则直接返回
    if (this.isOpen()) return Promise.resolve(this);

    return new Promise((resolve, reject)=>{
      _StorageAssistant.open(this.__file__, (error, handle)=>{
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          ConnMap[this.__file__] = handle;
          resolve(this);
        }
      });
    });
  }

  execute(sql, ...params) {
    return this.open().then((conn)=> {
      return new Promise((resolve, reject)=>{
        _StorageAssistant.execute(this.__db__, sql, params, (error, result)=> {
          if (error) {
            var err = new Error(error.msg);
            err.code = error.code;
            reject(err);
          }else{
            resolve(result);
          }
        });
      });
    });
  }

  close() {
    if (!this.isOpen()) return Promise.resolve(true);

    return new Promise((resolve, reject)=>{
      _StorageAssistant.close(this.__db__, function (error) {
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          resolve(true);
        }
      });
    });
  }
}

Connection.open = function(dbPath) {
  return new Connection(dbPath).open();
}

// dev test

// console.log(_StorageAssistant)

// _StorageAssistant.open('/Users/Littocats/Desktop/StorageAssistant.sqlite3', function (error, dbhandle) {
//   console.log(error, dbhandle);

//   _StorageAssistant.execute(dbhandle, 'CREATE TABLE IF NOT EXISTS COMPANY(ID INT PRIMARY KEY     NOT NULL, NAME           TEXT    NOT NULL, AGE            INT     NOT NULL, ADDRESS        CHAR(50), SALARY         REAL)', [], function (error, result) {
//     console.log(error, result);
//     _StorageAssistant.close(dbhandle, function (error) {
//       console.log(error);
//     });
//   })
// })

// var session;
// Session.open('/Users/Littocats/Desktop/StorageAssistant.sqlite3')
// .then(function (_session) {
//   session = _session;
//   return session.execute('CREATE TABLE IF NOT EXISTS COMPANY(ID INT PRIMARY KEY     NOT NULL, NAME           TEXT    NOT NULL, AGE            INT     NOT NULL, ADDRESS        CHAR(50), SALARY         REAL)');
// }).then(function (result) {
//   console.log(result)
// }).then(function() {
//   return session.close()
// })
// .catch(function (error) {
//   console.log(error)
// })