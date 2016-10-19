/**
* 管理 session 
* 如果 session 在指定的超时间内没有使用，则自动关闭
*/

import Session from './session'
const DefaultTimeout = 6000; // 默认超时时间为 60s

class SessionManager {
  constructor(props) {
    this.sessions = {};
    this.timers = {};
  }
  
  resetTimer(session) {
    return

    // session = this.sessions[session.__file__];

    // if (!session) return;

    // var timer = this.timers[session.__file__];
    // if (timer) { clearTimeout(timer); }

    // timer = setTimeout(()=>{

    //   this.sessions[session.__file__] = undefined
    //   this.timers[session.__file__] = undefined

    //   session.close()
    //   .then(function () {
    //     console.log('sqlite3 db handle has been closed .');
    //   })
    //   .catch(function (error) {
    //     console.warn(error);
    //   });

    // }, this.timeout ? this.timeout : DefaultTimeout);

    // this.timers = timer;
  }

  Get(dbPath) {
    var session = this.sessions[dbPath];
    if (session) {
      this.resetTimer(session);
      return new Promise(function (resolve) { resolve(session); });
    }

    return new Promise((resolve, reject)=> {
      Session.open(dbPath)
      .then((session)=> {

        this.sessions[session.__file__] = session;

        this.resetTimer(session);

        resolve(session);

      }).catch(function (error) {
        reject(error);
      })
    });
  }
}

export default new SessionManager();