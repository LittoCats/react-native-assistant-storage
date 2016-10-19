import {NativeModules} from 'react-native'
const _StorageAssistant = NativeModules.StorageAssistant

import SessionManager from './session-manager'

// function open(dbPath, callback)
// function callback(error, dbhandle)

// function execute(dbhandle, sql, paramsArray, callback)
// function callback(error[, dataArray])

// function close(dbhandle, callback)
// function callback(error)


export default class Session {

  static open(dbPath) {
    return new Promise(function (resolve, reject) {
      _StorageAssistant.open(dbPath, function (error, dbhandle) {
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          var session = new Session();
          Object.defineProperty(session, '__file__', {get: function () { return dbPath; }});
          Object.defineProperty(session, '__db__', {get: function () { return dbhandle; }});
          resolve(session);
        }
      })
    });
  }  

  execute(sql, ...params) {

    SessionManager.resetTimer(this);

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
  }

  close() {
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

const Home = _StorageAssistant.Home

export {Home};

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